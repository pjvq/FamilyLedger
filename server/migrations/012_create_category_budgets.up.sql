CREATE TABLE category_budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    budget_id UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id),
    amount BIGINT NOT NULL,
    UNIQUE(budget_id, category_id)
);
