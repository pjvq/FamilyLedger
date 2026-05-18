package middleware

import (
	"context"
	"regexp"

	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

type requestIDKey struct{}

// maxRequestIDLen caps client-provided request IDs to prevent log storage DoS.
const maxRequestIDLen = 64

// validRequestID allows only safe characters: alphanumeric, hyphens, underscores, dots.
var validRequestID = regexp.MustCompile(`^[a-zA-Z0-9\-_.]+$`)

// GetRequestID retrieves the request ID from context (empty string if not set).
func GetRequestID(ctx context.Context) string {
	if id, ok := ctx.Value(requestIDKey{}).(string); ok {
		return id
	}
	return ""
}

// sanitizeRequestID validates a client-provided request ID.
// Returns empty string if invalid (caller should generate a new one).
func sanitizeRequestID(id string) string {
	if len(id) == 0 || len(id) > maxRequestIDLen {
		return ""
	}
	if !validRequestID.MatchString(id) {
		return ""
	}
	return id
}

// UnaryRequestIDInterceptor assigns a unique request ID to each gRPC call.
// The ID is propagated via context and response metadata header "x-request-id".
// Client-provided IDs are validated (alphanumeric + hyphens, max 64 chars);
// invalid or missing IDs are replaced with a server-generated UUID.
func UnaryRequestIDInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		// Check if client provided a valid request ID
		reqID := ""
		if md, ok := metadata.FromIncomingContext(ctx); ok {
			if vals := md.Get("x-request-id"); len(vals) > 0 {
				reqID = sanitizeRequestID(vals[0])
			}
		}
		if reqID == "" {
			reqID = uuid.New().String()
		}

		ctx = context.WithValue(ctx, requestIDKey{}, reqID)

		// Set response header so client can correlate
		_ = grpc.SetHeader(ctx, metadata.Pairs("x-request-id", reqID))

		resp, err := handler(ctx, req)
		return resp, err
	}
}
