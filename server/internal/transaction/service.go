package transaction

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/transaction"
)

type Service struct {
	pb.UnimplementedTransactionServiceServer
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
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

	// Update account balance
	balanceDelta := req.Amount
	if txnType == "expense" {
		balanceDelta = -req.Amount
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

	offset := int32(0)
	if req.PageToken != "" {
		// Simple offset-based pagination via page token
		// In production, use cursor-based pagination
		// For now, page_token is just the offset string
		var n int
		_, err := uuid.Parse(req.PageToken)
		if err != nil {
			// try as int offset
			fmt.Sscanf(req.PageToken, "%d", &n)
			offset = int32(n)
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

	// Count total
	var totalCount int32
	err = s.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM transactions
		 WHERE user_id = $1 AND deleted_at IS NULL
		 AND ($2::uuid IS NULL OR account_id = $2)
		 AND ($3::timestamptz IS NULL OR txn_date >= $3)
		 AND ($4::timestamptz IS NULL OR txn_date <= $4)`,
		uid, accountID, startDate, endDate,
	).Scan(&totalCount)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to count transactions")
	}

	// Query transactions
	rows, err := s.pool.Query(ctx,
		`SELECT id, user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date, created_at, updated_at, tags, image_urls
		 FROM transactions
		 WHERE user_id = $1 AND deleted_at IS NULL
		 AND ($2::uuid IS NULL OR account_id = $2)
		 AND ($3::timestamptz IS NULL OR txn_date >= $3)
		 AND ($4::timestamptz IS NULL OR txn_date <= $4)
		 ORDER BY txn_date DESC, created_at DESC
		 LIMIT $5 OFFSET $6`,
		uid, accountID, startDate, endDate, pageSize, offset,
	)
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

	nextPageToken := ""
	nextOffset := offset + pageSize
	if nextOffset < totalCount {
		nextPageToken = fmt.Sprintf("%d", nextOffset)
	}

	return &pb.ListTransactionsResponse{
		Transactions:  transactions,
		NextPageToken: nextPageToken,
		TotalCount:    totalCount,
	}, nil
}

func (s *Service) GetCategories(ctx context.Context, req *pb.GetCategoriesRequest) (*pb.GetCategoriesResponse, error) {
	var rows pgx.Rows
	var err error

	if req.Type == pb.TransactionType_TRANSACTION_TYPE_UNSPECIFIED {
		rows, err = s.pool.Query(ctx, "SELECT id, name, icon, type, is_preset, sort_order FROM categories ORDER BY type, sort_order ASC")
	} else {
		catType := "expense"
		if req.Type == pb.TransactionType_TRANSACTION_TYPE_INCOME {
			catType = "income"
		}
		rows, err = s.pool.Query(ctx, "SELECT id, name, icon, type, is_preset, sort_order FROM categories WHERE type = $1::category_type ORDER BY sort_order ASC", catType)
	}
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query categories")
	}
	defer rows.Close()

	var categories []*pb.Category
	for rows.Next() {
		var id uuid.UUID
		var name, icon, catType string
		var isPreset bool
		var sortOrder int32

		if err := rows.Scan(&id, &name, &icon, &catType, &isPreset, &sortOrder); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan category")
		}

		pbType := pb.TransactionType_TRANSACTION_TYPE_EXPENSE
		if catType == "income" {
			pbType = pb.TransactionType_TRANSACTION_TYPE_INCOME
		}

		categories = append(categories, &pb.Category{
			Id:        id.String(),
			Name:      name,
			Icon:      icon,
			Type:      pbType,
			IsPreset:  isPreset,
			SortOrder: sortOrder,
		})
	}

	if categories == nil {
		categories = []*pb.Category{}
	}

	return &pb.GetCategoriesResponse{
		Categories: categories,
	}, nil
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


