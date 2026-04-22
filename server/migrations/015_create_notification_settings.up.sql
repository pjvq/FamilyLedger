CREATE TABLE notification_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    budget_alert BOOLEAN NOT NULL DEFAULT true,
    budget_warning BOOLEAN NOT NULL DEFAULT true,
    daily_summary BOOLEAN NOT NULL DEFAULT false,
    loan_reminder BOOLEAN NOT NULL DEFAULT true,
    reminder_days_before INT NOT NULL DEFAULT 3,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
