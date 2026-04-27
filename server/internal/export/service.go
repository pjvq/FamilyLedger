package export

import (
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"log"
	"time"

	"github.com/familyledger/server/pkg/db"
	"github.com/familyledger/server/pkg/permission"
	"github.com/jung-kurt/gofpdf"
	"github.com/xuri/excelize/v2"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/export"
)

type Service struct {
	pb.UnimplementedExportServiceServer
	pool db.Pool
}

func NewService(pool db.Pool) *Service {
	return &Service{pool: pool}
}

// transactionRow 是导出用的扁平化交易数据
type transactionRow struct {
	Date         string
	Type         string
	CategoryName string
	Amount       int64 // 分
	AccountName  string
	Note         string
}

func (s *Service) ExportTransactions(ctx context.Context, req *pb.ExportRequest) (*pb.ExportResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.Format == "" {
		req.Format = "csv"
	}
	if req.Format != "csv" && req.Format != "excel" && req.Format != "pdf" {
		return nil, status.Error(codes.InvalidArgument, "format must be csv, excel, or pdf")
	}

	// Permission check: exporting family data requires can_view
	if req.FamilyId != "" {
		if err := permission.Check(ctx, s.pool, userID, req.FamilyId, permission.CanView); err != nil {
			return nil, err
		}
	}

	// 查询交易记录
	rows, err := s.queryTransactions(ctx, userID, req)
	if err != nil {
		return nil, err
	}

	// 导出
	switch req.Format {
	case "csv":
		return s.exportCSV(rows)
	case "excel":
		return s.exportExcel(rows)
	case "pdf":
		return s.exportPDF(rows)
	default:
		return nil, status.Error(codes.InvalidArgument, "unsupported format")
	}
}

func (s *Service) queryTransactions(ctx context.Context, userID string, req *pb.ExportRequest) ([]transactionRow, error) {
	var query string
	var args []interface{}
	argIdx := 1

	if req.FamilyId != "" {
		// Family mode: query all transactions from accounts belonging to this family
		query = `SELECT t.txn_date, t.type, COALESCE(c.name, '未分类'), t.amount_cny,
		                 COALESCE(a.name, '未知账户'), COALESCE(t.note, '')
		          FROM transactions t
		          LEFT JOIN categories c ON c.id = t.category_id
		          JOIN accounts a ON a.id = t.account_id
		          WHERE a.family_id = $1 AND t.deleted_at IS NULL`
		args = append(args, req.FamilyId)
		argIdx = 2
	} else {
		// Personal mode: only query transactions from personal accounts (no family)
		query = `SELECT t.txn_date, t.type, COALESCE(c.name, '未分类'), t.amount_cny,
		                 COALESCE(a.name, '未知账户'), COALESCE(t.note, '')
		          FROM transactions t
		          LEFT JOIN categories c ON c.id = t.category_id
		          LEFT JOIN accounts a ON a.id = t.account_id
		          WHERE t.user_id = $1 AND t.deleted_at IS NULL
		            AND (a.family_id IS NULL OR a.family_id = '')`
		args = append(args, userID)
		argIdx = 2
	}

	if req.StartDate != "" {
		startDate, err := time.Parse("2006-01-02", req.StartDate)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid start_date format, expected YYYY-MM-DD")
		}
		query += fmt.Sprintf(" AND t.txn_date >= $%d", argIdx)
		args = append(args, startDate)
		argIdx++
	}

	if req.EndDate != "" {
		endDate, err := time.Parse("2006-01-02", req.EndDate)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid end_date format, expected YYYY-MM-DD")
		}
		// 包含结束日期当天
		endDate = endDate.AddDate(0, 0, 1)
		query += fmt.Sprintf(" AND t.txn_date < $%d", argIdx)
		args = append(args, endDate)
		argIdx++
	}

	if len(req.CategoryIds) > 0 {
		query += fmt.Sprintf(" AND t.category_id = ANY($%d)", argIdx)
		args = append(args, req.CategoryIds)
		argIdx++
	}

	query += " ORDER BY t.txn_date DESC, t.created_at DESC"

	dbRows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		log.Printf("export: query error: %v", err)
		return nil, status.Error(codes.Internal, "failed to query transactions")
	}
	defer dbRows.Close()

	var result []transactionRow
	for dbRows.Next() {
		var txnDate time.Time
		var txnType, catName, accName, note string
		var amount int64

		if err := dbRows.Scan(&txnDate, &txnType, &catName, &amount, &accName, &note); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan transaction row")
		}

		typeLabel := "支出"
		if txnType == "income" {
			typeLabel = "收入"
		}

		result = append(result, transactionRow{
			Date:         txnDate.Format("2006-01-02"),
			Type:         typeLabel,
			CategoryName: catName,
			Amount:       amount,
			AccountName:  accName,
			Note:         note,
		})
	}

	return result, nil
}

// amountToYuan 分转元，保留两位小数
func amountToYuan(cents int64) string {
	yuan := float64(cents) / 100.0
	return fmt.Sprintf("%.2f", yuan)
}

// ── CSV 导出 ────────────────────────────────────────────────────────────────

func (s *Service) exportCSV(rows []transactionRow) (*pb.ExportResponse, error) {
	var buf bytes.Buffer
	// UTF-8 BOM for Excel compatibility
	buf.Write([]byte{0xEF, 0xBB, 0xBF})

	w := csv.NewWriter(&buf)
	// Header
	if err := w.Write([]string{"日期", "类型", "分类", "金额(元)", "账户", "备注"}); err != nil {
		return nil, status.Error(codes.Internal, "csv write error")
	}

	for _, row := range rows {
		if err := w.Write([]string{
			row.Date,
			row.Type,
			row.CategoryName,
			amountToYuan(row.Amount),
			row.AccountName,
			row.Note,
		}); err != nil {
			return nil, status.Error(codes.Internal, "csv write error")
		}
	}
	w.Flush()
	if err := w.Error(); err != nil {
		return nil, status.Error(codes.Internal, "csv flush error")
	}

	filename := fmt.Sprintf("transactions_%s.csv", time.Now().Format("20060102"))
	return &pb.ExportResponse{
		Data:        buf.Bytes(),
		Filename:    filename,
		ContentType: "text/csv; charset=utf-8",
	}, nil
}

// ── Excel 导出 ──────────────────────────────────────────────────────────────

func (s *Service) exportExcel(rows []transactionRow) (*pb.ExportResponse, error) {
	f := excelize.NewFile()
	defer f.Close()

	sheet := "交易记录"
	idx, err := f.NewSheet(sheet)
	if err != nil {
		return nil, status.Error(codes.Internal, "excel create sheet error")
	}
	f.SetActiveSheet(idx)
	// 删除默认 Sheet1
	f.DeleteSheet("Sheet1")

	// 设置列宽
	f.SetColWidth(sheet, "A", "A", 14)
	f.SetColWidth(sheet, "B", "B", 8)
	f.SetColWidth(sheet, "C", "C", 12)
	f.SetColWidth(sheet, "D", "D", 14)
	f.SetColWidth(sheet, "E", "E", 16)
	f.SetColWidth(sheet, "F", "F", 30)

	// 表头样式
	headerStyle, _ := f.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true, Size: 11},
		Fill:      excelize.Fill{Type: "pattern", Color: []string{"#D9E1F2"}, Pattern: 1},
		Alignment: &excelize.Alignment{Horizontal: "center", Vertical: "center"},
		Border: []excelize.Border{
			{Type: "bottom", Color: "#4472C4", Style: 2},
		},
	})

	headers := []string{"日期", "类型", "分类", "金额(元)", "账户", "备注"}
	for i, h := range headers {
		cell, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cell, h)
		f.SetCellStyle(sheet, cell, cell, headerStyle)
	}

	// 数据行
	for i, row := range rows {
		rowIdx := i + 2
		f.SetCellValue(sheet, cellName(1, rowIdx), row.Date)
		f.SetCellValue(sheet, cellName(2, rowIdx), row.Type)
		f.SetCellValue(sheet, cellName(3, rowIdx), row.CategoryName)
		f.SetCellValue(sheet, cellName(4, rowIdx), amountToYuan(row.Amount))
		f.SetCellValue(sheet, cellName(5, rowIdx), row.AccountName)
		f.SetCellValue(sheet, cellName(6, rowIdx), row.Note)
	}

	var buf bytes.Buffer
	if err := f.Write(&buf); err != nil {
		return nil, status.Error(codes.Internal, "excel write error")
	}

	filename := fmt.Sprintf("transactions_%s.xlsx", time.Now().Format("20060102"))
	return &pb.ExportResponse{
		Data:        buf.Bytes(),
		Filename:    filename,
		ContentType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
	}, nil
}

func cellName(col, row int) string {
	name, _ := excelize.CoordinatesToCellName(col, row)
	return name
}

// ── PDF 导出 ─────────────────────────────────────────────────────────────────

func (s *Service) exportPDF(rows []transactionRow) (*pb.ExportResponse, error) {
	pdf := gofpdf.New("L", "mm", "A4", "")
	pdf.SetAutoPageBreak(true, 15)
	pdf.AddPage()

	// 标题
	pdf.SetFont("Helvetica", "B", 16)
	pdf.CellFormat(0, 12, "Transaction Report", "", 1, "C", false, 0, "")
	pdf.Ln(5)

	// 导出时间
	pdf.SetFont("Helvetica", "", 9)
	pdf.CellFormat(0, 6, fmt.Sprintf("Generated: %s", time.Now().Format("2006-01-02 15:04")), "", 1, "R", false, 0, "")
	pdf.Ln(3)

	// 表头
	colWidths := []float64{30, 20, 35, 35, 50, 100}
	headers := []string{"Date", "Type", "Category", "Amount(CNY)", "Account", "Note"}

	pdf.SetFont("Helvetica", "B", 10)
	pdf.SetFillColor(217, 225, 242)
	for i, h := range headers {
		pdf.CellFormat(colWidths[i], 8, h, "1", 0, "C", true, 0, "")
	}
	pdf.Ln(-1)

	// 数据行
	pdf.SetFont("Helvetica", "", 9)
	pdf.SetFillColor(245, 245, 245)
	for i, row := range rows {
		fill := i%2 == 0
		pdf.CellFormat(colWidths[0], 7, row.Date, "1", 0, "C", fill, 0, "")
		pdf.CellFormat(colWidths[1], 7, row.Type, "1", 0, "C", fill, 0, "")
		pdf.CellFormat(colWidths[2], 7, truncateStr(row.CategoryName, 20), "1", 0, "L", fill, 0, "")
		pdf.CellFormat(colWidths[3], 7, amountToYuan(row.Amount), "1", 0, "R", fill, 0, "")
		pdf.CellFormat(colWidths[4], 7, truncateStr(row.AccountName, 30), "1", 0, "L", fill, 0, "")
		pdf.CellFormat(colWidths[5], 7, truncateStr(row.Note, 60), "1", 0, "L", fill, 0, "")
		pdf.Ln(-1)
	}

	var buf bytes.Buffer
	if err := pdf.Output(&buf); err != nil {
		return nil, status.Error(codes.Internal, "pdf write error")
	}

	filename := fmt.Sprintf("transactions_%s.pdf", time.Now().Format("20060102"))
	return &pb.ExportResponse{
		Data:        buf.Bytes(),
		Filename:    filename,
		ContentType: "application/pdf",
	}, nil
}

func truncateStr(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) <= maxLen {
		return s
	}
	return string(runes[:maxLen-1]) + "…"
}
