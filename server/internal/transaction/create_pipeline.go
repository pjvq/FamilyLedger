package transaction

import (
	"context"
	"fmt"
	"time"

	db "github.com/familyledger/server/pkg/db"
	"github.com/familyledger/server/pkg/permission"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "github.com/familyledger/server/proto/transaction"
)

// createRequest holds validated and parsed inputs for CreateTransaction.
// Constructed by the validation step, consumed (read-only) by execution step.
// Note: categoryID is the *requested* category; the actual category used in
// the transaction may differ (see verifyCategory → resolvedCatID).
type createRequest struct {
	userID       uuid.UUID
	accountID    uuid.UUID
	categoryID   uuid.UUID
	amount       int64
	currency     string
	amountCny    int64
	exchangeRate float64
	txnType      string
	note         string
	txnDate      time.Time
	tags         []string
	imageURLs    []string
}

// validateCreateInput performs all input validation and parsing.
// Returns a validated createRequest or an appropriate gRPC error.
func validateCreateInput(userID string, req *pb.CreateTransactionRequest) (*createRequest, error) {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	accountID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}

	categoryID, err := uuid.Parse(req.CategoryId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid category_id")
	}

	if req.Amount <= 0 {
		return nil, status.Error(codes.InvalidArgument, "amount must be positive")
	}
	if req.Amount > 99999999999 {
		return nil, status.Error(codes.InvalidArgument, "amount exceeds maximum allowed (10 billion CNY)")
	}

	if len(req.Note) > 1000 {
		return nil, status.Error(codes.InvalidArgument, "note exceeds maximum length of 1000 characters")
	}

	currency := req.Currency
	if currency == "" {
		currency = "CNY"
	}

	amountCny := req.AmountCny
	exchangeRate := req.ExchangeRate
	if currency == "CNY" {
		amountCny = req.Amount
		exchangeRate = 1.0
	} else if amountCny <= 0 {
		return nil, status.Error(codes.InvalidArgument, "amount_cny is required for non-CNY currency")
	}

	txnDate := time.Now()
	if req.TxnDate != nil {
		txnDate, err = validateTxnDate(req.TxnDate)
		if err != nil {
			return nil, err
		}
	}

	txnType := "expense"
	if req.Type == pb.TransactionType_TRANSACTION_TYPE_INCOME {
		txnType = "income"
	}

	tags := req.Tags
	if tags == nil {
		tags = []string{}
	}
	imageURLs := req.ImageUrls
	if imageURLs == nil {
		imageURLs = []string{}
	}

	return &createRequest{
		userID:       uid,
		accountID:    accountID,
		categoryID:   categoryID,
		amount:       req.Amount,
		currency:     currency,
		amountCny:    amountCny,
		exchangeRate: exchangeRate,
		txnType:      txnType,
		note:         req.Note,
		txnDate:      txnDate,
		tags:         tags,
		imageURLs:    imageURLs,
	}, nil
}

// checkAccountPermission verifies the caller can create transactions on the account.
// Uses permission.Check for family accounts, direct ownership for personal.
func checkAccountPermission(ctx context.Context, pool db.Pool, userID uuid.UUID, accountID uuid.UUID) error {
	own, err := getAccountOwnershipFrom(ctx, pool, accountID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return status.Error(codes.NotFound, "account not found")
		}
		return status.Error(codes.Internal, "failed to check account ownership")
	}
	if own.familyID == "" {
		if own.ownerID != userID {
			return status.Error(codes.PermissionDenied, "account does not belong to user")
		}
	} else {
		if err := permission.Check(ctx, pool, userID.String(), own.familyID, permission.CanCreate); err != nil {
			return err
		}
	}
	return nil
}

// verifyAccountInTx re-checks account ownership within the transaction.
// For family accounts, verifies membership + create permission (consistent with checkAccountPermission).
// Returns account metadata needed for subsequent steps.
type accountMeta struct {
	ownerID    uuid.UUID
	familyID   *uuid.UUID
	acctType   string
}

func verifyAccountInTx(ctx context.Context, tx pgx.Tx, userID, accountID uuid.UUID) (*accountMeta, error) {
	var meta accountMeta
	err := tx.QueryRow(ctx,
		"SELECT user_id, family_id, type FROM accounts WHERE id = $1 AND deleted_at IS NULL",
		accountID,
	).Scan(&meta.ownerID, &meta.familyID, &meta.acctType)
	if err != nil {
		return nil, status.Error(codes.NotFound, "account not found")
	}
	if meta.ownerID != userID {
		if meta.familyID == nil {
			return nil, status.Error(codes.PermissionDenied, "account does not belong to user")
		}
		// Family account: verify membership + create permission via shared permission.Check
		if err := permission.Check(ctx, tx, userID.String(), meta.familyID.String(), permission.CanCreate); err != nil {
			return nil, err
		}
	}
	return &meta, nil
}

// verifyCategory checks that the category exists, with auto-creation fallback in batch mode.
func verifyCategory(ctx context.Context, tx pgx.Tx, cr *createRequest) (uuid.UUID, error) {
	var catExists bool
	err := tx.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM categories WHERE id = $1 AND deleted_at IS NULL)",
		cr.categoryID,
	).Scan(&catExists)
	if err != nil || !catExists {
		if ctx.Value(skipOverdraftKey) != nil {
			return resolveBatchCategory(ctx, tx, cr)
		}
		return uuid.Nil, status.Errorf(codes.InvalidArgument, "category %s not found", cr.categoryID)
	}
	return cr.categoryID, nil
}

// resolveBatchCategory handles category fallback/creation in batch import mode.
func resolveBatchCategory(ctx context.Context, tx pgx.Tx, cr *createRequest) (uuid.UUID, error) {
	// Try default preset category of same type
	var fallbackID uuid.UUID
	err := tx.QueryRow(ctx,
		`SELECT id FROM categories WHERE type = $1::category_type AND is_preset = true AND deleted_at IS NULL ORDER BY sort_order LIMIT 1`,
		cr.txnType,
	).Scan(&fallbackID)
	if err == nil {
		return fallbackID, nil
	}

	// Create placeholder as last resort
	typeLabel := "支出"
	if cr.txnType == "income" {
		typeLabel = "收入"
	}
	placeholderName := fmt.Sprintf("未分类-%s-%s", typeLabel, cr.categoryID.String()[:8])
	_, autoErr := tx.Exec(ctx,
		`INSERT INTO categories (id, name, icon, icon_key, type, is_preset, sort_order, user_id)
		 VALUES ($1, $2, '', 'category', $3::category_type, false, 0, $4)
		 ON CONFLICT (id) DO NOTHING`,
		cr.categoryID, placeholderName, cr.txnType, cr.userID,
	)
	if autoErr != nil {
		return uuid.Nil, status.Errorf(codes.InvalidArgument, "category %s not found and auto-create failed: %v", cr.categoryID, autoErr)
	}
	return cr.categoryID, nil
}

// checkOverdraft performs the overdraft protection check (lock row + verify balance).
func checkOverdraft(ctx context.Context, tx pgx.Tx, accountID uuid.UUID, amountCny int64, acctType string) error {
	if acctType == "credit_card" || ctx.Value(skipOverdraftKey) != nil {
		return nil
	}
	var currentBalance int64
	err := tx.QueryRow(ctx,
		"SELECT balance FROM accounts WHERE id = $1 FOR UPDATE",
		accountID,
	).Scan(&currentBalance)
	if err != nil {
		return status.Error(codes.Internal, "failed to lock account for balance check")
	}
	if currentBalance < amountCny {
		return status.Error(codes.FailedPrecondition, "insufficient balance: account does not allow overdraft")
	}
	return nil
}
