package middleware

import (
	"context"
	"log"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/jwt"
)

type contextKey string

const UserIDKey contextKey = "user_id"

// publicMethods lists gRPC methods that don't require authentication.
var publicMethods = map[string]bool{
	"/familyledger.auth.v1.AuthService/Register":     true,
	"/familyledger.auth.v1.AuthService/Login":        true,
	"/familyledger.auth.v1.AuthService/RefreshToken": true,
	"/familyledger.auth.v1.AuthService/OAuthLogin":   true,
}

func UnaryAuthInterceptor(jwtManager *jwt.Manager) grpc.UnaryServerInterceptor {
	return func(
		ctx context.Context,
		req interface{},
		info *grpc.UnaryServerInfo,
		handler grpc.UnaryHandler,
	) (interface{}, error) {
		if publicMethods[info.FullMethod] {
			return handler(ctx, req)
		}

		userID, err := extractAndValidateToken(ctx, jwtManager)
		if err != nil {
			log.Printf("auth: rejected %s: %v", info.FullMethod, err)
			return nil, err
		}

		ctx = context.WithValue(ctx, UserIDKey, userID)
		return handler(ctx, req)
	}
}

func StreamAuthInterceptor(jwtManager *jwt.Manager) grpc.StreamServerInterceptor {
	return func(
		srv interface{},
		ss grpc.ServerStream,
		info *grpc.StreamServerInfo,
		handler grpc.StreamHandler,
	) error {
		if publicMethods[info.FullMethod] {
			return handler(srv, ss)
		}

		userID, err := extractAndValidateToken(ss.Context(), jwtManager)
		if err != nil {
			return err
		}

		ctx := context.WithValue(ss.Context(), UserIDKey, userID)
		wrapped := &wrappedStream{ServerStream: ss, ctx: ctx}
		return handler(srv, wrapped)
	}
}

func extractAndValidateToken(ctx context.Context, jwtManager *jwt.Manager) (string, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return "", status.Error(codes.Unauthenticated, "missing metadata")
	}

	values := md.Get("authorization")
	if len(values) == 0 {
		return "", status.Error(codes.Unauthenticated, "missing authorization header")
	}

	token := values[0]
	if !strings.HasPrefix(token, "Bearer ") {
		return "", status.Error(codes.Unauthenticated, "invalid authorization format")
	}
	token = strings.TrimPrefix(token, "Bearer ")

	claims, err := jwtManager.Verify(token)
	if err != nil {
		return "", status.Error(codes.Unauthenticated, "invalid token")
	}

	return claims.UserID, nil
}

func GetUserID(ctx context.Context) (string, error) {
	userID, ok := ctx.Value(UserIDKey).(string)
	if !ok || userID == "" {
		return "", status.Error(codes.Unauthenticated, "user not authenticated")
	}
	return userID, nil
}

type wrappedStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (w *wrappedStream) Context() context.Context {
	return w.ctx
}
