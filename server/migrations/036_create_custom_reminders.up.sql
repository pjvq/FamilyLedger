CREATE TABLE custom_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    family_id UUID REFERENCES families(id),
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    remind_at TIMESTAMP NOT NULL,
    repeat_rule TEXT NOT NULL DEFAULT 'none',
    repeat_end_at TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_custom_reminders_user_id ON custom_reminders(user_id);
CREATE INDEX idx_custom_reminders_family_id ON custom_reminders(family_id) WHERE family_id IS NOT NULL;
CREATE INDEX idx_custom_reminders_remind_at ON custom_reminders(remind_at) WHERE is_active = true;
