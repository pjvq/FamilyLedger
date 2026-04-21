-- 004_seed_categories.up.sql
INSERT INTO categories (name, icon, type, is_preset, sort_order) VALUES
-- 支出分类
('餐饮', '🍜', 'expense', true, 1),
('交通', '🚗', 'expense', true, 2),
('购物', '🛍️', 'expense', true, 3),
('居住', '🏠', 'expense', true, 4),
('娱乐', '🎮', 'expense', true, 5),
('医疗', '💊', 'expense', true, 6),
('教育', '📚', 'expense', true, 7),
('通讯', '📱', 'expense', true, 8),
('人情', '🎁', 'expense', true, 9),
('服饰', '👔', 'expense', true, 10),
('日用', '🧹', 'expense', true, 11),
('旅行', '✈️', 'expense', true, 12),
('宠物', '🐾', 'expense', true, 13),
('其他', '📦', 'expense', true, 14),
-- 收入分类
('工资', '💵', 'income', true, 1),
('奖金', '🏆', 'income', true, 2),
('投资收益', '📈', 'income', true, 3),
('兼职', '💼', 'income', true, 4),
('红包', '🧧', 'income', true, 5),
('报销', '📋', 'income', true, 6),
('其他', '💫', 'income', true, 7);
