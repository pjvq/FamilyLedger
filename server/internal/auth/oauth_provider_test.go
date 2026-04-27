package auth

import (
	"context"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestMockProvider_ExchangeCode_TestCode(t *testing.T) {
	provider := NewMockProvider("wechat")
	info, err := provider.ExchangeCode(context.Background(), "test")
	require.NoError(t, err)
	assert.Equal(t, "wx_mock_openid_001", info.OAuthID)
	assert.Equal(t, "微信测试用户", info.DisplayName)
	assert.Equal(t, "https://example.com/avatar/wechat.png", info.AvatarURL)
}

func TestMockProvider_ExchangeCode_AppleTestCode(t *testing.T) {
	provider := NewMockProvider("apple")
	info, err := provider.ExchangeCode(context.Background(), "test")
	require.NoError(t, err)
	assert.Equal(t, "apple_mock_sub_001", info.OAuthID)
	assert.Equal(t, "Apple Test User", info.DisplayName)
	assert.Empty(t, info.AvatarURL)
}

func TestMockProvider_ExchangeCode_ArbitraryCode(t *testing.T) {
	provider := NewMockProvider("wechat")
	info, err := provider.ExchangeCode(context.Background(), "arbitrary_code_123")
	require.NoError(t, err)
	assert.Equal(t, "wechat_arbitrary_code_123", info.OAuthID)
	assert.Equal(t, "OAuth User", info.DisplayName)
}

func TestWeChatProvider_NotConfigured(t *testing.T) {
	// Ensure env vars are unset
	os.Unsetenv("WECHAT_APP_ID")
	os.Unsetenv("WECHAT_APP_SECRET")

	provider := NewWeChatProvider()
	_, err := provider.ExchangeCode(context.Background(), "some_code")
	require.Error(t, err)
	assert.Equal(t, codes.Unimplemented, status.Code(err))
	assert.Contains(t, err.Error(), "wechat oauth not configured")
}

func TestAppleProvider_NotConfigured(t *testing.T) {
	// Ensure env vars are unset
	os.Unsetenv("APPLE_CLIENT_ID")
	os.Unsetenv("APPLE_TEAM_ID")

	provider := NewAppleProvider()
	_, err := provider.ExchangeCode(context.Background(), "some_code")
	require.Error(t, err)
	assert.Equal(t, codes.Unimplemented, status.Code(err))
	assert.Contains(t, err.Error(), "apple oauth not configured")
}

func TestNewOAuthProviders_MockMode(t *testing.T) {
	os.Setenv("OAUTH_MODE", "mock")
	defer os.Unsetenv("OAUTH_MODE")

	providers := NewOAuthProviders()
	assert.Len(t, providers, 2)

	// Mock providers should return data successfully
	info, err := providers["wechat"].ExchangeCode(context.Background(), "test")
	require.NoError(t, err)
	assert.Equal(t, "wx_mock_openid_001", info.OAuthID)

	info, err = providers["apple"].ExchangeCode(context.Background(), "test")
	require.NoError(t, err)
	assert.Equal(t, "apple_mock_sub_001", info.OAuthID)
}

func TestNewOAuthProviders_ProductionMode_NotConfigured(t *testing.T) {
	os.Setenv("OAUTH_MODE", "production")
	os.Unsetenv("WECHAT_APP_ID")
	os.Unsetenv("WECHAT_APP_SECRET")
	os.Unsetenv("APPLE_CLIENT_ID")
	os.Unsetenv("APPLE_TEAM_ID")
	defer os.Unsetenv("OAUTH_MODE")

	providers := NewOAuthProviders()
	assert.Len(t, providers, 2)

	// Production providers without config should return Unimplemented
	_, err := providers["wechat"].ExchangeCode(context.Background(), "some_code")
	require.Error(t, err)
	assert.Equal(t, codes.Unimplemented, status.Code(err))

	_, err = providers["apple"].ExchangeCode(context.Background(), "some_code")
	require.Error(t, err)
	assert.Equal(t, codes.Unimplemented, status.Code(err))
}

func TestNewOAuthProviders_DefaultIsMock(t *testing.T) {
	os.Unsetenv("OAUTH_MODE")

	providers := NewOAuthProviders()

	// Should use mock by default
	info, err := providers["wechat"].ExchangeCode(context.Background(), "test")
	require.NoError(t, err)
	assert.Equal(t, "wx_mock_openid_001", info.OAuthID)
}
