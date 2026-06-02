import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show UpdateKind, Value, Variable;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' show CallOptions;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/app_constants.dart';
import '../data/local/database.dart';
import '../data/local/secure_token_storage.dart';
import '../data/remote/grpc_clients.dart';
import '../domain/providers/app_providers.dart';
import '../domain/providers/sync_status_provider.dart';
import '../generated/proto/google/protobuf/timestamp.pb.dart' as proto_ts;
import '../generated/proto/sync.pb.dart' as sync_pb;
import '../generated/proto/sync.pbenum.dart' as sync_enum;
import '../generated/proto/sync.pbgrpc.dart';
import 'sync_event.dart';

/// 离线同步引擎
///
/// 职责:
/// 1. 定期将 sync_queue 中的待同步操作通过 gRPC PushOperations 推送到服务端
/// 2. 通过 WebSocket 监听服务端推送的变更通知
/// 3. 收到通知后通过 gRPC PullChanges 拉取增量变更并写入本地
class SyncEngine {
  final AppDatabase? _db;
  final SyncServiceClient? _syncClient;
  final SharedPreferences? _prefs;
  final TokenStorage? _tokenStorage;

  Timer? _syncTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  /// Cached SecurityContext for WebSocket TLS (avoids re-parsing PEM on every reconnect).
  SecurityContext? _securityContext;

  /// Cached HttpClient for WebSocket TLS (avoids connection pool leaks on reconnect).
  HttpClient? _secureHttpClient;

  /// Consecutive sync failures - used for exponential backoff.
  int _consecutiveFailures = 0;
  static const _maxBackoffSeconds = 300; // 5 minutes cap

  /// Sync cycle counter for periodic dead-letter retry.
  int _syncCycleCount = 0;

  /// Guard against concurrent sync operations (pull + retry interleaving).
  bool _isSyncing = false;

  /// In-memory cache of lastSyncTs for fast heartbeat comparison.
  /// Authoritative value lives in SQLite (sync_metadata table).
  int _lastSyncTsMs = 0;

  // Dead-letter retry configuration
  static const _deadLetterMaxRetries = 5;
  static const _deadLetterBatchSize = 20;
  static const _deadLetterPurgeDays = 30;
  static const _deadLetterRetryCycleInterval = 10;

  static const _knownEntityTypes = {
    'transaction', 'account', 'category', 'loan',
    'loan_group', 'investment', 'fixed_asset', 'budget',
    'category_merge',
  };

  static const _wsReconnectBaseDelay = 1; // seconds
  static const _wsReconnectMaxDelay = 60; // seconds
  static const _wsReconnectMaxTotalDelay = 90; // seconds (includes jitter)

  /// Async mutex - prevents concurrent push/pull from corrupting state.
  /// At most one sync operation (push or pull) runs at a time.
  /// Additional requests are coalesced: if a pull is requested while syncing,
  /// it runs once after the current operation completes (not N times).
  bool _syncing = false;
  bool _pullRequested = false;
  bool _pushRequested = false;

  /// Callback to update sync status UI. Set by the provider.
  void Function(SyncEvent event)? onSyncEvent;

  /// 最后一次成功拉取的服务端时间戳(毫秒)
  static const _lastSyncTsKey = 'sync_last_pull_ts';

  SyncEngine(AppDatabase db, SyncServiceClient syncClient, SharedPreferences prefs,
      {TokenStorage? tokenStorage})
      : _db = db,
        _syncClient = syncClient,
        _prefs = prefs,
        _tokenStorage = tokenStorage;

  /// Inert engine that performs no operations.
  /// Used in production when no user is logged in (all methods are safe no-ops
  /// due to the `if (_disposed) return` / null guards).
  SyncEngine.inert()
      : _db = null,
        _syncClient = null,
        _prefs = null,
        _tokenStorage = null;

  /// Test-only constructor: provides a real DB but no network.
  @visibleForTesting
  SyncEngine.forTesting(AppDatabase db)
      : _db = db,
        _syncClient = null,
        _prefs = null,
        _tokenStorage = null;

  void start() {
    if (_disposed) return;

    // 定期 push + pull(pull 作为 WS 通知丢失的兜底)
    _syncTimer = Timer.periodic(
      const Duration(seconds: AppConstants.syncIntervalSeconds),
      (_) => _syncCycle(),
    );

    // 启动时立即尝试
    _syncCycle();
    _connectWebSocket();
  }

  /// Full sync cycle: push pending ops then pull remote changes.
  ///
  /// Uses `_isSyncing` to prevent timer re-entry. If a timer tick arrives
  /// while a cycle is in progress, it is silently dropped — acceptable since
  /// the next tick (30s later) will execute normally. WS-triggered pulls
  /// use their own coalescing via `_pullRequested`.
  Future<void> _syncCycle() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      _syncCycleCount++;
      await _pushPendingOps();
      await _pullChanges();

      // Retry dead-letter ops on first cycle (startup) and every 10th cycle
      if (_syncCycleCount == 1 || _syncCycleCount % _deadLetterRetryCycleInterval == 0) {
        await _retryDeadLetterOps();
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Public API: force an immediate pull from server.
  /// Call this from pull-to-refresh, app resume, etc.
  Future<void> forcePull() async {
    await _pullChanges();
  }

  // ─────────── Push: 本地 → 服务端 ───────────

  Future<void> _pushPendingOps() async {
    if (_disposed) return;
    if (!_tryAcquireSyncLock()) {
      // Coalesce: mark that a push is needed after current operation
      _pushRequested = true;
      return;
    }
    dev.log('[Sync] _pushPendingOps: started');
    onSyncEvent?.call(const SyncEvent.syncStarted());

    try {
      // Note: empty-path early return is inside try so that finally{} always
      // releases the lock. This is intentional - no double-release risk because
      // _tryAcquireSyncLock() is a simple bool flag, not a reentrant counter.
      final pendingOps =
          await _db!.getPendingSyncOps(AppConstants.syncBatchSize);
      dev.log('[Sync] _pushPendingOps: pendingOps count=${pendingOps.length}');
      if (pendingOps.isEmpty) {
        _onSyncSuccess(); // Reset backoff - no pending ops is not a failure
        onSyncEvent?.call(const SyncEvent.syncCompleted());
        return;
      }

      // 转换为 proto SyncOperation
      final protoOps = pendingOps.map(_toProtoOp).toList();
      final request = sync_pb.PushOperationsRequest()
        ..operations.addAll(protoOps);

      final response = await _syncClient!.pushOperations(
        request,
        options: CallOptions(timeout: const Duration(seconds: 10)),
      );

      // 标记成功上传的
      final failedSet = response.failedIds.toSet();
      final succeededIds = pendingOps
          .where((op) => !failedSet.contains(op.id))
          .map((op) => op.id)
          .toList();

      // Only mark succeeded ops as uploaded; failed ops remain in queue for retry.
      // R7 fix: previously marked ALL ops (including failed) which caused data loss.
      if (succeededIds.isNotEmpty) {
        await _db!.markSyncOpsUploaded(succeededIds);

        // Mark transaction entities as synced for UI display
        final syncedTxnIds = pendingOps
            .where((op) => !failedSet.contains(op.id) && op.entityType == 'transaction')
            .map((op) => op.entityId)
            .toList();
        if (syncedTxnIds.isNotEmpty) {
          await _db!.markTransactionsSynced(syncedTxnIds);
        }
      }

      // Increment retry count for failed ops (exponential backoff)
      final failedIds = pendingOps
          .where((op) => failedSet.contains(op.id))
          .map((op) => op.id)
          .toList();
      if (failedIds.isNotEmpty) {
        await _db!.incrementSyncOpRetry(failedIds);
        // Mark corresponding transactions as failed if retries exhausted
        final deadTxnIds = <String>[];
        for (final op in pendingOps) {
          if (failedSet.contains(op.id) &&
              op.entityType == 'transaction' &&
              // op.retryCount is the value BEFORE increment; after incrementSyncOpRetry
              // it becomes retryCount+1. So >= 9 here means 10th failure total → mark dead.
              op.retryCount >= 9) {
            deadTxnIds.add(op.entityId);
          }
        }
        if (deadTxnIds.isNotEmpty) {
          await _db!.markTransactionsFailed(deadTxnIds);
        }
        onSyncEvent?.call(PushFailed(failedIds.length));
      }

      dev.log('[Sync] _pushPendingOps: pushed ${succeededIds.length}/${pendingOps.length} ops');
      onSyncEvent?.call(const SyncEvent.serverReachable());
      _onSyncSuccess();
    } catch (e) {
      dev.log('[Sync] _pushPendingOps: push failed: $e');
      onSyncEvent?.call(const SyncEvent.serverUnreachable());
      _onSyncFailure();
    } finally {
      dev.log('[Sync] _pushPendingOps: finished');
      onSyncEvent?.call(const SyncEvent.syncStopped());
      _releaseSyncLock();
      _drainPendingRequests();
    }
  }

  sync_pb.SyncOperation _toProtoOp(SyncQueueData op) {
    final ts = op.timestamp;
    return sync_pb.SyncOperation(
      id: op.id,
      entityType: op.entityType,
      entityId: op.entityId,
      opType: _mapOpType(op.opType),
      payload: op.payload,
      clientId: op.clientId,
      timestamp: proto_ts.Timestamp(
        seconds: Int64(ts.millisecondsSinceEpoch ~/ 1000),
        nanos: (ts.millisecondsSinceEpoch % 1000) * 1000000,
      ),
    );
  }

  sync_enum.OperationType _mapOpType(String opType) {
    switch (opType) {
      case 'create':
        return sync_enum.OperationType.OPERATION_TYPE_CREATE;
      case 'update':
        return sync_enum.OperationType.OPERATION_TYPE_UPDATE;
      case 'delete':
        return sync_enum.OperationType.OPERATION_TYPE_DELETE;
      default:
        return sync_enum.OperationType.OPERATION_TYPE_UNSPECIFIED;
    }
  }

  // ─────────── Pull: 服务端 → 本地 ───────────

  Future<void> _pullChanges() async {
    if (_disposed) return;
    if (!_tryAcquireSyncLock()) {
      // Coalesce: mark that a pull is needed after current operation
      _pullRequested = true;
      return;
    }
    try {
      await _doPull();
    } finally {
      _releaseSyncLock();
      _drainPendingRequests();
    }
  }

  Future<void> _doPull() async {
    dev.log('[Sync] _doPull: started');
    try {
      final lastTsMs = await _db!.getSyncMetaInt(_lastSyncTsKey) ?? 0;
      _lastSyncTsMs = lastTsMs;
      final userId = _prefs!.getString(AppConstants.userIdKey);
      if (userId == null) return;

      final since = proto_ts.Timestamp(
        seconds: Int64(lastTsMs ~/ 1000),
        nanos: (lastTsMs % 1000) * 1000000,
      );

      final familyId = _prefs!.getString(AppConstants.familyIdKey) ?? '';

      int totalPulled = 0;
      String pageToken = '';

      // Paginated pull loop
      bool deadLetterDirty = false;
      do {
        if (_disposed) return;

        final request = sync_pb.PullChangesRequest(
          since: since,
          clientId: 'client_$userId',
        );
        if (familyId.isNotEmpty) {
          request.familyId = familyId;
        }
        request.pageSize = 100;
        if (pageToken.isNotEmpty) {
          request.pageToken = pageToken;
        }

        final response = await _syncClient!.pullChanges(request);

        // Apply ops individually with error isolation.
        // Failed ops go to dead-letter table; remaining ops + checkpoint still advance.
        await _db!.transaction(() async {
          for (final op in response.operations) {
            try {
              await _applyRemoteOp(op);
            } catch (e, st) {
              deadLetterDirty = true;
              dev.log(
                '[Sync] _doPull: failed to apply op ${op.id} '
                '(${op.entityType}/${op.entityId}): $e\n$st',
              );
              // Insert into dead-letter table (idempotent)
              final opTimestampMs = op.hasTimestamp()
                  ? op.timestamp.seconds.toInt() * 1000 +
                      op.timestamp.nanos ~/ 1000000
                  : 0;
              await _db!.insertDeadLetterOp(
                opId: op.id,
                entityType: op.entityType,
                entityId: op.entityId,
                opType: op.opType.name,
                timestampMs: opTimestampMs,
                error: e.toString(),
                payload: op.payload,
              );
            }
          }

          // Per-page checkpoint: advance cursor after each page so that an
          // interrupted multi-page pull doesn't replay already-applied ops.
          // On the final page, prefer server_time (authoritative clock);
          // on intermediate pages, use the last op's timestamp.
          if (response.nextPageToken.isEmpty && response.hasServerTime()) {
            // Final page (no more pages) — use server-provided authoritative time.
            final serverMs =
                response.serverTime.seconds.toInt() * 1000 +
                response.serverTime.nanos ~/ 1000000;
            await _db!.setSyncMetaInt(_lastSyncTsKey, serverMs);
            _lastSyncTsMs = serverMs;
          } else if (response.operations.isNotEmpty) {
            // Intermediate page — use max op timestamp as watermark.
            // Server uses strict `> since` semantics, so same-timestamp ops
            // spanning pages could be skipped. We subtract 1ms to turn the
            // next pull into `> (T-1ms)` ≡ `>= T`, accepting redundant re-
            // delivery of at most a few same-timestamp ops (handled by
            // idempotent balance logic). We use max() rather than last-op
            // in case a malformed op without timestamp appears at the tail.
            final maxOpMs = response.operations.fold<int>(0, (acc, op) {
              if (!op.hasTimestamp()) return acc;
              final ms = op.timestamp.seconds.toInt() * 1000 +
                  op.timestamp.nanos ~/ 1000000;
              return max(acc, ms);
            });
            // Debug: verify ops are ordered by timestamp ASC
            assert(() {
              int prev = 0;
              for (final op in response.operations) {
                if (!op.hasTimestamp()) continue;
                final ms = op.timestamp.seconds.toInt() * 1000 +
                    op.timestamp.nanos ~/ 1000000;
                if (ms < prev) {
                  dev.log('WARNING: ops not sorted by timestamp',
                      name: 'SyncEngine');
                  break;
                }
                prev = ms;
              }
              return true;
            }());
            // Subtract 1ms so next `> since` includes ops at maxOpMs.
            final checkpointMs = maxOpMs > 0 ? maxOpMs - 1 : 0;
            if (checkpointMs > _lastSyncTsMs) {
              await _db!.setSyncMetaInt(_lastSyncTsKey, checkpointMs);
              _lastSyncTsMs = checkpointMs;
            }
          }
        });
        totalPulled += response.operations.length;

        pageToken = response.nextPageToken;
      } while (pageToken.isNotEmpty);

      dev.log('[Sync] _doPull: pulled $totalPulled changes, done');
      onSyncEvent?.call(const SyncEvent.syncCompleted());
      onSyncEvent?.call(const SyncEvent.serverReachable());
      _onSyncSuccess();

      // Emit dead-letter count: on first sync (UI bootstrap) or when something failed
      if (deadLetterDirty || _syncCycleCount == 1) {
        final dlCount = await _db!.getDeadLetterCount();
        onSyncEvent?.call(SyncEvent.deadLetterCountUpdated(dlCount));
      }
    } catch (e) {
      dev.log('[Sync] _doPull: pull failed: $e');
      onSyncEvent?.call(const SyncEvent.serverUnreachable());
      _onSyncFailure();
    }
  }

  /// Retry dead-letter ops that might succeed after an app update.
  ///
  /// Called on engine start and every 10th sync cycle.
  /// Uses exponential backoff: 1h, 4h, 16h, 64h, 256h between retries.
  /// Auto-purges ops older than 30 days.
  ///
  /// Acquires the sync lock to prevent interleaving with WS-triggered pulls.
  Future<void> _retryDeadLetterOps() async {
    if (_disposed || _db == null) return;
    if (!_tryAcquireSyncLock()) return; // Skip if sync in progress

    try {
      // Purge expired ops first
      final purged = await _db!.purgeOldDeadLetterOps(days: _deadLetterPurgeDays);
      if (purged > 0) {
        dev.log('[Sync] _retryDeadLetterOps: purged $purged expired ops');
      }

      // Get ops eligible for retry (respects backoff via nextRetryAfter)
      final ops = await _db!.getDeadLetterOps(maxRetries: _deadLetterMaxRetries, limit: _deadLetterBatchSize);
      if (ops.isEmpty) return;

      dev.log('[Sync] _retryDeadLetterOps: attempting ${ops.length} ops');
      int succeeded = 0;

      for (final deadOp in ops) {
        if (_disposed) return;
        try {
          // Reconstruct the original SyncOperation with preserved opType + timestamp
          final resolvedOpType = sync_enum.OperationType.values.firstWhere(
            (v) => v.name == deadOp.opType,
            orElse: () => sync_enum.OperationType.OPERATION_TYPE_UNSPECIFIED,
          );
          // Skip ops with unresolvable opType (proto version mismatch)
          if (resolvedOpType ==
              sync_enum.OperationType.OPERATION_TYPE_UNSPECIFIED) {
            dev.log(
              '[Sync] _retryDeadLetterOps: skipping ${deadOp.opId} — '
              'unresolvable opType "${deadOp.opType}"',
            );
            await _db!.incrementDeadLetterRetry(deadOp.opId);
            continue;
          }
          final opProto = sync_pb.SyncOperation(
            id: deadOp.opId,
            entityType: deadOp.entityType,
            entityId: deadOp.entityId,
            payload: deadOp.payload,
            opType: resolvedOpType,
          );
          // Restore original timestamp so LWW comparison works correctly
          if (deadOp.timestampMs > 0) {
            opProto.timestamp = proto_ts.Timestamp(
              seconds: Int64(deadOp.timestampMs ~/ 1000),
              nanos: (deadOp.timestampMs % 1000) * 1000000,
            );
          }
          await _db!.transaction(() async {
            await _applyRemoteOp(opProto);
            await _db!.removeDeadLetterOp(deadOp.opId);
          });
          succeeded++;
          dev.log(
            '[Sync] dead-letter recovered: ${deadOp.opId}, '
            'entityType=${deadOp.entityType}, opType=${deadOp.opType}, '
            'ts=${deadOp.timestampMs}',
          );
        } catch (e) {
          dev.log(
            '[Sync] _retryDeadLetterOps: op ${deadOp.opId} still failing: $e',
          );
          await _db!.incrementDeadLetterRetry(deadOp.opId);
        }
      }

      if (succeeded > 0) {
        dev.log('[Sync] _retryDeadLetterOps: $succeeded ops recovered');
      }

      // Emit updated count
      final remaining = await _db!.getDeadLetterCount();
      onSyncEvent?.call(SyncEvent.deadLetterCountUpdated(remaining));
    } catch (e) {
      dev.log('[Sync] _retryDeadLetterOps: error: $e');
    } finally {
      _releaseSyncLock();
      _drainPendingRequests();
    }
  }

  /// 将远程操作应用到本地数据库
  ///
  /// Implements Last-Writer-Wins (LWW) conflict resolution:
  /// - DELETE operations are always applied (delete is a terminal state)
  /// - For CREATE/UPDATE: compare remote op timestamp with local entity's
  ///   updated_at. Only apply if remote timestamp >= local updated_at.
  ///
  /// Exceptions bubble up to the caller. In _doPull, each op is individually
  /// try-caught so failures go to the dead-letter table without blocking
  /// other ops.
  Future<void> _applyRemoteOp(sync_pb.SyncOperation op) async {
    final isDelete =
        op.opType == sync_enum.OperationType.OPERATION_TYPE_DELETE;

    // For DELETE: skip payload parsing (payload may be empty/null).
    // For CREATE/UPDATE: decode payload + apply LWW/R9 checks.
    Map<String, dynamic> payload;
    if (isDelete) {
      final state = await _getLocalEntityState(op.entityType, op.entityId);
      if (state.isDeleted) return; // Already deleted — idempotent
      // Entity doesn't exist locally — nothing to delete (safe no-op).
      // But for unknown entity types, throw to enter dead-letter.
      if (state.updatedAt == null) {
        if (!_knownEntityTypes.contains(op.entityType)) {
          throw UnsupportedError(
            'Unknown entity_type: ${op.entityType} (op: ${op.id})',
          );
        }
        return;
      }
      payload = const {};
    } else {
      payload = jsonDecode(op.payload) as Map<String, dynamic>;

      // Single query for both R9 + LWW checks (halves DB round-trips).
      final state = await _getLocalEntityState(op.entityType, op.entityId);

      // R9 fix: DELETE is terminal — reject CREATE/UPDATE on deleted entity.
      if (state.isDeleted) {
        dev.log(
          '[Sync] R9 terminal skip ${op.entityType}/${op.entityId} '
          '(locally deleted, ignoring ${op.opType})',
        );
        return;
      }

      // LWW check: skip if local data is newer
      final remoteTimestampMs = op.hasTimestamp()
          ? op.timestamp.seconds.toInt() * 1000 +
              op.timestamp.nanos ~/ 1000000
          : 0;
      if (state.updatedAt != null &&
          state.updatedAt!.millisecondsSinceEpoch > remoteTimestampMs) {
        dev.log(
          '[Sync] LWW skip ${op.entityType}/${op.entityId} '
          '(local=${state.updatedAt!.millisecondsSinceEpoch}, remote=$remoteTimestampMs)',
        );
        return;
      }
    }

    // Single dispatch for all op types
    switch (op.entityType) {
      case 'transaction':
        await _applyTransactionOp(op.opType, op.entityId, payload);
        break;
      case 'account':
        await _applyAccountOp(op.opType, op.entityId, payload);
        break;
      case 'category':
        await _applyCategoryOp(op.opType, op.entityId, payload);
        break;
      case 'loan':
        await _applyLoanOp(op.opType, op.entityId, payload);
        break;
      case 'loan_group':
        await _applyLoanGroupOp(op.opType, op.entityId, payload);
        break;
      case 'investment':
        await _applyInvestmentOp(op.opType, op.entityId, payload);
        break;
      case 'fixed_asset':
        await _applyFixedAssetOp(op.opType, op.entityId, payload);
        break;
      case 'budget':
        await _applyBudgetOp(op.opType, op.entityId, payload);
        break;
      case 'category_merge':
        // 合并操作从服务端拉取时，本地执行同样的合并
        await _applyCategoryMergeOp(op.entityId, payload);
        break;
      default:
        // Throw so unknown entity types enter dead-letter table.
        // When client upgrades with new handler, retry will succeed.
        throw UnsupportedError(
          'Unknown entity_type: ${op.entityType} (op: ${op.id})',
        );
    }
  }

  /// Get local entity state in a single DB query (avoids double-fetch).
  /// Returns both deletion status and updatedAt for LWW + R9 checks.
  /// updatedAt == null means entity doesn't exist locally.
  Future<({bool isDeleted, DateTime? updatedAt})> _getLocalEntityState(
      String entityType, String entityId) async {
    switch (entityType) {
      case 'transaction':
        final txn = await _db!.getTransactionById(entityId);
        return (
          isDeleted: txn != null && txn.deletedAt != null,
          updatedAt: txn?.updatedAt,
        );
      case 'account':
        final acc = await _db!.getAccountById(entityId);
        return (
          isDeleted: acc != null && !acc.isActive,
          updatedAt: acc?.updatedAt,
        );
      case 'category':
        // Categories don't track updatedAt (always accept remote ops via LWW).
        // Use DateTime(0) sentinel to indicate "exists" without LWW protection.
        // null = doesn't exist; DateTime(0) = exists but no LWW.
        final catExists = await _db!.categoryExists(entityId);
        return (isDeleted: false, updatedAt: catExists ? DateTime(0) : null);
      case 'loan':
        final loan = await _db!.getLoanById(entityId);
        return (
          isDeleted: loan != null && loan.deletedAt != null,
          updatedAt: loan?.updatedAt,
        );
      case 'loan_group':
        final group = await _db!.getLoanGroupById(entityId);
        return (
          isDeleted: group != null && group.deletedAt != null,
          updatedAt: group?.updatedAt,
        );
      case 'investment':
        final inv = await _db!.getInvestmentById(entityId);
        return (
          isDeleted: inv != null && inv.deletedAt != null,
          updatedAt: inv?.updatedAt,
        );
      case 'fixed_asset':
        final asset = await _db!.getFixedAssetById(entityId);
        return (
          isDeleted: asset != null && asset.deletedAt != null,
          updatedAt: asset?.updatedAt,
        );
      case 'budget':
        final budget = await _db!.getBudgetById(entityId);
        return (isDeleted: false, updatedAt: budget?.updatedAt);
      default:
        return (isDeleted: false, updatedAt: null);
    }
  }

  Future<void> _applyTransactionOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
        // Check if already exists (idempotent)
        final existing = await _db!.getTransactionById(entityId);
        if (existing != null) break; // already applied

        final txnDateCreate = DateTime.tryParse(payload['txn_date'] ?? '') ??
            DateTime.now();
        await _db!.insertOrUpdateTransaction(
          id: entityId,
          userId: payload['user_id'] ?? '',
          accountId: payload['account_id'] ?? '',
          categoryId: payload['category_id'] ?? '',
          amount: (payload['amount'] as num?)?.toInt() ?? 0,
          amountCny: (payload['amount_cny'] as num?)?.toInt() ?? 0,
          type: payload['type'] ?? 'expense',
          note: payload['note'] ?? '',
          txnDate: txnDateCreate,
        );
        // Apply balance delta for the new transaction
        final createAccountId = payload['account_id'] ?? '';
        final createAmountCny = (payload['amount_cny'] as num?)?.toInt() ?? 0;
        final createType = payload['type'] ?? 'expense';
        if (createAccountId.isNotEmpty && createAmountCny != 0 && createType != 'transfer') {
          final delta = createType == 'income' ? createAmountCny : -createAmountCny;
          await _db!.updateAccountBalance(createAccountId, delta);
        }
        break;
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        // IMPORTANT: fetch oldTxn BEFORE overwriting. The insert below
        // replaces the row, so oldTxn must be captured first for balance revert.
        final oldTxn = await _db!.getTransactionById(entityId);

        final txnDateUpdate = DateTime.tryParse(payload['txn_date'] ?? '') ??
            DateTime.now();
        final newAccountId = payload['account_id'] ?? '';
        final newAmountCny = (payload['amount_cny'] as num?)?.toInt() ?? 0;
        final newType = payload['type'] ?? 'expense';

        await _db!.insertOrUpdateTransaction(
          id: entityId,
          userId: payload['user_id'] ?? '',
          accountId: newAccountId,
          categoryId: payload['category_id'] ?? '',
          amount: (payload['amount'] as num?)?.toInt() ?? 0,
          amountCny: newAmountCny,
          type: newType,
          note: payload['note'] ?? '',
          txnDate: txnDateUpdate,
        );

        // Idempotent balance adjustment: only revert/apply if the values
        // that affect balance actually changed (or txn is new). This makes
        // UPDATE replay-safe even without per-page checkpoint (defense-in-depth).
        final bool shouldAdjustBalance = oldTxn == null ||
            oldTxn.accountId != newAccountId ||
            oldTxn.amountCny != newAmountCny ||
            oldTxn.type != newType;

        if (shouldAdjustBalance) {
          // Revert old balance contribution (if old txn existed and was active)
          if (oldTxn != null && oldTxn.deletedAt == null && oldTxn.type != 'transfer') {
            final oldDelta = oldTxn.type == 'income' ? oldTxn.amountCny : -oldTxn.amountCny;
            await _db!.updateAccountBalance(oldTxn.accountId, -oldDelta);
          }
          // Apply new balance delta
          if (newAccountId.isNotEmpty && newAmountCny != 0 && newType != 'transfer') {
            final newDelta = newType == 'income' ? newAmountCny : -newAmountCny;
            await _db!.updateAccountBalance(newAccountId, newDelta);
          }
        }
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        // Get transaction before soft-deleting to revert balance
        final txn = await _db!.getTransactionById(entityId);
        if (txn != null && txn.deletedAt == null && txn.type != 'transfer') {
          // Revert balance contribution
          final delta = txn.type == 'income' ? txn.amountCny : -txn.amountCny;
          await _db!.updateAccountBalance(txn.accountId, -delta);
        }
        await _db!.softDeleteTransaction(entityId);
        break;
      default:
        break;
    }
  }

  Future<void> _applyAccountOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _db!.upsertAccount(
          id: entityId,
          userId: payload['user_id'] ?? '',
          name: payload['name'] ?? 'Unknown',
          accountType: payload['type'] ?? 'other',
          icon: payload['icon'] ?? '💳',
          balance: (payload['balance'] as num?)?.toInt() ?? 0,
          currency: payload['currency'] ?? 'CNY',
          isActive: payload['is_active'] ?? true,
          updatedAt: DateTime.tryParse(payload['updated_at'] ?? ''),
        );
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _db!.softDeleteAccount(entityId);
        break;
      default:
        break;
    }
  }

  Future<void> _applyCategoryOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _db!.upsertCategory(
          id: entityId,
          name: payload['name'] ?? 'Unknown',
          iconKey: (payload['icon_key'] as String?) ?? '',
          type: payload['type'] ?? 'expense',
          isPreset: payload['is_preset'] ?? false,
          sortOrder: (payload['sort_order'] as num?)?.toInt() ?? 0,
          parentId: payload['parent_id'] as String?,
          userId: payload['user_id'] as String?,
        );
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        // Soft delete: set deleted_at
        await _db!.softDeleteCategory(entityId);
        break;
      default:
        break;
    }
  }

  // ─────────── Category Merge ops ───────────

  Future<void> _applyCategoryMergeOp(
    String mergeLogId,
    Map<String, dynamic> payload,
  ) async {
    final sourceId = payload['source_category_id'] as String?;
    final targetId = payload['target_category_id'] as String?;
    if (sourceId == null || targetId == null) return;
    if (_db == null) return; // CRITICAL #4: guard null db

    // 幂等保护：检查 source 是否已删除
    final source = await (_db!.select(_db!.categories)
          ..where((c) => c.id.equals(sourceId))
          ..where((c) => c.deletedAt.isNull()))
        .getSingleOrNull();
    if (source == null) return; // 已处理过，跳过

    // CRITICAL #1: 用 customUpdate + updates 触发 Stream 通知
    await _db!.customUpdate(
      'UPDATE transactions SET category_id = ? WHERE category_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(targetId), Variable.withString(sourceId)],
      updates: {_db!.transactions},
      updateKind: UpdateKind.update,
    );
    await _db!.customUpdate(
      'UPDATE categories SET parent_id = ? WHERE parent_id = ? AND deleted_at IS NULL',
      variables: [Variable.withString(targetId), Variable.withString(sourceId)],
      updates: {_db!.categories},
      updateKind: UpdateKind.update,
    );
    await _db!.customUpdate(
      'UPDATE categories SET deleted_at = ? WHERE id = ?',
      variables: [Variable.withDateTime(DateTime.now()), Variable.withString(sourceId)],
      updates: {_db!.categories},
      updateKind: UpdateKind.update,
    );

    // CRITICAL #5: 清理源分类的使用统计
    await (_db!.delete(_db!.categoryUsageSlots)
          ..where((s) => s.categoryId.equals(sourceId)))
        .go();
    await (_db!.delete(_db!.categoryUsageSummary)
          ..where((s) => s.categoryId.equals(sourceId)))
        .go();
  }

  // ─────────── Loan ops ───────────

  Future<void> _applyLoanOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _db!.upsertLoan(LoansCompanion(
          id: Value(entityId),
          userId: Value(payload['user_id'] ?? ''),
          familyId: Value(payload['family_id'] ?? ''),
          name: Value(payload['name'] ?? 'Unknown Loan'),
          loanType: Value(payload['loan_type'] ?? 'other'),
          principal: Value((payload['principal'] as num?)?.toInt() ?? 0),
          remainingPrincipal: Value((payload['remaining_principal'] as num?)?.toInt() ?? 0),
          annualRate: Value((payload['annual_rate'] as num?)?.toDouble() ?? 0.0),
          totalMonths: Value((payload['total_months'] as num?)?.toInt() ?? 0),
          paidMonths: Value((payload['paid_months'] as num?)?.toInt() ?? 0),
          repaymentMethod: Value(payload['repayment_method'] ?? 'equal_installment'),
          paymentDay: Value((payload['payment_day'] as num?)?.toInt() ?? 1),
          startDate: Value(DateTime.tryParse(payload['start_date'] ?? '') ?? DateTime.now()),
          accountId: Value(payload['account_id'] ?? ''),
          groupId: Value(payload['group_id'] ?? ''),
          subType: Value(payload['sub_type'] ?? ''),
          rateType: Value(payload['rate_type'] ?? 'fixed'),
          lprBase: Value((payload['lpr_base'] as num?)?.toDouble() ?? 0.0),
          lprSpread: Value((payload['lpr_spread'] as num?)?.toDouble() ?? 0.0),
          rateAdjustMonth: Value((payload['rate_adjust_month'] as num?)?.toInt() ?? 1),
          updatedAt: Value(DateTime.tryParse(payload['updated_at'] ?? '') ?? DateTime.now()),
        ));
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _db!.softDeleteLoan(entityId);
        break;
      default:
        break;
    }
  }

  // ─────────── LoanGroup ops ───────────

  Future<void> _applyLoanGroupOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _db!.upsertLoanGroup(LoanGroupsCompanion(
          id: Value(entityId),
          userId: Value(payload['user_id'] ?? ''),
          familyId: Value(payload['family_id'] ?? ''),
          name: Value(payload['name'] ?? 'Unknown Group'),
          groupType: Value(payload['group_type'] ?? 'combined'),
          totalPrincipal: Value((payload['total_principal'] as num?)?.toInt() ?? 0),
          paymentDay: Value((payload['payment_day'] as num?)?.toInt() ?? 1),
          startDate: Value(DateTime.tryParse(payload['start_date'] ?? '') ?? DateTime.now()),
          loanType: Value(payload['loan_type'] ?? 'mortgage'),
          updatedAt: Value(DateTime.tryParse(payload['updated_at'] ?? '') ?? DateTime.now()),
        ));
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _db!.softDeleteLoanGroup(entityId);
        break;
      default:
        break;
    }
  }

  // ─────────── Investment ops ───────────

  Future<void> _applyInvestmentOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _db!.upsertInvestment(InvestmentsCompanion(
          id: Value(entityId),
          userId: Value(payload['user_id'] ?? ''),
          familyId: Value(payload['family_id'] ?? ''),
          symbol: Value(payload['symbol'] ?? ''),
          name: Value(payload['name'] ?? 'Unknown'),
          marketType: Value(payload['market_type'] ?? 'a_share'),
          quantity: Value((payload['quantity'] as num?)?.toDouble() ?? 0.0),
          costBasis: Value((payload['cost_basis'] as num?)?.toInt() ?? 0),
          updatedAt: Value(DateTime.tryParse(payload['updated_at'] ?? '') ?? DateTime.now()),
        ));
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _db!.softDeleteInvestment(entityId);
        break;
      default:
        break;
    }
  }

  // ─────────── FixedAsset ops ───────────

  Future<void> _applyFixedAssetOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _db!.upsertFixedAsset(FixedAssetsCompanion(
          id: Value(entityId),
          userId: Value(payload['user_id'] ?? ''),
          familyId: Value(payload['family_id'] ?? ''),
          name: Value(payload['name'] ?? 'Unknown Asset'),
          assetType: Value(payload['asset_type'] ?? 'other'),
          purchasePrice: Value((payload['purchase_price'] as num?)?.toInt() ?? 0),
          currentValue: Value((payload['current_value'] as num?)?.toInt() ?? 0),
          purchaseDate: Value(DateTime.tryParse(payload['purchase_date'] ?? '') ?? DateTime.now()),
          updatedAt: Value(DateTime.tryParse(payload['updated_at'] ?? '') ?? DateTime.now()),
        ));
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _db!.softDeleteFixedAsset(entityId);
        break;
      default:
        break;
    }
  }

  // ─────────── Budget ops ───────────

  Future<void> _applyBudgetOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        await _db!.insertBudget(BudgetsCompanion(
          id: Value(entityId),
          userId: Value(payload['user_id'] ?? ''),
          familyId: Value(payload['family_id'] ?? ''),
          year: Value((payload['year'] as num?)?.toInt() ?? DateTime.now().year),
          month: Value((payload['month'] as num?)?.toInt() ?? DateTime.now().month),
          totalAmount: Value((payload['total_amount'] as num?)?.toInt() ?? 0),
          updatedAt: Value(DateTime.tryParse(payload['updated_at'] ?? '') ?? DateTime.now()),
        ));
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
        await _db!.deleteBudget(entityId);
        break;
      default:
        break;
    }
  }

  /// Auth-ok wait timeout - longer than server's AuthTimeout (5s) to account
  /// for network latency. Server closes with 4002 before this fires normally.
  static const _authOkTimeout = Duration(seconds: 10);

  /// Set during auth phase to prevent onDone/onError from triggering reconnect
  /// (the auth catch block handles reconnect itself).
  bool _awaitingAuth = false;
  Completer<void>? _authCompleter;

  Future<void> _connectWebSocket() async {
    if (_disposed) return;
    _disconnectWebSocket();

    final token = await _tokenStorage?.getAccessToken();
    if (token == null) {
      dev.log('[WS] _connectWebSocket: no token, skipping');
      return;
    }

    try {
      final scheme = AppConstants.useTls ? 'wss' : 'ws';
      // First-message auth: connect without token in URL
      final uri = Uri.parse(
        '$scheme://${AppConstants.serverHost}:${AppConstants.wsPort}/ws',
      );
      dev.log('[WS] connecting to $uri ...');
      _wsChannel = IOWebSocketChannel.connect(
        uri,
        customClient: AppConstants.useTls
            ? _createSecureHttpClient()
            : null,
      );

      // Await the ready future to catch connection failures early
      try {
        await _wsChannel!.ready;
        dev.log('[WS] connected successfully');
      } catch (e) {
        dev.log('[WS] handshake failed: $e');
        _scheduleReconnect();
        return;
      }

      if (_disposed) return;

      // Enter auth phase - suppress onDone/onError reconnect
      _awaitingAuth = true;
      _authCompleter = Completer<void>();

      // Subscribe BEFORE sending auth (so we don't miss auth_ok)
      _wsSub = _wsChannel!.stream.listen(
        (message) {
          if (message is! String) {
            dev.log('[WS] ignoring non-text frame (${message.runtimeType})');
            return;
          }
          dev.log('[WS] message received (${message.length} chars)');
          _handleWsMessage(message);
        },
        onError: (error) {
          dev.log('[WS] error: $error');
          if (_awaitingAuth) {
            _authCompleter?.completeError(error);
          } else {
            _scheduleReconnect();
          }
        },
        onDone: () {
          dev.log('[WS] closed');
          if (_awaitingAuth) {
            if (_authCompleter != null && !_authCompleter!.isCompleted) {
              _authCompleter!.completeError('connection closed before auth_ok');
            }
          } else {
            _scheduleReconnect();
          }
        },
      );

      // Send auth message after listen is registered
      _wsChannel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));

      // Wait for auth_ok with timeout
      try {
        await _authCompleter!.future.timeout(
          _authOkTimeout,
          onTimeout: () {
            throw TimeoutException('auth_ok timeout', _authOkTimeout);
          },
        );
      } catch (e) {
        dev.log('[Sync] auth_ok not received: $e');
        _awaitingAuth = false;
        _authCompleter = null;
        _disconnectWebSocket();
        _scheduleReconnect();
        return;
      }

      // Auth succeeded - exit auth phase
      _awaitingAuth = false;
      _authCompleter = null;
      dev.log('[WS] authenticated');
    } catch (e) {
      dev.log('[WS] connect failed: $e');
      _awaitingAuth = false;
      _authCompleter = null;
      _scheduleReconnect();
    }
  }

  void _handleWsMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'auth_ok') {
        dev.log('[WS] auth_ok received');
        _reconnectAttempts = 0;
        onSyncEvent?.call(const SyncEvent.wsStateChanged(true));
        if (_authCompleter != null && !_authCompleter!.isCompleted) {
          _authCompleter!.complete();
        }
        // Pull immediately after auth to catch up on changes
        unawaited(_pullChanges());
        return;
      }

      if (type == 'sync_notify' || type == 'change') {
        // 服务端通知有新变更,触发增量拉取
        _pullChanges();
      } else if (type == 'heartbeat' || type == 'ping') {
        // Server heartbeat with watermark: compare with our lastSyncTs
        final serverTimeMs = (data['server_time'] as num?)?.toInt();
        if (serverTimeMs != null) {
          final localTs = _lastSyncTsMs;
          if (serverTimeMs > localTs) {
            // We're behind - pull to catch up
            dev.log(
              '[Sync] heartbeat watermark ahead (server=$serverTimeMs, local=$localTs), pulling',
            );
            _pullChanges();
          }
        }
      }
    } catch (e) {
      dev.log('[WS] failed to parse message: $e');
    }
  }

  // ─────────── Sync Mutex ───────────

  /// Try-lock: returns true if acquired, false if another op holds the lock.
  /// Synchronous - no async gap between check and acquire.
  bool _tryAcquireSyncLock() {
    if (_syncing) return false;
    _syncing = true;
    return true;
  }

  /// Releases the sync lock, allowing the next operation to proceed.
  void _releaseSyncLock() {
    _syncing = false;
  }

  /// Drains coalesced push/pull requests after lock release.
  /// Push is checked first (local edits should reach server promptly),
  /// then pull. Each winner re-acquires the lock inside its own call.
  ///
  /// Design note: only one pending request is drained per cycle. Under
  /// extreme high-frequency interleaving, push and pull alternate one-at-a-time
  /// (theoretical ping-pong). For a household finance app this is a non-issue
  /// (sync ops are seconds apart, not milliseconds).
  void _drainPendingRequests() {
    if (_disposed) return;
    if (_pushRequested) {
      _pushRequested = false;
      unawaited(_pushPendingOps());
    } else if (_pullRequested) {
      _pullRequested = false;
      unawaited(_pullChanges());
    }
  }

  /// Create or reuse an HttpClient with our pinned CA for WebSocket TLS.
  HttpClient _createSecureHttpClient() {
    if (_secureHttpClient != null) return _secureHttpClient!;
    _securityContext ??= SecurityContext()
      ..setTrustedCertificatesBytes(caCertBytes);
    _secureHttpClient = HttpClient(context: _securityContext!)
      ..badCertificateCallback = (cert, host, port) {
        // CA chain validated by SecurityContext (pinned CA only).
        // This callback fires only for non-chain issues (e.g. IP SAN
        // mismatch). Accept if issued by our pinned CA.
        return cert.issuer.contains(AppConstants.pinnedCaIssuer);
      };
    return _secureHttpClient!;
  }

  // ─────────── Backoff: 连续失败时延长重试间隔 ───────────

  void _onSyncSuccess() {
    if (_disposed) return;
    if (_consecutiveFailures > 0) {
      _consecutiveFailures = 0;
      _rescheduleTimer(AppConstants.syncIntervalSeconds);
    }
  }

  void _onSyncFailure() {
    if (_disposed) return;
    _consecutiveFailures++;
    // Exponential backoff: 30s, 60s, 120s, 240s, capped at 300s
    final backoff = (AppConstants.syncIntervalSeconds * pow(2, _consecutiveFailures - 1))
        .clamp(AppConstants.syncIntervalSeconds, _maxBackoffSeconds)
        .toInt();
    _rescheduleTimer(backoff);
    dev.log('[Sync] backoff: $_consecutiveFailures consecutive failures, next retry in ${backoff}s');
  }

  void _rescheduleTimer(int seconds) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => _syncCycle(),
    );
  }

  void _disconnectWebSocket() {
    // Cancel any pending auth wait
    if (_awaitingAuth) {
      _awaitingAuth = false;
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.completeError('disconnected');
      }
      _authCompleter = null;
    }
    _wsSub?.cancel();
    _wsSub = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    onSyncEvent?.call(const SyncEvent.wsStateChanged(false));
  }

  void _scheduleReconnect() {
    if (_disposed) return;

    final exponentialDelay = _wsReconnectBaseDelay * (1 << _reconnectAttempts.clamp(0, 6));
    final delay = exponentialDelay.clamp(_wsReconnectBaseDelay, _wsReconnectMaxDelay);
    final jitter = Random().nextInt((delay * 0.5).ceil() + 1);
    final totalDelay = (delay + jitter).clamp(0, _wsReconnectMaxTotalDelay);

    dev.log(
      '[WS] reconnecting in ${totalDelay}s (attempt ${_reconnectAttempts + 1})',
    );
    _reconnectAttempts++;

    Future.delayed(Duration(seconds: totalDelay), () {
      if (!_disposed) _connectWebSocket();
    });
  }

  /// 手动触发完整同步(推送 + 拉取)
  Future<void> syncNow() => _syncCycle();

  /// App 回到前台时调用:立即同步 + 重启 timer + 重连 WS
  void onAppResumed() {
    if (_disposed) return;
    dev.log('[Sync] app resumed, syncing...');
    // Reset backoff - user returning to foreground deserves a fresh start
    _consecutiveFailures = 0;
    // Restart timer at normal interval
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: AppConstants.syncIntervalSeconds),
      (_) => _syncCycle(),
    );
    // Immediate sync + reconnect (fire-and-forget)
    unawaited(_syncCycle());
    if (_wsChannel == null) _connectWebSocket();
  }

  /// App 进入后台时调用:停止 timer 省电,保持 WS(会自然断开)
  void onAppPaused() {
    if (_disposed) return;
    dev.log('[Sync] app paused, stopping timer');
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Test-only: apply a remote op directly.
  /// Only works when engine is constructed with [SyncEngine.forTesting].
  @visibleForTesting
  Future<void> applyRemoteOpForTest(sync_pb.SyncOperation op) async {
    assert(_db != null,
        'applyRemoteOpForTest: engine must be constructed with forTesting(db)');
    await _applyRemoteOp(op);
  }

  void dispose() {
    _disposed = true;
    _reconnectAttempts = 0;
    _syncTimer?.cancel();
    _disconnectWebSocket();
    _secureHttpClient?.close();
    _secureHttpClient = null;
  }
}

/// User-scoped sync engine.
///
/// This provider watches [currentUserIdProvider]. When the user changes
/// (login/logout/switch), the old engine is disposed (timer stopped, WS
/// disconnected) and a new one is created for the new user. This prevents:
/// - Cross-user data contamination (old engine pushing to wrong account)
/// - Stale auth tokens being used for gRPC/WS
/// - Duplicate timer instances accumulating across login cycles
///
/// When userId is null (logged out), returns a no-op engine.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  // Not logged in - return inert stub that does nothing.
  if (userId == null) {
    return SyncEngine.inert();
  }

  final db = ref.watch(databaseProvider);
  final syncClient = ref.watch(syncClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final tokenStorage = ref.watch(secureTokenStorageProvider);
  final engine = SyncEngine(db, syncClient, prefs, tokenStorage: tokenStorage);

  // Wire status callbacks to SyncStatusNotifier.
  // All state updates are deferred to next microtask to break the
  // synchronous call chain that could trigger provider rebuild loops
  // (engine.onSyncEvent → notifier.markX → widget rebuild → provider rebuild → engine dispose).
  final statusNotifier = ref.read(syncStatusProvider.notifier);
  engine.onSyncEvent = (SyncEvent event) {
    Future.microtask(() {
      if (!statusNotifier.mounted) return;
      switch (event) {
        case SyncStarted():
          statusNotifier.markSyncing();
        case SyncStopped():
          statusNotifier.markSyncStopped();
        case SyncCompleted():
          statusNotifier.markSynced();
        case ServerReachable():
          statusNotifier.updateServerReachable(true);
        case ServerUnreachable():
          statusNotifier.updateServerReachable(false);
        case WsStateChanged(:final connected):
          statusNotifier.updateWsConnected(connected);
        case PushFailed(:final failedCount):
          statusNotifier.markFailed(failedCount);
        case PendingCountUpdated():
          break;
        case DeadLetterCountUpdated():
          break;
      }
    });
  };

  ref.onDispose(() => engine.dispose());

  // Auto-start: engine begins sync cycle + WS connection immediately.
  // Previously this was triggered manually by home_page.dart - now it's
  // lifecycle-managed: starts when user logs in, stops when they log out.
  engine.start();

  return engine;
});

/// Lifecycle observer that pauses/resumes SyncEngine with the app.
/// Wrap your app content with this inside ProviderScope.
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;
  const SyncLifecycleObserver({super.key, required this.child});

  @override
  ConsumerState<SyncLifecycleObserver> createState() => _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(syncEngineProvider);
    if (state == AppLifecycleState.resumed) {
      engine.onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      // Only pause on actual background (not inactive - e.g. phone call, notification center)
      engine.onAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
