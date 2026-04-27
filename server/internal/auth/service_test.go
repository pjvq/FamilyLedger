package auth

import (
	"context"
	"testing"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/bcrypt"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/jwt"
	pb "github.com/familyledger/server/proto/auth"
)

// testPassword / testHash are pre-computed to avoid bcrypt overhead per test.
var (
	testPassword = "securepass123"
	testHash     string
)

func init() {
	h, err := bcrypt.GenerateFromPassword([]byte(testPassword), bcrypt.MinCost)
	if err != nil {
		panic(err)
	}
	testHash = string(h)
}

func newTestService(t *testing.T) (*Service, pgxmock.PgxPoolIface) {
	t.Helper()
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	jwtManager := jwt.NewManager("test-secret-key")
	// Use mock providers for testing
	providers := OAuthProviders{
		"wechat": NewMockProvider("wechat"),
		"apple":  NewMockProvider("apple"),
	}
	svc := NewService(mock, jwtManager, WithOAuthProviders(providers))
	return svc, mock
}

// ─── Register ────────────────────────────────────────────────────────────────

func TestRegister_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	// Check user existence → not found
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs("test@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	// Begin tx
	mock.ExpectBegin()

	// Insert user
	mock.ExpectQuery("INSERT INTO users").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(userID))

	// Insert default account
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectCommit()

	resp, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "test@example.com",
		Password: "password123",
	})

	require.NoError(t, err)
	assert.Equal(t, userID.String(), resp.UserId)
	assert.NotEmpty(t, resp.AccessToken)
	assert.NotEmpty(t, resp.RefreshToken)
	assert.NotNil(t, resp.ExpiresAt)
}

func TestRegister_EmptyEmail(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestRegister_ShortPassword(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "test@example.com",
		Password: "12345",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestRegister_AlreadyExists(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs("existing@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	_, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "existing@example.com",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.AlreadyExists, status.Code(err))
}

// ─── Login ───────────────────────────────────────────────────────────────────

func TestLogin_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	mock.ExpectQuery("SELECT id, password_hash FROM users").
		WithArgs("test@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"id", "password_hash"}).AddRow(userID, testHash))

	resp, err := svc.Login(context.Background(), &pb.LoginRequest{
		Email:    "test@example.com",
		Password: testPassword,
	})

	require.NoError(t, err)
	assert.Equal(t, userID.String(), resp.UserId)
	assert.NotEmpty(t, resp.AccessToken)
	assert.NotEmpty(t, resp.RefreshToken)
}

func TestLogin_EmptyFields(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.Login(context.Background(), &pb.LoginRequest{
		Email:    "",
		Password: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestLogin_WrongPassword(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	mock.ExpectQuery("SELECT id, password_hash FROM users").
		WithArgs("test@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"id", "password_hash"}).AddRow(userID, testHash))

	_, err := svc.Login(context.Background(), &pb.LoginRequest{
		Email:    "test@example.com",
		Password: "wrongpassword",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestLogin_UserNotFound(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	// Return empty rows → QueryRow.Scan gets pgx.ErrNoRows
	mock.ExpectQuery("SELECT id, password_hash FROM users").
		WithArgs("notfound@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"id", "password_hash"}))

	_, err := svc.Login(context.Background(), &pb.LoginRequest{
		Email:    "notfound@example.com",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── RefreshToken ────────────────────────────────────────────────────────────

func TestRefreshToken_Success(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	jwtManager := jwt.NewManager("test-secret-key")

	// Generate a valid refresh token
	userID := uuid.New().String()
	tokenPair, err := jwtManager.GenerateTokenPair(userID)
	require.NoError(t, err)

	// Mock: user exists check
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(userID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	resp, err := svc.RefreshToken(context.Background(), &pb.RefreshTokenRequest{
		RefreshToken: tokenPair.RefreshToken,
	})

	require.NoError(t, err)
	assert.NotEmpty(t, resp.AccessToken)
	assert.NotEmpty(t, resp.RefreshToken)
}

func TestRefreshToken_EmptyToken(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.RefreshToken(context.Background(), &pb.RefreshTokenRequest{
		RefreshToken: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestRefreshToken_InvalidToken(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.RefreshToken(context.Background(), &pb.RefreshTokenRequest{
		RefreshToken: "invalid.token.string",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── OAuthLogin ──────────────────────────────────────────────────────────────

func TestOAuthLogin_NewUser(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	// Look up existing oauth user → not found (empty rows)
	mock.ExpectQuery("SELECT id FROM users WHERE oauth_provider").
		WithArgs("wechat", "wx_mock_openid_001").
		WillReturnRows(pgxmock.NewRows([]string{"id"}))

	// Begin tx for new user creation
	mock.ExpectBegin()

	// Insert new user with OAuth fields
	mock.ExpectQuery("INSERT INTO users").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(userID))

	// Insert default account
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectCommit()

	resp, err := svc.OAuthLogin(context.Background(), &pb.OAuthLoginRequest{
		Provider: "wechat",
		Code:     "test",
	})

	require.NoError(t, err)
	assert.Equal(t, userID.String(), resp.UserId)
	assert.True(t, resp.IsNewUser)
	assert.NotEmpty(t, resp.AccessToken)
	assert.NotEmpty(t, resp.RefreshToken)
}

func TestOAuthLogin_ExistingUser(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	// Look up existing oauth user → found
	mock.ExpectQuery("SELECT id FROM users WHERE oauth_provider").
		WithArgs("wechat", "wx_mock_openid_001").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(userID))

	// Update display_name + avatar_url
	mock.ExpectExec("UPDATE users SET display_name").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	resp, err := svc.OAuthLogin(context.Background(), &pb.OAuthLoginRequest{
		Provider: "wechat",
		Code:     "test",
	})

	require.NoError(t, err)
	assert.Equal(t, userID.String(), resp.UserId)
	assert.False(t, resp.IsNewUser)
	assert.NotEmpty(t, resp.AccessToken)
}

func TestOAuthLogin_InvalidProvider(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.OAuthLogin(context.Background(), &pb.OAuthLoginRequest{
		Provider: "github",
		Code:     "test",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}
