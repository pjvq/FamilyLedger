/// Events emitted by [SyncEngine] to communicate status changes.
///
/// Sealed hierarchy — add new variants without changing the callback signature.
sealed class SyncEvent {
  const SyncEvent();

  /// Push/pull cycle started.
  const factory SyncEvent.syncStarted() = SyncStarted;

  /// Pull completed successfully.
  const factory SyncEvent.syncCompleted() = SyncCompleted;

  /// A gRPC call succeeded — server is reachable.
  const factory SyncEvent.serverReachable() = ServerReachable;

  /// A gRPC call failed — server may be unreachable.
  const factory SyncEvent.serverUnreachable() = ServerUnreachable;

  /// WebSocket connection state changed.
  const factory SyncEvent.wsStateChanged(bool connected) = WsStateChanged;

  /// Some sync operations failed after push.
  const factory SyncEvent.pushFailed(int failedCount) = PushFailed;
}

class SyncStarted extends SyncEvent {
  const SyncStarted();
}

class SyncCompleted extends SyncEvent {
  const SyncCompleted();
}

class ServerReachable extends SyncEvent {
  const ServerReachable();
}

class ServerUnreachable extends SyncEvent {
  const ServerUnreachable();
}

class WsStateChanged extends SyncEvent {
  final bool connected;
  const WsStateChanged(this.connected);
}

class PushFailed extends SyncEvent {
  final int failedCount;
  const PushFailed(this.failedCount);
}
