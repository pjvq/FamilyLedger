package notify

import (
	"context"
	"encoding/json"
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
	pb "github.com/familyledger/server/proto/notify"
)

type Service struct {
	pb.UnimplementedNotifyServiceServer
	pool *pgxpool.Pool
}

func NewService(pool *pgxpool.Pool) *Service {
	return &Service{pool: pool}
}

func (s *Service) RegisterDevice(ctx context.Context, req *pb.RegisterDeviceRequest) (*pb.RegisterDeviceResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	if req.DeviceToken == "" {
		return nil, status.Error(codes.InvalidArgument, "device_token is required")
	}
	if req.Platform == "" {
		return nil, status.Error(codes.InvalidArgument, "platform is required")
	}
	switch req.Platform {
	case "ios", "android", "web":
	default:
		return nil, status.Error(codes.InvalidArgument, "platform must be ios, android, or web")
	}

	var deviceID uuid.UUID
	err = s.pool.QueryRow(ctx,
		`INSERT INTO user_devices (user_id, device_token, platform, device_name)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (device_token) DO UPDATE SET user_id = $1, device_name = $4
		 RETURNING id`,
		uid, req.DeviceToken, req.Platform, req.DeviceName,
	).Scan(&deviceID)
	if err != nil {
		log.Printf("notify: register device error: %v", err)
		return nil, status.Error(codes.Internal, "failed to register device")
	}

	log.Printf("notify: registered device %s for user %s", deviceID, userID)
	return &pb.RegisterDeviceResponse{DeviceId: deviceID.String()}, nil
}

func (s *Service) UnregisterDevice(ctx context.Context, req *pb.UnregisterDeviceRequest) (*pb.UnregisterDeviceResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	deviceID, err := uuid.Parse(req.DeviceId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid device_id")
	}

	tag, err := s.pool.Exec(ctx,
		"DELETE FROM user_devices WHERE id = $1 AND user_id = $2",
		deviceID, userID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to unregister device")
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "device not found")
	}

	log.Printf("notify: unregistered device %s", deviceID)
	return &pb.UnregisterDeviceResponse{}, nil
}

func (s *Service) GetNotificationSettings(ctx context.Context, req *pb.GetNotificationSettingsRequest) (*pb.GetNotificationSettingsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	var settings pb.NotificationSettings
	err = s.pool.QueryRow(ctx,
		`SELECT budget_alert, budget_warning, daily_summary, loan_reminder, reminder_days_before
		 FROM notification_settings WHERE user_id = $1`,
		userID,
	).Scan(&settings.BudgetAlert, &settings.BudgetWarning, &settings.DailySummary, &settings.LoanReminder, &settings.ReminderDaysBefore)
	if err != nil {
		if err == pgx.ErrNoRows {
			// Return defaults
			return &pb.GetNotificationSettingsResponse{
				Settings: &pb.NotificationSettings{
					BudgetAlert:        true,
					BudgetWarning:      true,
					DailySummary:       false,
					LoanReminder:       true,
					ReminderDaysBefore: 3,
				},
			}, nil
		}
		return nil, status.Error(codes.Internal, "failed to query notification settings")
	}

	return &pb.GetNotificationSettingsResponse{Settings: &settings}, nil
}

func (s *Service) UpdateNotificationSettings(ctx context.Context, req *pb.UpdateNotificationSettingsRequest) (*pb.UpdateNotificationSettingsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.Settings == nil {
		return nil, status.Error(codes.InvalidArgument, "settings is required")
	}

	_, err = s.pool.Exec(ctx,
		`INSERT INTO notification_settings (user_id, budget_alert, budget_warning, daily_summary, loan_reminder, reminder_days_before)
		 VALUES ($1, $2, $3, $4, $5, $6)
		 ON CONFLICT (user_id) DO UPDATE SET
		   budget_alert = $2, budget_warning = $3, daily_summary = $4,
		   loan_reminder = $5, reminder_days_before = $6, updated_at = NOW()`,
		userID,
		req.Settings.BudgetAlert,
		req.Settings.BudgetWarning,
		req.Settings.DailySummary,
		req.Settings.LoanReminder,
		req.Settings.ReminderDaysBefore,
	)
	if err != nil {
		log.Printf("notify: update settings error: %v", err)
		return nil, status.Error(codes.Internal, "failed to update notification settings")
	}

	return &pb.UpdateNotificationSettingsResponse{}, nil
}

func (s *Service) ListNotifications(ctx context.Context, req *pb.ListNotificationsRequest) (*pb.ListNotificationsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	pageSize := int32(20)
	if req.PageSize > 0 && req.PageSize <= 100 {
		pageSize = req.PageSize
	}
	page := int32(1)
	if req.Page > 0 {
		page = req.Page
	}
	offset := (page - 1) * pageSize

	var totalCount int32
	err = s.pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM notifications WHERE user_id = $1",
		userID,
	).Scan(&totalCount)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to count notifications")
	}

	rows, err := s.pool.Query(ctx,
		`SELECT id, user_id, type, title, body, data_json, is_read, created_at
		 FROM notifications
		 WHERE user_id = $1
		 ORDER BY created_at DESC
		 LIMIT $2 OFFSET $3`,
		userID, pageSize, offset,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query notifications")
	}
	defer rows.Close()

	var notifications []*pb.Notification
	for rows.Next() {
		var id, nUserID uuid.UUID
		var nType, title, body string
		var dataJSON []byte
		var isRead bool
		var createdAt time.Time

		if err := rows.Scan(&id, &nUserID, &nType, &title, &body, &dataJSON, &isRead, &createdAt); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan notification")
		}

		n := &pb.Notification{
			Id:        id.String(),
			UserId:    nUserID.String(),
			Type:      nType,
			Title:     title,
			Body:      body,
			IsRead:    isRead,
			CreatedAt: timestamppb.New(createdAt),
		}
		if dataJSON != nil {
			n.DataJson = string(dataJSON)
		}
		notifications = append(notifications, n)
	}

	if notifications == nil {
		notifications = []*pb.Notification{}
	}

	return &pb.ListNotificationsResponse{
		Notifications: notifications,
		TotalCount:    totalCount,
	}, nil
}

func (s *Service) MarkAsRead(ctx context.Context, req *pb.MarkAsReadRequest) (*pb.MarkAsReadResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if len(req.NotificationIds) == 0 {
		return nil, status.Error(codes.InvalidArgument, "notification_ids is required")
	}

	ids := make([]uuid.UUID, 0, len(req.NotificationIds))
	for _, idStr := range req.NotificationIds {
		id, err := uuid.Parse(idStr)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, fmt.Sprintf("invalid notification_id: %s", idStr))
		}
		ids = append(ids, id)
	}

	_, err = s.pool.Exec(ctx,
		`UPDATE notifications SET is_read = true
		 WHERE id = ANY($1) AND user_id = $2`,
		ids, userID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to mark as read")
	}

	return &pb.MarkAsReadResponse{}, nil
}

// ── Internal methods (used by scheduled tasks) ──────────────────────────────

// CreateNotification creates a notification record in the database.
func (s *Service) CreateNotification(ctx context.Context, userID string, nType, title, body string, data map[string]interface{}) error {
	var dataJSON []byte
	if data != nil {
		var err error
		dataJSON, err = json.Marshal(data)
		if err != nil {
			return fmt.Errorf("marshal data: %w", err)
		}
	}

	_, err := s.pool.Exec(ctx,
		`INSERT INTO notifications (user_id, type, title, body, data_json) VALUES ($1, $2, $3, $4, $5)`,
		userID, nType, title, body, dataJSON,
	)
	return err
}

// CheckBudgets iterates all active budgets (current month), computes execution rates,
// and creates warning/exceeded notifications. Deduplicates by budget_id + type + month.
func (s *Service) CheckBudgets(ctx context.Context) error {
	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	startOfMonth := time.Date(int(year), time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	log.Printf("notify: checking budgets for %d-%02d", year, month)

	// Get all budgets for current month
	rows, err := s.pool.Query(ctx,
		`SELECT b.id, b.user_id, b.total_amount
		 FROM budgets b
		 WHERE b.year = $1 AND b.month = $2`,
		year, month,
	)
	if err != nil {
		return fmt.Errorf("query budgets: %w", err)
	}
	defer rows.Close()

	type budgetRow struct {
		ID          uuid.UUID
		UserID      string
		TotalAmount int64
	}
	var budgets []budgetRow
	for rows.Next() {
		var b budgetRow
		var uid uuid.UUID
		if err := rows.Scan(&b.ID, &uid, &b.TotalAmount); err != nil {
			return fmt.Errorf("scan budget: %w", err)
		}
		b.UserID = uid.String()
		budgets = append(budgets, b)
	}
	rows.Close()

	for _, b := range budgets {
		// Compute total spent
		var totalSpent int64
		err := s.pool.QueryRow(ctx,
			`SELECT COALESCE(SUM(amount), 0)
			 FROM transactions
			 WHERE user_id = $1 AND type = 'expense' AND deleted_at IS NULL
			   AND txn_date >= $2 AND txn_date < $3`,
			b.UserID, startOfMonth, endOfMonth,
		).Scan(&totalSpent)
		if err != nil {
			log.Printf("notify: failed to compute spent for budget %s: %v", b.ID, err)
			continue
		}

		if b.TotalAmount <= 0 {
			continue
		}

		rate := float64(totalSpent) / float64(b.TotalAmount)

		// Check if notification already sent this month for this budget
		if rate >= 1.0 {
			if s.hasNotification(ctx, b.UserID, b.ID.String(), "budget_exceeded", year, month) {
				continue
			}
			err := s.CreateNotification(ctx, b.UserID, "budget_exceeded",
				"预算超支提醒",
				fmt.Sprintf("您 %d年%d月 的预算已超支，执行率 %.0f%%", year, month, rate*100),
				map[string]interface{}{"budget_id": b.ID.String(), "execution_rate": rate},
			)
			if err != nil {
				log.Printf("notify: failed to create budget_exceeded notification: %v", err)
			} else {
				log.Printf("notify: budget_exceeded notification created for user %s budget %s (%.0f%%)", b.UserID, b.ID, rate*100)
			}
		} else if rate >= 0.8 {
			if s.hasNotification(ctx, b.UserID, b.ID.String(), "budget_warning", year, month) {
				continue
			}
			err := s.CreateNotification(ctx, b.UserID, "budget_warning",
				"预算预警提醒",
				fmt.Sprintf("您 %d年%d月 的预算已使用 %.0f%%，请注意控制支出", year, month, rate*100),
				map[string]interface{}{"budget_id": b.ID.String(), "execution_rate": rate},
			)
			if err != nil {
				log.Printf("notify: failed to create budget_warning notification: %v", err)
			} else {
				log.Printf("notify: budget_warning notification created for user %s budget %s (%.0f%%)", b.UserID, b.ID, rate*100)
			}
		}
	}

	log.Printf("notify: budget check complete, processed %d budgets", len(budgets))
	return nil
}

// hasNotification checks if a notification with matching budget_id, type, and month
// has already been sent, to avoid duplicate alerts.
func (s *Service) hasNotification(ctx context.Context, userID, budgetID, nType string, year, month int32) bool {
	startOfMonth := time.Date(int(year), time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	var exists bool
	err := s.pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM notifications
			WHERE user_id = $1 AND type = $2
			  AND data_json->>'budget_id' = $3
			  AND created_at >= $4 AND created_at < $5
		)`,
		userID, nType, budgetID, startOfMonth, endOfMonth,
	).Scan(&exists)
	if err != nil {
		log.Printf("notify: hasNotification check error: %v", err)
		return false // Fail open: allow duplicate rather than miss notification
	}
	return exists
}
