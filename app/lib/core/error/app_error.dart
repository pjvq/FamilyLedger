import 'package:grpc/grpc.dart';

/// Unified error classification for the app.
///
/// All providers should convert raw exceptions (gRPC, DB, network)
/// into [AppError] before surfacing to the UI layer.
///
/// Usage:
///   try { ... }
///   catch (e) { state = state.copyWith(error: AppError.from(e)); }
///
/// UI layer checks `error.isRetryable` to decide whether to show retry button.
sealed class AppError {
  /// User-visible message (Chinese).
  String get message;

  /// Whether a retry might resolve this error.
  bool get isRetryable;

  /// Original exception for logging/debugging.
  Object? get cause;

  /// Convert any exception into a typed [AppError].
  factory AppError.from(Object error, {String? context}) {
    if (error is AppError) return error;

    if (error is GrpcError) {
      return switch (error.code) {
        StatusCode.unauthenticated => AuthError._(
            message: '登录已过期，请重新登录',
            cause: error,
          ),
        StatusCode.permissionDenied => PermissionError._(
            message: context != null ? '$context：权限不足' : '权限不足',
            cause: error,
          ),
        StatusCode.notFound => NotFoundError._(
            message: context != null ? '$context：未找到' : '数据未找到',
            cause: error,
          ),
        StatusCode.unavailable || StatusCode.deadlineExceeded => NetworkError._(
            message: '网络连接失败，请检查网络后重试',
            cause: error,
          ),
        StatusCode.resourceExhausted => RateLimitError._(
            message: '操作过于频繁，请稍后再试',
            cause: error,
          ),
        StatusCode.invalidArgument ||
        StatusCode.failedPrecondition => ValidationError._(
            message: error.message ?? '请求参数无效',
            cause: error,
          ),
        _ => UnknownError._(
            message: context != null ? '$context失败' : '操作失败，请稍后重试',
            cause: error,
          ),
      };
    }

    // Network / IO errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Network is unreachable')) {
      return NetworkError._(
        message: '网络连接失败，请检查网络后重试',
        cause: error,
      );
    }

    return UnknownError._(
      message: context != null ? '$context失败' : '操作失败，请稍后重试',
      cause: error,
    );
  }
}

/// Authentication expired or invalid.
class AuthError implements AppError {
  @override
  final String message;
  @override
  final Object? cause;
  @override
  bool get isRetryable => false;

  const AuthError._({required this.message, this.cause});
}

/// Insufficient permissions for the operation.
class PermissionError implements AppError {
  @override
  final String message;
  @override
  final Object? cause;
  @override
  bool get isRetryable => false;

  const PermissionError._({required this.message, this.cause});
}

/// Resource not found.
class NotFoundError implements AppError {
  @override
  final String message;
  @override
  final Object? cause;
  @override
  bool get isRetryable => false;

  const NotFoundError._({required this.message, this.cause});
}

/// Network / connectivity issue — retryable.
class NetworkError implements AppError {
  @override
  final String message;
  @override
  final Object? cause;
  @override
  bool get isRetryable => true;

  const NetworkError._({required this.message, this.cause});
}

/// Server-side rate limiting.
class RateLimitError implements AppError {
  @override
  final String message;
  @override
  final Object? cause;
  @override
  bool get isRetryable => true;

  const RateLimitError._({required this.message, this.cause});
}

/// Input validation failed (client or server side).
class ValidationError implements AppError {
  @override
  final String message;
  @override
  final Object? cause;
  @override
  bool get isRetryable => false;

  const ValidationError._({required this.message, this.cause});
}

/// Catch-all for unclassified errors.
class UnknownError implements AppError {
  @override
  final String message;
  @override
  final Object? cause;
  @override
  bool get isRetryable => true;

  const UnknownError._({required this.message, this.cause});
}
