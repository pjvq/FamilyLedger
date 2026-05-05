package notify

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/notify"
)

const boostTestUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
const boostTestFamilyID = "f1234567-9c0b-4ef8-bb6d-6bb9bd380a22"

var boostTestUID = uuid.MustParse(boostTestUserID)

func boostAuthedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, boostTestUserID)
}

// ══════════════════════════════════════════════════════════════════════════════
// UpdateReminder (currently 0%)
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostUpdateReminder_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New().String()
	remindAt := time.Now().Add(24 * time.Hour)

	// Verify ownership
	mock.ExpectQuery("SELECT user_id FROM custom_reminders WHERE id").
		WithArgs(reminderID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(boostTestUserID))

	// Update
	mock.ExpectExec("UPDATE custom_reminders SET").
		WithArgs("Updated Title", "Updated Desc", pgxmock.AnyArg(), "weekly", pgxmock.AnyArg(), true, reminderID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	// Re-query for return value
	rID := uuid.MustParse(reminderID)
	now := time.Now()
	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at, is_active, created_at, updated_at").
		WithArgs(reminderID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at", "is_active", "created_at", "updated_at"}).
			AddRow(rID, boostTestUserID, (*uuid.UUID)(nil), "Updated Title", "Updated Desc", remindAt, "weekly", (*time.Time)(nil), true, now, now))

	repeatEndAt := timestamppb.New(remindAt.AddDate(1, 0, 0))
	resp, err := svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		ReminderId:  reminderID,
		Title:       "Updated Title",
		Description: "Updated Desc",
		RemindAt:    timestamppb.New(remindAt),
		RepeatRule:  "weekly",
		RepeatEndAt: repeatEndAt,
		IsActive:    true,
	})
	require.NoError(t, err)
	assert.Equal(t, reminderID, resp.Id)
	assert.Equal(t, "Updated Title", resp.Title)
	assert.Equal(t, "weekly", resp.RepeatRule)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostUpdateReminder_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.UpdateReminder(context.Background(), &pb.UpdateReminderRequest{
		ReminderId: uuid.New().String(),
		Title:      "Title",
		RemindAt:   timestamppb.Now(),
	})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestBoostUpdateReminder_MissingReminderID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		Title:    "Title",
		RemindAt: timestamppb.Now(),
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoostUpdateReminder_MissingTitle(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		ReminderId: uuid.New().String(),
		RemindAt:   timestamppb.Now(),
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoostUpdateReminder_MissingRemindAt(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		ReminderId: uuid.New().String(),
		Title:      "Title",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoostUpdateReminder_InvalidRepeatRule(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		ReminderId: uuid.New().String(),
		Title:      "Title",
		RemindAt:   timestamppb.Now(),
		RepeatRule: "biweekly", // invalid
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoostUpdateReminder_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New().String()
	mock.ExpectQuery("SELECT user_id FROM custom_reminders WHERE id").
		WithArgs(reminderID).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		ReminderId: reminderID,
		Title:      "Title",
		RemindAt:   timestamppb.Now(),
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostUpdateReminder_NotOwner(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New().String()
	mock.ExpectQuery("SELECT user_id FROM custom_reminders WHERE id").
		WithArgs(reminderID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow("other-user-id"))

	_, err = svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		ReminderId: reminderID,
		Title:      "Title",
		RemindAt:   timestamppb.Now(),
	})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostUpdateReminder_UpdateExecError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New().String()

	// Ownership check passes
	mock.ExpectQuery("SELECT user_id FROM custom_reminders WHERE id").
		WithArgs(reminderID).
		WillReturnRows(pgxmock.NewRows([]string{"user_id"}).AddRow(boostTestUserID))

	// Update fails
	mock.ExpectExec("UPDATE custom_reminders SET").
		WithArgs("Title", "", pgxmock.AnyArg(), "none", (*time.Time)(nil), false, reminderID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		ReminderId: reminderID,
		Title:      "Title",
		RemindAt:   timestamppb.Now(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostUpdateReminder_QueryOwnershipError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New().String()
	mock.ExpectQuery("SELECT user_id FROM custom_reminders WHERE id").
		WithArgs(reminderID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.UpdateReminder(boostAuthedCtx(), &pb.UpdateReminderRequest{
		ReminderId: reminderID,
		Title:      "Title",
		RemindAt:   timestamppb.Now(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// CheckLoanReminders (currently 39.6%)
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostCheckLoanReminders_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	dueDate := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, time.UTC) // tomorrow

	loanID := uuid.New()

	// Query notification settings
	mock.ExpectQuery("SELECT user_id, reminder_days_before FROM notification_settings WHERE loan_reminder = true").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "reminder_days_before"}).
			AddRow(boostTestUID, 3))

	// Query upcoming loan payments
	mock.ExpectQuery("SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "month_number", "payment", "due_date"}).
			AddRow(loanID, boostTestUID, "房贷", int32(12), int64(500000), dueDate))

	// hasLoanNotification check
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, loanID.String(), dueDate.Format("2006-01-02")).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	// CreateNotification
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(boostTestUserID, "loan_reminder", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.CheckLoanReminders(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckLoanReminders_AlreadyNotified(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	dueDate := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, time.UTC)
	loanID := uuid.New()

	// Query notification settings
	mock.ExpectQuery("SELECT user_id, reminder_days_before FROM notification_settings WHERE loan_reminder = true").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "reminder_days_before"}).
			AddRow(boostTestUID, 3))

	// Query upcoming loan payments
	mock.ExpectQuery("SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "month_number", "payment", "due_date"}).
			AddRow(loanID, boostTestUID, "房贷", int32(12), int64(500000), dueDate))

	// hasLoanNotification check - already notified
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, loanID.String(), dueDate.Format("2006-01-02")).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	err = svc.CheckLoanReminders(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckLoanReminders_NoSettings(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	// Query notification settings - empty
	mock.ExpectQuery("SELECT user_id, reminder_days_before FROM notification_settings WHERE loan_reminder = true").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "reminder_days_before"}))

	// Query upcoming loan payments (still runs with default maxDays=3)
	mock.ExpectQuery("SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "month_number", "payment", "due_date"}))

	err = svc.CheckLoanReminders(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckLoanReminders_SettingsQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT user_id, reminder_days_before FROM notification_settings WHERE loan_reminder = true").
		WillReturnError(fmt.Errorf("db error"))

	err = svc.CheckLoanReminders(context.Background())
	assert.Error(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckLoanReminders_PaymentsQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT user_id, reminder_days_before FROM notification_settings WHERE loan_reminder = true").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "reminder_days_before"}).
			AddRow(boostTestUID, 5))

	mock.ExpectQuery("SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("query error"))

	err = svc.CheckLoanReminders(context.Background())
	assert.Error(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckLoanReminders_DueTooFar(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	// Payment due in 10 days but user's reminder window is only 2 days
	dueDate := time.Date(now.Year(), now.Month(), now.Day()+10, 0, 0, 0, 0, time.UTC)
	loanID := uuid.New()

	// Longer reminder window to include this payment in query
	mock.ExpectQuery("SELECT user_id, reminder_days_before FROM notification_settings WHERE loan_reminder = true").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "reminder_days_before"}).
			AddRow(boostTestUID, 2))

	mock.ExpectQuery("SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "month_number", "payment", "due_date"}).
			AddRow(loanID, boostTestUID, "车贷", int32(6), int64(300000), dueDate))

	// daysUntilDue > user's 2-day window, so should be skipped (no hasLoanNotification or notification created)

	err = svc.CheckLoanReminders(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckLoanReminders_UserWithoutSettings_UsesDefault(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	otherUserID := "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380c33"
	otherUID := uuid.MustParse(otherUserID)
	now := time.Now()
	dueDate := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, time.UTC)
	loanID := uuid.New()

	// No notification settings for the loan owner
	mock.ExpectQuery("SELECT user_id, reminder_days_before FROM notification_settings WHERE loan_reminder = true").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "reminder_days_before"}))

	// Upcoming payment for a user without settings
	mock.ExpectQuery("SELECT l.id, l.user_id, l.name, ls.month_number, ls.payment, ls.due_date").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "name", "month_number", "payment", "due_date"}).
			AddRow(loanID, otherUID, "消费贷", int32(1), int64(100000), dueDate))

	// hasLoanNotification check (default 3-day window, due tomorrow so within range)
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(otherUserID, loanID.String(), dueDate.Format("2006-01-02")).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	// Create notification
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(otherUserID, "loan_reminder", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.CheckLoanReminders(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// hasLoanNotification (currently 0%)
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostHasLoanNotification_Exists(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, "loan-123", "2026-05-01").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	result := svc.hasLoanNotification(context.Background(), boostTestUserID, "loan-123", "2026-05-01")
	assert.True(t, result)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostHasLoanNotification_NotExists(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, "loan-123", "2026-05-01").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	result := svc.hasLoanNotification(context.Background(), boostTestUserID, "loan-123", "2026-05-01")
	assert.False(t, result)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostHasLoanNotification_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, "loan-123", "2026-05-01").
		WillReturnError(fmt.Errorf("db error"))

	result := svc.hasLoanNotification(context.Background(), boostTestUserID, "loan-123", "2026-05-01")
	assert.False(t, result) // fail open
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// UpdateNotificationSettings additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostUpdateNotificationSettings_ExecError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectExec("INSERT INTO notification_settings").
		WithArgs(boostTestUserID, true, true, false, true, int32(3)).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.UpdateNotificationSettings(boostAuthedCtx(), &pb.UpdateNotificationSettingsRequest{
		Settings: &pb.NotificationSettings{
			BudgetAlert:        true,
			BudgetWarning:      true,
			DailySummary:       false,
			LoanReminder:       true,
			ReminderDaysBefore: 3,
		},
	})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// CreateReminder additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostCreateReminder_WithFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	remindAt := time.Now().Add(24 * time.Hour)
	reminderID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("INSERT INTO custom_reminders").
		WithArgs(boostTestUserID, pgxmock.AnyArg(), "Family Reminder", "description", pgxmock.AnyArg(), "monthly", pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(reminderID, now, now))

	repeatEndAt := timestamppb.New(remindAt.AddDate(1, 0, 0))
	resp, err := svc.CreateReminder(boostAuthedCtx(), &pb.CreateReminderRequest{
		Title:       "Family Reminder",
		Description: "description",
		RemindAt:    timestamppb.New(remindAt),
		RepeatRule:  "monthly",
		FamilyId:    boostTestFamilyID,
		RepeatEndAt: repeatEndAt,
	})
	require.NoError(t, err)
	assert.Equal(t, "Family Reminder", resp.Title)
	assert.Equal(t, boostTestFamilyID, resp.FamilyId)
	assert.Equal(t, "monthly", resp.RepeatRule)
	assert.NotNil(t, resp.RepeatEndAt)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCreateReminder_MissingRemindAt(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateReminder(boostAuthedCtx(), &pb.CreateReminderRequest{
		Title: "Reminder",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoostCreateReminder_InvalidFamilyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	_, err = svc.CreateReminder(boostAuthedCtx(), &pb.CreateReminderRequest{
		Title:    "Reminder",
		RemindAt: timestamppb.Now(),
		FamilyId: "not-a-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestBoostCreateReminder_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("INSERT INTO custom_reminders").
		WithArgs(boostTestUserID, (*uuid.UUID)(nil), "Title", "", pgxmock.AnyArg(), "none", (*time.Time)(nil)).
		WillReturnError(fmt.Errorf("db insert error"))

	_, err = svc.CreateReminder(boostAuthedCtx(), &pb.CreateReminderRequest{
		Title:    "Title",
		RemindAt: timestamppb.Now(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// CheckBudgets - budget warning path (rate >= 0.8 and < 1.0)
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostCheckBudgets_BudgetWarning(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())
	budgetID := uuid.New()

	// Query budgets
	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}).
			AddRow(budgetID, boostTestUID, (*uuid.UUID)(nil), int64(100000)))

	// Personal budget: spent 85% -> warning
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(boostTestUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(85000)))

	// hasNotification check for warning
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, "budget_warning", budgetID.String(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))

	// Create budget_warning notification
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(boostTestUserID, "budget_warning", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.CheckBudgets(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckBudgets_BudgetQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())

	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnError(fmt.Errorf("db error"))

	err = svc.CheckBudgets(context.Background())
	assert.Error(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckBudgets_SpentQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())
	budgetID := uuid.New()

	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}).
			AddRow(budgetID, boostTestUID, (*uuid.UUID)(nil), int64(100000)))

	// Spent query fails - should continue (not fatal)
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(boostTestUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("query error"))

	err = svc.CheckBudgets(context.Background())
	require.NoError(t, err) // non-fatal
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckBudgets_UnderBudget_NoNotification(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())
	budgetID := uuid.New()

	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}).
			AddRow(budgetID, boostTestUID, (*uuid.UUID)(nil), int64(100000)))

	// Spent only 50% -> no notification
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(boostTestUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(50000)))

	err = svc.CheckBudgets(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckBudgets_FamilySpentQueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())
	budgetID := uuid.New()
	familyUUID := uuid.MustParse(boostTestFamilyID)

	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}).
			AddRow(budgetID, boostTestUID, &familyUUID, int64(100000)))

	// Family spent query fails
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(t.amount_cny\\), 0\\)").
		WithArgs(boostTestFamilyID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("family query error"))

	err = svc.CheckBudgets(context.Background())
	require.NoError(t, err) // non-fatal, continues
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckBudgets_NotificationAlreadyExists(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	now := time.Now()
	year := int32(now.Year())
	month := int32(now.Month())
	budgetID := uuid.New()

	mock.ExpectQuery("SELECT b.id, b.user_id, b.family_id, b.total_amount").
		WithArgs(year, month).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "total_amount"}).
			AddRow(budgetID, boostTestUID, (*uuid.UUID)(nil), int64(100000)))

	// Exceeded budget
	mock.ExpectQuery("SELECT COALESCE\\(SUM\\(amount_cny\\), 0\\)").
		WithArgs(boostTestUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"coalesce"}).AddRow(int64(120000)))

	// hasNotification returns true - already notified
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, "budget_exceeded", budgetID.String(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))

	err = svc.CheckBudgets(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// CheckCustomReminders - additional paths
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostCheckCustomReminders_RepeatingReminder_AdvancesDate(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New()
	remindAt := time.Now().Add(-1 * time.Hour) // already past

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at"}).
			AddRow(reminderID, boostTestUID, (*uuid.UUID)(nil), "Daily Reminder", "desc", remindAt, "daily", (*time.Time)(nil)))

	// Create notification
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(boostTestUserID, "custom_reminder", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// Advance remind_at to next occurrence
	mock.ExpectExec("UPDATE custom_reminders SET remind_at").
		WithArgs(pgxmock.AnyArg(), reminderID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err = svc.CheckCustomReminders(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckCustomReminders_RepeatingReminder_PastEndDate_Deactivates(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New()
	remindAt := time.Now().Add(-1 * time.Hour)
	repeatEndAt := time.Now().Add(-30 * time.Minute) // already past

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at"}).
			AddRow(reminderID, boostTestUID, (*uuid.UUID)(nil), "Expired Repeat", "", remindAt, "daily", &repeatEndAt))

	// Create notification
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(boostTestUserID, "custom_reminder", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// Deactivate because next occurrence is past repeat_end_at
	mock.ExpectExec("UPDATE custom_reminders SET is_active = false").
		WithArgs(reminderID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err = svc.CheckCustomReminders(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckCustomReminders_WithDescription(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New()
	remindAt := time.Now().Add(-1 * time.Hour)

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at"}).
			AddRow(reminderID, boostTestUID, (*uuid.UUID)(nil), "Payment", "Pay electricity bill", remindAt, "none", (*time.Time)(nil)))

	// Create notification with description
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(boostTestUserID, "custom_reminder", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	// One-time: deactivate
	mock.ExpectExec("UPDATE custom_reminders SET is_active = false").
		WithArgs(reminderID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err = svc.CheckCustomReminders(context.Background())
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckCustomReminders_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("db error"))

	err = svc.CheckCustomReminders(context.Background())
	assert.Error(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostCheckCustomReminders_NotificationCreateError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New()
	remindAt := time.Now().Add(-1 * time.Hour)

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at").
		WithArgs(pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at"}).
			AddRow(reminderID, boostTestUID, (*uuid.UUID)(nil), "Fail", "", remindAt, "none", (*time.Time)(nil)))

	// Notification creation fails
	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(boostTestUserID, "custom_reminder", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("insert error"))

	err = svc.CheckCustomReminders(context.Background())
	require.NoError(t, err) // non-fatal
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// DeleteReminder additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostDeleteReminder_ExecError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	reminderID := uuid.New().String()
	mock.ExpectExec("DELETE FROM custom_reminders").
		WithArgs(reminderID, boostTestUserID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.DeleteReminder(boostAuthedCtx(), &pb.DeleteReminderRequest{ReminderId: reminderID})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// ListNotifications additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostListNotifications_CountError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT COUNT").
		WithArgs(boostTestUserID).
		WillReturnError(fmt.Errorf("count error"))

	_, err = svc.ListNotifications(boostAuthedCtx(), &pb.ListNotificationsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostListNotifications_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT COUNT").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(5)))

	mock.ExpectQuery("SELECT id, user_id, type, title, body, data_json, is_read, created_at").
		WithArgs(boostTestUserID, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("query error"))

	_, err = svc.ListNotifications(boostAuthedCtx(), &pb.ListNotificationsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostListNotifications_WithPagination(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	nID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT COUNT").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(10)))

	mock.ExpectQuery("SELECT id, user_id, type, title, body, data_json, is_read, created_at").
		WithArgs(boostTestUserID, int32(5), int32(5)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "type", "title", "body", "data_json", "is_read", "created_at"}).
			AddRow(nID, boostTestUID, "info", "Title", "Body", []byte(`{"key":"val"}`), false, now))

	resp, err := svc.ListNotifications(boostAuthedCtx(), &pb.ListNotificationsRequest{
		PageSize: 5,
		Page:     2,
	})
	require.NoError(t, err)
	assert.Equal(t, int32(10), resp.TotalCount)
	assert.Len(t, resp.Notifications, 1)
	assert.Equal(t, `{"key":"val"}`, resp.Notifications[0].DataJson)
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// ListReminders additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostListReminders_FamilyMode(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	rID := uuid.New()
	familyUUID := uuid.MustParse(boostTestFamilyID)
	now := time.Now()
	remindAt := now.Add(24 * time.Hour)
	repeatEndAt := now.AddDate(1, 0, 0)

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at, is_active, created_at, updated_at").
		WithArgs(boostTestFamilyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at", "is_active", "created_at", "updated_at"}).
			AddRow(rID, boostTestUserID, &familyUUID, "Family Reminder", "desc", remindAt, "monthly", &repeatEndAt, true, now, now))

	resp, err := svc.ListReminders(boostAuthedCtx(), &pb.ListRemindersRequest{
		FamilyId: boostTestFamilyID,
	})
	require.NoError(t, err)
	assert.Len(t, resp.Reminders, 1)
	assert.Equal(t, boostTestFamilyID, resp.Reminders[0].FamilyId)
	assert.NotNil(t, resp.Reminders[0].RepeatEndAt)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostListReminders_IncludeInactive(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at, is_active, created_at, updated_at").
		WithArgs(boostTestUserID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "family_id", "title", "description", "remind_at", "repeat_rule", "repeat_end_at", "is_active", "created_at", "updated_at"}))

	resp, err := svc.ListReminders(boostAuthedCtx(), &pb.ListRemindersRequest{
		IncludeInactive: true,
	})
	require.NoError(t, err)
	assert.Len(t, resp.Reminders, 0)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestBoostListReminders_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT id, user_id, family_id, title, description, remind_at, repeat_rule, repeat_end_at, is_active, created_at, updated_at").
		WithArgs(boostTestUserID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.ListReminders(boostAuthedCtx(), &pb.ListRemindersRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// GetNotificationSettings additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostGetNotificationSettings_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT budget_alert, budget_warning, daily_summary, loan_reminder, reminder_days_before").
		WithArgs(boostTestUserID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.GetNotificationSettings(boostAuthedCtx(), &pb.GetNotificationSettingsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// RegisterDevice additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostRegisterDevice_DBError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("INSERT INTO user_devices").
		WithArgs(pgxmock.AnyArg(), "test-token", "ios", "iPhone").
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.RegisterDevice(boostAuthedCtx(), &pb.RegisterDeviceRequest{
		DeviceToken: "test-token",
		Platform:    "ios",
		DeviceName:  "iPhone",
	})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// MarkAsRead additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostMarkAsRead_ExecError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	nID := uuid.New()
	mock.ExpectExec("UPDATE notifications SET is_read = true").
		WithArgs(pgxmock.AnyArg(), boostTestUserID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.MarkAsRead(boostAuthedCtx(), &pb.MarkAsReadRequest{
		NotificationIds: []string{nID.String()},
	})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// hasCreditCardNotification additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostHasCreditCardNotification_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, "billing_day_reminder", "acc-1", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("db error"))

	result := svc.hasCreditCardNotification(context.Background(), boostTestUserID, "acc-1", "billing_day_reminder")
	assert.False(t, result) // fail open
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// hasNotification additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostHasNotification_QueryError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(boostTestUserID, "budget_exceeded", "budget-1", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(fmt.Errorf("db error"))

	result := svc.hasNotification(context.Background(), boostTestUserID, "budget-1", "budget_exceeded", 2026, 5)
	assert.False(t, result) // fail open
	assert.NoError(t, mock.ExpectationsWereMet())
}

// ══════════════════════════════════════════════════════════════════════════════
// UnregisterDevice additional coverage
// ══════════════════════════════════════════════════════════════════════════════

func TestBoostUnregisterDevice_ExecError(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	deviceID := uuid.New()
	mock.ExpectExec("DELETE FROM user_devices").
		WithArgs(deviceID, boostTestUserID).
		WillReturnError(fmt.Errorf("db error"))

	_, err = svc.UnregisterDevice(boostAuthedCtx(), &pb.UnregisterDeviceRequest{
		DeviceId: deviceID.String(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
	assert.NoError(t, mock.ExpectationsWereMet())
}
