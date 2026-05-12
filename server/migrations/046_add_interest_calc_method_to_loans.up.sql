-- Add interest_calc_method column to loans table
-- Values: 'monthly' (default), 'daily_act_365', 'daily_act_360'
ALTER TABLE loans ADD COLUMN IF NOT EXISTS interest_calc_method VARCHAR(20) NOT NULL DEFAULT 'monthly';
