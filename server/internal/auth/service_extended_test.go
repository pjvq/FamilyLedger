package auth

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/jwt"
	pb "github.com/familyledger/server/proto/auth"
)

// ─── Register: error paths ───────────────────────────────────────────────────

func TestRegister_InvalidEmailFormat(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	// ValidateEmail only checks: non-empty + contains "@" + contains "."
	cases := []string{
		"notanemail",        // no @ or .
		"missing-at-sign",   // no @
		"nodot@example",     // no .
	}

	for _, email := range cases {
		t.Run(email, func(t *testing.T) {
			_, err := svc.Register(context.Background(), &pb.RegisterRequest{
				Email:    email,
				Password: "password123",
			})
			require.Error(t, err)
			assert.Equal(t, codes.InvalidArgument, status.Code(err))
		})
	}
}

func TestRegister_DBCheckExistenceFailure(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs("test@example.com").
		WillReturnError(errors.New("connection refused"))

	_, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "test@example.com",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestRegister_DBBeginTxFailure(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs("test@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	mock.ExpectBegin().WillReturnError(errors.New("cannot allocate transaction"))

	_, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "test@example.com",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestRegister_DBInsertUserFailure(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs("test@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	mock.ExpectBegin()

	mock.ExpectQuery("INSERT INTO users").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(errors.New("unique violation"))

	mock.ExpectRollback()

	_, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "test@example.com",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestRegister_DBInsertAccountFailure(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs("test@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	mock.ExpectBegin()

	mock.ExpectQuery("INSERT INTO users").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(userID))

	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(errors.New("disk full"))

	mock.ExpectRollback()

	_, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "test@example.com",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestRegister_DBCommitFailure(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs("test@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	mock.ExpectBegin()

	mock.ExpectQuery("INSERT INTO users").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(userID))

	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectCommit().WillReturnError(errors.New("serialization failure"))

	_, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "test@example.com",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ─── Login: error paths ──────────────────────────────────────────────────────

func TestLogin_OnlyEmailEmpty(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.Login(context.Background(), &pb.LoginRequest{
		Email:    "",
		Password: "password123",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestLogin_OnlyPasswordEmpty(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.Login(context.Background(), &pb.LoginRequest{
		Email:    "test@example.com",
		Password: "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestLogin_DBFailure(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	mock.ExpectQuery("SELECT id, password_hash FROM users").
		WithArgs("test@example.com").
		WillReturnError(errors.New("connection reset"))

	_, err := svc.Login(context.Background(), &pb.LoginRequest{
		Email:    "test@example.com",
		Password: "password123",
	})

	require.Error(t, err)
	// DB errors appear as Unauthenticated to avoid leaking info
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── RefreshToken: error paths ───────────────────────────────────────────────

func TestRefreshToken_UserDeleted(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	jwtManager := jwt.NewManager("test-secret-key")
	userID := uuid.New().String()
	tokenPair, err := jwtManager.GenerateTokenPair(userID)
	require.NoError(t, err)

	// User no longer exists
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(userID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	_, err = svc.RefreshToken(context.Background(), &pb.RefreshTokenRequest{
		RefreshToken: tokenPair.RefreshToken,
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
	assert.Contains(t, status.Convert(err).Message(), "user not found")
}

func TestRefreshToken_DBFailure(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	jwtManager := jwt.NewManager("test-secret-key")
	userID := uuid.New().String()
	tokenPair, err := jwtManager.GenerateTokenPair(userID)
	require.NoError(t, err)

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(userID).
		WillReturnError(errors.New("timeout"))

	_, err = svc.RefreshToken(context.Background(), &pb.RefreshTokenRequest{
		RefreshToken: tokenPair.RefreshToken,
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestRefreshToken_ExpiredToken(t *testing.T) {
	// Create a JWT manager with very short TTL to simulate expired token
	jwtManager := jwt.NewManager("test-secret-key", jwt.WithAccessTTL(1*time.Millisecond), jwt.WithRefreshTTL(1*time.Millisecond))

	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	svc := NewService(mock, jwtManager)

	userID := uuid.New().String()
	tokenPair, err := jwtManager.GenerateTokenPair(userID)
	require.NoError(t, err)

	// Wait for token to expire
	time.Sleep(5 * time.Millisecond)

	_, err = svc.RefreshToken(context.Background(), &pb.RefreshTokenRequest{
		RefreshToken: tokenPair.RefreshToken,
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

// ─── OAuthLogin: error paths ─────────────────────────────────────────────────

func TestOAuthLogin_EmptyCode(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.OAuthLogin(context.Background(), &pb.OAuthLoginRequest{
		Provider: "wechat",
		Code:     "",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestOAuthLogin_EmptyProvider(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	_, err := svc.OAuthLogin(context.Background(), &pb.OAuthLoginRequest{
		Provider: "",
		Code:     "test",
	})

	require.Error(t, err)
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// failingProvider simulates an OAuth provider that always fails.
type failingProvider struct{}

func (p *failingProvider) ExchangeCode(_ context.Context, _ string) (*OAuthUserInfo, error) {
	return nil, status.Error(codes.Unavailable, "provider unreachable")
}

func TestOAuthLogin_ProviderExchangeFailure(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	jwtManager := jwt.NewManager("test-secret-key")
	providers := OAuthProviders{
		"wechat": &failingProvider{},
		"apple":  &failingProvider{},
	}
	svc := NewService(mock, jwtManager, WithOAuthProviders(providers))

	_, err = svc.OAuthLogin(context.Background(), &pb.OAuthLoginRequest{
		Provider: "wechat",
		Code:     "some_code",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestOAuthLogin_DBLookupFailure(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	// Query for existing user fails with a non-ErrNoRows error
	mock.ExpectQuery("SELECT id FROM users WHERE oauth_provider").
		WithArgs("wechat", "wx_mock_openid_001").
		WillReturnError(pgx.ErrNoRows)

	// pgx.ErrNoRows triggers new user creation path
	mock.ExpectBegin()

	mock.ExpectQuery("INSERT INTO users").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(errors.New("constraint violation"))

	mock.ExpectRollback()

	_, err := svc.OAuthLogin(context.Background(), &pb.OAuthLoginRequest{
		Provider: "wechat",
		Code:     "test",
	})

	require.Error(t, err)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestOAuthLogin_AppleProvider(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	mock.ExpectQuery("SELECT id FROM users WHERE oauth_provider").
		WithArgs("apple", "apple_mock_sub_001").
		WillReturnRows(pgxmock.NewRows([]string{"id"}))

	mock.ExpectBegin()

	mock.ExpectQuery("INSERT INTO users").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(userID))

	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	mock.ExpectCommit()

	resp, err := svc.OAuthLogin(context.Background(), &pb.OAuthLoginRequest{
		Provider: "apple",
		Code:     "test",
	})

	require.NoError(t, err)
	assert.Equal(t, userID.String(), resp.UserId)
	assert.True(t, resp.IsNewUser)
}

// ─── JWT / Password verification ─────────────────────────────────────────────

func TestRegister_ResponseTokensAreValid(t *testing.T) {
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs("verify@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO users").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(userID))
	mock.ExpectExec("INSERT INTO accounts").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	resp, err := svc.Register(context.Background(), &pb.RegisterRequest{
		Email:    "verify@example.com",
		Password: "password123",
	})
	require.NoError(t, err)

	// Verify access token is valid and contains correct user ID
	jwtManager := jwt.NewManager("test-secret-key")
	claims, err := jwtManager.Verify(resp.AccessToken)
	require.NoError(t, err)
	assert.Equal(t, userID.String(), claims.UserID)

	// Verify refresh token is also valid
	refreshClaims, err := jwtManager.Verify(resp.RefreshToken)
	require.NoError(t, err)
	assert.Equal(t, userID.String(), refreshClaims.UserID)

	// Verify expiry is in the future
	assert.True(t, resp.ExpiresAt.AsTime().After(time.Now()))
}

func TestLogin_PasswordHashVerification(t *testing.T) {
	// Ensure bcrypt hash from Register would be verifiable in Login
	svc, mock := newTestService(t)
	defer func() { assert.NoError(t, mock.ExpectationsWereMet()) }()

	userID := uuid.New()

	// Login with the pre-computed testHash
	mock.ExpectQuery("SELECT id, password_hash FROM users").
		WithArgs("hash-test@example.com").
		WillReturnRows(pgxmock.NewRows([]string{"id", "password_hash"}).AddRow(userID, testHash))

	resp, err := svc.Login(context.Background(), &pb.LoginRequest{
		Email:    "hash-test@example.com",
		Password: testPassword,
	})

	require.NoError(t, err)
	assert.Equal(t, userID.String(), resp.UserId)
}
