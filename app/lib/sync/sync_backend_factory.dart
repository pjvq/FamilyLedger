// MOBILE-ONLY: this file imports `dart:io` (for [Platform]) and is therefore
// not Flutter Web compatible. There is no web target today; if one is ever
// added, swap `dart:io` for a conditional import
// (`platform_io.dart` / `platform_web.dart`) or a flag, since `dart:io` is
// unavailable on Web.
import 'dart:io' show Platform;

import '../data/local/secure_token_storage.dart';
import '../generated/proto/sync.pbgrpc.dart';
import 'grpc_sync_backend.dart';
import 'no_sync_backend.dart';
import 'sync_backend.dart';

/// Compile-time sync mode, selecting which [SyncBackend] the app assembles.
///
/// Pass `--dart-define=SYNC_BACKEND=none` to force the local-only build
/// (no sync transport). Values:
/// - `grpc`  — current gRPC + WebSocket backend (default).
/// - `none`  — [NoSyncBackend]; the Android local-only form (design §9.3).
/// - `auto`  — pick by platform: Android → none, others → grpc.
const String _syncBackendMode = String.fromEnvironment(
  'SYNC_BACKEND',
  defaultValue: 'grpc',
);

/// Whether the active build should use a real sync transport.
///
/// Resolves the compile-time [_syncBackendMode] against the current platform.
/// Use this to gate sync-only setup (e.g. building a gRPC client) so a
/// local-only build never touches it.
bool get syncEnabled {
  switch (_syncBackendMode) {
    case 'none':
      return false;
    case 'auto':
      return !Platform.isAndroid;
    case 'grpc':
    default:
      return true;
  }
}

/// Build the [SyncBackend] for this build/platform.
///
/// [syncClientFactory] is only invoked when a real transport is selected, so
/// the local-only path never constructs a gRPC client. Returns a
/// [NoSyncBackend] otherwise.
SyncBackend createSyncBackend({
  required SyncServiceClient Function() syncClientFactory,
  TokenStorage? tokenStorage,
}) {
  if (!syncEnabled) {
    return NoSyncBackend();
  }
  return GrpcSyncBackend(syncClientFactory(), tokenStorage: tokenStorage);
}
