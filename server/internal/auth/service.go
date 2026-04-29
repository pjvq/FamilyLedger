package auth

import (
	"context"
	"errors"
	"fmt"
	"log"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/familyledger/server/pkg/db"
	"github.com/familyledger/server/pkg/middleware"
	"golang.org/x/crypto/bcrypt"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/auth"
	"github.com/familyledger/server/pkg/jwt"
)

type Service struct {
	pb.UnimplementedAuthServiceServer
	pool           db.Pool
	jwtManager     *jwt.Manager
	oauthProviders OAuthProviders
}

func NewService(pool db.Pool, jwtManager *jwt.Manager, opts ...ServiceOption) *Service {
	s := &Service{
		pool:       pool,
		jwtManager: jwtManager,
	}
	for _, opt := range opts {
		opt(s)
	}
	if s.oauthProviders == nil {
		s.oauthProviders = NewOAuthProviders()
	}
	return s
}

// ServiceOption configures the auth Service.
type ServiceOption func(*Service)

// WithOAuthProviders sets custom OAuth providers (useful for testing).
func WithOAuthProviders(providers OAuthProviders) ServiceOption {
	return func(s *Service) {
		s.oauthProviders = providers
	}
}

func (s *Service) Register(ctx context.Context, req *pb.RegisterRequest) (*pb.RegisterResponse, error) {
	if err := middleware.ValidateEmail(req.Email); err != nil {
		return nil, err
	}
	if err := middleware.ValidatePassword(req.Password); err != nil {
		return nil, err
	}

	// Check if user already exists
	var exists bool
	err := s.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)", req.Email).Scan(&exists)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check user existence")
	}
	if exists {
		return nil, status.Error(codes.AlreadyExists, "email already registered")
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	// Create user + default account in a transaction
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	var userID uuid.UUID
	err = tx.QueryRow(ctx,
		"INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id",
		req.Email, string(hash),
	).Scan(&userID)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, status.Error(codes.AlreadyExists, "email already registered")
		}
		return nil, status.Error(codes.Internal, "failed to create user")
	}

	// Create default account
	_, err = tx.Exec(ctx,
		"INSERT INTO accounts (user_id, name, type, balance, currency, is_default) VALUES ($1, $2, $3, $4, $5, $6)",
		userID, "默认账户", "cash", 0, "CNY", true,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create default account")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit transaction")
	}

	// Generate tokens
	tokenPair, err := s.jwtManager.GenerateTokenPair(userID.String())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to generate tokens")
	}

	log.Printf("auth: user registered: %s (%s)", userID, req.Email)

	return &pb.RegisterResponse{
		UserId:       userID.String(),
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		ExpiresAt:    timestamppb.New(tokenPair.ExpiresAt),
	}, nil
}

func (s *Service) Login(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
	if req.Email == "" || req.Password == "" {
		return nil, status.Error(codes.InvalidArgument, "email and password are required")
	}

	var userID uuid.UUID
	var passwordHash string
	err := s.pool.QueryRow(ctx,
		"SELECT id, password_hash FROM users WHERE email = $1",
		req.Email,
	).Scan(&userID, &passwordHash)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid email or password")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid email or password")
	}

	tokenPair, err := s.jwtManager.GenerateTokenPair(userID.String())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to generate tokens")
	}

	log.Printf("auth: user logged in: %s (%s)", userID, req.Email)

	return &pb.LoginResponse{
		UserId:       userID.String(),
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		ExpiresAt:    timestamppb.New(tokenPair.ExpiresAt),
	}, nil
}

func (s *Service) RefreshToken(ctx context.Context, req *pb.RefreshTokenRequest) (*pb.RefreshTokenResponse, error) {
	if req.RefreshToken == "" {
		return nil, status.Error(codes.InvalidArgument, "refresh token is required")
	}

	claims, err := s.jwtManager.Verify(req.RefreshToken)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, fmt.Sprintf("invalid refresh token: %v", err))
	}

	// Verify user still exists
	var exists bool
	err = s.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)", claims.UserID).Scan(&exists)
	if err != nil || !exists {
		return nil, status.Error(codes.Unauthenticated, "user not found")
	}

	tokenPair, err := s.jwtManager.GenerateTokenPair(claims.UserID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to generate tokens")
	}

	return &pb.RefreshTokenResponse{
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		ExpiresAt:    timestamppb.New(tokenPair.ExpiresAt),
	}, nil
}

// OAuthLogin handles OAuth-based login for WeChat and Apple providers.
// Currently uses a mock implementation: code="test" creates a test user directly.
// In production, replace with real OAuth flows.
func (s *Service) OAuthLogin(ctx context.Context, req *pb.OAuthLoginRequest) (*pb.OAuthLoginResponse, error) {
	if req.Provider == "" {
		return nil, status.Error(codes.InvalidArgument, "provider is required")
	}
	if req.Code == "" {
		return nil, status.Error(codes.InvalidArgument, "code is required")
	}

	provider := req.Provider
	if provider != "wechat" && provider != "apple" {
		return nil, status.Error(codes.InvalidArgument, "unsupported provider; use wechat or apple")
	}

	// Mock implementation: code="test" → create/find test user
	// In production, exchange code for access_token with the provider
	oauthID, displayName, avatarURL, err := s.exchangeOAuthCode(ctx, provider, req.Code, req.RedirectUri)
	if err != nil {
		return nil, status.Errorf(codes.Unauthenticated, "oauth exchange failed: %v", err)
	}

	// Look up existing user by oauth_provider + oauth_id
	var userID uuid.UUID
	isNewUser := false

	err = s.pool.QueryRow(ctx,
		`SELECT id FROM users WHERE oauth_provider = $1 AND oauth_id = $2`,
		provider, oauthID,
	).Scan(&userID)

	if err != nil {
		// User not found — create new user
		tx, txErr := s.pool.Begin(ctx)
		if txErr != nil {
			return nil, status.Error(codes.Internal, "failed to begin transaction")
		}
		defer tx.Rollback(ctx)

		// Create user with OAuth fields; email and password_hash are set to placeholders
		email := fmt.Sprintf("%s_%s@oauth.local", provider, oauthID)
		placeholderHash := "oauth_no_password"

		err = tx.QueryRow(ctx,
			`INSERT INTO users (email, password_hash, oauth_provider, oauth_id, display_name, avatar_url)
			 VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
			email, placeholderHash, provider, oauthID, displayName, avatarURL,
		).Scan(&userID)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "create oauth user: %v", err)
		}

		// Create default account
		_, err = tx.Exec(ctx,
			`INSERT INTO accounts (user_id, name, type, balance, currency, is_default) VALUES ($1, $2, $3, $4, $5, $6)`,
			userID, "默认账户", "cash", 0, "CNY", true,
		)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "create default account: %v", err)
		}

		if err := tx.Commit(ctx); err != nil {
			return nil, status.Error(codes.Internal, "failed to commit transaction")
		}

		isNewUser = true
		log.Printf("auth: new oauth user created: %s (provider=%s)", userID, provider)
	} else {
		// Update display_name and avatar_url if changed
		_, _ = s.pool.Exec(ctx,
			`UPDATE users SET display_name = $1, avatar_url = $2, updated_at = NOW() WHERE id = $3`,
			displayName, avatarURL, userID,
		)
		log.Printf("auth: oauth user logged in: %s (provider=%s)", userID, provider)
	}

	tokenPair, err := s.jwtManager.GenerateTokenPair(userID.String())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to generate tokens")
	}

	return &pb.OAuthLoginResponse{
		UserId:       userID.String(),
		AccessToken:  tokenPair.AccessToken,
		RefreshToken: tokenPair.RefreshToken,
		ExpiresAt:    timestamppb.New(tokenPair.ExpiresAt),
		IsNewUser:    isNewUser,
	}, nil
}

// exchangeOAuthCode exchanges an OAuth code for user info using the configured provider.
func (s *Service) exchangeOAuthCode(ctx context.Context, provider, code, _ string) (oauthID, displayName, avatarURL string, err error) {
	p, ok := s.oauthProviders[provider]
	if !ok {
		return "", "", "", status.Errorf(codes.InvalidArgument, "no oauth provider configured for: %s", provider)
	}

	info, err := p.ExchangeCode(ctx, code)
	if err != nil {
		return "", "", "", err
	}

	return info.OAuthID, info.DisplayName, info.AvatarURL, nil
}
