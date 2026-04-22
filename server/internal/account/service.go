package account

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/account"
)

type Service struct {
	pb.UnimplementedAccountServiceServer
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

func (s *Service) CreateAccount(ctx context.Context, req *pb.CreateAccountRequest) (*pb.CreateAccountResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "account name is required")
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	currency := req.Currency
	if currency == "" {
		currency = "CNY"
	}

	acctType := protoTypeToString(req.Type)

	// Handle family_id
	var familyID *uuid.UUID
	if req.FamilyId != "" {
		fid, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		// Verify user is a member with can_manage_accounts or can_create permission
		if err := s.requireFamilyPermission(ctx, fid, userID, "can_manage_accounts"); err != nil {
			return nil, err
		}
		familyID = &fid
	}

	var acctID uuid.UUID
	var createdAt, updatedAt time.Time

	err = s.pool.QueryRow(ctx,
		`INSERT INTO accounts (user_id, name, type, balance, currency, icon, family_id, is_active, is_default)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, true, false)
		 RETURNING id, created_at, updated_at`,
		uid, req.Name, acctType, req.InitialBalance, currency, req.Icon, familyID,
	).Scan(&acctID, &createdAt, &updatedAt)
	if err != nil {
		log.Printf("account: create error: %v", err)
		return nil, status.Error(codes.Internal, "failed to create account")
	}

	log.Printf("account: created %s for user %s", acctID, userID)

	acct := &pb.Account{
		Id:        acctID.String(),
		UserId:    userID,
		Name:      req.Name,
		Type:      req.Type,
		Currency:  currency,
		Icon:      req.Icon,
		Balance:   req.InitialBalance,
		IsActive:  true,
		IsDefault: false,
		CreatedAt: timestamppb.New(createdAt),
		UpdatedAt: timestamppb.New(updatedAt),
	}
	if familyID != nil {
		acct.FamilyId = familyID.String()
	}

	return &pb.CreateAccountResponse{Account: acct}, nil
}

func (s *Service) ListAccounts(ctx context.Context, req *pb.ListAccountsRequest) (*pb.ListAccountsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	var rows pgx.Rows
	if req.FamilyId != "" {
		familyID, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		// Verify membership
		var isMember bool
		err = s.pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
			familyID, uid,
		).Scan(&isMember)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to check membership")
		}
		if !isMember {
			return nil, status.Error(codes.PermissionDenied, "not a member of this family")
		}

		if req.IncludeInactive {
			rows, err = s.pool.Query(ctx,
				`SELECT id, user_id, COALESCE(family_id::text, ''), name, type, currency, COALESCE(icon, ''), balance, is_active, is_default, created_at, updated_at
				 FROM accounts WHERE family_id = $1 AND deleted_at IS NULL
				 ORDER BY created_at ASC`,
				familyID,
			)
		} else {
			rows, err = s.pool.Query(ctx,
				`SELECT id, user_id, COALESCE(family_id::text, ''), name, type, currency, COALESCE(icon, ''), balance, is_active, is_default, created_at, updated_at
				 FROM accounts WHERE family_id = $1 AND is_active = true AND deleted_at IS NULL
				 ORDER BY created_at ASC`,
				familyID,
			)
		}
	} else {
		// Personal accounts (no family_id)
		if req.IncludeInactive {
			rows, err = s.pool.Query(ctx,
				`SELECT id, user_id, COALESCE(family_id::text, ''), name, type, currency, COALESCE(icon, ''), balance, is_active, is_default, created_at, updated_at
				 FROM accounts WHERE user_id = $1 AND family_id IS NULL AND deleted_at IS NULL
				 ORDER BY created_at ASC`,
				uid,
			)
		} else {
			rows, err = s.pool.Query(ctx,
				`SELECT id, user_id, COALESCE(family_id::text, ''), name, type, currency, COALESCE(icon, ''), balance, is_active, is_default, created_at, updated_at
				 FROM accounts WHERE user_id = $1 AND family_id IS NULL AND is_active = true AND deleted_at IS NULL
				 ORDER BY created_at ASC`,
				uid,
			)
		}
	}
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query accounts")
	}
	defer rows.Close()

	var accounts []*pb.Account
	for rows.Next() {
		acct, err := scanAccount(rows)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to scan account")
		}
		accounts = append(accounts, acct)
	}

	if accounts == nil {
		accounts = []*pb.Account{}
	}

	return &pb.ListAccountsResponse{Accounts: accounts}, nil
}

func (s *Service) GetAccount(ctx context.Context, req *pb.GetAccountRequest) (*pb.GetAccountResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.AccountId == "" {
		return nil, status.Error(codes.InvalidArgument, "account_id is required")
	}

	acctID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}

	row := s.pool.QueryRow(ctx,
		`SELECT id, user_id, COALESCE(family_id::text, ''), name, type, currency, COALESCE(icon, ''), balance, is_active, is_default, created_at, updated_at
		 FROM accounts WHERE id = $1 AND deleted_at IS NULL`,
		acctID,
	)

	var id, ownerUID uuid.UUID
	var familyIDStr, name, acctType, currency, icon string
	var balance int64
	var isActive, isDefault bool
	var createdAt, updatedAt time.Time

	err = row.Scan(&id, &ownerUID, &familyIDStr, &name, &acctType, &currency, &icon, &balance, &isActive, &isDefault, &createdAt, &updatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "account not found")
		}
		return nil, status.Error(codes.Internal, "failed to get account")
	}

	// Check access: owner or family member
	if err := s.checkAccountAccess(ctx, ownerUID.String(), familyIDStr, userID); err != nil {
		return nil, err
	}

	acct := &pb.Account{
		Id:        id.String(),
		UserId:    ownerUID.String(),
		FamilyId:  familyIDStr,
		Name:      name,
		Type:      stringToProtoType(acctType),
		Currency:  currency,
		Icon:      icon,
		Balance:   balance,
		IsActive:  isActive,
		IsDefault: isDefault,
		CreatedAt: timestamppb.New(createdAt),
		UpdatedAt: timestamppb.New(updatedAt),
	}

	return &pb.GetAccountResponse{Account: acct}, nil
}

func (s *Service) UpdateAccount(ctx context.Context, req *pb.UpdateAccountRequest) (*pb.UpdateAccountResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.AccountId == "" {
		return nil, status.Error(codes.InvalidArgument, "account_id is required")
	}

	acctID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}

	// Get current account to check ownership
	var ownerID string
	var familyIDStr string
	err = s.pool.QueryRow(ctx,
		`SELECT user_id::text, COALESCE(family_id::text, '') FROM accounts WHERE id = $1 AND deleted_at IS NULL`,
		acctID,
	).Scan(&ownerID, &familyIDStr)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "account not found")
		}
		return nil, status.Error(codes.Internal, "failed to get account")
	}

	if err := s.checkAccountAccess(ctx, ownerID, familyIDStr, userID); err != nil {
		return nil, err
	}

	// Build partial update
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	if req.Name != nil {
		_, err = tx.Exec(ctx, `UPDATE accounts SET name = $1, updated_at = NOW() WHERE id = $2`, *req.Name, acctID)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to update name")
		}
	}
	if req.Icon != nil {
		_, err = tx.Exec(ctx, `UPDATE accounts SET icon = $1, updated_at = NOW() WHERE id = $2`, *req.Icon, acctID)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to update icon")
		}
	}
	if req.IsActive != nil {
		_, err = tx.Exec(ctx, `UPDATE accounts SET is_active = $1, updated_at = NOW() WHERE id = $2`, *req.IsActive, acctID)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to update is_active")
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit transaction")
	}

	// Re-fetch updated account
	resp, err := s.GetAccount(ctx, &pb.GetAccountRequest{AccountId: req.AccountId})
	if err != nil {
		return nil, err
	}

	return &pb.UpdateAccountResponse{Account: resp.Account}, nil
}

func (s *Service) DeleteAccount(ctx context.Context, req *pb.DeleteAccountRequest) (*pb.DeleteAccountResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.AccountId == "" {
		return nil, status.Error(codes.InvalidArgument, "account_id is required")
	}

	acctID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}

	// Check ownership
	var ownerID string
	var familyIDStr string
	err = s.pool.QueryRow(ctx,
		`SELECT user_id::text, COALESCE(family_id::text, '') FROM accounts WHERE id = $1 AND deleted_at IS NULL`,
		acctID,
	).Scan(&ownerID, &familyIDStr)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "account not found")
		}
		return nil, status.Error(codes.Internal, "failed to get account")
	}

	if err := s.checkAccountAccess(ctx, ownerID, familyIDStr, userID); err != nil {
		return nil, err
	}

	// Soft delete
	_, err = s.pool.Exec(ctx,
		`UPDATE accounts SET is_active = false, updated_at = NOW() WHERE id = $1`,
		acctID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete account")
	}

	log.Printf("account: soft-deleted %s by user %s", acctID, userID)

	return &pb.DeleteAccountResponse{}, nil
}

func (s *Service) TransferBetween(ctx context.Context, req *pb.TransferBetweenRequest) (*pb.TransferBetweenResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FromAccountId == "" || req.ToAccountId == "" {
		return nil, status.Error(codes.InvalidArgument, "from_account_id and to_account_id are required")
	}
	if req.Amount <= 0 {
		return nil, status.Error(codes.InvalidArgument, "amount must be positive")
	}
	if req.FromAccountId == req.ToAccountId {
		return nil, status.Error(codes.InvalidArgument, "cannot transfer to the same account")
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	fromID, err := uuid.Parse(req.FromAccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid from_account_id")
	}

	toID, err := uuid.Parse(req.ToAccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid to_account_id")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Verify both accounts exist and are accessible
	// Lock rows to prevent race conditions (SELECT FOR UPDATE)
	var fromOwner, toOwner string
	var fromFamilyIDStr, toFamilyIDStr string

	err = tx.QueryRow(ctx,
		`SELECT user_id::text, COALESCE(family_id::text, '')
		 FROM accounts WHERE id = $1 AND is_active = true AND deleted_at IS NULL FOR UPDATE`,
		fromID,
	).Scan(&fromOwner, &fromFamilyIDStr)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "source account not found")
		}
		return nil, status.Error(codes.Internal, "failed to get source account")
	}

	err = tx.QueryRow(ctx,
		`SELECT user_id::text, COALESCE(family_id::text, '')
		 FROM accounts WHERE id = $1 AND is_active = true AND deleted_at IS NULL FOR UPDATE`,
		toID,
	).Scan(&toOwner, &toFamilyIDStr)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "destination account not found")
		}
		return nil, status.Error(codes.Internal, "failed to get destination account")
	}

	// Check access to both accounts
	if err := s.checkAccountAccessTx(ctx, tx, fromOwner, fromFamilyIDStr, userID); err != nil {
		return nil, status.Errorf(codes.PermissionDenied, "no access to source account")
	}
	if err := s.checkAccountAccessTx(ctx, tx, toOwner, toFamilyIDStr, userID); err != nil {
		return nil, status.Errorf(codes.PermissionDenied, "no access to destination account")
	}

	// Deduct from source
	_, err = tx.Exec(ctx,
		`UPDATE accounts SET balance = balance - $1, updated_at = NOW() WHERE id = $2`,
		req.Amount, fromID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update source balance")
	}

	// Add to destination
	_, err = tx.Exec(ctx,
		`UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2`,
		req.Amount, toID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update destination balance")
	}

	// Create transfer record
	var transferID uuid.UUID
	var createdAt time.Time
	err = tx.QueryRow(ctx,
		`INSERT INTO transfers (user_id, from_account_id, to_account_id, amount, note)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, created_at`,
		uid, fromID, toID, req.Amount, req.Note,
	).Scan(&transferID, &createdAt)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create transfer record")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit transfer")
	}

	log.Printf("account: transfer %d cents from %s to %s by user %s", req.Amount, fromID, toID, userID)

	return &pb.TransferBetweenResponse{
		Transfer: &pb.Transfer{
			Id:            transferID.String(),
			UserId:        userID,
			FromAccountId: fromID.String(),
			ToAccountId:   toID.String(),
			Amount:        req.Amount,
			Note:          req.Note,
			CreatedAt:     timestamppb.New(createdAt),
		},
	}, nil
}

// ── Helpers ──────────────────────────────────────────────────────────────────

func (s *Service) checkAccountAccess(ctx context.Context, ownerID, familyIDStr, callerID string) error {
	// Direct owner
	if ownerID == callerID {
		return nil
	}
	// Family member
	if familyIDStr != "" {
		uid, err := uuid.Parse(callerID)
		if err != nil {
			return status.Error(codes.Internal, "invalid user id")
		}
		fid, err := uuid.Parse(familyIDStr)
		if err != nil {
			return status.Error(codes.Internal, "invalid family id")
		}
		var exists bool
		err = s.pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
			fid, uid,
		).Scan(&exists)
		if err == nil && exists {
			return nil
		}
	}
	return status.Error(codes.PermissionDenied, "no access to this account")
}

func (s *Service) checkAccountAccessTx(ctx context.Context, tx pgx.Tx, ownerID, familyIDStr, callerID string) error {
	if ownerID == callerID {
		return nil
	}
	if familyIDStr != "" {
		uid, err := uuid.Parse(callerID)
		if err != nil {
			return status.Error(codes.Internal, "invalid user id")
		}
		fid, err := uuid.Parse(familyIDStr)
		if err != nil {
			return status.Error(codes.Internal, "invalid family id")
		}
		var exists bool
		err = tx.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
			fid, uid,
		).Scan(&exists)
		if err == nil && exists {
			return nil
		}
	}
	return status.Error(codes.PermissionDenied, "no access to this account")
}

func (s *Service) requireFamilyPermission(ctx context.Context, familyID uuid.UUID, userID, permKey string) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return status.Error(codes.Internal, "invalid user id")
	}

	var role string
	var permsJSON []byte
	err = s.pool.QueryRow(ctx,
		`SELECT role, permissions FROM family_members WHERE family_id = $1 AND user_id = $2`,
		familyID, uid,
	).Scan(&role, &permsJSON)
	if err != nil {
		if err == pgx.ErrNoRows {
			return status.Error(codes.PermissionDenied, "not a member of this family")
		}
		return status.Error(codes.Internal, "failed to check permissions")
	}

	// Owner/admin always has permission
	if role == "owner" || role == "admin" {
		return nil
	}

	// Check specific permission
	var permsMap map[string]bool
	if err := json.Unmarshal(permsJSON, &permsMap); err != nil {
		return status.Error(codes.Internal, "failed to parse permissions")
	}

	if allowed, ok := permsMap[permKey]; ok && allowed {
		return nil
	}

	return status.Error(codes.PermissionDenied, "insufficient permissions")
}

func scanAccount(rows pgx.Rows) (*pb.Account, error) {
	var id, ownerUID uuid.UUID
	var familyIDStr, name, acctType, currency, icon string
	var balance int64
	var isActive, isDefault bool
	var createdAt, updatedAt time.Time

	err := rows.Scan(&id, &ownerUID, &familyIDStr, &name, &acctType, &currency, &icon, &balance, &isActive, &isDefault, &createdAt, &updatedAt)
	if err != nil {
		return nil, err
	}

	return &pb.Account{
		Id:        id.String(),
		UserId:    ownerUID.String(),
		FamilyId:  familyIDStr,
		Name:      name,
		Type:      stringToProtoType(acctType),
		Currency:  currency,
		Icon:      icon,
		Balance:   balance,
		IsActive:  isActive,
		IsDefault: isDefault,
		CreatedAt: timestamppb.New(createdAt),
		UpdatedAt: timestamppb.New(updatedAt),
	}, nil
}

func protoTypeToString(t pb.AccountType) string {
	switch t {
	case pb.AccountType_ACCOUNT_TYPE_CASH:
		return "cash"
	case pb.AccountType_ACCOUNT_TYPE_BANK_CARD:
		return "bank_card"
	case pb.AccountType_ACCOUNT_TYPE_CREDIT_CARD:
		return "credit_card"
	case pb.AccountType_ACCOUNT_TYPE_ALIPAY:
		return "alipay"
	case pb.AccountType_ACCOUNT_TYPE_WECHAT_PAY:
		return "wechat_pay"
	case pb.AccountType_ACCOUNT_TYPE_INVESTMENT:
		return "investment"
	case pb.AccountType_ACCOUNT_TYPE_OTHER:
		return "other"
	default:
		return "cash"
	}
}

func stringToProtoType(s string) pb.AccountType {
	switch s {
	case "cash":
		return pb.AccountType_ACCOUNT_TYPE_CASH
	case "bank_card":
		return pb.AccountType_ACCOUNT_TYPE_BANK_CARD
	case "credit_card":
		return pb.AccountType_ACCOUNT_TYPE_CREDIT_CARD
	case "alipay":
		return pb.AccountType_ACCOUNT_TYPE_ALIPAY
	case "wechat_pay":
		return pb.AccountType_ACCOUNT_TYPE_WECHAT_PAY
	case "investment":
		return pb.AccountType_ACCOUNT_TYPE_INVESTMENT
	case "other":
		return pb.AccountType_ACCOUNT_TYPE_OTHER
	default:
		return pb.AccountType_ACCOUNT_TYPE_UNSPECIFIED
	}
}
