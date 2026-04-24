-- 034_seed_subcategories.down.sql
DELETE FROM categories WHERE parent_id IS NOT NULL AND is_preset = true;
