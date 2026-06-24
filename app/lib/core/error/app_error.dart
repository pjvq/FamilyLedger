import 'dart:io';

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
  final String message;

  /// Whether a retry might resolve this error.
  bool get isRetryable;

  /// Original exception for logging/debugging.
  final Object? cause;

  const AppError._({required this.message, this.cause});

  /// Convert any exception into a typed [AppError].
  factory AppError.from(Object error, {String? context}) {
    if (error is AppError) return error;

    if (error is GrpcError) return _fromGrpc(error, context);
    if (error is SocketException || error is HttpException) {
      return NetworkError(message: '网络连接失败，请检查网络后重试', cause: error);
    }

    return UnknownError(
      message: context != null ? '$context失败' : '操作失败，请稍后重试',
      cause: error,
    );
  }

  static AppError _fromGrpc(GrpcError error, String? context) {
    return switch (error.code) {
      StatusCode.unauthenticated => AuthError(cause: error),
      StatusCode.permissionDenied => PermissionError(
        message: context != null ? '$context：权限不足' : '权限不足',
        cause: error,
      ),
      StatusCode.notFound => NotFoundError(
        message: context != null ? '$context：未找到' : '数据未找到',
        cause: error,
      ),
      StatusCode.unavailable || StatusCode.deadlineExceeded => NetworkError(
        message: '网络连接失败，请检查网络后重试',
        cause: error,
      ),
      StatusCode.resourceExhausted => RateLimitError(cause: error),
      StatusCode.invalidArgument ||
      StatusCode.failedPrecondition => ValidationError(
        message: context != null ? '$context：参数无效' : '请求参数无效',
        cause: error,
      ),
      _ => UnknownError(
        message: context != null ? '$context失败' : '操作失败，请稍后重试',
        cause: error,
      ),
    };
  }
}

/// Authentication expired or invalid.
class AuthError extends AppError {
  @override
  bool get isRetryable => false;

  const AuthError({super.cause}) : super._(message: '登录已过期，请重新登录');
}

/// Insufficient permissions for the operation.
class PermissionError extends AppError {
  @override
  bool get isRetryable => false;

  const PermissionError({super.message = '权限不足', super.cause}) : super._();
}

/// Resource not found.
class NotFoundError extends AppError {
  @override
  bool get isRetryable => false;

  const NotFoundError({super.message = '数据未找到', super.cause}) : super._();
}

/// Network / connectivity issue — retryable.
class NetworkError extends AppError {
  @override
  bool get isRetryable => true;

  const NetworkError({super.message = '网络连接失败，请检查网络后重试', super.cause})
    : super._();
}

/// Server-side rate limiting.
class RateLimitError extends AppError {
  @override
  bool get isRetryable => true;

  const RateLimitError({super.cause}) : super._(message: '操作过于频繁，请稍后再试');
}

/// Input validation failed (client or server side).
class ValidationError extends AppError {
  @override
  bool get isRetryable => false;

  const ValidationError({super.message = '请求参数无效', super.cause}) : super._();
}

/// Catch-all for unclassified errors.
class UnknownError extends AppError {
  @override
  bool get isRetryable => true;

  const UnknownError({super.message = '操作失败，请稍后重试', super.cause}) : super._();
}
