package transaction

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/familyledger/server/pkg/db"
	"github.com/familyledger/server/pkg/permission"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/transaction"
)

type Service struct {
	pb.UnimplementedTransactionServiceServer
	pool      db.Pool
	uploadDir string // 图片上传目录
	baseURL   string // 图片访问基础 URL
}

func NewService(pool db.Pool, opts ...ServiceOption) *Service {
	s := &Service{
		pool:      pool,
		uploadDir: "./uploads/images",
		baseURL:   "/uploads/images",
	}
	for _, opt := range opts {
		opt(s)
	}
	return s
}

type ServiceOption func(*Service)

func WithUploadDir(dir string) ServiceOption {
	return func(s *Service) { s.uploadDir = dir }
}

func WithBaseURL(url string) ServiceOption {
	return func(s *Service) { s.baseURL = url }
}

// getAccountFamilyID returns the family_id for an account (empty string if personal).
func (s *Service) getAccountFamilyID(ctx context.Context, accountID uuid.UUID) (string, error) {
	var familyID *string
	err := s.pool.QueryRow(ctx,
		"SELECT family_id::text FROM accounts WHERE id = $1 AND deleted_at IS NULL",
		accountID,
	).Scan(&familyID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return "", nil
		}
		return "", err
	}
	if familyID == nil {
		return "", nil
	}
	return *familyID, nil
}

func (s *Service) CreateTransaction(ctx context.Context, req *pb.CreateTransactionRequest) (*pb.CreateTransactionResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

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

	// Permission check: verify user can create transactions in this account's family
	familyID, err := s.getAccountFamilyID(ctx, accountID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check account family")
	}
	if err := permission.Check(ctx, s.pool, userID, familyID, permission.CanCreate); err != nil {
		return nil, err
	}

	if req.Amount <= 0 {
		return nil, status.Error(codes.InvalidArgument, "amount must be positive")
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
		// Foreign currency must provide amountCny
		return nil, status.Error(codes.InvalidArgument, "amount_cny is required for non-CNY currency")
	}

	txnDate := time.Now()
	if req.TxnDate != nil {
		txnDate = req.TxnDate.AsTime()
	}

	txnType := "expense"
	if req.Type == pb.TransactionType_TRANSACTION_TYPE_INCOME {
		txnType = "income"
	}

	// Begin transaction
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Verify account belongs to user
	var ownerID uuid.UUID
	err = tx.QueryRow(ctx,
		"SELECT user_id FROM accounts WHERE id = $1 AND deleted_at IS NULL",
		accountID,
	).Scan(&ownerID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "account not found")
	}
	if ownerID != uid {
		return nil, status.Error(codes.PermissionDenied, "account does not belong to user")
	}

	// Create transaction
	var txnID uuid.UUID
	var createdAt, updatedAt time.Time
	tags := req.Tags
	if tags == nil {
		tags = []string{}
	}
	imageURLs := req.ImageUrls
	if imageURLs == nil {
		imageURLs = []string{}
	}
	err = tx.QueryRow(ctx,
		`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, tags, image_urls)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8::transaction_type, $9, $10, $11, $12)
		 RETURNING id, created_at, updated_at`,
		uid, accountID, categoryID, req.Amount, currency, amountCny, exchangeRate, txnType, req.Note, txnDate, tags, imageURLs,
	).Scan(&txnID, &createdAt, &updatedAt)
	if err != nil {
		log.Printf("transaction: create error: %v", err)
		return nil, status.Error(codes.Internal, "failed to create transaction")
	}

	// Update account balance (use amountCny — balance is always in CNY)
	balanceDelta := amountCny
	if txnType == "expense" {
		balanceDelta = -amountCny
	}
	_, err = tx.Exec(ctx,
		"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
		balanceDelta, accountID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update account balance")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit transaction")
	}

	pbType := pb.TransactionType_TRANSACTION_TYPE_EXPENSE
	if txnType == "income" {
		pbType = pb.TransactionType_TRANSACTION_TYPE_INCOME
	}

	return &pb.CreateTransactionResponse{
		Transaction: &pb.Transaction{
			Id:           txnID.String(),
			UserId:       userID,
			AccountId:    accountID.String(),
			CategoryId:   categoryID.String(),
			Amount:       req.Amount,
			Currency:     currency,
			AmountCny:    amountCny,
			ExchangeRate: exchangeRate,
			Type:         pbType,
			Note:         req.Note,
			TxnDate:      timestamppb.New(txnDate),
			CreatedAt:    timestamppb.New(createdAt),
			UpdatedAt:    timestamppb.New(updatedAt),
			Tags:         tags,
			ImageUrls:    imageURLs,
		},
	}, nil
}

func (s *Service) UpdateTransaction(ctx context.Context, req *pb.UpdateTransactionRequest) (*pb.UpdateTransactionResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	txnID, err := uuid.Parse(req.TransactionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid transaction_id")
	}

	// Begin DB transaction
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Fetch existing transaction and verify ownership
	var ownerID, accountID, categoryID uuid.UUID
	var oldAmount int64
	var oldType, currency, note string
	var oldTags []string
	var exchangeRate float64
	var amountCny int64
	err = tx.QueryRow(ctx,
		`SELECT user_id, account_id, category_id, amount, type, currency, note, tags, exchange_rate, amount_cny
		 FROM transactions WHERE id = $1 AND deleted_at IS NULL FOR UPDATE`,
		txnID,
	).Scan(&ownerID, &accountID, &categoryID, &oldAmount, &oldType, &currency, &note, &oldTags, &exchangeRate, &amountCny)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "transaction not found")
		}
		return nil, status.Error(codes.Internal, "failed to query transaction")
	}

	if ownerID != uid {
		return nil, status.Error(codes.PermissionDenied, "transaction does not belong to user")
	}

	// Permission check: verify user can edit transactions in this account's family
	familyID, err := s.getAccountFamilyID(ctx, accountID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check account family")
	}
	if err := permission.Check(ctx, s.pool, userID, familyID, permission.CanEdit); err != nil {
		return nil, err
	}

	// Build dynamic UPDATE
	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{}
	argIdx := 1

	newAmount := oldAmount
	newType := oldType

	if req.Amount != nil {
		if *req.Amount <= 0 {
			return nil, status.Error(codes.InvalidArgument, "amount must be positive")
		}
		newAmount = *req.Amount
		args = append(args, newAmount)
		setClauses = append(setClauses, fmt.Sprintf("amount = $%d", argIdx))
		argIdx++
		// Also update amount_cny: if currency is CNY, amount_cny = amount
		// For foreign currency, recalculate using existing exchange_rate
		var newAmountCny int64
		if currency == "CNY" || currency == "" {
			newAmountCny = newAmount
		} else {
			newAmountCny = int64(float64(newAmount) * exchangeRate)
		}
		args = append(args, newAmountCny)
		setClauses = append(setClauses, fmt.Sprintf("amount_cny = $%d", argIdx))
		argIdx++
	}

	if req.CategoryId != nil {
		newCatID, err := uuid.Parse(*req.CategoryId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid category_id")
		}
		// Verify category exists
		var exists bool
		err = tx.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM categories WHERE id = $1)", newCatID).Scan(&exists)
		if err != nil || !exists {
			return nil, status.Error(codes.InvalidArgument, "category not found")
		}
		args = append(args, newCatID)
		setClauses = append(setClauses, fmt.Sprintf("category_id = $%d", argIdx))
		argIdx++
	}

	if req.Note != nil {
		args = append(args, *req.Note)
		setClauses = append(setClauses, fmt.Sprintf("note = $%d", argIdx))
		argIdx++
	}

	if req.Tags != nil {
		// Tags can be JSON array string (from Flutter) or comma-separated
		var tagsArr []string
		rawTags := strings.TrimSpace(*req.Tags)
		if rawTags == "" || rawTags == "[]" {
			tagsArr = []string{}
		} else if strings.HasPrefix(rawTags, "[") {
			// Try JSON array
			if err := json.Unmarshal([]byte(rawTags), &tagsArr); err != nil {
				// Fallback: strip brackets and split
				inner := strings.Trim(rawTags, "[]")
				for _, t := range strings.Split(inner, ",") {
					if trimmed := strings.Trim(strings.TrimSpace(t), `"'`); trimmed != "" {
						tagsArr = append(tagsArr, trimmed)
					}
				}
			}
		} else {
			// Comma-separated
			for _, t := range strings.Split(rawTags, ",") {
				if trimmed := strings.TrimSpace(t); trimmed != "" {
					tagsArr = append(tagsArr, trimmed)
				}
			}
		}
		if tagsArr == nil {
			tagsArr = []string{}
		}
		args = append(args, tagsArr)
		setClauses = append(setClauses, fmt.Sprintf("tags = $%d", argIdx))
		argIdx++
	}

	if req.Type != nil {
		switch *req.Type {
		case pb.TransactionType_TRANSACTION_TYPE_INCOME:
			newType = "income"
		case pb.TransactionType_TRANSACTION_TYPE_EXPENSE:
			newType = "expense"
		default:
			return nil, status.Error(codes.InvalidArgument, "invalid transaction type")
		}
		args = append(args, newType)
		setClauses = append(setClauses, fmt.Sprintf("type = $%d::transaction_type", argIdx))
		argIdx++
	}

	if req.Currency != nil {
		args = append(args, *req.Currency)
		setClauses = append(setClauses, fmt.Sprintf("currency = $%d", argIdx))
		argIdx++
	}

	// Execute UPDATE
	args = append(args, txnID)
	query := fmt.Sprintf("UPDATE transactions SET %s WHERE id = $%d AND deleted_at IS NULL",
		strings.Join(setClauses, ", "), argIdx)
	_, err = tx.Exec(ctx, query, args...)
	if err != nil {
		log.Printf("transaction: update error: %v", err)
		return nil, status.Error(codes.Internal, "failed to update transaction")
	}

	// Recalculate account balance: revert old amountCny, apply new amountCny
	// Balance is always in CNY, so we must use amountCny (not raw amount)
	var oldAmountCny int64 = amountCny
	var newAmountCny int64
	if newAmount == oldAmount && newType == oldType {
		// Nothing changed that affects balance — skip recalc entirely
		newAmountCny = oldAmountCny
	} else if currency == "CNY" || currency == "" {
		newAmountCny = newAmount
	} else {
		newAmountCny = int64(float64(newAmount) * exchangeRate)
	}
	var oldDelta, newDelta int64
	if oldType == "income" {
		oldDelta = oldAmountCny
	} else {
		oldDelta = -oldAmountCny
	}
	if newType == "income" {
		newDelta = newAmountCny
	} else {
		newDelta = -newAmountCny
	}
	balanceAdjust := newDelta - oldDelta
	if balanceAdjust != 0 {
		_, err = tx.Exec(ctx,
			"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
			balanceAdjust, accountID,
		)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to update account balance")
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit transaction")
	}

	// Fetch the updated transaction to return
	rows, err := s.pool.Query(ctx,
		`SELECT id, user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, created_at, updated_at, tags, image_urls
		 FROM transactions WHERE id = $1`,
		txnID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch updated transaction")
	}
	defer rows.Close()

	if !rows.Next() {
		return nil, status.Error(codes.Internal, "updated transaction not found")
	}
	txn, err := scanTransaction(rows)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to scan updated transaction")
	}

	return &pb.UpdateTransactionResponse{Transaction: txn}, nil
}

func (s *Service) DeleteTransaction(ctx context.Context, req *pb.DeleteTransactionRequest) (*pb.DeleteTransactionResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	txnID, err := uuid.Parse(req.TransactionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid transaction_id")
	}

	// Begin DB transaction
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Fetch existing transaction and verify ownership
	var ownerID, accountID uuid.UUID
	var amountCny int64
	var txnType string
	err = tx.QueryRow(ctx,
		`SELECT user_id, account_id, amount_cny, type
		 FROM transactions WHERE id = $1 AND deleted_at IS NULL FOR UPDATE`,
		txnID,
	).Scan(&ownerID, &accountID, &amountCny, &txnType)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "transaction not found")
		}
		return nil, status.Error(codes.Internal, "failed to query transaction")
	}

	if ownerID != uid {
		return nil, status.Error(codes.PermissionDenied, "transaction does not belong to user")
	}

	// Permission check: verify user can delete transactions in this account's family
	familyID, err := s.getAccountFamilyID(ctx, accountID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check account family")
	}
	if err := permission.Check(ctx, s.pool, userID, familyID, permission.CanDelete); err != nil {
		return nil, err
	}

	// Soft delete
	_, err = tx.Exec(ctx,
		"UPDATE transactions SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1",
		txnID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete transaction")
	}

	// Revert account balance (use amount_cny since balance is CNY)
	var balanceRevert int64
	if txnType == "income" {
		balanceRevert = -amountCny // undo income: subtract
	} else {
		balanceRevert = amountCny // undo expense: add back
	}
	_, err = tx.Exec(ctx,
		"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
		balanceRevert, accountID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update account balance")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit transaction")
	}

	return &pb.DeleteTransactionResponse{}, nil
}

// ── BatchDeleteTransactions ─────────────────────────────────────────────────

func (s *Service) BatchDeleteTransactions(ctx context.Context, req *pb.BatchDeleteTransactionsRequest) (*pb.BatchDeleteTransactionsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if len(req.TransactionIds) == 0 {
		return nil, status.Error(codes.InvalidArgument, "transaction_ids is required")
	}
	if len(req.TransactionIds) > 100 {
		return nil, status.Error(codes.InvalidArgument, "max 100 transactions per batch")
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	// Parse all IDs upfront
	txnIDs := make([]uuid.UUID, 0, len(req.TransactionIds))
	for _, idStr := range req.TransactionIds {
		id, err := uuid.Parse(idStr)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid transaction_id: %s", idStr)
		}
		txnIDs = append(txnIDs, id)
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Fetch all transactions in one query, lock for update
	rows, err := tx.Query(ctx,
		`SELECT id, user_id, account_id, amount_cny, type
		 FROM transactions
		 WHERE id = ANY($1) AND deleted_at IS NULL
		 FOR UPDATE`,
		txnIDs,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query transactions")
	}
	defer rows.Close()

	type txnInfo struct {
		id        uuid.UUID
		accountID uuid.UUID
		amountCny int64
		txnType   string
	}
	var toDelete []txnInfo

	for rows.Next() {
		var info txnInfo
		var ownerID uuid.UUID
		if err := rows.Scan(&info.id, &ownerID, &info.accountID, &info.amountCny, &info.txnType); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan transaction")
		}
		if ownerID != uid {
			// Check family permission
			familyID, err := s.getAccountFamilyID(ctx, info.accountID)
			if err != nil {
				return nil, status.Error(codes.Internal, "failed to check account family")
			}
			if err := permission.Check(ctx, s.pool, userID, familyID, permission.CanDelete); err != nil {
				return nil, status.Errorf(codes.PermissionDenied, "no delete permission for transaction %s", info.id)
			}
		}
		toDelete = append(toDelete, info)
	}
	if rows.Err() != nil {
		return nil, status.Error(codes.Internal, "failed to iterate transactions")
	}

	if len(toDelete) == 0 {
		return &pb.BatchDeleteTransactionsResponse{DeletedCount: 0}, nil
	}

	// Soft delete all
	deleteIDs := make([]uuid.UUID, len(toDelete))
	for i, info := range toDelete {
		deleteIDs[i] = info.id
	}
	_, err = tx.Exec(ctx,
		"UPDATE transactions SET deleted_at = NOW(), updated_at = NOW() WHERE id = ANY($1)",
		deleteIDs,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to batch delete transactions")
	}

	// Revert balances per account
	balanceReverts := make(map[uuid.UUID]int64)
	for _, info := range toDelete {
		if info.txnType == "income" {
			balanceReverts[info.accountID] -= info.amountCny
		} else {
			balanceReverts[info.accountID] += info.amountCny
		}
	}
	for accountID, revert := range balanceReverts {
		_, err = tx.Exec(ctx,
			"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
			revert, accountID,
		)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to revert balance for account %s", accountID)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("transaction: batch-deleted %d transactions by user %s", len(toDelete), userID)
	return &pb.BatchDeleteTransactionsResponse{DeletedCount: int32(len(toDelete))}, nil
}

// ── UploadTransactionImage ─────────────────────────────────────────────

const maxImageSize = 5 * 1024 * 1024 // 5MB
const maxImagesPerUser = 500         // 每用户最多图片数

// imageSignatures 验证文件头 magic bytes
var imageSignatures = map[string][][]byte{
	"image/jpeg": {{0xFF, 0xD8, 0xFF}},
	"image/png":  {{0x89, 0x50, 0x4E, 0x47}},
	"image/webp": {{0x52, 0x49, 0x46, 0x46}}, // RIFF
	"image/heic": {{0x00, 0x00, 0x00}},       // ftyp box (offset 4 = 'ftyp')
}

func validateImageMagic(data []byte, contentType string) bool {
	sigs, ok := imageSignatures[contentType]
	if !ok {
		return false
	}
	for _, sig := range sigs {
		if len(data) >= len(sig) {
			match := true
			for i, b := range sig {
				if data[i] != b {
					match = false
					break
				}
			}
			if match {
				return true
			}
		}
	}
	return false
}

func (s *Service) UploadTransactionImage(ctx context.Context, req *pb.UploadTransactionImageRequest) (*pb.UploadTransactionImageResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if len(req.Data) == 0 {
		return nil, status.Error(codes.InvalidArgument, "image data is required")
	}
	if len(req.Data) > maxImageSize {
		return nil, status.Error(codes.InvalidArgument, "image exceeds 5MB limit")
	}

	// Validate content type (whitelist)
	contentType := req.ContentType
	if contentType == "" {
		contentType = "image/jpeg"
	}
	allowed := map[string]string{
		"image/jpeg": ".jpg",
		"image/png":  ".png",
		"image/webp": ".webp",
		"image/heic": ".heic",
	}
	ext, ok := allowed[contentType]
	if !ok {
		return nil, status.Errorf(codes.InvalidArgument, "unsupported content type: %s", contentType)
	}

	// Validate file magic bytes — prevent disguised executables
	if !validateImageMagic(req.Data, contentType) {
		return nil, status.Error(codes.InvalidArgument, "file content does not match declared content type")
	}

	// Per-user quota check
	userDir := filepath.Join(s.uploadDir, userID)
	if entries, err := os.ReadDir(userDir); err == nil {
		if len(entries) >= maxImagesPerUser {
			return nil, status.Error(codes.ResourceExhausted, "image upload quota exceeded (max 500)")
		}
	}

	// Create upload directory (clean path to prevent traversal)
	userDir = filepath.Clean(userDir)
	if err := os.MkdirAll(userDir, 0o755); err != nil {
		return nil, status.Errorf(codes.Internal, "create upload dir: %v", err)
	}

	// Generate unique filename (server-controlled, ignores client filename)
	fileName := fmt.Sprintf("%d_%s%s", time.Now().UnixMilli(), uuid.New().String()[:8], ext)
	filePath := filepath.Join(userDir, fileName)

	if err := os.WriteFile(filePath, req.Data, 0o644); err != nil {
		return nil, status.Errorf(codes.Internal, "write image: %v", err)
	}

	// Build URL
	imageURL := fmt.Sprintf("%s/%s/%s", s.baseURL, userID, fileName)

	// If transaction_id is provided, verify ownership then append
	if req.TransactionId != "" {
		var ownerID string
		err := s.pool.QueryRow(ctx,
			"SELECT user_id FROM transactions WHERE id = $1 AND deleted_at IS NULL",
			req.TransactionId,
		).Scan(&ownerID)
		if err != nil {
			log.Printf("upload: transaction %s not found, skipping association", req.TransactionId)
		} else if ownerID != userID {
			// 不是自己的交易，不允许关联
			log.Printf("upload: user %s tried to attach image to transaction owned by %s", userID, ownerID)
		} else {
			_, err := s.pool.Exec(ctx,
				`UPDATE transactions
				 SET image_urls = CASE
				   WHEN image_urls = '' OR image_urls IS NULL THEN $1
				   ELSE image_urls || ',' || $1
				 END,
				 updated_at = NOW()
				 WHERE id = $2 AND deleted_at IS NULL`,
				imageURL, req.TransactionId,
			)
			if err != nil {
				log.Printf("upload: saved image but failed to update transaction: %v", err)
			}
		}
	}

	log.Printf("upload: user %s uploaded image %s (%d bytes)", userID, fileName, len(req.Data))
	return &pb.UploadTransactionImageResponse{ImageUrl: imageURL}, nil
}

func (s *Service) ListTransactions(ctx context.Context, req *pb.ListTransactionsRequest) (*pb.ListTransactionsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	pageSize := int32(20)
	if req.PageSize > 0 && req.PageSize <= 100 {
		pageSize = req.PageSize
	}

	// Parse cursor from page_token: "txn_date_unix_nano|id"
	var cursorDate *time.Time
	var cursorID *uuid.UUID
	if req.PageToken != "" {
		parts := strings.SplitN(req.PageToken, "|", 2)
		if len(parts) == 2 {
			if ns, err := strconv.ParseInt(parts[0], 10, 64); err == nil {
				t := time.Unix(0, ns)
				cursorDate = &t
			}
			if cid, err := uuid.Parse(parts[1]); err == nil {
				cursorID = &cid
			}
		}
	}

	var accountID *uuid.UUID
	if req.AccountId != "" {
		aid, err := uuid.Parse(req.AccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid account_id")
		}
		accountID = &aid
	}

	var startDate, endDate *time.Time
	if req.StartDate != nil {
		t := req.StartDate.AsTime()
		startDate = &t
	}
	if req.EndDate != nil {
		t := req.EndDate.AsTime()
		endDate = &t
	}

	// Family filter: empty = personal accounts only, non-empty = family accounts
	var familyID *uuid.UUID
	if req.FamilyId != "" {
		fid, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		familyID = &fid
	}

	// Count total (only on first page — cursor present means not first page)
	var totalCount int32
	if cursorDate == nil {
		if familyID != nil {
			err = s.pool.QueryRow(ctx,
				`SELECT COUNT(*) FROM transactions t
				 JOIN accounts a ON a.id = t.account_id
				 WHERE t.user_id = $1 AND t.deleted_at IS NULL
				 AND a.family_id = $5
				 AND ($2::uuid IS NULL OR t.account_id = $2)
				 AND ($3::timestamptz IS NULL OR t.txn_date >= $3)
				 AND ($4::timestamptz IS NULL OR t.txn_date <= $4)`,
				uid, accountID, startDate, endDate, familyID,
			).Scan(&totalCount)
		} else {
			err = s.pool.QueryRow(ctx,
				`SELECT COUNT(*) FROM transactions t
				 JOIN accounts a ON a.id = t.account_id
				 WHERE t.user_id = $1 AND t.deleted_at IS NULL
				 AND a.family_id IS NULL
				 AND ($2::uuid IS NULL OR t.account_id = $2)
				 AND ($3::timestamptz IS NULL OR t.txn_date >= $3)
				 AND ($4::timestamptz IS NULL OR t.txn_date <= $4)`,
				uid, accountID, startDate, endDate,
			).Scan(&totalCount)
		}
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to count transactions")
		}
	}

	// Query transactions with cursor-based pagination
	// Sort: txn_date DESC, id DESC — cursor seeks to (txn_date, id) < (cursor_date, cursor_id)
	var rows pgx.Rows
	if familyID != nil {
		rows, err = s.pool.Query(ctx,
			`SELECT t.id, t.user_id, t.account_id, t.category_id, t.amount, t.currency, t.amount_cny, t.exchange_rate, t.type, t.note, t.txn_date, t.created_at, t.updated_at, t.tags, t.image_urls
			 FROM transactions t
			 JOIN accounts a ON a.id = t.account_id
			 WHERE t.user_id = $1 AND t.deleted_at IS NULL
			 AND a.family_id = $8
			 AND ($2::uuid IS NULL OR t.account_id = $2)
			 AND ($3::timestamptz IS NULL OR t.txn_date >= $3)
			 AND ($4::timestamptz IS NULL OR t.txn_date <= $4)
			 AND (
			   $5::timestamptz IS NULL
			   OR (t.txn_date, t.id) < ($5, $6)
			 )
			 ORDER BY t.txn_date DESC, t.id DESC
			 LIMIT $7`,
			uid, accountID, startDate, endDate, cursorDate, cursorID, pageSize+1, familyID,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT t.id, t.user_id, t.account_id, t.category_id, t.amount, t.currency, t.amount_cny, t.exchange_rate, t.type, t.note, t.txn_date, t.created_at, t.updated_at, t.tags, t.image_urls
			 FROM transactions t
			 JOIN accounts a ON a.id = t.account_id
			 WHERE t.user_id = $1 AND t.deleted_at IS NULL
			 AND a.family_id IS NULL
			 AND ($2::uuid IS NULL OR t.account_id = $2)
			 AND ($3::timestamptz IS NULL OR t.txn_date >= $3)
			 AND ($4::timestamptz IS NULL OR t.txn_date <= $4)
			 AND (
			   $5::timestamptz IS NULL
			   OR (t.txn_date, t.id) < ($5, $6)
			 )
			 ORDER BY t.txn_date DESC, t.id DESC
			 LIMIT $7`,
			uid, accountID, startDate, endDate, cursorDate, cursorID, pageSize+1,
		)
	}
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query transactions")
	}
	defer rows.Close()

	var transactions []*pb.Transaction
	for rows.Next() {
		txn, err := scanTransaction(rows)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to scan transaction")
		}
		transactions = append(transactions, txn)
	}

	if transactions == nil {
		transactions = []*pb.Transaction{}
	}

	// Build next_page_token from last item if there are more results
	nextPageToken := ""
	if int32(len(transactions)) > pageSize {
		// We fetched pageSize+1, trim to pageSize and build cursor from last kept item
		transactions = transactions[:pageSize]
		last := transactions[pageSize-1]
		lastDate := last.TxnDate.AsTime()
		nextPageToken = fmt.Sprintf("%d|%s", lastDate.UnixNano(), last.Id)
	}

	return &pb.ListTransactionsResponse{
		Transactions:  transactions,
		NextPageToken: nextPageToken,
		TotalCount:    totalCount,
	}, nil
}

func (s *Service) GetCategories(ctx context.Context, req *pb.GetCategoriesRequest) (*pb.GetCategoriesResponse, error) {
	// Query all categories (including subcategories), excluding soft-deleted
	query := `SELECT id, name, icon, type, is_preset, sort_order,
	          COALESCE(parent_id::text, '') as parent_id,
	          COALESCE(icon_key, '') as icon_key
	          FROM categories WHERE deleted_at IS NULL`
	var args []interface{}

	if req.Type != pb.TransactionType_TRANSACTION_TYPE_UNSPECIFIED {
		catType := "expense"
		if req.Type == pb.TransactionType_TRANSACTION_TYPE_INCOME {
			catType = "income"
		}
		query += " AND type = $1::category_type"
		args = append(args, catType)
	}
	query += " ORDER BY type, sort_order ASC"

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query categories")
	}
	defer rows.Close()

	// Collect all categories into a flat map
	type catEntry struct {
		pb       *pb.Category
		parentID string
	}
	all := make([]catEntry, 0, 80)
	byID := make(map[string]*pb.Category, 80)

	for rows.Next() {
		var id uuid.UUID
		var name, icon, catType, parentID, iconKey string
		var isPreset bool
		var sortOrder int32

		if err := rows.Scan(&id, &name, &icon, &catType, &isPreset, &sortOrder, &parentID, &iconKey); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan category")
		}

		pbType := pb.TransactionType_TRANSACTION_TYPE_EXPENSE
		if catType == "income" {
			pbType = pb.TransactionType_TRANSACTION_TYPE_INCOME
		}

		cat := &pb.Category{
			Id:        id.String(),
			Name:      name,
			Icon:      icon,
			Type:      pbType,
			IsPreset:  isPreset,
			SortOrder: sortOrder,
			ParentId:  parentID,
			IconKey:   iconKey,
			Children:  []*pb.Category{},
		}
		all = append(all, catEntry{pb: cat, parentID: parentID})
		byID[id.String()] = cat
	}

	// Build tree: attach children to parents
	var roots []*pb.Category
	for _, entry := range all {
		if entry.parentID == "" {
			roots = append(roots, entry.pb)
		} else if parent, ok := byID[entry.parentID]; ok {
			parent.Children = append(parent.Children, entry.pb)
		} else {
			// Orphan subcategory (parent deleted?), treat as root
			roots = append(roots, entry.pb)
		}
	}

	if roots == nil {
		roots = []*pb.Category{}
	}

	return &pb.GetCategoriesResponse{
		Categories: roots,
	}, nil
}

// ── CreateCategory ──────────────────────────────────────────────────────────────

func (s *Service) CreateCategory(ctx context.Context, req *pb.CreateCategoryRequest) (*pb.CreateCategoryResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "name is required")
	}
	if req.IconKey == "" {
		return nil, status.Error(codes.InvalidArgument, "icon_key is required")
	}
	if req.Type == pb.TransactionType_TRANSACTION_TYPE_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "type is required")
	}

	catType := "expense"
	if req.Type == pb.TransactionType_TRANSACTION_TYPE_INCOME {
		catType = "income"
	}

	var parentID *uuid.UUID
	if req.ParentId != "" {
		pid, err := uuid.Parse(req.ParentId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid parent_id")
		}
		// Verify parent exists and is a main category
		var parentParent *uuid.UUID
		err = s.pool.QueryRow(ctx, "SELECT parent_id FROM categories WHERE id = $1 AND deleted_at IS NULL", pid).Scan(&parentParent)
		if err != nil {
			return nil, status.Error(codes.NotFound, "parent category not found")
		}
		if parentParent != nil {
			return nil, status.Error(codes.InvalidArgument, "cannot create sub-subcategory, only two levels allowed")
		}
		parentID = &pid
	}

	// Get next sort_order
	var maxSort int32
	if parentID != nil {
		_ = s.pool.QueryRow(ctx, "SELECT COALESCE(MAX(sort_order), 0) FROM categories WHERE parent_id = $1 AND deleted_at IS NULL", *parentID).Scan(&maxSort)
	} else {
		_ = s.pool.QueryRow(ctx, "SELECT COALESCE(MAX(sort_order), 0) FROM categories WHERE parent_id IS NULL AND type = $1::category_type AND deleted_at IS NULL", catType).Scan(&maxSort)
	}

	newID := uuid.New()
	_, err = s.pool.Exec(ctx,
		`INSERT INTO categories (id, name, icon, icon_key, type, is_preset, sort_order, parent_id, user_id)
		 VALUES ($1, $2, '', $3, $4::category_type, false, $5, $6, $7)`,
		newID, req.Name, req.IconKey, catType, maxSort+1, parentID, userID,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to create category: %v", err)
	}

	cat := &pb.Category{
		Id:        newID.String(),
		Name:      req.Name,
		IconKey:   req.IconKey,
		Type:      req.Type,
		IsPreset:  false,
		SortOrder: maxSort + 1,
		Children:  []*pb.Category{},
	}
	if parentID != nil {
		cat.ParentId = parentID.String()
	}

	return &pb.CreateCategoryResponse{Category: cat}, nil
}

// ── UpdateCategory ──────────────────────────────────────────────────────────────

func (s *Service) UpdateCategory(ctx context.Context, req *pb.UpdateCategoryRequest) (*pb.UpdateCategoryResponse, error) {
	_, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	catID, err := uuid.Parse(req.CategoryId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid category_id")
	}

	// Build dynamic UPDATE
	sets := []string{}
	args := []interface{}{}
	argIdx := 1

	if req.Name != nil {
		sets = append(sets, fmt.Sprintf("name = $%d", argIdx))
		args = append(args, *req.Name)
		argIdx++
	}
	if req.IconKey != nil {
		sets = append(sets, fmt.Sprintf("icon_key = $%d", argIdx))
		args = append(args, *req.IconKey)
		argIdx++
	}

	if len(sets) == 0 {
		return nil, status.Error(codes.InvalidArgument, "nothing to update")
	}

	query := fmt.Sprintf("UPDATE categories SET %s WHERE id = $%d AND deleted_at IS NULL RETURNING id, name, icon, icon_key, type, is_preset, sort_order, COALESCE(parent_id::text, '')",
		strings.Join(sets, ", "), argIdx)
	args = append(args, catID)

	var id uuid.UUID
	var name, icon, iconKey, catType, parentIDStr string
	var isPreset bool
	var sortOrder int32

	err = s.pool.QueryRow(ctx, query, args...).Scan(&id, &name, &icon, &iconKey, &catType, &isPreset, &sortOrder, &parentIDStr)
	if err != nil {
		return nil, status.Error(codes.NotFound, "category not found")
	}

	pbType := pb.TransactionType_TRANSACTION_TYPE_EXPENSE
	if catType == "income" {
		pbType = pb.TransactionType_TRANSACTION_TYPE_INCOME
	}

	cat := &pb.Category{
		Id:        id.String(),
		Name:      name,
		Icon:      icon,
		IconKey:   iconKey,
		Type:      pbType,
		IsPreset:  isPreset,
		SortOrder: sortOrder,
		ParentId:  parentIDStr,
		Children:  []*pb.Category{},
	}

	return &pb.UpdateCategoryResponse{Category: cat}, nil
}

// ── DeleteCategory ──────────────────────────────────────────────────────────────

func (s *Service) DeleteCategory(ctx context.Context, req *pb.DeleteCategoryRequest) (*pb.DeleteCategoryResponse, error) {
	_, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	catID, err := uuid.Parse(req.CategoryId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid category_id")
	}

	// Check category exists and is not preset
	var isPreset bool
	err = s.pool.QueryRow(ctx, "SELECT is_preset FROM categories WHERE id = $1 AND deleted_at IS NULL", catID).Scan(&isPreset)
	if err != nil {
		return nil, status.Error(codes.NotFound, "category not found")
	}
	if isPreset {
		return nil, status.Error(codes.PermissionDenied, "cannot delete preset category")
	}

	// Soft delete: category + its children
	_, err = s.pool.Exec(ctx, "UPDATE categories SET deleted_at = NOW() WHERE (id = $1 OR parent_id = $1) AND deleted_at IS NULL", catID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "failed to delete category: %v", err)
	}

	return &pb.DeleteCategoryResponse{}, nil
}

// ── ReorderCategories ───────────────────────────────────────────────────────────

func (s *Service) ReorderCategories(ctx context.Context, req *pb.ReorderCategoriesRequest) (*pb.ReorderCategoriesResponse, error) {
	_, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if len(req.Orders) == 0 {
		return &pb.ReorderCategoriesResponse{}, nil
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	for _, order := range req.Orders {
		catID, err := uuid.Parse(order.CategoryId)
		if err != nil {
			continue
		}
		_, err = tx.Exec(ctx, "UPDATE categories SET sort_order = $1 WHERE id = $2 AND deleted_at IS NULL", order.SortOrder, catID)
		if err != nil {
			return nil, status.Errorf(codes.Internal, "failed to reorder: %v", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit reorder")
	}

	return &pb.ReorderCategoriesResponse{}, nil
}

func scanTransaction(rows pgx.Rows) (*pb.Transaction, error) {
	var id, userID, accountID, categoryID uuid.UUID
	var amount, amountCny int64
	var currency, txnType, note string
	var exchangeRate float64
	var txnDate, createdAt, updatedAt time.Time
	var tags, imageURLs []string

	err := rows.Scan(&id, &userID, &accountID, &categoryID, &amount, &currency, &amountCny, &exchangeRate, &txnType, &note, &txnDate, &createdAt, &updatedAt, &tags, &imageURLs)
	if err != nil {
		return nil, err
	}

	pbType := pb.TransactionType_TRANSACTION_TYPE_EXPENSE
	if txnType == "income" {
		pbType = pb.TransactionType_TRANSACTION_TYPE_INCOME
	}

	if tags == nil {
		tags = []string{}
	}
	if imageURLs == nil {
		imageURLs = []string{}
	}

	return &pb.Transaction{
		Id:           id.String(),
		UserId:       userID.String(),
		AccountId:    accountID.String(),
		CategoryId:   categoryID.String(),
		Amount:       amount,
		Currency:     currency,
		AmountCny:    amountCny,
		ExchangeRate: exchangeRate,
		Type:         pbType,
		Note:         note,
		TxnDate:      timestamppb.New(txnDate),
		CreatedAt:    timestamppb.New(createdAt),
		UpdatedAt:    timestamppb.New(updatedAt),
		Tags:         tags,
		ImageUrls:    imageURLs,
	}, nil
}


