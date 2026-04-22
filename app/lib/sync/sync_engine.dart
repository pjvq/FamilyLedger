import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../data/local/database.dart';
import '../domain/providers/app_providers.dart';

/// 离线同步引擎
/// Phase 1: 本地队列 + 联网检测
/// TODO: 接入 gRPC SyncService + WebSocket
class SyncEngine {
  final AppDatabase _db;
  final Connectivity _connectivity = Connectivity();
  Timer? _syncTimer;
  StreamSubscription? _connectivitySub;
  bool _isSyncing = false;

  SyncEngine(this._db);

  void start() {
    // 定期同步
    _syncTimer = Timer.periodic(
      const Duration(seconds: AppConstants.syncIntervalSeconds),
      (_) => _trySync(),
    );
    // 网络变化时触发同步
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        _trySync();
      }
    });
    // 启动时立即尝试一次
    _trySync();
  }

  Future<void> _trySync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) return;

      final pendingOps =
          await _db.getPendingSyncOps(AppConstants.syncBatchSize);
      if (pendingOps.isEmpty) return;

      // TODO: 调用 gRPC SyncService.PushOperations
      // 目前先标记为已上传（模拟成功）
      final ids = pendingOps.map((op) => op.id).toList();
      await _db.markSyncOpsUploaded(ids);
    } catch (_) {
      // 同步失败静默重试
    } finally {
      _isSyncing = false;
    }
  }

  /// 手动触发同步
  Future<void> syncNow() => _trySync();

  void dispose() {
    _syncTimer?.cancel();
    _connectivitySub?.cancel();
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final engine = SyncEngine(db);
  ref.onDispose(() => engine.dispose());
  return engine;
});
