package notify

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/familyledger/server/pkg/db"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/notify"
)

type Service struct {
	pb.UnimplementedNotifyServiceServer
	pool db.Pool
}

func NewService(pool db.Pool) *Service {
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
// For family budgets, notifications are sent to all family members with budget_alert enabled.
func (s *Service) CheckBudgets(ctx context.Context) error {
	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	startOfMonth := time.Date(int(year), time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	log.Printf("notify: checking budgets for %d-%02d", year, month)

	// Get all budgets for current month
	rows, err := s.pool.Query(ctx,
		`SELECT b.id, b.user_id, b.family_id, b.total_amount
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
		FamilyID    string
		TotalAmount int64
	}
	var budgets []budgetRow
	for rows.Next() {
		var b budgetRow
		var uid uuid.UUID
		var familyID *uuid.UUID
		if err := rows.Scan(&b.ID, &uid, &familyID, &b.TotalAmount); err != nil {
			return fmt.Errorf("scan budget: %w", err)
		}
		b.UserID = uid.String()
		if familyID != nil {
			b.FamilyID = familyID.String()
		}
		budgets = append(budgets, b)
	}
	rows.Close()

	for _, b := range budgets {
		// Compute total spent
		var totalSpent int64
		if b.FamilyID != "" {
			// Family budget: sum expenses from all family accounts
			err := s.pool.QueryRow(ctx,
				`SELECT COALESCE(SUM(t.amount_cny), 0)
				 FROM transactions t
				 JOIN accounts a ON a.id = t.account_id
				 WHERE a.family_id = $1 AND t.type = 'expense' AND t.deleted_at IS NULL
				   AND t.txn_date >= $2 AND t.txn_date < $3`,
				b.FamilyID, startOfMonth, endOfMonth,
			).Scan(&totalSpent)
			if err != nil {
				log.Printf("notify: failed to compute spent for family budget %s: %v", b.ID, err)
				continue
			}
		} else {
			// Personal budget: only count user's own expenses
			err := s.pool.QueryRow(ctx,
				`SELECT COALESCE(SUM(amount_cny), 0)
				 FROM transactions
				 WHERE user_id = $1 AND type = 'expense' AND deleted_at IS NULL
				   AND txn_date >= $2 AND txn_date < $3`,
				b.UserID, startOfMonth, endOfMonth,
			).Scan(&totalSpent)
			if err != nil {
				log.Printf("notify: failed to compute spent for budget %s: %v", b.ID, err)
				continue
			}
		}

		if b.TotalAmount <= 0 {
			continue
		}

		rate := float64(totalSpent) / float64(b.TotalAmount)

		// Determine recipients: for family budgets, notify all family members with budget_alert enabled
		recipients, err := s.getBudgetNotificationRecipients(ctx, b.UserID, b.FamilyID)
		if err != nil {
			log.Printf("notify: failed to get recipients for budget %s: %v", b.ID, err)
			continue
		}

		if rate >= 1.0 {
			for _, recipientID := range recipients {
				if s.hasNotification(ctx, recipientID, b.ID.String(), "budget_exceeded", year, month) {
					continue
				}
				err := s.CreateNotification(ctx, recipientID, "budget_exceeded",
					"预算超支提醒",
					fmt.Sprintf("您 %d年%d月 的预算已超支，执行率 %.0f%%", year, month, rate*100),
					map[string]interface{}{"budget_id": b.ID.String(), "execution_rate": rate},
				)
				if err != nil {
					log.Printf("notify: failed to create budget_exceeded notification: %v", err)
				} else {
					log.Printf("notify: budget_exceeded notification created for user %s budget %s (%.0f%%)", recipientID, b.ID, rate*100)
				}
			}
		} else if rate >= 0.8 {
			for _, recipientID := range recipients {
				if s.hasNotification(ctx, recipientID, b.ID.String(), "budget_warning", year, month) {
					continue
				}
				err := s.CreateNotification(ctx, recipientID, "budget_warning",
					"预算预警提醒",
					fmt.Sprintf("您 %d年%d月 的预算已使用 %.0f%%，请注意控制支出", year, month, rate*100),
					map[string]interface{}{"budget_id": b.ID.String(), "execution_rate": rate},
				)
				if err != nil {
					log.Printf("notify: failed to create budget_warning notification: %v", err)
				} else {
					log.Printf("notify: budget_warning notification created for user %s budget %s (%.0f%%)", recipientID, b.ID, rate*100)
				}
			}
		}
	}

	log.Printf("notify: budget check complete, processed %d budgets", len(budgets))
	return nil
}

// getBudgetNotificationRecipients returns the list of user IDs who should receive
// budget notifications. For personal budgets, it returns only the budget owner.
// For family budgets, it returns all family members who have budget_alert enabled.
func (s *Service) getBudgetNotificationRecipients(ctx context.Context, ownerUserID, familyID string) ([]string, error) {
	if familyID == "" {
		// Personal budget: only notify the owner
		return []string{ownerUserID}, nil
	}

	// Family budget: get all family members
	rows, err := s.pool.Query(ctx,
		`SELECT fm.user_id FROM family_members fm
		 WHERE fm.family_id = $1`,
		familyID,
	)
	if err != nil {
		return nil, fmt.Errorf("query family members: %w", err)
	}
	defer rows.Close()

	var memberIDs []string
	for rows.Next() {
		var uid uuid.UUID
		if err := rows.Scan(&uid); err != nil {
			return nil, fmt.Errorf("scan family member: %w", err)
		}
		memberIDs = append(memberIDs, uid.String())
	}
	rows.Close()

	if len(memberIDs) == 0 {
		// Fallback: notify budget owner
		return []string{ownerUserID}, nil
	}

	// Filter members who have budget_alert enabled
	var recipients []string
	for _, memberID := range memberIDs {
		var budgetAlert bool
		err := s.pool.QueryRow(ctx,
			`SELECT budget_alert FROM notification_settings WHERE user_id = $1`,
			memberID,
		).Scan(&budgetAlert)
		if err != nil {
			// If no settings row, default is budget_alert = true
			budgetAlert = true
		}
		if budgetAlert {
			recipients = append(recipients, memberID)
		}
	}

	if len(recipients) == 0 {
		// Edge case: no one has alerts enabled, still notify owner
		return []string{ownerUserID}, nil
	}

	return recipients, nil
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

// hasCreditCardNotification checks if a credit card notification already exists today.
func (s *Service) hasCreditCardNotification(ctx context.Context, userID, accountID, nType string) bool {
	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	endOfDay := startOfDay.Add(24 * time.Hour)

	var exists bool
	err := s.pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM notifications
			WHERE user_id = $1 AND type = $2
			  AND data_json->>'account_id' = $3
			  AND created_at >= $4 AND created_at < $5
		)`,
		userID, nType, accountID, startOfDay, endOfDay,
	).Scan(&exists)
	if err != nil {
		log.Printf("notify: hasCreditCardNotification check error: %v", err)
		return false
	}
	return exists
}

// CheckCreditCardReminders checks all credit card accounts for billing day and
// payment due day reminders. Notifications are sent to the account owner and,
// for family accounts, to all family members.
func (s *Service) CheckCreditCardReminders(ctx context.Context) error {
	now := time.Now()
	today := now.Day()

	log.Printf("notify: checking credit card reminders for day %d", today)

	// Query all credit card accounts with billing_day or payment_due_day set
	rows, err := s.pool.Query(ctx,
		`SELECT id, user_id, family_id, name, billing_day, payment_due_day
		 FROM accounts
		 WHERE type = 'credit_card' AND deleted_at IS NULL
		   AND (billing_day IS NOT NULL OR payment_due_day IS NOT NULL)`,
	)
	if err != nil {
		return fmt.Errorf("query credit card accounts: %w", err)
	}
	defer rows.Close()

	type ccAccount struct {
		ID            uuid.UUID
		UserID        string
		FamilyID      string
		Name          string
		BillingDay    *int
		PaymentDueDay *int
	}

	var accounts []ccAccount
	for rows.Next() {
		var a ccAccount
		var uid uuid.UUID
		var familyID *uuid.UUID
		var billingDay, paymentDueDay *int
		if err := rows.Scan(&a.ID, &uid, &familyID, &a.Name, &billingDay, &paymentDueDay); err != nil {
			log.Printf("notify: scan credit card account error: %v", err)
			continue
		}
		a.UserID = uid.String()
		if familyID != nil {
			a.FamilyID = familyID.String()
		}
		a.BillingDay = billingDay
		a.PaymentDueDay = paymentDueDay
		accounts = append(accounts, a)
	}
	rows.Close()

	created := 0
	for _, a := range accounts {
		recipients := s.getCreditCardRecipients(ctx, a.UserID, a.FamilyID)

		// Check billing day
		if a.BillingDay != nil && today == *a.BillingDay {
			for _, recipientID := range recipients {
				if s.hasCreditCardNotification(ctx, recipientID, a.ID.String(), "billing_day_reminder") {
					continue
				}
				err := s.CreateNotification(ctx, recipientID, "billing_day_reminder",
					"信用卡账单日提醒",
					fmt.Sprintf("您的信用卡「%s」今天是账单日，请查看本期账单", a.Name),
					map[string]interface{}{"account_id": a.ID.String(), "billing_day": *a.BillingDay},
				)
				if err != nil {
					log.Printf("notify: failed to create billing_day_reminder: %v", err)
				} else {
					created++
				}
			}
		}

		// Check payment due day (remind 3 days before)
		if a.PaymentDueDay != nil {
			reminderDaysBefore := 3
			// Calculate days until due
			dueDay := *a.PaymentDueDay
			daysUntilDue := dueDay - today
			if daysUntilDue < 0 {
				// Due day is next month
				daysUntilDue += daysInMonth(now)
			}

			if daysUntilDue >= 0 && daysUntilDue <= reminderDaysBefore {
				for _, recipientID := range recipients {
					if s.hasCreditCardNotification(ctx, recipientID, a.ID.String(), "payment_due_reminder") {
						continue
					}

					var body string
					if daysUntilDue == 0 {
						body = fmt.Sprintf("您的信用卡「%s」今天是还款日，请及时还款", a.Name)
					} else {
						body = fmt.Sprintf("您的信用卡「%s」还有 %d 天到还款日（每月%d日），请及时还款", a.Name, daysUntilDue, dueDay)
					}

					err := s.CreateNotification(ctx, recipientID, "payment_due_reminder",
						"信用卡还款日提醒",
						body,
						map[string]interface{}{"account_id": a.ID.String(), "payment_due_day": dueDay, "days_until_due": daysUntilDue},
					)
					if err != nil {
						log.Printf("notify: failed to create payment_due_reminder: %v", err)
					} else {
						created++
					}
				}
			}
		}
	}

	log.Printf("notify: credit card reminder check complete, created %d reminders", created)
	return nil
}

// getCreditCardRecipients returns user IDs who should receive credit card notifications.
// For personal accounts: only the account owner.
// For family accounts: all family members.
func (s *Service) getCreditCardRecipients(ctx context.Context, ownerUserID, familyID string) []string {
	if familyID == "" {
		return []string{ownerUserID}
	}

	rows, err := s.pool.Query(ctx,
		`SELECT user_id FROM family_members WHERE family_id = $1`,
		familyID,
	)
	if err != nil {
		return []string{ownerUserID}
	}
	defer rows.Close()

	var members []string
	for rows.Next() {
		var uid uuid.UUID
		if err := rows.Scan(&uid); err != nil {
			continue
		}
		members = append(members, uid.String())
	}

	if len(members) == 0 {
		return []string{ownerUserID}
	}
	return members
}

// daysInMonth returns the number of days in the current month.
func daysInMonth(t time.Time) int {
	y, m, _ := t.Date()
	return time.Date(y, m+1, 0, 0, 0, 0, 0, t.Location()).Day()
}

// hasLoanNotification checks if a loan_reminder notification already exists for a
// specific loan and due_date (to avoid duplicate reminders).
func (s *Service) hasLoanNotification(ctx context.Context, userID, loanID, dueDateStr string) bool {
	var exists bool
	err := s.pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM notifications
			WHERE user_id = $1 AND type = 'loan_reminder'
			  AND data_json->>'loan_id' = $2
			  AND data_json->>'due_date' = $3
		)`,
		userID, loanID, dueDateStr,
	).Scan(&exists)
	if err != nil {
		log.Printf("notify: hasLoanNotification check error: %v", err)
		return false
	}
	return exists
}

// CheckLoanReminders checks all upcoming loan payments and creates reminder
// notifications for users who have loan_reminder enabled.
func (s *Service) CheckLoanReminders(ctx context.Context) error {
	log.Println("notify: checking loan reminders...")

	// Get all users' notification settings where loan_reminder is enabled
	rows, err := s.pool.Query(ctx,
		`SELECT user_id, reminder_days_before FROM notification_settings WHERE loan_reminder = true`,
	)
	if err != nil {
		return fmt.Errorf("query notification settings: %w", err)
	}

	type userSetting struct {
		UserID       string
		ReminderDays int
	}
	var settings []userSetting
	for rows.Next() {
		var us userSetting
		var uid uuid.UUID
		if err := rows.Scan(&uid, &us.ReminderDays); err != nil {
			rows.Close()
			return fmt.Errorf("scan setting: %w", err)
		}
		us.UserID = uid.String()
		settings = append(settings, us)
	}
	rows.Close()

	// Find the max reminder window
	maxDays := 3 // default
	for _, us := range settings {
		if us.ReminderDays > maxDays {
			maxDays = us.ReminderDays
		}
	}

	// Query upcoming loan payments directly
	now := time.Now()
	cutoff := now.AddDate(0, 0, maxDays)

	paymentRows, err := s.pool.Query(ctx,
		`SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date
		 FROM loan_schedules ls
		 JOIN loans l ON l.id = ls.loan_id AND l.deleted_at IS NULL
		 WHERE ls.is_paid = false
		   AND ls.due_date >= $1::date AND ls.due_date <= $2::date
		 ORDER BY ls.due_date`,
		now.Format("2006-01-02"), cutoff.Format("2006-01-02"),
	)
	if err != nil {
		return fmt.Errorf("query upcoming loan payments: %w", err)
	}
	defer paymentRows.Close()

	type upcomingPayment struct {
		LoanID      string
		UserID      string
		LoanName    string
		MonthNumber int32
		Payment     int64
		DueDate     time.Time
	}

	userDays := make(map[string]int)
	for _, us := range settings {
		userDays[us.UserID] = us.ReminderDays
	}

	created := 0
	for paymentRows.Next() {
		var p upcomingPayment
		var loanID, userID uuid.UUID
		if err := paymentRows.Scan(&loanID, &userID, &p.LoanName, &p.MonthNumber, &p.Payment, &p.DueDate); err != nil {
			return fmt.Errorf("scan upcoming payment: %w", err)
		}
		p.LoanID = loanID.String()
		p.UserID = userID.String()

		days, ok := userDays[p.UserID]
		if !ok {
			days = 3 // default for users without explicit settings
		}

		daysUntilDue := int(p.DueDate.Sub(now).Hours() / 24)
		if daysUntilDue > days {
			continue
		}

		dueDateStr := p.DueDate.Format("2006-01-02")
		if s.hasLoanNotification(ctx, p.UserID, p.LoanID, dueDateStr) {
			continue
		}

		amountYuan := float64(p.Payment) / 100.0
		err := s.CreateNotification(ctx, p.UserID, "loan_reminder",
			"贷款还款提醒",
			fmt.Sprintf("您的贷款「%s」第%d期还款 ¥%.2f 将于 %s 到期",
				p.LoanName, p.MonthNumber, amountYuan, dueDateStr),
			map[string]interface{}{
				"loan_id":      p.LoanID,
				"month_number": p.MonthNumber,
				"payment":      p.Payment,
				"due_date":     dueDateStr,
			},
		)
		if err != nil {
			log.Printf("notify: failed to create loan_reminder: %v", err)
		} else {
			created++
		}
	}

	log.Printf("notify: loan reminder check complete, created %d reminders", created)
	return nil
}

// ══════════════════════════════════════════════════════════════════════════════
// Custom Reminder CRUD
// ══════════════════════════════════════════════════════════════════════════════

var validRepeatRules = map[string]bool{
	"none": true, "daily": true, "weekly": true, "monthly": true, "yearly": true,
}

func (s *Service) CreateReminder(ctx context.Context, req *pb.CreateReminderRequest) (*pb.Reminder, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.Title == "" {
		return nil, status.Error(codes.InvalidArgument, "title is required")
	}
	if req.RemindAt == nil {
		return nil, status.Error(codes.InvalidArgument, "remind_at is required")
	}
	repeatRule := req.RepeatRule
	if repeatRule == "" {
		repeatRule = "none"
	}
	if !validRepeatRules[repeatRule] {
		return nil, status.Error(codes.InvalidArgument, "repeat_rule must be none, daily, weekly, monthly, or yearly")
	}

	var familyID *uuid.UUID
	if req.FamilyId != "" {
		fid, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		familyID = &fid
	}

	var repeatEndAt *time.Time
	if req.RepeatEndAt != nil {
		t := req.RepeatEndAt.AsTime()
		repeatEndAt = &t
	}

	var id uuid.UUID
	var createdAt, updatedAt time.Time
	err = s.pool.QueryRow(ctx,
		`INSERT INTO custom_reminders (user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 RETURNING id, created_at, updated_at`,
		userID, familyID, req.Title, req.Description, req.RemindAt.AsTime(), repeatRule, repeatEndAt,
	).Scan(&id, &createdAt, &updatedAt)
	if err != nil {
		log.Printf("notify: create reminder error: %v", err)
		return nil, status.Error(codes.Internal, "failed to create reminder")
	}

	reminder := &pb.Reminder{
		Id:         id.String(),
		UserId:     userID,
		Title:      req.Title,
		Description: req.Description,
		RemindAt:   req.RemindAt,
		RepeatRule: repeatRule,
		IsActive:   true,
		CreatedAt:  timestamppb.New(createdAt),
		UpdatedAt:  timestamppb.New(updatedAt),
	}
	if familyID != nil {
		reminder.FamilyId = familyID.String()
	}
	if req.RepeatEndAt != nil {
		reminder.RepeatEndAt = req.RepeatEndAt
	}

	log.Printf("notify: created reminder %s for user %s", id, userID)
	return reminder, nil
}

func (s *Service) ListReminders(ctx context.Context, req *pb.ListRemindersRequest) (*pb.ListRemindersResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	var query string
	var args []interface{}

	if req.FamilyId != "" {
		query = `SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at, is_active, created_at, updated_at
				 FROM custom_reminders WHERE family_id = $1`
		args = []interface{}{req.FamilyId}
	} else {
		query = `SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at, is_active, created_at, updated_at
				 FROM custom_reminders WHERE user_id = $1 AND family_id IS NULL`
		args = []interface{}{userID}
	}

	if !req.IncludeInactive {
		query += " AND is_active = true"
	}
	query += " ORDER BY remind_at ASC"

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query reminders")
	}
	defer rows.Close()

	var reminders []*pb.Reminder
	for rows.Next() {
		r, err := scanReminderRow(rows)
		if err != nil {
			return nil, err
		}
		reminders = append(reminders, r)
	}
	if reminders == nil {
		reminders = []*pb.Reminder{}
	}

	return &pb.ListRemindersResponse{Reminders: reminders}, nil
}

func (s *Service) UpdateReminder(ctx context.Context, req *pb.UpdateReminderRequest) (*pb.Reminder, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.ReminderId == "" {
		return nil, status.Error(codes.InvalidArgument, "reminder_id is required")
	}
	if req.Title == "" {
		return nil, status.Error(codes.InvalidArgument, "title is required")
	}
	if req.RemindAt == nil {
		return nil, status.Error(codes.InvalidArgument, "remind_at is required")
	}
	repeatRule := req.RepeatRule
	if repeatRule == "" {
		repeatRule = "none"
	}
	if !validRepeatRules[repeatRule] {
		return nil, status.Error(codes.InvalidArgument, "repeat_rule must be none, daily, weekly, monthly, or yearly")
	}

	// Verify ownership
	var ownerID string
	err = s.pool.QueryRow(ctx,
		"SELECT user_id FROM custom_reminders WHERE id = $1",
		req.ReminderId,
	).Scan(&ownerID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "reminder not found")
		}
		return nil, status.Error(codes.Internal, "failed to query reminder")
	}
	if ownerID != userID {
		return nil, status.Error(codes.PermissionDenied, "not your reminder")
	}

	var repeatEndAt *time.Time
	if req.RepeatEndAt != nil {
		t := req.RepeatEndAt.AsTime()
		repeatEndAt = &t
	}

	_, err = s.pool.Exec(ctx,
		`UPDATE custom_reminders SET title = $1, description = $2, remind_at = $3,
			repeat_rule = $4, repeat_end_at = $5, is_active = $6, updated_at = NOW()
		 WHERE id = $7`,
		req.Title, req.Description, req.RemindAt.AsTime(), repeatRule, repeatEndAt, req.IsActive, req.ReminderId,
	)
	if err != nil {
		log.Printf("notify: update reminder error: %v", err)
		return nil, status.Error(codes.Internal, "failed to update reminder")
	}

	// Return updated reminder
	row := s.pool.QueryRow(ctx,
		`SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at, is_active, created_at, updated_at
		 FROM custom_reminders WHERE id = $1`,
		req.ReminderId,
	)
	return scanSingleReminderRow(row)
}

func (s *Service) DeleteReminder(ctx context.Context, req *pb.DeleteReminderRequest) (*emptypb.Empty, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.ReminderId == "" {
		return nil, status.Error(codes.InvalidArgument, "reminder_id is required")
	}

	tag, err := s.pool.Exec(ctx,
		"DELETE FROM custom_reminders WHERE id = $1 AND user_id = $2",
		req.ReminderId, userID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete reminder")
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "reminder not found")
	}

	log.Printf("notify: deleted reminder %s by user %s", req.ReminderId, userID)
	return &emptypb.Empty{}, nil
}

// CheckCustomReminders checks all active custom reminders that are due and creates notifications.
func (s *Service) CheckCustomReminders(ctx context.Context) error {
	now := time.Now()

	log.Println("notify: checking custom reminders...")

	rows, err := s.pool.Query(ctx,
		`SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at
		 FROM custom_reminders
		 WHERE is_active = true AND remind_at <= $1`,
		now,
	)
	if err != nil {
		return fmt.Errorf("query custom reminders: %w", err)
	}
	defer rows.Close()

	type reminderRow struct {
		ID          uuid.UUID
		UserID      string
		FamilyID    string
		Title       string
		Description string
		RemindAt    time.Time
		RepeatRule  string
		RepeatEndAt *time.Time
	}

	var dueReminders []reminderRow
	for rows.Next() {
		var r reminderRow
		var uid uuid.UUID
		var familyID *uuid.UUID
		var repeatEndAt *time.Time
		if err := rows.Scan(&r.ID, &uid, &familyID, &r.Title, &r.Description, &r.RemindAt, &r.RepeatRule, &repeatEndAt); err != nil {
			log.Printf("notify: scan custom reminder error: %v", err)
			continue
		}
		r.UserID = uid.String()
		if familyID != nil {
			r.FamilyID = familyID.String()
		}
		r.RepeatEndAt = repeatEndAt
		dueReminders = append(dueReminders, r)
	}
	rows.Close()

	created := 0
	for _, r := range dueReminders {
		// Create notification
		body := r.Title
		if r.Description != "" {
			body = r.Title + ": " + r.Description
		}

		err := s.CreateNotification(ctx, r.UserID, "custom_reminder",
			"自定义提醒", body,
			map[string]interface{}{"reminder_id": r.ID.String()},
		)
		if err != nil {
			log.Printf("notify: failed to create custom_reminder notification: %v", err)
			continue
		}
		created++

		// Handle repeat: advance remind_at or deactivate
		if r.RepeatRule == "none" {
			// One-time reminder: deactivate
			_, _ = s.pool.Exec(ctx,
				"UPDATE custom_reminders SET is_active = false, updated_at = NOW() WHERE id = $1",
				r.ID,
			)
		} else {
			// Advance to next occurrence
			nextRemindAt := nextOccurrence(r.RemindAt, r.RepeatRule)
			if r.RepeatEndAt != nil && nextRemindAt.After(*r.RepeatEndAt) {
				// Past repeat_end_at: deactivate
				_, _ = s.pool.Exec(ctx,
					"UPDATE custom_reminders SET is_active = false, updated_at = NOW() WHERE id = $1",
					r.ID,
				)
			} else {
				_, _ = s.pool.Exec(ctx,
					"UPDATE custom_reminders SET remind_at = $1, updated_at = NOW() WHERE id = $2",
					nextRemindAt, r.ID,
				)
			}
		}
	}

	log.Printf("notify: custom reminder check complete, triggered %d reminders", created)
	return nil
}

// nextOccurrence computes the next reminder time based on the repeat rule.
func nextOccurrence(current time.Time, rule string) time.Time {
	switch rule {
	case "daily":
		return current.AddDate(0, 0, 1)
	case "weekly":
		return current.AddDate(0, 0, 7)
	case "monthly":
		return current.AddDate(0, 1, 0)
	case "yearly":
		return current.AddDate(1, 0, 0)
	default:
		return current
	}
}

// scanReminderRow scans a reminder row from pgx.Rows.
func scanReminderRow(rows pgx.Rows) (*pb.Reminder, error) {
	var id uuid.UUID
	var userID string
	var familyID *uuid.UUID
	var title, description, repeatRule string
	var remindAt time.Time
	var repeatEndAt *time.Time
	var isActive bool
	var createdAt, updatedAt time.Time

	if err := rows.Scan(&id, &userID, &familyID, &title, &description, &remindAt, &repeatRule, &repeatEndAt, &isActive, &createdAt, &updatedAt); err != nil {
		return nil, status.Error(codes.Internal, "failed to scan reminder")
	}

	r := &pb.Reminder{
		Id:          id.String(),
		UserId:      userID,
		Title:       title,
		Description: description,
		RemindAt:    timestamppb.New(remindAt),
		RepeatRule:  repeatRule,
		IsActive:    isActive,
		CreatedAt:   timestamppb.New(createdAt),
		UpdatedAt:   timestamppb.New(updatedAt),
	}
	if familyID != nil {
		r.FamilyId = familyID.String()
	}
	if repeatEndAt != nil {
		r.RepeatEndAt = timestamppb.New(*repeatEndAt)
	}
	return r, nil
}

// scanSingleReminderRow scans a single reminder from pgx.Row.
func scanSingleReminderRow(row pgx.Row) (*pb.Reminder, error) {
	var id uuid.UUID
	var userID string
	var familyID *uuid.UUID
	var title, description, repeatRule string
	var remindAt time.Time
	var repeatEndAt *time.Time
	var isActive bool
	var createdAt, updatedAt time.Time

	if err := row.Scan(&id, &userID, &familyID, &title, &description, &remindAt, &repeatRule, &repeatEndAt, &isActive, &createdAt, &updatedAt); err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "reminder not found")
		}
		return nil, status.Error(codes.Internal, "failed to scan reminder")
	}

	r := &pb.Reminder{
		Id:          id.String(),
		UserId:      userID,
		Title:       title,
		Description: description,
		RemindAt:    timestamppb.New(remindAt),
		RepeatRule:  repeatRule,
		IsActive:    isActive,
		CreatedAt:   timestamppb.New(createdAt),
		UpdatedAt:   timestamppb.New(updatedAt),
	}
	if familyID != nil {
		r.FamilyId = familyID.String()
	}
	if repeatEndAt != nil {
		r.RepeatEndAt = timestamppb.New(*repeatEndAt)
	}
	return r, nil
}
