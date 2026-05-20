import 'dart:developer' as dev;

/// Lightweight logger that wraps dart:developer.log.
/// In release builds, dev.log is a no-op (tree-shaken by the compiler).
/// Use [AppLogger.sync], [AppLogger.ws], [AppLogger.auth] for named loggers.
class AppLogger {
  final String _name;

  const AppLogger(this._name);

  static const sync = AppLogger('sync');
  static const ws = AppLogger('ws');
  static const auth = AppLogger('auth');

  void info(String message) {
    dev.log(message, name: _name);
  }

  void warn(String message) {
    dev.log('[WARN] $message', name: _name);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    dev.log('[ERROR] $message', name: _name, error: error, stackTrace: stackTrace);
  }
}
