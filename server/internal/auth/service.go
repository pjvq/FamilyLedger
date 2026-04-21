package auth

import (
	"context"
	"fmt"
	"log"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/auth"
	"github.com/familyledger/server/pkg/jwt"
)

type Service struct {
	pb.UnimplementedAuthServiceServer
	pool       *pgxpool.Pool
	jwtManager *jwt.Manager
}

func NewService(pool *pgxpool.Pool, jwtManager *jwt.Manager) *Service {
	return &Service{
		pool:       pool,
		jwtManager: jwtManager,
	}
}

func (s *Service) Register(ctx context.Context, req *pb.RegisterRequest) (*pb.RegisterResponse, error) {
	if req.Email == "" || req.Password == "" {
		return nil, status.Error(codes.InvalidArgument, "email and password are required")
	}

	if len(req.Password) < 6 {
		return nil, status.Error(codes.InvalidArgument, "password must be at least 6 characters")
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
