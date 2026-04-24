package notify

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/notify"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

var testUID = uuid.MustParse(testUserID)

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

// ─── RegisterDevice ─────────────────────────────────────────────────────────

func TestRegisterDevice_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	devID := uuid.New()

	mock.ExpectQuery("INSERT INTO user_devices").
		WithArgs(testUID, "token123", "ios", "iPhone").
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(devID))

	resp, err := svc.RegisterDevice(authedCtx(), &pb.RegisterDeviceRequest{
		DeviceToken: "token123",
		Platform:    "ios",
		DeviceName:  "iPhone",
	})
	require.NoError(t, err)
	assert.Equal(t, devID.String(), resp.DeviceId)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestRegisterDevice_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.RegisterDevice(context.Background(), &pb.RegisterDeviceRequest{})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestRegisterDevice_MissingToken(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.RegisterDevice(authedCtx(), &pb.RegisterDeviceRequest{
		Platform: "ios",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestRegisterDevice_InvalidPlatform(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.RegisterDevice(authedCtx(), &pb.RegisterDeviceRequest{
		DeviceToken: "x",
		Platform:    "windows",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── UnregisterDevice ───────────────────────────────────────────────────────

func TestUnregisterDevice_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	devID := uuid.New()

	mock.ExpectExec("DELETE FROM user_devices").
		WithArgs(devID, testUserID).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	_, err = svc.UnregisterDevice(authedCtx(), &pb.UnregisterDeviceRequest{DeviceId: devID.String()})
	require.NoError(t, err)
}

func TestUnregisterDevice_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	devID := uuid.New()

	mock.ExpectExec("DELETE FROM user_devices").
		WithArgs(devID, testUserID).
		WillReturnResult(pgxmock.NewResult("DELETE", 0))

	_, err = svc.UnregisterDevice(authedCtx(), &pb.UnregisterDeviceRequest{DeviceId: devID.String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestUnregisterDevice_InvalidID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.UnregisterDevice(authedCtx(), &pb.UnregisterDeviceRequest{DeviceId: "not-a-uuid"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetNotificationSettings ────────────────────────────────────────────────

func TestGetNotificationSettings_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM notification_settings").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"budget_alert", "budget_warning", "daily_summary", "loan_reminder", "reminder_days_before"}).
			AddRow(true, true, false, true, int32(3)))

	resp, err := svc.GetNotificationSettings(authedCtx(), &pb.GetNotificationSettingsRequest{})
	require.NoError(t, err)
	assert.True(t, resp.Settings.BudgetAlert)
	assert.Equal(t, int32(3), resp.Settings.ReminderDaysBefore)
}

func TestGetNotificationSettings_Defaults(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT .+ FROM notification_settings").
		WithArgs(testUserID).
		WillReturnError(pgx.ErrNoRows)

	resp, err := svc.GetNotificationSettings(authedCtx(), &pb.GetNotificationSettingsRequest{})
	require.NoError(t, err)
	assert.True(t, resp.Settings.BudgetAlert)
	assert.True(t, resp.Settings.LoanReminder)
	assert.Equal(t, int32(3), resp.Settings.ReminderDaysBefore)
}

// ─── UpdateNotificationSettings ─────────────────────────────────────────────

func TestUpdateNotificationSettings_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectExec("INSERT INTO notification_settings").
		WithArgs(testUserID, true, false, true, true, int32(5)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	_, err = svc.UpdateNotificationSettings(authedCtx(), &pb.UpdateNotificationSettingsRequest{
		Settings: &pb.NotificationSettings{
			BudgetAlert:        true,
			BudgetWarning:      false,
			DailySummary:       true,
			LoanReminder:       true,
			ReminderDaysBefore: 5,
		},
	})
	require.NoError(t, err)
}

func TestUpdateNotificationSettings_NilSettings(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.UpdateNotificationSettings(authedCtx(), &pb.UpdateNotificationSettingsRequest{Settings: nil})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── ListNotifications ──────────────────────────────────────────────────────

func TestListNotifications_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	now := time.Now()

	mock.ExpectQuery("SELECT COUNT").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(1)))
	mock.ExpectQuery("SELECT .+ FROM notifications").
		WithArgs(testUserID, int32(20), int32(0)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "type", "title", "body", "data_json", "is_read", "created_at"}).
			AddRow(uuid.New(), testUID, "budget_warning", "预算预警", "已用80%", []byte(`{}`), false, now))

	resp, err := svc.ListNotifications(authedCtx(), &pb.ListNotificationsRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Notifications, 1)
	assert.Equal(t, int32(1), resp.TotalCount)
}

func TestListNotifications_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectQuery("SELECT COUNT").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"count"}).AddRow(int32(0)))
	mock.ExpectQuery("SELECT .+ FROM notifications").
		WithArgs(testUserID, int32(20), int32(0)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "user_id", "type", "title", "body", "data_json", "is_read", "created_at"}))

	resp, err := svc.ListNotifications(authedCtx(), &pb.ListNotificationsRequest{})
	require.NoError(t, err)
	assert.Empty(t, resp.Notifications)
}

// ─── MarkAsRead ─────────────────────────────────────────────────────────────

func TestMarkAsRead_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	nid := uuid.New()

	mock.ExpectExec("UPDATE notifications SET is_read").
		WithArgs([]uuid.UUID{nid}, testUserID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	_, err = svc.MarkAsRead(authedCtx(), &pb.MarkAsReadRequest{NotificationIds: []string{nid.String()}})
	require.NoError(t, err)
}

func TestMarkAsRead_EmptyIDs(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.MarkAsRead(authedCtx(), &pb.MarkAsReadRequest{NotificationIds: []string{}})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestMarkAsRead_InvalidID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.MarkAsRead(authedCtx(), &pb.MarkAsReadRequest{NotificationIds: []string{"not-uuid"}})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── CreateNotification (internal) ──────────────────────────────────────────

func TestCreateNotification_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(testUserID, "budget_warning", "预算预警", "已用80%", pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.CreateNotification(context.Background(), testUserID, "budget_warning", "预算预警", "已用80%",
		map[string]interface{}{"budget_id": "xxx"})
	assert.NoError(t, err)
}

func TestCreateNotification_NilData(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectExec("INSERT INTO notifications").
		WithArgs(testUserID, "info", "title", "body", ([]byte)(nil)).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err = svc.CreateNotification(context.Background(), testUserID, "info", "title", "body", nil)
	assert.NoError(t, err)
}
