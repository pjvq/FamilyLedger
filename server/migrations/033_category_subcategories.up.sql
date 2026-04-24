-- 033_category_subcategories.up.sql
-- Add subcategory support: parent_id, user_id, icon_key, deleted_at

ALTER TABLE categories
    ADD COLUMN parent_id UUID REFERENCES categories(id),
    ADD COLUMN user_id UUID REFERENCES users(id),
    ADD COLUMN icon_key VARCHAR(50) NOT NULL DEFAULT '',
    ADD COLUMN deleted_at TIMESTAMPTZ;

-- Backfill icon_key from existing emoji icon field
UPDATE categories SET icon_key = CASE name
    -- Expense
    WHEN '餐饮' THEN 'food'
    WHEN '交通' THEN 'transport'
    WHEN '购物' THEN 'shopping'
    WHEN '居住' THEN 'housing'
    WHEN '娱乐' THEN 'entertainment'
    WHEN '医疗' THEN 'medical'
    WHEN '教育' THEN 'education'
    WHEN '通讯' THEN 'communication'
    WHEN '人情' THEN 'gift'
    WHEN '服饰' THEN 'clothing'
    WHEN '日用' THEN 'daily'
    WHEN '旅行' THEN 'travel'
    WHEN '宠物' THEN 'pet'
    -- Income
    WHEN '工资' THEN 'salary'
    WHEN '奖金' THEN 'bonus'
    WHEN '投资收益' THEN 'investment_income'
    WHEN '兼职' THEN 'freelance'
    WHEN '红包' THEN 'red_packet'
    WHEN '报销' THEN 'reimbursement'
    ELSE 'other'
END
WHERE icon_key = '';

CREATE INDEX idx_categories_parent_id ON categories(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_categories_user_id ON categories(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_categories_deleted_at ON categories(deleted_at) WHERE deleted_at IS NULL;
