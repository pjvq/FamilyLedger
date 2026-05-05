package middleware

import (
	"context"
	"net"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
)

// ── extractIP ───────────────────────────────────────────────────────────────

func TestExtractIP_WithPort(t *testing.T) {
	addr, _ := net.ResolveTCPAddr("tcp", "192.168.1.1:8080")
	ctx := peer.NewContext(context.Background(), &peer.Peer{Addr: addr})
	ip := extractIP(ctx)
	assert.Equal(t, "192.168.1.1", ip)
}

func TestExtractIP_NoPeer(t *testing.T) {
	ip := extractIP(context.Background())
	assert.Equal(t, "unknown", ip)
}

func TestExtractIP_NilAddr(t *testing.T) {
	ctx := peer.NewContext(context.Background(), &peer.Peer{Addr: nil})
	ip := extractIP(ctx)
	assert.Equal(t, "unknown", ip)
}

func TestExtractIP_NoPort(t *testing.T) {
	// Address without port (unlikely but test the fallback)
	addr := &fakeAddr{addr: "192.168.1.1"}
	ctx := peer.NewContext(context.Background(), &peer.Peer{Addr: addr})
	ip := extractIP(ctx)
	assert.Equal(t, "192.168.1.1", ip)
}

type fakeAddr struct{ addr string }

func (f *fakeAddr) Network() string { return "tcp" }
func (f *fakeAddr) String() string  { return f.addr }

// ── UnaryValidationInterceptor ──────────────────────────────────────────────

type validRequest struct{ err error }

func (v *validRequest) Validate() error { return v.err }

func TestUnaryValidationInterceptor_Valid(t *testing.T) {
	interceptor := UnaryValidationInterceptor()
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return "ok", nil
	}
	resp, err := interceptor(context.Background(), &validRequest{err: nil}, &grpc.UnaryServerInfo{}, handler)
	require.NoError(t, err)
	assert.Equal(t, "ok", resp)
}

func TestUnaryValidationInterceptor_Invalid(t *testing.T) {
	interceptor := UnaryValidationInterceptor()
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return "ok", nil
	}
	_, err := interceptor(context.Background(), &validRequest{err: assert.AnError}, &grpc.UnaryServerInfo{}, handler)
	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestUnaryValidationInterceptor_NoValidator(t *testing.T) {
	interceptor := UnaryValidationInterceptor()
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return "ok", nil
	}
	// Plain struct without Validate method → passes through
	resp, err := interceptor(context.Background(), "plain-string", &grpc.UnaryServerInfo{}, handler)
	require.NoError(t, err)
	assert.Equal(t, "ok", resp)
}

// ── DefaultRateLimiterConfig ────────────────────────────────────────────────

func TestDefaultRateLimiterConfig(t *testing.T) {
	cfg := DefaultRateLimiterConfig()
	assert.Greater(t, cfg.GlobalRPS, 0)
	assert.Greater(t, cfg.GlobalBurst, 0)
	assert.Greater(t, cfg.AuthRPS, 0)
}

func TestDefaultRateLimiterConfig_EnvOverride(t *testing.T) {
	t.Setenv("AUTH_RATE_RPS", "20")
	t.Setenv("AUTH_RATE_BURST", "50")
	cfg := DefaultRateLimiterConfig()
	assert.Equal(t, 20, cfg.AuthRPS)
	assert.Equal(t, 50, cfg.AuthBurst)
}

func TestDefaultRateLimiterConfig_InvalidEnv(t *testing.T) {
	t.Setenv("AUTH_RATE_RPS", "not-a-number")
	t.Setenv("AUTH_RATE_BURST", "-1")
	cfg := DefaultRateLimiterConfig()
	assert.Equal(t, 5, cfg.AuthRPS)   // default
	assert.Equal(t, 10, cfg.AuthBurst) // default
}
