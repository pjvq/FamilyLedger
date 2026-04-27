package middleware

import (
	"context"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestRateLimiter_GlobalLimit(t *testing.T) {
	cfg := RateLimiterConfig{
		GlobalRPS:       2,
		GlobalBurst:     2,
		AuthRPS:         1,
		AuthBurst:       1,
		CleanupInterval: time.Minute,
		EntryTTL:        time.Minute,
	}
	rl := NewRateLimiter(cfg)
	defer rl.Stop()

	interceptor := UnaryRateLimitInterceptor(rl)
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return "ok", nil
	}
	info := &grpc.UnaryServerInfo{FullMethod: "/some.Service/Method"}

	// First 2 requests should pass (burst=2)
	for i := 0; i < 2; i++ {
		resp, err := interceptor(context.Background(), nil, info, handler)
		if err != nil {
			t.Fatalf("request %d should pass: %v", i, err)
		}
		if resp != "ok" {
			t.Fatalf("expected 'ok', got %v", resp)
		}
	}

	// 3rd request should be rate limited
	_, err := interceptor(context.Background(), nil, info, handler)
	if err == nil {
		t.Fatal("3rd request should be rate limited")
	}
	st, ok := status.FromError(err)
	if !ok || st.Code() != codes.ResourceExhausted {
		t.Fatalf("expected ResourceExhausted, got %v", err)
	}
}

func TestRateLimiter_AuthLimit(t *testing.T) {
	cfg := RateLimiterConfig{
		GlobalRPS:       100,
		GlobalBurst:     100,
		AuthRPS:         1,
		AuthBurst:       1,
		CleanupInterval: time.Minute,
		EntryTTL:        time.Minute,
	}
	rl := NewRateLimiter(cfg)
	defer rl.Stop()

	interceptor := UnaryRateLimitInterceptor(rl)
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return "ok", nil
	}
	info := &grpc.UnaryServerInfo{FullMethod: "/familyledger.auth.v1.AuthService/Login"}

	// 1st login should pass
	_, err := interceptor(context.Background(), nil, info, handler)
	if err != nil {
		t.Fatalf("1st login should pass: %v", err)
	}

	// 2nd login should be rate limited (auth burst=1)
	_, err = interceptor(context.Background(), nil, info, handler)
	if err == nil {
		t.Fatal("2nd rapid login should be rate limited")
	}
	st, _ := status.FromError(err)
	if st.Code() != codes.ResourceExhausted {
		t.Fatalf("expected ResourceExhausted, got %v", st.Code())
	}
}

func TestRateLimiter_Refill(t *testing.T) {
	cfg := RateLimiterConfig{
		GlobalRPS:       10,
		GlobalBurst:     1,
		AuthRPS:         10,
		AuthBurst:       1,
		CleanupInterval: time.Minute,
		EntryTTL:        time.Minute,
	}
	rl := NewRateLimiter(cfg)
	defer rl.Stop()

	interceptor := UnaryRateLimitInterceptor(rl)
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return "ok", nil
	}
	info := &grpc.UnaryServerInfo{FullMethod: "/some.Service/Method"}

	// Exhaust the bucket
	_, _ = interceptor(context.Background(), nil, info, handler)
	_, err := interceptor(context.Background(), nil, info, handler)
	if err == nil {
		t.Fatal("should be rate limited after exhausting burst")
	}

	// Wait for refill (100ms at 10 RPS = 1 token)
	time.Sleep(150 * time.Millisecond)

	_, err = interceptor(context.Background(), nil, info, handler)
	if err != nil {
		t.Fatalf("should pass after refill: %v", err)
	}
}

func TestRateLimiter_Cleanup(t *testing.T) {
	cfg := RateLimiterConfig{
		GlobalRPS:       100,
		GlobalBurst:     100,
		AuthRPS:         10,
		AuthBurst:       10,
		CleanupInterval: 50 * time.Millisecond,
		EntryTTL:        100 * time.Millisecond,
	}
	rl := NewRateLimiter(cfg)
	defer rl.Stop()

	// Create an entry
	rl.getEntry("1.2.3.4")

	rl.mu.Lock()
	if len(rl.buckets) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(rl.buckets))
	}
	rl.mu.Unlock()

	// Wait for cleanup
	time.Sleep(200 * time.Millisecond)

	rl.mu.Lock()
	count := len(rl.buckets)
	rl.mu.Unlock()
	if count != 0 {
		t.Fatalf("expected 0 entries after cleanup, got %d", count)
	}
}

func TestExtractIP(t *testing.T) {
	// Without peer info, should return "unknown"
	ip := extractIP(context.Background())
	if ip != "unknown" {
		t.Fatalf("expected 'unknown', got %s", ip)
	}
}
