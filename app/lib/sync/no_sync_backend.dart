import '../generated/proto/sync.pb.dart' as sync_pb;
import 'sync_backend.dart';

/// Inert [SyncBackend] for local-only builds (Android, design §9.3 / §11.3).
///
/// Performs no network/transport work and pulls in no sync dependencies.
/// Push/pull return empty responses so the engine's orchestration logic runs
/// to completion harmlessly; realtime methods are no-ops.
class NoSyncBackend implements SyncBackend {
  @override
  bool get isActive => false;

  @override
  Future<sync_pb.PushOperationsResponse> push(
    sync_pb.PushOperationsRequest request,
  ) async {
    // No remote. The engine short-circuits the sync cycle when [isActive] is
    // false, so this is normally never reached. We return an empty (no
    // failures) response rather than marking ops failed: there is no failure,
    // sync simply does not apply on a local-only build. Ops stay queued in the
    // local DB regardless (the engine only marks ops uploaded on real success).
    return sync_pb.PushOperationsResponse();
  }

  @override
  Future<sync_pb.PullChangesResponse> pull(
    sync_pb.PullChangesRequest request,
  ) async {
    // No remote changes to apply.
    return sync_pb.PullChangesResponse();
  }

  @override
  void connectRealtime() {}

  @override
  void disconnectRealtime() {}

  @override
  void onAppResumed() {}

  @override
  void dispose() {}

  @override
  void Function()? onRealtimeChange;

  @override
  void Function(int serverTimeMs)? onRealtimeWatermark;

  @override
  void Function(bool connected)? onConnectionStateChanged;
}
