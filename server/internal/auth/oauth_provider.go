package auth

import (
	"context"
	"fmt"
	"log"
	"os"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// OAuthUserInfo holds the user info returned from an OAuth provider.
type OAuthUserInfo struct {
	OAuthID     string
	DisplayName string
	AvatarURL   string
}

// OAuthProvider defines the interface for exchanging an OAuth code for user info.
type OAuthProvider interface {
	ExchangeCode(ctx context.Context, code string) (*OAuthUserInfo, error)
}

// ── MockProvider ────────────────────────────────────────────────────────────────

// MockProvider returns deterministic test user data for development.
type MockProvider struct {
	providerName string
}

func NewMockProvider(providerName string) *MockProvider {
	return &MockProvider{providerName: providerName}
}

func (p *MockProvider) ExchangeCode(_ context.Context, code string) (*OAuthUserInfo, error) {
	if code == "test" {
		switch p.providerName {
		case "wechat":
			return &OAuthUserInfo{
				OAuthID:     "wx_mock_openid_001",
				DisplayName: "微信测试用户",
				AvatarURL:   "https://example.com/avatar/wechat.png",
			}, nil
		case "apple":
			return &OAuthUserInfo{
				OAuthID:     "apple_mock_sub_001",
				DisplayName: "Apple Test User",
				AvatarURL:   "",
			}, nil
		}
	}

	// For any other code, generate a deterministic mock user
	return &OAuthUserInfo{
		OAuthID:     fmt.Sprintf("%s_%s", p.providerName, code),
		DisplayName: "OAuth User",
		AvatarURL:   "",
	}, nil
}

// ── WeChatProvider ──────────────────────────────────────────────────────────────

// WeChatProvider exchanges WeChat OAuth codes for user info.
// In production, this would call https://api.weixin.qq.com/sns/oauth2/access_token.
type WeChatProvider struct {
	AppID     string
	AppSecret string
}

func NewWeChatProvider() *WeChatProvider {
	return &WeChatProvider{
		AppID:     os.Getenv("WECHAT_APP_ID"),
		AppSecret: os.Getenv("WECHAT_APP_SECRET"),
	}
}

func (p *WeChatProvider) ExchangeCode(_ context.Context, _ string) (*OAuthUserInfo, error) {
	if p.AppID == "" || p.AppSecret == "" {
		return nil, status.Error(codes.Unimplemented, "wechat oauth not configured")
	}
	// TODO: implement real WeChat OAuth exchange
	// POST https://api.weixin.qq.com/sns/oauth2/access_token
	// GET https://api.weixin.qq.com/sns/userinfo
	return nil, status.Error(codes.Unimplemented, "wechat oauth not implemented")
}

// ── AppleProvider ───────────────────────────────────────────────────────────────

// AppleProvider verifies Apple identity tokens.
// In production, this would verify the JWT with Apple's public keys.
type AppleProvider struct {
	ClientID string
	TeamID   string
}

func NewAppleProvider() *AppleProvider {
	return &AppleProvider{
		ClientID: os.Getenv("APPLE_CLIENT_ID"),
		TeamID:   os.Getenv("APPLE_TEAM_ID"),
	}
}

func (p *AppleProvider) ExchangeCode(_ context.Context, _ string) (*OAuthUserInfo, error) {
	if p.ClientID == "" || p.TeamID == "" {
		return nil, status.Error(codes.Unimplemented, "apple oauth not configured")
	}
	// TODO: implement real Apple OAuth verification
	// Verify the JWT identity token with Apple's public keys
	return nil, status.Error(codes.Unimplemented, "apple oauth not implemented")
}

// ── Factory ─────────────────────────────────────────────────────────────────────

// OAuthProviders holds the set of registered OAuth providers keyed by name.
type OAuthProviders map[string]OAuthProvider

// NewOAuthProviders creates OAuth providers based on the OAUTH_MODE environment variable.
// OAUTH_MODE=mock (default): uses MockProvider for all providers.
// OAUTH_MODE=production: uses real providers (WeChatProvider, AppleProvider).
func NewOAuthProviders() OAuthProviders {
	mode := os.Getenv("OAUTH_MODE")
	if mode == "" {
		mode = "mock"
	}

	providers := make(OAuthProviders)

	if mode == "mock" {
		log.Printf("auth: OAuth mode=mock — using mock providers for development")
		providers["wechat"] = NewMockProvider("wechat")
		providers["apple"] = NewMockProvider("apple")
		return providers
	}

	// Production mode
	log.Printf("auth: OAuth mode=production — using real providers")

	wechat := NewWeChatProvider()
	if wechat.AppID == "" || wechat.AppSecret == "" {
		log.Printf("auth: WARNING: OAUTH_MODE=production but WECHAT_APP_ID/WECHAT_APP_SECRET not configured")
	}
	providers["wechat"] = wechat

	apple := NewAppleProvider()
	if apple.ClientID == "" || apple.TeamID == "" {
		log.Printf("auth: WARNING: OAUTH_MODE=production but APPLE_CLIENT_ID/APPLE_TEAM_ID not configured")
	}
	providers["apple"] = apple

	return providers
}
