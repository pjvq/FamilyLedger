import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../data/local/database.dart';

/// Manages the offline sync queue — enqueuing operations when network calls fail.
///
/// This is a write-through queue: operations are appended here, then consumed
/// by SyncEngine's periodic push cycle. The queue is append-only (callers never
/// read from it directly).
///
/// Responsibilities:
/// - Serialize operation payloads to JSON
/// - Assign unique client IDs for idempotent server-side deduplication
/// - Fire a notification stream so SyncEngine can react immediately
///
/// Non-responsibilities:
/// - Does NOT execute gRPC calls
/// - Does NOT read/retry operations (that's SyncEngine's job)
/// - Does NOT manage account balance or transaction state
class OfflineSyncQueue {
  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Stream that fires whenever a new operation is enqueued.
  /// SyncEngine subscribes to trigger immediate push attempts.
  final _enqueueController = StreamController<void>.broadcast();
  Stream<void> get onEnqueued => _enqueueController.stream;

  OfflineSyncQueue(this._db);

  /// Enqueue a create operation for later sync.
  Future<void> enqueueCreate({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _enqueue(entityType: entityType, entityId: entityId, opType: 'create', payload: payload);
  }

  /// Enqueue an update operation for later sync.
  Future<void> enqueueUpdate({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _enqueue(entityType: entityType, entityId: entityId, opType: 'update', payload: payload);
  }

  /// Enqueue a delete operation for later sync.
  Future<void> enqueueDelete({
    required String entityType,
    required String entityId,
  }) async {
    await _enqueue(
      entityType: entityType,
      entityId: entityId,
      opType: 'delete',
      payload: {'id': entityId},
    );
  }

  /// Enqueue multiple delete operations in a batch (single stream notification).
  Future<void> enqueueBatchDelete({
    required String entityType,
    required List<String> entityIds,
  }) async {
    for (final id in entityIds) {
      final syncOpId = _uuid.v4();
      await _db.insertSyncOp(SyncQueueCompanion.insert(
        id: syncOpId,
        entityType: entityType,
        entityId: id,
        opType: 'delete',
        payload: jsonEncode({'id': id}),
        clientId: syncOpId,
        timestamp: DateTime.now(),
      ));
    }
    // Single notification for the entire batch — avoids N sync cycles.
    if (entityIds.isNotEmpty) {
      _enqueueController.add(null);
    }
  }

  void dispose() {
    _enqueueController.close();
  }

  // ─── Private ─────────────────────────────────────────────────────────

  Future<void> _enqueue({
    required String entityType,
    required String entityId,
    required String opType,
    required Map<String, dynamic> payload,
  }) async {
    final syncOpId = _uuid.v4();
    await _db.insertSyncOp(SyncQueueCompanion.insert(
      id: syncOpId,
      entityType: entityType,
      entityId: entityId,
      opType: opType,
      payload: jsonEncode(payload),
      clientId: syncOpId,
      timestamp: DateTime.now(),
    ));
    _enqueueController.add(null);
  }
}
