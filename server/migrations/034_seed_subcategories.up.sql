-- 034_seed_subcategories.up.sql
-- Seed preset subcategories with deterministic UUID v5
-- Formula: UUIDv5("6ba7b810-...", "{type}:{parent}/{child}")

INSERT INTO categories (id, name, icon, type, is_preset, sort_order, parent_id, icon_key) VALUES
-- 餐饮子分类 (parent: 95d6dc66-12c4-5f2b-bf9b-1d439a9c8100)
('0d925f20-7ec9-5ad2-8a83-1af6e8494784', '早餐', '🌅', 'expense', true, 1, '95d6dc66-12c4-5f2b-bf9b-1d439a9c8100', 'food_breakfast'),
('50654fd8-6cac-5a6c-b1a8-a18fab36a8ce', '午餐', '🍱', 'expense', true, 2, '95d6dc66-12c4-5f2b-bf9b-1d439a9c8100', 'food_lunch'),
('e2a9b492-b275-5e4d-a8f8-0c86234d65f1', '晚餐', '🍽️', 'expense', true, 3, '95d6dc66-12c4-5f2b-bf9b-1d439a9c8100', 'food_dinner'),
('ad32d6d8-6db6-5d55-9628-7c8d41ed761b', '夜宵', '🌙', 'expense', true, 4, '95d6dc66-12c4-5f2b-bf9b-1d439a9c8100', 'food_midnight'),
('c9e09182-b775-5558-b479-58d824dd1447', '饮品', '🧋', 'expense', true, 5, '95d6dc66-12c4-5f2b-bf9b-1d439a9c8100', 'food_drink'),
('25118775-fb1e-5d77-9cdb-053e7e2e5fa0', '水果零食', '🍎', 'expense', true, 6, '95d6dc66-12c4-5f2b-bf9b-1d439a9c8100', 'food_snack'),

-- 交通子分类 (parent: 6f7a88e1-fb21-5409-b6b3-606787668c02)
('cac58310-ac7e-5b49-87ef-b51edb2023b0', '地铁公交', '🚇', 'expense', true, 1, '6f7a88e1-fb21-5409-b6b3-606787668c02', 'transport_metro'),
('2375caee-1303-5d1c-9f58-876eca67ce03', '打车', '🚕', 'expense', true, 2, '6f7a88e1-fb21-5409-b6b3-606787668c02', 'transport_taxi'),
('e6635b2b-b575-5753-a16a-d4168fdcb19b', '加油', '⛽', 'expense', true, 3, '6f7a88e1-fb21-5409-b6b3-606787668c02', 'transport_fuel'),
('5ee69f83-8c27-5854-a362-1ee69020960c', '停车', '🅿️', 'expense', true, 4, '6f7a88e1-fb21-5409-b6b3-606787668c02', 'transport_parking'),

-- 购物子分类 (parent: 3feb7580-9bad-5c6a-bf4f-db9e59eb3e64)
('a1367757-61e3-55cd-b68d-a20e3bbe0d2d', '电器数码', '💻', 'expense', true, 1, '3feb7580-9bad-5c6a-bf4f-db9e59eb3e64', 'shopping_digital'),
('b7eed6b4-c146-5b33-bb5b-6c828106c2cf', '日用百货', '🛒', 'expense', true, 2, '3feb7580-9bad-5c6a-bf4f-db9e59eb3e64', 'shopping_daily'),
('146c36af-4eaf-55eb-8a46-ec707c76c576', '美妆护肤', '💄', 'expense', true, 3, '3feb7580-9bad-5c6a-bf4f-db9e59eb3e64', 'shopping_beauty'),

-- 居住子分类 (parent: f925409c-19b9-5461-8a3d-5dc88e50efeb)
('3a61853a-5846-56ee-9dae-c58bd9a5bdcb', '房租', '🏘️', 'expense', true, 1, 'f925409c-19b9-5461-8a3d-5dc88e50efeb', 'housing_rent'),
('f19b65e4-a078-5198-8eb7-900d819c6268', '物业', '🏢', 'expense', true, 2, 'f925409c-19b9-5461-8a3d-5dc88e50efeb', 'housing_property'),
('6c9ff8e4-805d-5cf4-90ee-cad60d826a7f', '水电燃气', '💡', 'expense', true, 3, 'f925409c-19b9-5461-8a3d-5dc88e50efeb', 'housing_utility'),
('3010f07c-d2a1-5ef2-b01f-c9e476a47147', '家政服务', '🧹', 'expense', true, 4, 'f925409c-19b9-5461-8a3d-5dc88e50efeb', 'housing_cleaning'),

-- 娱乐子分类 (parent: 805a7628-6497-5252-b4ab-a76361e5aa0a)
('48f098d5-7768-5306-b433-7c8ecadabdbc', '电影演出', '🎬', 'expense', true, 1, '805a7628-6497-5252-b4ab-a76361e5aa0a', 'entertainment_movie'),
('3ba0058a-76ce-59fe-b481-98576bf24270', '游戏', '🎮', 'expense', true, 2, '805a7628-6497-5252-b4ab-a76361e5aa0a', 'entertainment_game'),
('23646a6c-976b-53ab-a4fb-9d7817aa86f5', '运动健身', '🏋️', 'expense', true, 3, '805a7628-6497-5252-b4ab-a76361e5aa0a', 'entertainment_sport'),
('7bd5a360-9e1d-589c-90a8-7e05619792df', '书籍', '📖', 'expense', true, 4, '805a7628-6497-5252-b4ab-a76361e5aa0a', 'entertainment_book'),

-- 医疗子分类 (parent: f0683ffe-fe9c-593f-8701-4ec1c296b32c)
('b53ceaf3-f9a0-53e7-8b12-0ce58a24de88', '门诊', '🏥', 'expense', true, 1, 'f0683ffe-fe9c-593f-8701-4ec1c296b32c', 'medical_clinic'),
('4eebee88-a921-5c71-9e10-540d5df5d000', '住院', '🛏️', 'expense', true, 2, 'f0683ffe-fe9c-593f-8701-4ec1c296b32c', 'medical_hospital'),
('7fd4033a-0e44-52d8-8272-b6620d3f40d8', '买药', '💊', 'expense', true, 3, 'f0683ffe-fe9c-593f-8701-4ec1c296b32c', 'medical_pharmacy'),
('06412463-527c-580a-a705-5ac154b4e73b', '保健', '🧘', 'expense', true, 4, 'f0683ffe-fe9c-593f-8701-4ec1c296b32c', 'medical_health'),

-- 教育子分类 (parent: b41989ae-e78a-59f2-9c02-4f904d8e6841)
('36c84b57-b38f-5cbc-91dc-487e01a8fc4b', '培训课程', '🎓', 'expense', true, 1, 'b41989ae-e78a-59f2-9c02-4f904d8e6841', 'education_course'),
('b7af3604-aa4f-5646-a9c0-32d564c4638d', '书籍资料', '📚', 'expense', true, 2, 'b41989ae-e78a-59f2-9c02-4f904d8e6841', 'education_book'),
('cb4dc931-e6f8-5ed2-b5fe-6fff338f4a3a', '学费', '🏫', 'expense', true, 3, 'b41989ae-e78a-59f2-9c02-4f904d8e6841', 'education_tuition'),

-- 通讯子分类 (parent: 656b4d2c-887e-5757-a2ce-1feb0684fb7a)
('aeec8da2-b1d3-5d70-9624-9330295b9e1d', '话费', '📞', 'expense', true, 1, '656b4d2c-887e-5757-a2ce-1feb0684fb7a', 'communication_phone'),
('77c00375-652d-51a1-9313-d06e96fecec0', '宽带', '🌐', 'expense', true, 2, '656b4d2c-887e-5757-a2ce-1feb0684fb7a', 'communication_broadband'),
('f1565885-2092-5d80-ac21-1bd2f4ae465f', '会员订阅', '📺', 'expense', true, 3, '656b4d2c-887e-5757-a2ce-1feb0684fb7a', 'communication_subscription'),

-- 人情子分类 (parent: 7e0c4d7e-15e9-5cbf-a3c9-059d14a86383)
('cbbf0009-709b-5770-b42a-1fa8640c6a15', '红包礼金', '🧧', 'expense', true, 1, '7e0c4d7e-15e9-5cbf-a3c9-059d14a86383', 'gift_red_packet'),
('4f34fa48-7a26-56f5-9b70-46b44e163b28', '请客', '🍻', 'expense', true, 2, '7e0c4d7e-15e9-5cbf-a3c9-059d14a86383', 'gift_treat'),
('02ff929a-a3c3-5478-ab03-8cd07dd835cc', '份子钱', '💒', 'expense', true, 3, '7e0c4d7e-15e9-5cbf-a3c9-059d14a86383', 'gift_wedding'),

-- 服饰子分类 (parent: 6d6ada2a-52b5-5fda-9ccf-af89a21a7682)
('3efabd8c-7708-564b-9109-623c0c0f0d9e', '衣服', '👗', 'expense', true, 1, '6d6ada2a-52b5-5fda-9ccf-af89a21a7682', 'clothing_clothes'),
('3c0ec457-f53b-5dc6-b6af-0b49b76b41ed', '鞋包', '👟', 'expense', true, 2, '6d6ada2a-52b5-5fda-9ccf-af89a21a7682', 'clothing_shoes'),
('009834db-7eee-5fde-b5c8-a08925cd2d00', '配饰', '💍', 'expense', true, 3, '6d6ada2a-52b5-5fda-9ccf-af89a21a7682', 'clothing_accessory'),

-- 日用子分类 (parent: 73f24f43-cc21-5cff-8c74-232f68301017)
('e004827c-3d9e-5513-bfe6-8e40c1ed5cc7', '清洁用品', '🧴', 'expense', true, 1, '73f24f43-cc21-5cff-8c74-232f68301017', 'daily_cleaning'),
('47942a4a-d1ea-59cd-a4b3-b910e54a0f97', '个人护理', '🪥', 'expense', true, 2, '73f24f43-cc21-5cff-8c74-232f68301017', 'daily_personal'),

-- 旅行子分类 (parent: c2f51a85-2379-5492-8d91-66bb30000e61)
('ca14a119-648e-5659-805d-41e90498f10b', '住宿', '🏨', 'expense', true, 1, 'c2f51a85-2379-5492-8d91-66bb30000e61', 'travel_hotel'),
('270bba43-2369-5ac9-b388-ed1a7d6a8244', '机票火车', '🚄', 'expense', true, 2, 'c2f51a85-2379-5492-8d91-66bb30000e61', 'travel_ticket'),
('9e56d04d-c58e-5151-9458-3eb6f49b97e2', '门票景点', '🎡', 'expense', true, 3, 'c2f51a85-2379-5492-8d91-66bb30000e61', 'travel_attraction'),

-- 宠物子分类 (parent: 88d5185f-b4ae-5ee6-8031-7d1e702204dc)
('66eb9f0e-fdb3-54ee-bbba-fa0c68bce44a', '口粮用品', '🦴', 'expense', true, 1, '88d5185f-b4ae-5ee6-8031-7d1e702204dc', 'pet_food'),
('db059a9e-f2e3-5659-9b6b-3b7790213d5d', '宠物医疗', '🩺', 'expense', true, 2, '88d5185f-b4ae-5ee6-8031-7d1e702204dc', 'pet_medical'),

-- 工资子分类 (parent: 5c7b17d7-a3ec-59c0-b2ad-4a62ad32f2c3)
('afe99d80-bb26-5e62-ac45-2bfc457c1b65', '基本工资', '💰', 'income', true, 1, '5c7b17d7-a3ec-59c0-b2ad-4a62ad32f2c3', 'salary_base'),
('81bcea17-19cd-5b8b-8c69-f4856bbcd4a5', '绩效', '📊', 'income', true, 2, '5c7b17d7-a3ec-59c0-b2ad-4a62ad32f2c3', 'salary_performance'),
('1b3c9805-67e4-52f9-a80a-b7d0ffc25513', '加班费', '⏰', 'income', true, 3, '5c7b17d7-a3ec-59c0-b2ad-4a62ad32f2c3', 'salary_overtime'),

-- 奖金子分类 (parent: a163e39c-8eb4-5317-8ef9-7c433897b569)
('e91548c9-55bd-5221-acb4-3ed194db019d', '年终奖', '🎊', 'income', true, 1, 'a163e39c-8eb4-5317-8ef9-7c433897b569', 'bonus_annual'),
('a8e160d2-9465-5fae-82d0-c839c0a7a6ff', '项目奖', '🏅', 'income', true, 2, 'a163e39c-8eb4-5317-8ef9-7c433897b569', 'bonus_project'),

-- 投资收益子分类 (parent: 0aacf353-c7a5-5ac1-8da6-5b8815ffcef7)
('e962c923-aad1-508f-b77a-72657bca8862', '股票', '📈', 'income', true, 1, '0aacf353-c7a5-5ac1-8da6-5b8815ffcef7', 'investment_stock'),
('30f0d260-7d64-5ab0-aac4-da323eecab76', '基金', '📉', 'income', true, 2, '0aacf353-c7a5-5ac1-8da6-5b8815ffcef7', 'investment_fund'),
('0cd13664-536f-5ec0-992e-3fafa270a438', '利息', '🏦', 'income', true, 3, '0aacf353-c7a5-5ac1-8da6-5b8815ffcef7', 'investment_interest');
