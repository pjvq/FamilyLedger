import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database.dart';
import '../../sync/sync_event.dart';
import '../providers/app_providers.dart';

enum SyncStatus {
  synced, // 全部同步完成 + WS 正常
  syncing, // 正在 push 或 pull
  pending, // 有待同步（等待网络或下个周期）
  failed, // 有操作多次失败
  offline, // 无网络
}

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncTime;
  final bool wsConnected;
  final bool serverReachable;

  const SyncState({
    this.status = SyncStatus.synced,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncTime,
    this.wsConnected = false,
    this.serverReachable = true,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncTime,
    bool clearLastSyncTime = false,
    bool? wsConnected,
    bool? serverReachable,
  }) => SyncState(
    status: status ?? this.status,
    pendingCount: pendingCount ?? this.pendingCount,
    failedCount: failedCount ?? this.failedCount,
    lastSyncTime: clearLastSyncTime
        ? null
        : (lastSyncTime ?? this.lastSyncTime),
    wsConnected: wsConnected ?? this.wsConnected,
    serverReachable: serverReachable ?? this.serverReachable,
  );

  /// Pure state machine transition function.
  ///
  /// Given the current state and an event, returns the next state.
  /// This is the **single source of truth** for state transitions —
  /// both production code and tests use this same function.
  ///
  /// State transition diagram:
  /// ```
  /// synced  →  syncing (SyncStarted)
  /// synced  →  pending (ServerUnreachable)
  /// syncing →  synced  (SyncStopped [pending=0, failed=0, reachable])
  /// syncing →  pending (SyncStopped [pending>0 OR !reachable])
  /// syncing →  failed  (SyncStopped [failed>0])
  /// pending →  syncing (SyncStarted)
  /// pending →  synced  (ServerReachable [pending=0, failed=0])
  /// failed  →  syncing (SyncStarted)
  /// any     →  failed  (PushFailed)
  /// any     →  synced  (SyncCompleted)
  /// ```
  static SyncState applyEvent(SyncState state, SyncEvent event) {
    switch (event) {
      case SyncStarted():
        // Guard: cannot start sync while offline
        if (state.status == SyncStatus.offline) return state;
        return state.copyWith(status: SyncStatus.syncing);
      case SyncStopped():
        if (state.status != SyncStatus.syncing) return state;
        if (state.failedCount > 0) {
          return state.copyWith(status: SyncStatus.failed);
        } else if (state.pendingCount > 0 || !state.serverReachable) {
          return state.copyWith(status: SyncStatus.pending);
        } else {
          return state.copyWith(status: SyncStatus.synced);
        }
      case SyncCompleted(:final timestamp):
        return state.copyWith(
          status: SyncStatus.synced,
          pendingCount: 0,
          lastSyncTime: timestamp ?? DateTime.now(),
        );
      case ServerReachable():
        final s = state.copyWith(serverReachable: true);
        if ((s.status == SyncStatus.pending ||
                s.status == SyncStatus.syncing) &&
            s.pendingCount == 0 &&
            s.failedCount == 0) {
          return s.copyWith(status: SyncStatus.synced);
        }
        return s;
      case ServerUnreachable():
        final s = state.copyWith(serverReachable: false);
        if (s.status == SyncStatus.synced) {
          return s.copyWith(status: SyncStatus.pending);
        }
        return s;
      case WsStateChanged(:final connected):
        return state.copyWith(wsConnected: connected);
      case PushFailed(:final failedCount):
        return state.copyWith(
          status: SyncStatus.failed,
          failedCount: failedCount,
        );
      case PendingCountUpdated(:final count):
        final s = state.copyWith(pendingCount: count);
        // Don't interrupt active sync or offline state
        if (s.status == SyncStatus.syncing || s.status == SyncStatus.offline) {
          return s;
        }
        // Recalculate resting state based on counts
        if (s.failedCount > 0) {
          return s.copyWith(status: SyncStatus.failed);
        } else if (count > 0) {
          return s.copyWith(status: SyncStatus.pending);
        } else {
          return s.copyWith(status: SyncStatus.synced);
        }
      case DeadLetterCountUpdated():
        // Dead-letter count is informational; does not change sync status
        return state;
    }
  }

  /// Connectivity change transition (offline ↔ online).
  ///
  /// Separated from [applyEvent] because connectivity is an external
  /// system-level signal, not a domain event from the sync engine.
  static SyncState applyConnectivity(SyncState state, {required bool online}) {
    if (!online) {
      return state.copyWith(status: SyncStatus.offline);
    }
    // Don't interrupt active sync — timer-based refresh must not clobber syncing
    if (state.status == SyncStatus.syncing) return state;
    // Restoring connectivity — determine resting state from current counts
    if (state.failedCount > 0) {
      return state.copyWith(status: SyncStatus.failed);
    } else if (state.pendingCount > 0) {
      return state.copyWith(status: SyncStatus.pending);
    } else {
      return state.copyWith(status: SyncStatus.synced);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          pendingCount == other.pendingCount &&
          failedCount == other.failedCount &&
          lastSyncTime == other.lastSyncTime &&
          wsConnected == other.wsConnected &&
          serverReachable == other.serverReachable;

  @override
  int get hashCode => Object.hash(
    status,
    pendingCount,
    failedCount,
    lastSyncTime,
    wsConnected,
    serverReachable,
  );

  @override
  String toString() =>
      'SyncState(status: $status, pending: $pendingCount, failed: $failedCount, '
      'ws: $wsConnected, reachable: $serverReachable, lastSync: $lastSyncTime)';
}

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncState>(
  (ref) {
    final db = ref.watch(databaseProvider);
    return SyncStatusNotifier(db);
  },
);

class SyncStatusNotifier extends StateNotifier<SyncState> {
  final AppDatabase _db;
  Timer? _pollTimer;

  SyncStatusNotifier(this._db) : super(const SyncState()) {
    _startMonitoring();
  }

  void _startMonitoring() {
    // Check pending count every 5s
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());

    // Initial check
    refresh();
  }

  /// Dispatches a [SyncEvent] through the state machine.
  ///
  /// This is the primary API for the sync engine to communicate state changes.
  /// All transitions go through [SyncState.applyEvent] for consistency.
  void dispatch(SyncEvent event) {
    state = SyncState.applyEvent(state, event);
  }

  Future<void> refresh() async {
    try {
      // Update pending count through the state machine
      final pendingOps = await _db.getPendingSyncOps(1000);
      dispatch(PendingCountUpdated(pendingOps.length));
    } catch (_) {
      // DB not ready yet
    }
  }

  // ─── Legacy convenience methods (delegate to dispatch) ────────────
  // These exist for backward compatibility with existing callers.
  // New code should prefer `dispatch(SyncEvent.xxx())`.

  void markSyncing() => dispatch(const SyncEvent.syncStarted());

  void markSynced() => dispatch(const SyncEvent.syncCompleted());

  void markFailed(int failedCount) => dispatch(PushFailed(failedCount));

  void updateWsConnected(bool connected) =>
      dispatch(SyncEvent.wsStateChanged(connected));

  void markSyncStopped() => dispatch(const SyncEvent.syncStopped());

  void updateServerReachable(bool reachable) => dispatch(
    reachable
        ? const SyncEvent.serverReachable()
        : const SyncEvent.serverUnreachable(),
  );

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
