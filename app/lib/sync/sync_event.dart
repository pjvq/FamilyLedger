/// Events emitted by [SyncEngine] to communicate status changes.
///
/// Sealed hierarchy — add new variants without changing the callback signature.
sealed class SyncEvent {
  const SyncEvent();

  /// Push/pull cycle started.
  const factory SyncEvent.syncStarted() = SyncStarted;

  /// Push/pull cycle ended (regardless of success/failure).
  /// Always emitted in finally blocks to prevent state-machine deadlock.
  const factory SyncEvent.syncStopped() = SyncStopped;

  /// Pull completed successfully — data is up to date.
  const factory SyncEvent.syncCompleted({DateTime? timestamp}) = SyncCompleted;

  /// A gRPC call succeeded — server is reachable.
  const factory SyncEvent.serverReachable() = ServerReachable;

  /// A gRPC call failed — server may be unreachable.
  const factory SyncEvent.serverUnreachable() = ServerUnreachable;

  /// WebSocket connection state changed.
  const factory SyncEvent.wsStateChanged(bool connected) = WsStateChanged;

  /// Some sync operations failed after push.
  const factory SyncEvent.pushFailed(int failedCount) = PushFailed;

  /// Pending operation count refreshed from DB.
  /// Triggers resting-state recalculation without bypassing the state machine.
  const factory SyncEvent.pendingCountUpdated(int count) = PendingCountUpdated;

  /// Dead-letter count changed (ops that failed during pull).
  /// UI can show a warning badge when count > 0.
  const factory SyncEvent.deadLetterCountUpdated(int count) =
      DeadLetterCountUpdated;
}

class SyncStarted extends SyncEvent {
  const SyncStarted();

  @override
  String toString() => 'SyncEvent.syncStarted()';
}

class SyncStopped extends SyncEvent {
  const SyncStopped();

  @override
  String toString() => 'SyncEvent.syncStopped()';
}

class SyncCompleted extends SyncEvent {
  final DateTime? timestamp;
  const SyncCompleted({this.timestamp});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCompleted && other.timestamp == timestamp);

  @override
  int get hashCode => timestamp.hashCode;

  @override
  String toString() => 'SyncEvent.syncCompleted(timestamp: $timestamp)';
}

class ServerReachable extends SyncEvent {
  const ServerReachable();

  @override
  String toString() => 'SyncEvent.serverReachable()';
}

class ServerUnreachable extends SyncEvent {
  const ServerUnreachable();

  @override
  String toString() => 'SyncEvent.serverUnreachable()';
}

class WsStateChanged extends SyncEvent {
  final bool connected;
  const WsStateChanged(this.connected);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WsStateChanged && other.connected == connected);

  @override
  int get hashCode => connected.hashCode;

  @override
  String toString() => 'SyncEvent.wsStateChanged($connected)';
}

class PushFailed extends SyncEvent {
  final int failedCount;
  const PushFailed(this.failedCount);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PushFailed && other.failedCount == failedCount);

  @override
  int get hashCode => failedCount.hashCode;

  @override
  String toString() => 'SyncEvent.pushFailed($failedCount)';
}

class PendingCountUpdated extends SyncEvent {
  final int count;
  const PendingCountUpdated(this.count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingCountUpdated && other.count == count);

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'SyncEvent.pendingCountUpdated($count)';
}

class DeadLetterCountUpdated extends SyncEvent {
  final int count;
  const DeadLetterCountUpdated(this.count);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeadLetterCountUpdated && other.count == count);

  @override
  int get hashCode => count.hashCode;

  @override
  String toString() => 'SyncEvent.deadLetterCountUpdated($count)';
}
