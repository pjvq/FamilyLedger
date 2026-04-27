package middleware

import (
	"context"
	"testing"
	"time"

	jwtgo "github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/jwt"
)

const testSecret = "test-middleware-secret"

func newTestJWTManager() *jwt.Manager {
	return jwt.NewManager(testSecret)
}

func validToken(t *testing.T, userID string) string {
	t.Helper()
	m := newTestJWTManager()
	pair, err := m.GenerateTokenPair(userID)
	require.NoError(t, err)
	return pair.AccessToken
}

func ctxWithToken(token string) context.Context {
	md := metadata.Pairs("authorization", "Bearer "+token)
	return metadata.NewIncomingContext(context.Background(), md)
}

func makeExpiredToken(t *testing.T) string {
	t.Helper()
	claims := &jwt.Claims{
		UserID: "expired-user",
	}
	claims.ExpiresAt = jwtgo.NewNumericDate(time.Now().Add(-1 * time.Hour))
	claims.IssuedAt = jwtgo.NewNumericDate(time.Now().Add(-2 * time.Hour))

	token := jwtgo.NewWithClaims(jwtgo.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(testSecret))
	require.NoError(t, err)
	return tokenString
}

// --- UnaryAuthInterceptor Tests ---

func TestUnaryAuthInterceptor_PublicMethod_Register(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.auth.v1.AuthService/Register"}

	called := false
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		called = true
		return "ok", nil
	}

	resp, err := interceptor(context.Background(), nil, info, handler)
	require.NoError(t, err)
	assert.True(t, called)
	assert.Equal(t, "ok", resp)
}

func TestUnaryAuthInterceptor_PublicMethod_Login(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.auth.v1.AuthService/Login"}

	called := false
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		called = true
		return "ok", nil
	}

	_, err := interceptor(context.Background(), nil, info, handler)
	require.NoError(t, err)
	assert.True(t, called)
}

func TestUnaryAuthInterceptor_PublicMethod_RefreshToken(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.auth.v1.AuthService/RefreshToken"}

	called := false
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		called = true
		return "ok", nil
	}

	_, err := interceptor(context.Background(), nil, info, handler)
	require.NoError(t, err)
	assert.True(t, called)
}

func TestUnaryAuthInterceptor_PrivateMethod_ValidToken(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.ledger.v1.LedgerService/CreateEntry"}

	token := validToken(t, "user-abc")
	ctx := ctxWithToken(token)

	var capturedUserID string
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		uid, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		capturedUserID = uid
		return "ok", nil
	}

	_, err := interceptor(ctx, nil, info, handler)
	require.NoError(t, err)
	assert.Equal(t, "user-abc", capturedUserID)
}

func TestUnaryAuthInterceptor_PrivateMethod_MissingMetadata(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.ledger.v1.LedgerService/CreateEntry"}

	_, err := interceptor(context.Background(), nil, info, nil)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
	assert.Contains(t, st.Message(), "missing metadata")
}

func TestUnaryAuthInterceptor_PrivateMethod_NoAuthorizationHeader(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.ledger.v1.LedgerService/CreateEntry"}

	md := metadata.Pairs("other-key", "value")
	ctx := metadata.NewIncomingContext(context.Background(), md)

	_, err := interceptor(ctx, nil, info, nil)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
	assert.Contains(t, st.Message(), "missing authorization header")
}

func TestUnaryAuthInterceptor_PrivateMethod_NoBearerPrefix(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.ledger.v1.LedgerService/CreateEntry"}

	md := metadata.Pairs("authorization", "Token some-token-here")
	ctx := metadata.NewIncomingContext(context.Background(), md)

	_, err := interceptor(ctx, nil, info, nil)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
	assert.Contains(t, st.Message(), "invalid authorization format")
}

func TestUnaryAuthInterceptor_PrivateMethod_ExpiredToken(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.ledger.v1.LedgerService/CreateEntry"}

	token := makeExpiredToken(t)
	md := metadata.Pairs("authorization", "Bearer "+token)
	ctx := metadata.NewIncomingContext(context.Background(), md)

	_, err := interceptor(ctx, nil, info, nil)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}

func TestUnaryAuthInterceptor_PrivateMethod_InvalidToken(t *testing.T) {
	interceptor := UnaryAuthInterceptor(newTestJWTManager())
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.ledger.v1.LedgerService/CreateEntry"}

	md := metadata.Pairs("authorization", "Bearer totally-invalid-token")
	ctx := metadata.NewIncomingContext(context.Background(), md)

	_, err := interceptor(ctx, nil, info, nil)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
	assert.Contains(t, st.Message(), "invalid token")
}

// --- StreamAuthInterceptor Tests ---

type mockServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (m *mockServerStream) Context() context.Context {
	return m.ctx
}

func TestStreamAuthInterceptor_PublicMethod(t *testing.T) {
	interceptor := StreamAuthInterceptor(newTestJWTManager())
	info := &grpc.StreamServerInfo{FullMethod: "/familyledger.auth.v1.AuthService/Register"}

	called := false
	handler := func(srv interface{}, stream grpc.ServerStream) error {
		called = true
		return nil
	}

	err := interceptor(nil, &mockServerStream{ctx: context.Background()}, info, handler)
	require.NoError(t, err)
	assert.True(t, called)
}

func TestStreamAuthInterceptor_ValidToken(t *testing.T) {
	interceptor := StreamAuthInterceptor(newTestJWTManager())
	info := &grpc.StreamServerInfo{FullMethod: "/familyledger.ledger.v1.LedgerService/StreamEntries"}

	token := validToken(t, "stream-user")
	ctx := ctxWithToken(token)
	stream := &mockServerStream{ctx: ctx}

	var capturedUserID string
	handler := func(srv interface{}, ss grpc.ServerStream) error {
		uid, err := GetUserID(ss.Context())
		if err != nil {
			return err
		}
		capturedUserID = uid
		return nil
	}

	err := interceptor(nil, stream, info, handler)
	require.NoError(t, err)
	assert.Equal(t, "stream-user", capturedUserID)
}

func TestStreamAuthInterceptor_InvalidToken(t *testing.T) {
	interceptor := StreamAuthInterceptor(newTestJWTManager())
	info := &grpc.StreamServerInfo{FullMethod: "/familyledger.ledger.v1.LedgerService/StreamEntries"}

	md := metadata.Pairs("authorization", "Bearer bad-token")
	ctx := metadata.NewIncomingContext(context.Background(), md)
	stream := &mockServerStream{ctx: ctx}

	handler := func(srv interface{}, ss grpc.ServerStream) error {
		t.Fatal("handler should not be called")
		return nil
	}

	err := interceptor(nil, stream, info, handler)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}

// --- GetUserID Tests ---

func TestGetUserID_ValidContext(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserIDKey, "user-in-ctx")
	uid, err := GetUserID(ctx)
	require.NoError(t, err)
	assert.Equal(t, "user-in-ctx", uid)
}

func TestGetUserID_MissingFromContext(t *testing.T) {
	_, err := GetUserID(context.Background())
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}

func TestGetUserID_EmptyString(t *testing.T) {
	ctx := context.WithValue(context.Background(), UserIDKey, "")
	_, err := GetUserID(ctx)
	require.Error(t, err)
	st, ok := status.FromError(err)
	require.True(t, ok)
	assert.Equal(t, codes.Unauthenticated, st.Code())
}
