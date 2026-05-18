package middleware

import (
	"context"
	"log/slog"

	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

type requestIDKey struct{}

// GetRequestID retrieves the request ID from context (empty string if not set).
func GetRequestID(ctx context.Context) string {
	if id, ok := ctx.Value(requestIDKey{}).(string); ok {
		return id
	}
	return ""
}

// UnaryRequestIDInterceptor assigns a unique request ID to each gRPC call.
// The ID is propagated via context and response metadata header "x-request-id".
func UnaryRequestIDInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		// Check if client provided a request ID
		reqID := ""
		if md, ok := metadata.FromIncomingContext(ctx); ok {
			if vals := md.Get("x-request-id"); len(vals) > 0 {
				reqID = vals[0]
			}
		}
		if reqID == "" {
			reqID = uuid.New().String()
		}

		ctx = context.WithValue(ctx, requestIDKey{}, reqID)

		// Set response header
		_ = grpc.SetHeader(ctx, metadata.Pairs("x-request-id", reqID))

		// Add to slog context
		slog.DebugContext(ctx, "grpc request", "method", info.FullMethod, "request_id", reqID)

		resp, err := handler(ctx, req)
		if err != nil {
			slog.WarnContext(ctx, "grpc error", "method", info.FullMethod, "request_id", reqID, "error", err)
		}
		return resp, err
	}
}
