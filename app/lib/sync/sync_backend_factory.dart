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
/// Override with `--dart-define=SYNC_BACKEND=<mode>`. Values:
/// - `auto`  — pick by platform: Android → none (local-only, design §9), other
///   platforms → grpc. This is the default.
/// - `grpc`  — force the gRPC + WebSocket backend.
/// - `none`  — force [NoSyncBackend] (local-only, no sync transport).
const String _syncBackendMode = String.fromEnvironment(
  'SYNC_BACKEND',
  defaultValue: 'auto',
);

/// Whether the active build should use a real sync transport.
///
/// Resolves the compile-time [_syncBackendMode] against the current platform.
/// Use this to gate sync-only setup (building a gRPC client, CRUD over gRPC,
/// auth login) so a local-only build never touches the network.
///
/// This is an **app-lifecycle-immutable** decision: it depends only on a
/// compile-time define and the platform, so providers read it once at build
/// time. Runtime toggling of the sync mode is not supported and would require
/// a restart. If dynamic switching is ever needed (e.g. Phase 3 iCloud opt-in),
/// promote this to a Riverpod `syncEnabledProvider` that providers watch.
bool get syncEnabled {
  switch (_syncBackendMode) {
    case 'none':
      return false;
    case 'grpc':
      return true;
    case 'auto':
    default:
      return !Platform.isAndroid;
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
