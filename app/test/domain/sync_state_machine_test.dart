import 'dart:math';

import 'package:familyledger/domain/providers/sync_status_provider.dart';
import 'package:familyledger/sync/sync_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Formal state machine verification for SyncStatus.
///
/// These tests exercise the **production** [SyncState.applyEvent] and
/// [SyncState.applyConnectivity] methods — the same code that runs in
/// [SyncStatusNotifier]. No separate "test-only" transition function exists.
///
/// State transition diagram (Mermaid):
/// ```mermaid
/// stateDiagram-v2
///     [*] --> synced
///     synced --> syncing : SyncStarted
///     synced --> offline : connectivity_lost
///     synced --> pending : serverUnreachable
///
///     syncing --> synced : SyncStopped [pending=0, failed=0, reachable]
///     syncing --> pending : SyncStopped [pending>0 OR !reachable]
///     syncing --> failed : SyncStopped [failed>0]
///     syncing --> offline : connectivity_lost
///
///     pending --> syncing : SyncStarted
///     pending --> synced : serverReachable [pending=0, failed=0]
///     pending --> offline : connectivity_lost
///
///     failed --> syncing : SyncStarted
///     failed --> offline : connectivity_lost
///
///     offline --> pending : connectivity_restored [pending>0]
///     offline --> synced : connectivity_restored [pending=0, failed=0]
///     offline --> failed : connectivity_restored [failed>0]
/// ```
void main() {
  // ─── Deterministic Transition Tests ────────────────────────────────────

  group('SyncStatus state machine — deterministic transitions', () {
    test('synced → syncing via SyncStarted', () {
      const state = SyncState(status: SyncStatus.synced);
      final next = SyncState.applyEvent(state, const SyncEvent.syncStarted());
      expect(next.status, SyncStatus.syncing);
    });

    test('syncing → synced via SyncStopped (nothing pending)', () {
      const state = SyncState(status: SyncStatus.syncing, pendingCount: 0, failedCount: 0, serverReachable: true);
      final next = SyncState.applyEvent(state, const SyncEvent.syncStopped());
      expect(next.status, SyncStatus.synced);
    });

    test('syncing → pending via SyncStopped (pending > 0)', () {
      const state = SyncState(status: SyncStatus.syncing, pendingCount: 3, failedCount: 0, serverReachable: true);
      final next = SyncState.applyEvent(state, const SyncEvent.syncStopped());
      expect(next.status, SyncStatus.pending);
    });

    test('syncing → pending via SyncStopped (server unreachable)', () {
      const state = SyncState(status: SyncStatus.syncing, pendingCount: 0, failedCount: 0, serverReachable: false);
      final next = SyncState.applyEvent(state, const SyncEvent.syncStopped());
      expect(next.status, SyncStatus.pending);
    });

    test('syncing → failed via SyncStopped (failed > 0)', () {
      const state = SyncState(status: SyncStatus.syncing, pendingCount: 0, failedCount: 2, serverReachable: true);
      final next = SyncState.applyEvent(state, const SyncEvent.syncStopped());
      expect(next.status, SyncStatus.failed);
    });

    test('synced → pending via ServerUnreachable', () {
      const state = SyncState(status: SyncStatus.synced);
      final next = SyncState.applyEvent(state, const SyncEvent.serverUnreachable());
      expect(next.status, SyncStatus.pending);
      expect(next.serverReachable, false);
    });

    test('pending → synced via ServerReachable (nothing pending)', () {
      const state = SyncState(status: SyncStatus.pending, pendingCount: 0, failedCount: 0, serverReachable: false);
      final next = SyncState.applyEvent(state, const SyncEvent.serverReachable());
      expect(next.status, SyncStatus.synced);
      expect(next.serverReachable, true);
    });

    test('pending stays pending via ServerReachable (still has pending)', () {
      const state = SyncState(status: SyncStatus.pending, pendingCount: 5, failedCount: 0, serverReachable: false);
      final next = SyncState.applyEvent(state, const SyncEvent.serverReachable());
      expect(next.status, SyncStatus.pending);
    });

    test('any → offline via connectivity loss', () {
      for (final status in SyncStatus.values) {
        if (status == SyncStatus.offline) continue;
        final state = SyncState(status: status);
        final next = SyncState.applyConnectivity(state, online: false);
        expect(next.status, SyncStatus.offline, reason: 'from $status');
      }
    });

    test('offline → synced via connectivity restored (nothing pending)', () {
      const state = SyncState(status: SyncStatus.offline, pendingCount: 0, failedCount: 0);
      final next = SyncState.applyConnectivity(state, online: true);
      expect(next.status, SyncStatus.synced);
    });

    test('offline → pending via connectivity restored (has pending)', () {
      const state = SyncState(status: SyncStatus.offline, pendingCount: 5);
      final next = SyncState.applyConnectivity(state, online: true);
      expect(next.status, SyncStatus.pending);
    });

    test('offline → failed via connectivity restored (has failures)', () {
      const state = SyncState(status: SyncStatus.offline, failedCount: 3);
      final next = SyncState.applyConnectivity(state, online: true);
      expect(next.status, SyncStatus.failed);
    });

    test('SyncStopped is no-op when not syncing', () {
      for (final status in SyncStatus.values) {
        if (status == SyncStatus.syncing) continue;
        final state = SyncState(status: status);
        final next = SyncState.applyEvent(state, const SyncEvent.syncStopped());
        expect(next.status, status, reason: 'SyncStopped should be no-op in $status');
      }
    });

    test('WsStateChanged does not affect sync status', () {
      for (final status in SyncStatus.values) {
        final state = SyncState(status: status, wsConnected: false);
        final next = SyncState.applyEvent(state, const SyncEvent.wsStateChanged(true));
        expect(next.status, status);
        expect(next.wsConnected, true);
      }
    });

    test('applyConnectivity(online: true) does not interrupt syncing', () {
      const state = SyncState(status: SyncStatus.syncing, pendingCount: 0, failedCount: 0);
      final next = SyncState.applyConnectivity(state, online: true);
      expect(next.status, SyncStatus.syncing,
          reason: 'Timer refresh must not clobber active sync');
    });

    test('applyConnectivity(online: false) CAN interrupt syncing (network lost)', () {
      const state = SyncState(status: SyncStatus.syncing);
      final next = SyncState.applyConnectivity(state, online: false);
      expect(next.status, SyncStatus.offline,
          reason: 'Network loss always takes precedence');
    });
  });

  // ─── Pairing Property: SyncStarted always has SyncStopped ─────────────

  group('SyncStatus state machine — pairing invariant', () {
    test('SyncStarted/SyncStopped always pair: status != syncing after stop', () {
      var state = const SyncState(status: SyncStatus.synced);

      state = SyncState.applyEvent(state, const SyncEvent.syncStarted());
      expect(state.status, SyncStatus.syncing);

      state = SyncState.applyEvent(state, const SyncEvent.serverReachable());
      state = SyncState.applyEvent(state, const SyncEvent.syncStopped());
      expect(state.status, isNot(SyncStatus.syncing));
    });

    test('multiple start/stop cycles never leave status stuck in syncing', () {
      var state = const SyncState(status: SyncStatus.synced);

      for (int i = 0; i < 100; i++) {
        state = SyncState.applyEvent(state, const SyncEvent.syncStarted());
        expect(state.status, SyncStatus.syncing);

        if (i % 3 == 0) {
          state = SyncState.applyEvent(state, const SyncEvent.serverUnreachable());
        }
        if (i % 5 == 0) {
          state = SyncState.applyEvent(state, PushFailed(i % 4));
        }

        state = SyncState.applyEvent(state, const SyncEvent.syncStopped());
        expect(state.status, isNot(SyncStatus.syncing),
            reason: 'Cycle $i left status stuck in syncing');
      }
    });
  });

  // ─── Value Equality ────────────────────────────────────────────────────

  group('SyncState — value equality', () {
    test('equal states have same hashCode and ==', () {
      const a = SyncState(status: SyncStatus.pending, pendingCount: 3);
      const b = SyncState(status: SyncStatus.pending, pendingCount: 3);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different states are not equal', () {
      const a = SyncState(status: SyncStatus.synced);
      const b = SyncState(status: SyncStatus.pending);
      expect(a, isNot(equals(b)));
    });

    test('toString includes all fields', () {
      const state = SyncState(status: SyncStatus.failed, failedCount: 2, pendingCount: 1);
      expect(state.toString(), contains('failed'));
      expect(state.toString(), contains('pending: 1'));
      expect(state.toString(), contains('failed: 2'));
    });
  });

  // ─── Property-Based: Random Event Sequences (including connectivity) ──

  group('SyncStatus state machine — property-based (random sequences)', () {
    final rng = Random(42);

    /// Generates a random mix of sync events AND connectivity changes.
    /// Returns a list of functions that apply either applyEvent or applyConnectivity.
    List<SyncState Function(SyncState)> randomTransitions(int count) {
      final transitions = <SyncState Function(SyncState)>[
        (s) => SyncState.applyEvent(s, const SyncEvent.syncStarted()),
        (s) => SyncState.applyEvent(s, const SyncEvent.syncStopped()),
        (s) => SyncState.applyEvent(s, const SyncEvent.syncCompleted()),
        (s) => SyncState.applyEvent(s, const SyncEvent.serverReachable()),
        (s) => SyncState.applyEvent(s, const SyncEvent.serverUnreachable()),
        (s) => SyncState.applyEvent(s, const SyncEvent.wsStateChanged(true)),
        (s) => SyncState.applyEvent(s, const SyncEvent.wsStateChanged(false)),
        (s) => SyncState.applyEvent(s, const PushFailed(1)),
        (s) => SyncState.applyEvent(s, const PushFailed(0)),
        (s) => SyncState.applyEvent(s, const PendingCountUpdated(3)),
        (s) => SyncState.applyEvent(s, const PendingCountUpdated(0)),
        // Connectivity events
        (s) => SyncState.applyConnectivity(s, online: false),
        (s) => SyncState.applyConnectivity(s, online: true),
      ];
      return List.generate(count, (_) => transitions[rng.nextInt(transitions.length)]);
    }

    test('no event sequence produces null or undefined status', () {
      var state = const SyncState();
      for (final transition in randomTransitions(500)) {
        state = transition(state);
        expect(state.status, isNotNull);
        expect(SyncStatus.values, contains(state.status));
      }
    });

    test('status is always one of the 5 defined values', () {
      var state = const SyncState();
      for (final transition in randomTransitions(500)) {
        state = transition(state);
        expect(
          [SyncStatus.synced, SyncStatus.syncing, SyncStatus.pending, SyncStatus.failed, SyncStatus.offline],
          contains(state.status),
        );
      }
    });

    test('offline status IS reachable via random sequences', () {
      // Verifies m4: connectivity events are included in random sequences
      var state = const SyncState();
      bool hitOffline = false;
      for (final transition in randomTransitions(500)) {
        state = transition(state);
        if (state.status == SyncStatus.offline) {
          hitOffline = true;
          break;
        }
      }
      expect(hitOffline, true, reason: 'Random sequences should include offline transitions');
    });

    test('SyncStarted followed by SyncStopped never results in syncing', () {
      var state = const SyncState();
      final transitions = randomTransitions(200);

      for (int i = 0; i < transitions.length; i++) {
        final before = state;
        state = transitions[i](state);

        // If we just entered syncing, apply SyncStopped and verify
        if (before.status != SyncStatus.syncing && state.status == SyncStatus.syncing) {
          final afterStop = SyncState.applyEvent(state, const SyncEvent.syncStopped());
          expect(afterStop.status, isNot(SyncStatus.syncing),
              reason: 'SyncStopped should always exit syncing at step $i');
        }
      }
    });

    test('convergence: long event sequence reaches stable state', () {
      var state = const SyncState();
      for (final transition in randomTransitions(1000)) {
        state = transition(state);
      }
      state = SyncState.applyEvent(state, const SyncEvent.syncStopped());
      expect(state.status, isNot(SyncStatus.syncing));
    });

    test('serverReachable=true + pendingCount=0 + failedCount=0 → eventually synced', () {
      var state = const SyncState(
        status: SyncStatus.pending,
        pendingCount: 0,
        failedCount: 0,
        serverReachable: true,
      );
      state = SyncState.applyEvent(state, const SyncEvent.serverReachable());
      expect(state.status, SyncStatus.synced);
    });
  });

  // ─── Guard Invariants ──────────────────────────────────────────────────

  group('SyncStatus state machine — guard invariants', () {
    test('PushFailed always results in failed status', () {
      for (final status in SyncStatus.values) {
        final state = SyncState(status: status);
        final next = SyncState.applyEvent(state, const PushFailed(3));
        expect(next.status, SyncStatus.failed);
        expect(next.failedCount, 3);
      }
    });

    test('SyncCompleted always results in synced regardless of previous state', () {
      for (final status in SyncStatus.values) {
        final state = SyncState(status: status);
        final next = SyncState.applyEvent(state, const SyncEvent.syncCompleted());
        expect(next.status, SyncStatus.synced);
        expect(next.pendingCount, 0);
      }
    });

    test('pendingCount is never negative after any event sequence', () {
      var state = const SyncState();
      final rng2 = Random(123);
      final transitions = <SyncState Function(SyncState)>[
        (s) => SyncState.applyEvent(s, const SyncEvent.syncStarted()),
        (s) => SyncState.applyEvent(s, const SyncEvent.syncStopped()),
        (s) => SyncState.applyEvent(s, const SyncEvent.syncCompleted()),
        (s) => SyncState.applyEvent(s, const SyncEvent.serverReachable()),
        (s) => SyncState.applyEvent(s, const SyncEvent.serverUnreachable()),
        (s) => SyncState.applyEvent(s, const PushFailed(1)),
        (s) => SyncState.applyEvent(s, const PendingCountUpdated(5)),
        (s) => SyncState.applyEvent(s, const PendingCountUpdated(0)),
        (s) => SyncState.applyConnectivity(s, online: false),
        (s) => SyncState.applyConnectivity(s, online: true),
      ];

      for (int i = 0; i < 300; i++) {
        state = transitions[rng2.nextInt(transitions.length)](state);
        expect(state.pendingCount, greaterThanOrEqualTo(0));
        expect(state.failedCount, greaterThanOrEqualTo(0));
      }
    });

    test('offline → online respects current pendingCount (no external param needed)', () {
      // M4 fix verification: applyConnectivity reads state.pendingCount
      const state = SyncState(status: SyncStatus.offline, pendingCount: 7, failedCount: 0);
      final next = SyncState.applyConnectivity(state, online: true);
      expect(next.status, SyncStatus.pending);
      expect(next.pendingCount, 7); // preserved from state, not from param
    });

    test('SyncStarted is no-op when offline (guard)', () {
      const state = SyncState(status: SyncStatus.offline);
      final next = SyncState.applyEvent(state, const SyncEvent.syncStarted());
      expect(next.status, SyncStatus.offline, reason: 'Cannot start sync while offline');
    });

    test('SyncCompleted uses provided timestamp (deterministic)', () {
      final ts = DateTime(2026, 1, 1, 12, 0);
      const state = SyncState(status: SyncStatus.syncing);
      final next = SyncState.applyEvent(state, SyncEvent.syncCompleted(timestamp: ts));
      expect(next.status, SyncStatus.synced);
      expect(next.lastSyncTime, ts);
    });

    test('SyncCompleted without timestamp falls back to DateTime.now()', () {
      const state = SyncState(status: SyncStatus.syncing);
      final before = DateTime.now();
      final next = SyncState.applyEvent(state, const SyncEvent.syncCompleted());
      final after = DateTime.now();
      expect(next.lastSyncTime, isNotNull);
      expect(next.lastSyncTime!.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(next.lastSyncTime!.isBefore(after.add(const Duration(seconds: 1))), true);
    });

    test('PendingCountUpdated updates count and recalculates resting state', () {
      const state = SyncState(status: SyncStatus.synced, pendingCount: 0);
      final next = SyncState.applyEvent(state, const PendingCountUpdated(5));
      expect(next.status, SyncStatus.pending);
      expect(next.pendingCount, 5);
    });

    test('PendingCountUpdated to 0 transitions to synced', () {
      const state = SyncState(status: SyncStatus.pending, pendingCount: 3);
      final next = SyncState.applyEvent(state, const PendingCountUpdated(0));
      expect(next.status, SyncStatus.synced);
      expect(next.pendingCount, 0);
    });

    test('PendingCountUpdated does not interrupt syncing', () {
      const state = SyncState(status: SyncStatus.syncing, pendingCount: 0);
      final next = SyncState.applyEvent(state, const PendingCountUpdated(10));
      expect(next.status, SyncStatus.syncing);
      expect(next.pendingCount, 10);
    });

    test('PendingCountUpdated does not interrupt offline', () {
      const state = SyncState(status: SyncStatus.offline, pendingCount: 0);
      final next = SyncState.applyEvent(state, const PendingCountUpdated(3));
      expect(next.status, SyncStatus.offline);
      expect(next.pendingCount, 3);
    });

    test('PendingCountUpdated with failedCount > 0 stays failed', () {
      const state = SyncState(status: SyncStatus.failed, pendingCount: 2, failedCount: 1);
      final next = SyncState.applyEvent(state, const PendingCountUpdated(0));
      expect(next.status, SyncStatus.failed);
      expect(next.pendingCount, 0);
    });
  });
}
