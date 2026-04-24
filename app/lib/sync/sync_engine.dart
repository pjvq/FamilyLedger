import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants/app_constants.dart';
import '../data/local/database.dart';
import '../data/remote/grpc_clients.dart';
import '../domain/providers/app_providers.dart';
import '../generated/proto/google/protobuf/timestamp.pb.dart' as proto_ts;
import '../generated/proto/sync.pb.dart' as sync_pb;
import '../generated/proto/sync.pbgrpc.dart';
import '../generated/proto/sync.pbenum.dart' as sync_enum;

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
  final Connectivity _connectivity = Connectivity();

  Timer? _syncTimer;
  StreamSubscription? _connectivitySub;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  bool _isSyncing = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  /// 最后一次成功拉取的服务端时间戳（毫秒）
  static const _lastSyncTsKey = 'sync_last_pull_ts';

  SyncEngine(AppDatabase db, SyncServiceClient syncClient, SharedPreferences prefs)
      : _db = db,
        _syncClient = syncClient,
        _prefs = prefs;

  /// @visibleForTesting — stub constructor, all methods become no-ops
  SyncEngine.forTesting()
      : _db = null,
        _syncClient = null,
        _prefs = null;

  void start() {
    if (_disposed) return;

    // 定期推送
    _syncTimer = Timer.periodic(
      const Duration(seconds: AppConstants.syncIntervalSeconds),
      (_) => _pushPendingOps(),
    );

    // 网络变化时触发推送 + 重连 WebSocket
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _pushPendingOps();
        _connectWebSocket();
      } else {
        _disconnectWebSocket();
      }
    });

    // 启动时立即尝试
    _pushPendingOps();
    _connectWebSocket();
  }

  // ─────────── Push: 本地 → 服务端 ───────────

  Future<void> _pushPendingOps() async {
    if (_isSyncing || _disposed) return;
    _isSyncing = true;
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) return;

      final pendingOps =
          await _db!.getPendingSyncOps(AppConstants.syncBatchSize);
      if (pendingOps.isEmpty) return;

      // 转换为 proto SyncOperation
      final protoOps = pendingOps.map(_toProtoOp).toList();
      final request = sync_pb.PushOperationsRequest()
        ..operations.addAll(protoOps);

      final response = await _syncClient!.pushOperations(request);

      // 标记成功上传的
      final failedSet = response.failedIds.toSet();
      final succeededIds = pendingOps
          .where((op) => !failedSet.contains(op.id))
          .map((op) => op.id)
          .toList();

      // Also mark permanently failed ops as uploaded to stop retrying
      // (e.g. invalid category_id format that will never succeed)
      final allProcessedIds = pendingOps.map((op) => op.id).toList();

      if (allProcessedIds.isNotEmpty) {
        await _db!.markSyncOpsUploaded(allProcessedIds);
      }

      dev.log(
        'SyncEngine: pushed ${succeededIds.length}/${pendingOps.length} ops',
        name: 'sync',
      );
    } catch (e) {
      dev.log('SyncEngine: push failed: $e', name: 'sync');
    } finally {
      _isSyncing = false;
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
    try {
      final lastTsMs = _prefs!.getInt(_lastSyncTsKey) ?? 0;
      final userId = _prefs!.getString(AppConstants.userIdKey);
      if (userId == null) return;

      final since = proto_ts.Timestamp(
        seconds: Int64(lastTsMs ~/ 1000),
        nanos: (lastTsMs % 1000) * 1000000,
      );

      final request = sync_pb.PullChangesRequest(
        since: since,
        clientId: 'client_$userId',
      );

      final response = await _syncClient!.pullChanges(request);

      for (final op in response.operations) {
        await _applyRemoteOp(op);
      }

      // 保存服务端时间作为下次 pull 的起点
      if (response.hasServerTime()) {
        final serverMs =
            response.serverTime.seconds.toInt() * 1000 +
            response.serverTime.nanos ~/ 1000000;
        await _prefs!.setInt(_lastSyncTsKey, serverMs);
      }

      dev.log(
        'SyncEngine: pulled ${response.operations.length} changes',
        name: 'sync',
      );
    } catch (e) {
      dev.log('SyncEngine: pull failed: $e', name: 'sync');
    }
  }

  /// 将远程操作应用到本地数据库
  Future<void> _applyRemoteOp(sync_pb.SyncOperation op) async {
    try {
      final payload = jsonDecode(op.payload) as Map<String, dynamic>;
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
      }
    } catch (e) {
      dev.log('SyncEngine: apply op failed: $e', name: 'sync');
    }
  }

  Future<void> _applyTransactionOp(
    sync_enum.OperationType opType,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    switch (opType) {
      case sync_enum.OperationType.OPERATION_TYPE_CREATE:
      case sync_enum.OperationType.OPERATION_TYPE_UPDATE:
        // Upsert transaction
        final txnDate = DateTime.tryParse(payload['txn_date'] ?? '') ??
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
          txnDate: txnDate,
        );
        break;
      case sync_enum.OperationType.OPERATION_TYPE_DELETE:
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
          icon: payload['icon'] ?? '📦',
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

  Future<void> _connectWebSocket() async {
    if (_disposed) return;
    _disconnectWebSocket();

    final token = _prefs?.getString(AppConstants.accessTokenKey);
    if (token == null) return;

    try {
      final uri = Uri.parse(
        'ws://${AppConstants.serverHost}:${AppConstants.wsPort}/ws?token=$token',
      );
      _wsChannel = WebSocketChannel.connect(uri);

      // Await the ready future to catch connection failures early
      try {
        await _wsChannel!.ready;
      } catch (e) {
        dev.log('SyncEngine: ws handshake failed: $e', name: 'sync');
        _scheduleReconnect();
        return;
      }

      if (_disposed) return;

      _wsSub = _wsChannel!.stream.listen(
        (message) {
          dev.log('SyncEngine: ws message: $message', name: 'sync');
          _handleWsMessage(message);
        },
        onError: (error) {
          dev.log('SyncEngine: ws error: $error', name: 'sync');
          _scheduleReconnect();
        },
        onDone: () {
          dev.log('SyncEngine: ws closed', name: 'sync');
          _scheduleReconnect();
        },
      );

      dev.log('SyncEngine: ws connected', name: 'sync');
      _reconnectAttempts = 0;
    } catch (e) {
      dev.log('SyncEngine: ws connect failed: $e', name: 'sync');
      _scheduleReconnect();
    }
  }

  void _handleWsMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'sync_notify' || type == 'change') {
        // 服务端通知有新变更，触发增量拉取
        _pullChanges();
      }
    } catch (e) {
      // 非 JSON 消息或未知格式，尝试拉取
      _pullChanges();
    }
  }

  void _disconnectWebSocket() {
    _wsSub?.cancel();
    _wsSub = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void _scheduleReconnect() {
    if (_disposed) return;

    final baseDelay = 1; // seconds
    final maxDelay = 60; // seconds
    final exponentialDelay = baseDelay * (1 << _reconnectAttempts.clamp(0, 6));
    final delay = exponentialDelay.clamp(baseDelay, maxDelay);
    final jitter = Random().nextInt((delay * 0.5).ceil() + 1);
    final totalDelay = (delay + jitter).clamp(0, 90);

    dev.log(
      'SyncEngine: reconnecting in ${totalDelay}s (attempt ${_reconnectAttempts + 1})',
      name: 'sync',
    );
    _reconnectAttempts++;

    Future.delayed(Duration(seconds: totalDelay), () {
      if (!_disposed) _connectWebSocket();
    });
  }

  /// 手动触发完整同步（推送 + 拉取）
  Future<void> syncNow() async {
    await _pushPendingOps();
    await _pullChanges();
  }

  void dispose() {
    _disposed = true;
    _reconnectAttempts = 0;
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
    _disconnectWebSocket();
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final syncClient = ref.watch(syncClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final engine = SyncEngine(db, syncClient, prefs);
  ref.onDispose(() => engine.dispose());
  return engine;
});
