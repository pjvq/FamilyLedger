import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database.dart';
import '../providers/app_providers.dart';

enum SyncStatus {
  synced,   // 全部同步完成 + WS 正常
  syncing,  // 正在 push 或 pull
  pending,  // 有待同步（等待网络或下个周期）
  failed,   // 有操作多次失败
  offline,  // 无网络
}

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncTime;
  final bool wsConnected;

  const SyncState({
    this.status = SyncStatus.synced,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncTime,
    this.wsConnected = false,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncTime,
    bool? wsConnected,
  }) =>
      SyncState(
        status: status ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        failedCount: failedCount ?? this.failedCount,
        lastSyncTime: lastSyncTime ?? this.lastSyncTime,
        wsConnected: wsConnected ?? this.wsConnected,
      );
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncState>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncStatusNotifier(db);
});

class SyncStatusNotifier extends StateNotifier<SyncState> {
  final AppDatabase _db;
  Timer? _pollTimer;
  StreamSubscription? _connectivitySub;
  final Connectivity _connectivity = Connectivity();

  SyncStatusNotifier(this._db) : super(const SyncState()) {
    _startMonitoring();
  }

  void _startMonitoring() {
    // Check pending count every 5s
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());

    // React to connectivity changes
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOffline = results.every((r) => r == ConnectivityResult.none);
      if (isOffline) {
        state = state.copyWith(status: SyncStatus.offline);
      } else {
        refresh();
      }
    });

    // Initial check
    refresh();
  }

  Future<void> refresh() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isOffline = results.every((r) => r == ConnectivityResult.none);

      final pendingOps = await _db.getPendingSyncOps(1000);
      final count = pendingOps.length;

      if (isOffline) {
        state = state.copyWith(status: SyncStatus.offline, pendingCount: count);
      } else if (state.failedCount > 0) {
        state = state.copyWith(status: SyncStatus.failed, pendingCount: count);
      } else if (count > 0) {
        state = state.copyWith(status: SyncStatus.pending, pendingCount: count);
      } else {
        state = state.copyWith(
          status: SyncStatus.synced,
          pendingCount: 0,
        );
      }
    } catch (_) {
      // DB not ready yet
    }
  }

  void markSyncing() {
    state = state.copyWith(status: SyncStatus.syncing);
  }

  void markSynced() {
    state = state.copyWith(
      status: SyncStatus.synced,
      pendingCount: 0,
      lastSyncTime: DateTime.now(),
    );
  }

  void markFailed(int failedCount) {
    state = state.copyWith(
      status: SyncStatus.failed,
      failedCount: failedCount,
    );
  }

  void updateWsConnected(bool connected) {
    state = state.copyWith(wsConnected: connected);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
