-- 004_seed_categories.up.sql
-- UUIDs are deterministic: UUIDv5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "{type}:{name}")
INSERT INTO categories (id, name, icon, type, is_preset, sort_order) VALUES
-- 支出分类
('95d6dc66-12c4-5f2b-bf9b-1d439a9c8100', '餐饮', '🍜', 'expense', true, 1),
('6f7a88e1-fb21-5409-b6b3-606787668c02', '交通', '🚗', 'expense', true, 2),
('3feb7580-9bad-5c6a-bf4f-db9e59eb3e64', '购物', '🛍️', 'expense', true, 3),
('f925409c-19b9-5461-8a3d-5dc88e50efeb', '居住', '🏠', 'expense', true, 4),
('805a7628-6497-5252-b4ab-a76361e5aa0a', '娱乐', '🎮', 'expense', true, 5),
('f0683ffe-fe9c-593f-8701-4ec1c296b32c', '医疗', '💊', 'expense', true, 6),
('b41989ae-e78a-59f2-9c02-4f904d8e6841', '教育', '📚', 'expense', true, 7),
('656b4d2c-887e-5757-a2ce-1feb0684fb7a', '通讯', '📱', 'expense', true, 8),
('7e0c4d7e-15e9-5cbf-a3c9-059d14a86383', '人情', '🎁', 'expense', true, 9),
('6d6ada2a-52b5-5fda-9ccf-af89a21a7682', '服饰', '👔', 'expense', true, 10),
('73f24f43-cc21-5cff-8c74-232f68301017', '日用', '🧹', 'expense', true, 11),
('c2f51a85-2379-5492-8d91-66bb30000e61', '旅行', '✈️', 'expense', true, 12),
('88d5185f-b4ae-5ee6-8031-7d1e702204dc', '宠物', '🐾', 'expense', true, 13),
('c3103fdd-7fe8-5df8-b40f-b88f2bb3e249', '其他', '📦', 'expense', true, 14),
-- 收入分类
('5c7b17d7-a3ec-59c0-b2ad-4a62ad32f2c3', '工资', '💵', 'income', true, 1),
('a163e39c-8eb4-5317-8ef9-7c433897b569', '奖金', '🏆', 'income', true, 2),
('0aacf353-c7a5-5ac1-8da6-5b8815ffcef7', '投资收益', '📈', 'income', true, 3),
('b723b10f-6791-5c4a-9403-b07fd88f7569', '兼职', '💼', 'income', true, 4),
('a7b6b004-de00-5025-8eaa-750c4c0ac6af', '红包', '🧧', 'income', true, 5),
('dd39543f-1fd5-58d7-9aa6-122b19cefc4a', '报销', '📋', 'income', true, 6),
('7f7b737f-5cea-550f-bf23-4d781b83a4be', '其他', '💫', 'income', true, 7);
