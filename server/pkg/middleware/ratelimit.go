package middleware

import (
	"context"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
)

// RateLimiterConfig defines rate limiting parameters.
type RateLimiterConfig struct {
	// Global per-IP limit (requests per second)
	GlobalRPS int
	// Burst size (max tokens in bucket)
	GlobalBurst int
	// Auth endpoints have stricter limits (per-IP)
	AuthRPS   int
	AuthBurst int
	// Cleanup interval for stale entries
	CleanupInterval time.Duration
	// Entry TTL (remove if no requests for this duration)
	EntryTTL time.Duration
}

// DefaultRateLimiterConfig returns sensible defaults.
func DefaultRateLimiterConfig() RateLimiterConfig {
	return RateLimiterConfig{
		GlobalRPS:       100,
		GlobalBurst:     200,
		AuthRPS:         5,
		AuthBurst:       10,
		CleanupInterval: 5 * time.Minute,
		EntryTTL:        10 * time.Minute,
	}
}

// tokenBucket implements a simple token bucket rate limiter.
type tokenBucket struct {
	tokens     float64
	maxTokens  float64
	refillRate float64 // tokens per second
	lastRefill time.Time
}

func newTokenBucket(rps, burst int) *tokenBucket {
	return &tokenBucket{
		tokens:     float64(burst),
		maxTokens:  float64(burst),
		refillRate: float64(rps),
		lastRefill: time.Now(),
	}
}

// allow checks if a request is allowed and consumes a token if so.
func (tb *tokenBucket) allow() bool {
	now := time.Now()
	elapsed := now.Sub(tb.lastRefill).Seconds()
	tb.tokens += elapsed * tb.refillRate
	if tb.tokens > tb.maxTokens {
		tb.tokens = tb.maxTokens
	}
	tb.lastRefill = now

	if tb.tokens >= 1 {
		tb.tokens--
		return true
	}
	return false
}

type bucketEntry struct {
	global   *tokenBucket
	auth     *tokenBucket
	lastSeen time.Time
}

// RateLimiter manages per-IP rate limiting.
type RateLimiter struct {
	mu      sync.Mutex
	buckets map[string]*bucketEntry
	config  RateLimiterConfig
	stop    chan struct{}
}

// NewRateLimiter creates a new rate limiter with background cleanup.
func NewRateLimiter(cfg RateLimiterConfig) *RateLimiter {
	rl := &RateLimiter{
		buckets: make(map[string]*bucketEntry),
		config:  cfg,
		stop:    make(chan struct{}),
	}
	go rl.cleanup()
	return rl
}

// Stop halts the background cleanup goroutine.
func (rl *RateLimiter) Stop() {
	close(rl.stop)
}

func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(rl.config.CleanupInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			rl.mu.Lock()
			now := time.Now()
			for ip, entry := range rl.buckets {
				if now.Sub(entry.lastSeen) > rl.config.EntryTTL {
					delete(rl.buckets, ip)
				}
			}
			rl.mu.Unlock()
		case <-rl.stop:
			return
		}
	}
}

func (rl *RateLimiter) getEntry(ip string) *bucketEntry {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	entry, ok := rl.buckets[ip]
	if !ok {
		entry = &bucketEntry{
			global:   newTokenBucket(rl.config.GlobalRPS, rl.config.GlobalBurst),
			auth:     newTokenBucket(rl.config.AuthRPS, rl.config.AuthBurst),
			lastSeen: time.Now(),
		}
		rl.buckets[ip] = entry
	} else {
		entry.lastSeen = time.Now()
	}
	return entry
}

// authMethods are rate-limited more strictly.
var authMethods = map[string]bool{
	"/familyledger.auth.v1.AuthService/Register":     true,
	"/familyledger.auth.v1.AuthService/Login":        true,
	"/familyledger.auth.v1.AuthService/RefreshToken": true,
	"/familyledger.auth.v1.AuthService/OAuthLogin":   true,
}

// UnaryRateLimitInterceptor returns a gRPC unary interceptor for rate limiting.
func UnaryRateLimitInterceptor(rl *RateLimiter) grpc.UnaryServerInterceptor {
	return func(
		ctx context.Context,
		req interface{},
		info *grpc.UnaryServerInfo,
		handler grpc.UnaryHandler,
	) (interface{}, error) {
		ip := extractIP(ctx)
		entry := rl.getEntry(ip)

		// Check auth-specific rate limit first
		if authMethods[info.FullMethod] {
			if !entry.auth.allow() {
				return nil, status.Errorf(codes.ResourceExhausted,
					"rate limit exceeded for auth endpoint, try again later")
			}
		}

		// Check global rate limit
		if !entry.global.allow() {
			return nil, status.Errorf(codes.ResourceExhausted,
				"rate limit exceeded, try again later")
		}

		return handler(ctx, req)
	}
}

// extractIP gets the client IP from gRPC peer info.
func extractIP(ctx context.Context) string {
	p, ok := peer.FromContext(ctx)
	if !ok || p.Addr == nil {
		return "unknown"
	}
	// peer.Addr.String() returns "ip:port"
	addr := p.Addr.String()
	// Strip port
	for i := len(addr) - 1; i >= 0; i-- {
		if addr[i] == ':' {
			return addr[:i]
		}
	}
	return addr
}
