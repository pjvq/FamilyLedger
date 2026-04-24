-- 032: Replace auto-generated category UUIDs with deterministic UUID v5
-- Formula: UUIDv5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "{type}:{name}")
-- This ensures client and server use identical category IDs.

-- Drop FK constraints
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_category_id_fkey;
ALTER TABLE category_budgets DROP CONSTRAINT IF EXISTS category_budgets_category_id_fkey;

-- Build old→new mapping and update all references
DO $$
DECLARE
  r RECORD;
  new_uuid UUID;
  mapping TEXT[][] := ARRAY[
    -- [type, name, new_uuid]
    ['expense', '餐饮', '95d6dc66-12c4-5f2b-bf9b-1d439a9c8100'],
    ['expense', '交通', '6f7a88e1-fb21-5409-b6b3-606787668c02'],
    ['expense', '购物', '3feb7580-9bad-5c6a-bf4f-db9e59eb3e64'],
    ['expense', '居住', 'f925409c-19b9-5461-8a3d-5dc88e50efeb'],
    ['expense', '娱乐', '805a7628-6497-5252-b4ab-a76361e5aa0a'],
    ['expense', '医疗', 'f0683ffe-fe9c-593f-8701-4ec1c296b32c'],
    ['expense', '教育', 'b41989ae-e78a-59f2-9c02-4f904d8e6841'],
    ['expense', '通讯', '656b4d2c-887e-5757-a2ce-1feb0684fb7a'],
    ['expense', '人情', '7e0c4d7e-15e9-5cbf-a3c9-059d14a86383'],
    ['expense', '服饰', '6d6ada2a-52b5-5fda-9ccf-af89a21a7682'],
    ['expense', '日用', '73f24f43-cc21-5cff-8c74-232f68301017'],
    ['expense', '旅行', 'c2f51a85-2379-5492-8d91-66bb30000e61'],
    ['expense', '宠物', '88d5185f-b4ae-5ee6-8031-7d1e702204dc'],
    ['expense', '其他', 'c3103fdd-7fe8-5df8-b40f-b88f2bb3e249'],
    ['income', '工资', '5c7b17d7-a3ec-59c0-b2ad-4a62ad32f2c3'],
    ['income', '奖金', 'a163e39c-8eb4-5317-8ef9-7c433897b569'],
    ['income', '投资收益', '0aacf353-c7a5-5ac1-8da6-5b8815ffcef7'],
    ['income', '兼职', 'b723b10f-6791-5c4a-9403-b07fd88f7569'],
    ['income', '红包', 'a7b6b004-de00-5025-8eaa-750c4c0ac6af'],
    ['income', '报销', 'dd39543f-1fd5-58d7-9aa6-122b19cefc4a'],
    ['income', '其他', '7f7b737f-5cea-550f-bf23-4d781b83a4be']
  ];
  old_uuid UUID;
BEGIN
  FOR i IN 1..array_length(mapping, 1) LOOP
    SELECT id INTO old_uuid FROM categories
      WHERE type = mapping[i][1]::category_type AND name = mapping[i][2] AND is_preset = true;
    new_uuid := mapping[i][3]::uuid;

    IF old_uuid IS NOT NULL AND old_uuid != new_uuid THEN
      -- Update references first
      UPDATE transactions SET category_id = new_uuid WHERE category_id = old_uuid;
      UPDATE category_budgets SET category_id = new_uuid WHERE category_id = old_uuid;
      -- Then update the category itself
      UPDATE categories SET id = new_uuid WHERE id = old_uuid;
    END IF;
  END LOOP;
END $$;

-- Re-add FK constraints
ALTER TABLE transactions ADD CONSTRAINT transactions_category_id_fkey
  FOREIGN KEY (category_id) REFERENCES categories(id);
ALTER TABLE category_budgets ADD CONSTRAINT category_budgets_category_id_fkey
  FOREIGN KEY (category_id) REFERENCES categories(id);
