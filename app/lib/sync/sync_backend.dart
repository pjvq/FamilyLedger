import '../generated/proto/sync.pb.dart' as sync_pb;

/// Pluggable transport for the sync layer.
///
/// [SyncEngine] owns all orchestration (timer, mutex, dead-letter retry) and
/// local-DB apply logic; the *transport* — how pending ops reach the remote,
/// how remote changes are fetched, and how realtime change notifications
/// arrive — lives behind this interface.
///
/// This lets the same Flutter codebase ship in two forms (design §9.3 / §11.3):
/// - iOS: [GrpcSyncBackend] today, an iCloud/CloudKit backend later.
/// - Android: [NoSyncBackend] — a no-op so the build pulls in no sync/network
///   transport dependencies.
///
/// Implementations must be safe to call after [dispose] (no-op).
abstract class SyncBackend {
  /// Whether this backend performs real sync. `false` for [NoSyncBackend],
  /// letting the engine skip work entirely on local-only builds.
  bool get isActive;

  /// Push pending operations to the remote.
  ///
  /// Throws on transport failure (caller treats this as "server unreachable").
  Future<sync_pb.PushOperationsResponse> push(
    sync_pb.PushOperationsRequest request,
  );

  /// Pull incremental changes from the remote.
  ///
  /// Throws on transport failure.
  Future<sync_pb.PullChangesResponse> pull(sync_pb.PullChangesRequest request);

  /// Start the realtime change channel (e.g. WebSocket / CloudKit
  /// subscription). Signals are delivered via the callbacks below.
  void connectRealtime();

  /// Tear down the realtime channel.
  void disconnectRealtime();

  /// App returned to foreground — reconnect the realtime channel if needed.
  void onAppResumed();

  /// Release all resources (timers, sockets, clients). Idempotent.
  void dispose();

  // ─────────── Engine callbacks ───────────
  // The engine wires these so the backend can drive pulls and surface
  // connection state without depending on the engine's internals.

  /// Invoked when the remote signals there may be new changes
  /// (e.g. a `sync_notify`/`change` frame, or auth completed). The engine
  /// responds by triggering an incremental pull.
  void Function()? onRealtimeChange;

  /// Invoked with a server watermark (ms since epoch). The engine pulls only
  /// if it is behind. Used for heartbeat-driven catch-up.
  void Function(int serverTimeMs)? onRealtimeWatermark;

  /// Invoked when the realtime connection state changes (connected / dropped).
  void Function(bool connected)? onConnectionStateChanged;
}
