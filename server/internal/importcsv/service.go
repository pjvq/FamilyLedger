package importcsv

import (
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/familyledger/server/pkg/db"
	"golang.org/x/text/encoding/simplifiedchinese"
	"golang.org/x/text/transform"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

		"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/importpb"
)

const maxPreviewRows = 10

// Service implements the ImportService gRPC service.
type Service struct {
	pb.UnimplementedImportServiceServer
	pool db.Pool
}

// NewService creates a new ImportService.
func NewService(pool db.Pool) *Service {
	return &Service{pool: pool}
}

// ParseCSV parses CSV data, stores it in a session, and returns headers + preview rows.
func (s *Service) ParseCSV(ctx context.Context, req *pb.ParseCSVRequest) (*pb.ParseCSVResponse, error) {
	if len(req.CsvData) == 0 {
		return nil, status.Error(codes.InvalidArgument, "csv_data is required")
	}

	// Decode encoding
	data, err := decodeCSVData(req.CsvData, req.Encoding)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "decode csv: %v", err)
	}

	// Parse CSV
	reader := csv.NewReader(bytes.NewReader(data))
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	// Read header
	headers, err := reader.Read()
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "read csv header: %v", err)
	}

	// Read all rows to count + preview
	var allRows [][]string
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			// Skip malformed rows
			continue
		}
		allRows = append(allRows, record)
	}

	totalRows := len(allRows)

	// Build preview (up to 10 rows)
	previewCount := totalRows
	if previewCount > maxPreviewRows {
		previewCount = maxPreviewRows
	}

	previewRows := make([]*pb.CSVRow, previewCount)
	for i := 0; i < previewCount; i++ {
		previewRows[i] = &pb.CSVRow{Values: allRows[i]}
	}

	// Store session
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "authentication required for CSV import")
	}
	sessionID := uuid.New()
	expiresAt := time.Now().Add(30 * time.Minute)
	_, err = s.pool.Exec(ctx,
		`INSERT INTO import_sessions (id, user_id, csv_data, headers, total_rows, expires_at)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		sessionID,
		userID,
		req.CsvData,
		headers,
		int32(totalRows),
		expiresAt,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "store import session: %v", err)
	}

	log.Printf("import: created session %s with %d rows, %d headers", sessionID, totalRows, len(headers))

	return &pb.ParseCSVResponse{
		Headers:     headers,
		PreviewRows: previewRows,
		TotalRows:   int32(totalRows),
		SessionId:   sessionID.String(),
	}, nil
}

// ConfirmImport applies field mappings and batch-inserts transactions.
func (s *Service) ConfirmImport(ctx context.Context, req *pb.ConfirmImportRequest) (*pb.ConfirmImportResponse, error) {
	if req.SessionId == "" {
		return nil, status.Error(codes.InvalidArgument, "session_id is required")
	}
	if req.UserId == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}
	if len(req.Mappings) == 0 {
		return nil, status.Error(codes.InvalidArgument, "mappings are required")
	}

	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	userID, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}

	// Load session
	var csvData []byte
	var headers []string
	var expiresAt time.Time
	err = s.pool.QueryRow(ctx,
		`SELECT csv_data, headers, expires_at FROM import_sessions WHERE id = $1`,
		sessionID,
	).Scan(&csvData, &headers, &expiresAt)
	if err != nil {
		return nil, status.Error(codes.NotFound, "import session not found or expired")
	}

	if time.Now().After(expiresAt) {
		return nil, status.Error(codes.FailedPrecondition, "import session expired")
	}

	// Decode CSV again
	data, err := decodeCSVData(csvData, "utf8")
	if err != nil {
		// Try raw
		data = csvData
	}

	reader := csv.NewReader(bytes.NewReader(data))
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	// Skip header
	readHeaders, err := reader.Read()
	if err != nil {
		return nil, status.Errorf(codes.Internal, "re-read csv header: %v", err)
	}

	// Build column index map
	colIdx := make(map[string]int, len(readHeaders))
	for i, h := range readHeaders {
		colIdx[h] = i
	}

	// Build mapping: target_field → column_index
	fieldMap := make(map[string]int)
	for _, m := range req.Mappings {
		idx, ok := colIdx[m.CsvColumn]
		if !ok {
			return nil, status.Errorf(codes.InvalidArgument, "csv column %q not found", m.CsvColumn)
		}
		fieldMap[m.TargetField] = idx
	}

	// Default account
	defaultAccountID := uuid.Nil
	if req.DefaultAccountId != "" {
		defaultAccountID, err = uuid.Parse(req.DefaultAccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid default_account_id")
		}
	}

	// If no default account, find user's default account
	if defaultAccountID == uuid.Nil {
		err = s.pool.QueryRow(ctx,
			`SELECT id FROM accounts WHERE user_id = $1 AND is_default = true AND deleted_at IS NULL LIMIT 1`,
			userID,
		).Scan(&defaultAccountID)
		if err != nil {
			return nil, status.Error(codes.FailedPrecondition, "no default account found; provide default_account_id")
		}
	}

	// Process rows
	var importedCount, skippedCount int32
	var errors []string

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	rowNum := 0
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		rowNum++
		if err != nil {
			skippedCount++
			errors = append(errors, fmt.Sprintf("row %d: parse error: %v", rowNum, err))
			continue
		}

		// Extract fields
		txnDate, amount, txnType, categoryName, note, err := extractFields(record, fieldMap)
		if err != nil {
			skippedCount++
			errors = append(errors, fmt.Sprintf("row %d: %v", rowNum, err))
			continue
		}

		// Look up category by name (or use first matching)
		var categoryID uuid.UUID
		if categoryName != "" {
			err = tx.QueryRow(ctx,
				`SELECT id FROM categories WHERE name = $1 LIMIT 1`,
				categoryName,
			).Scan(&categoryID)
			if err != nil {
				// Try fuzzy match
				err = tx.QueryRow(ctx,
					`SELECT id FROM categories WHERE name ILIKE $1 LIMIT 1`,
					"%"+categoryName+"%",
				).Scan(&categoryID)
				if err != nil {
					// Use first category of matching type
					catType := "expense"
					if txnType == "income" {
						catType = "income"
					}
					err = tx.QueryRow(ctx,
						`SELECT id FROM categories WHERE type = $1::category_type ORDER BY sort_order LIMIT 1`,
						catType,
					).Scan(&categoryID)
					if err != nil {
						skippedCount++
						errors = append(errors, fmt.Sprintf("row %d: no category found", rowNum))
						continue
					}
				}
			}
		} else {
			// Default to first expense category
			catType := "expense"
			if txnType == "income" {
				catType = "income"
			}
			err = tx.QueryRow(ctx,
				`SELECT id FROM categories WHERE type = $1::category_type ORDER BY sort_order LIMIT 1`,
				catType,
			).Scan(&categoryID)
			if err != nil {
				skippedCount++
				errors = append(errors, fmt.Sprintf("row %d: no default category", rowNum))
				continue
			}
		}

		// Insert transaction
		_, err = tx.Exec(ctx,
			`INSERT INTO transactions (user_id, account_id, category_id, amount, currency, amount_cny, exchange_rate, type, note, txn_date)
			 VALUES ($1, $2, $3, $4, 'CNY', $4, 1.0, $5::transaction_type, $6, $7)`,
			userID, defaultAccountID, categoryID, amount, txnType, note, txnDate,
		)
		if err != nil {
			skippedCount++
			errors = append(errors, fmt.Sprintf("row %d: insert error: %v", rowNum, err))
			continue
		}

		importedCount++

		// Update account balance
		balanceDelta := amount
		if txnType == "expense" {
			balanceDelta = -amount
		}
		_, err = tx.Exec(ctx,
			"UPDATE accounts SET balance = balance + $1, updated_at = NOW() WHERE id = $2",
			balanceDelta, defaultAccountID,
		)
		if err != nil {
			log.Printf("import: row %d: failed to update balance: %v", rowNum, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "commit: %v", err)
	}

	// Clean up session
	_, _ = s.pool.Exec(ctx, `DELETE FROM import_sessions WHERE id = $1`, sessionID)

	log.Printf("import: session %s done — imported=%d skipped=%d errors=%d",
		sessionID, importedCount, skippedCount, len(errors))

	return &pb.ConfirmImportResponse{
		ImportedCount: importedCount,
		SkippedCount:  skippedCount,
		Errors:        errors,
	}, nil
}

// CleanupExpiredSessions removes expired import sessions.
func (s *Service) CleanupExpiredSessions(ctx context.Context) error {
	result, err := s.pool.Exec(ctx,
		`DELETE FROM import_sessions WHERE expires_at < NOW()`,
	)
	if err != nil {
		return fmt.Errorf("cleanup expired sessions: %w", err)
	}
	count := result.RowsAffected()
	if count > 0 {
		log.Printf("import: cleaned up %d expired sessions", count)
	}
	return nil
}

// ── Internal helpers ────────────────────────────────────────────────────────

func decodeCSVData(data []byte, encoding string) ([]byte, error) {
	enc := strings.ToLower(strings.TrimSpace(encoding))
	switch enc {
	case "gbk", "gb2312", "gb18030":
		reader := transform.NewReader(bytes.NewReader(data), simplifiedchinese.GBK.NewDecoder())
		decoded, err := io.ReadAll(reader)
		if err != nil {
			return nil, fmt.Errorf("decode GBK: %w", err)
		}
		return decoded, nil
	case "utf8", "utf-8", "":
		// Remove BOM if present
		if len(data) >= 3 && data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF {
			data = data[3:]
		}
		return data, nil
	default:
		return data, nil
	}
}

func extractFields(record []string, fieldMap map[string]int) (txnDate time.Time, amount int64, txnType, categoryName, note string, err error) {
	// Date
	if idx, ok := fieldMap["date"]; ok && idx < len(record) {
		txnDate, err = parseDate(record[idx])
		if err != nil {
			return time.Time{}, 0, "", "", "", fmt.Errorf("parse date %q: %w", record[idx], err)
		}
	} else {
		txnDate = time.Now()
	}

	// Amount (in fen/cents)
	if idx, ok := fieldMap["amount"]; ok && idx < len(record) {
		amountStr := strings.TrimSpace(record[idx])
		amountStr = strings.ReplaceAll(amountStr, ",", "")
		amountStr = strings.ReplaceAll(amountStr, "¥", "")
		amountStr = strings.ReplaceAll(amountStr, "￥", "")
		amountStr = strings.TrimSpace(amountStr)

		f, parseErr := strconv.ParseFloat(amountStr, 64)
		if parseErr != nil {
			return time.Time{}, 0, "", "", "", fmt.Errorf("parse amount %q: %w", record[idx], parseErr)
		}
		// Convert to fen (cents)
		amount = int64(f * 100)
		if amount < 0 {
			amount = -amount
		}
	} else {
		return time.Time{}, 0, "", "", "", fmt.Errorf("amount field not mapped")
	}

	// Type
	txnType = "expense" // default
	if idx, ok := fieldMap["type"]; ok && idx < len(record) {
		val := strings.TrimSpace(record[idx])
		val = strings.ToLower(val)
		if val == "income" || val == "收入" || val == "1" {
			txnType = "income"
		}
	}

	// Category
	if idx, ok := fieldMap["category"]; ok && idx < len(record) {
		categoryName = strings.TrimSpace(record[idx])
	}

	// Note
	if idx, ok := fieldMap["note"]; ok && idx < len(record) {
		note = strings.TrimSpace(record[idx])
	}

	return txnDate, amount, txnType, categoryName, note, nil
}

func parseDate(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	formats := []string{
		"2006-01-02",
		"2006/01/02",
		"2006.01.02",
		"20060102",
		"2006-01-02 15:04:05",
		"2006/01/02 15:04:05",
		"01/02/2006",
		"02/01/2006",
		time.RFC3339,
	}
	cst, _ := time.LoadLocation("Asia/Shanghai")
	for _, f := range formats {
		t, err := time.ParseInLocation(f, s, cst)
		if err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("unrecognized date format: %s", s)
}
