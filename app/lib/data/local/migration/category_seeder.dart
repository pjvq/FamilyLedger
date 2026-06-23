import 'package:drift/drift.dart';

import '../database.dart';
import '../../../core/utils/category_uuid.dart';

/// Preset category seeding logic — extracted from AppDatabase.
///
/// Owns all seed data (parent + subcategory presets) and the logic
/// to populate an empty database after first auth.
///
/// Usage: `CategorySeeder(db).seedForOwner(userId)`
class CategorySeeder {
  final AppDatabase _db;

  const CategorySeeder(this._db);

  /// Seed preset categories if none exist yet.
  ///
  /// Runs check + insert atomically in a single transaction to prevent
  /// partial seeding on mid-execution crash (iOS background kill).
  Future<void> seedForOwner(String ownerID) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.categories)..limit(1)).get();
      if (existing.isNotEmpty) return;
      await _seedCategories(ownerID);
      await _seedSubcategories(ownerID);
    });
  }

  Future<void> _seedCategories(String ownerID) async {
    final presets = [
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '餐饮'),
        '餐饮',
        'food',
        'expense',
        true,
        1,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '交通'),
        '交通',
        'transport',
        'expense',
        true,
        2,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '购物'),
        '购物',
        'shopping',
        'expense',
        true,
        3,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '居住'),
        '居住',
        'housing',
        'expense',
        true,
        4,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '娱乐'),
        '娱乐',
        'entertainment',
        'expense',
        true,
        5,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '医疗'),
        '医疗',
        'medical',
        'expense',
        true,
        6,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '教育'),
        '教育',
        'education',
        'expense',
        true,
        7,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '通讯'),
        '通讯',
        'communication',
        'expense',
        true,
        8,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '人情'),
        '人情',
        'gift',
        'expense',
        true,
        9,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '服饰'),
        '服饰',
        'clothing',
        'expense',
        true,
        10,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '日用'),
        '日用',
        'daily',
        'expense',
        true,
        11,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '旅行'),
        '旅行',
        'travel',
        'expense',
        true,
        12,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '宠物'),
        '宠物',
        'pet',
        'expense',
        true,
        13,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'expense', '其他'),
        '其他',
        'other',
        'expense',
        true,
        14,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'income', '工资'),
        '工资',
        'salary',
        'income',
        true,
        1,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'income', '奖金'),
        '奖金',
        'bonus',
        'income',
        true,
        2,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'income', '投资收益'),
        '投资收益',
        'investment_income',
        'income',
        true,
        3,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'income', '兼职'),
        '兼职',
        'freelance',
        'income',
        true,
        4,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'income', '红包'),
        '红包',
        'red_packet',
        'income',
        true,
        5,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'income', '报销'),
        '报销',
        'reimbursement',
        'income',
        true,
        6,
      ),
      _cat(
        CategoryUUID.generate(ownerID, 'income', '其他'),
        '其他',
        'other',
        'income',
        true,
        7,
      ),
    ];
    await _db.batch(
      (b) => b.insertAllOnConflictUpdate(_db.categories, presets),
    );
  }

  CategoriesCompanion _cat(
    String id,
    String name,
    String iconKey,
    String type,
    bool isPreset,
    int sort,
  ) => CategoriesCompanion.insert(
    id: id,
    name: name,
    type: type,
    isPreset: Value(isPreset),
    sortOrder: Value(sort),
    iconKey: Value(iconKey),
  );

  CategoriesCompanion _subcat(
    String ownerID,
    String parentType,
    String parentName,
    String childName,
    String iconKey,
    int sort,
  ) {
    final parentId = CategoryUUID.generate(ownerID, parentType, parentName);
    final id = CategoryUUID.generate(
      ownerID,
      parentType,
      '$parentId:$childName',
    );
    return CategoriesCompanion.insert(
      id: id,
      name: childName,
      type: parentType,
      isPreset: const Value(true),
      sortOrder: Value(sort),
      parentId: Value(parentId),
      iconKey: Value(iconKey),
    );
  }

  Future<void> _seedSubcategories(String ownerID) async {
    final subs = [
      _subcat(ownerID, 'expense', '餐饮', '早餐', 'food_breakfast', 1),
      _subcat(ownerID, 'expense', '餐饮', '午餐', 'food_lunch', 2),
      _subcat(ownerID, 'expense', '餐饮', '晚餐', 'food_dinner', 3),
      _subcat(ownerID, 'expense', '餐饮', '夜宵', 'food_midnight', 4),
      _subcat(ownerID, 'expense', '餐饮', '饮品', 'food_drink', 5),
      _subcat(ownerID, 'expense', '餐饮', '水果零食', 'food_snack', 6),
      _subcat(ownerID, 'expense', '交通', '地铁公交', 'transport_metro', 1),
      _subcat(ownerID, 'expense', '交通', '打车', 'transport_taxi', 2),
      _subcat(ownerID, 'expense', '交通', '加油', 'transport_fuel', 3),
      _subcat(ownerID, 'expense', '交通', '停车', 'transport_parking', 4),
      _subcat(ownerID, 'expense', '购物', '电器数码', 'shopping_digital', 1),
      _subcat(ownerID, 'expense', '购物', '日用百货', 'shopping_daily', 2),
      _subcat(ownerID, 'expense', '购物', '美妆护肤', 'shopping_beauty', 3),
      _subcat(ownerID, 'expense', '居住', '房租', 'housing_rent', 1),
      _subcat(ownerID, 'expense', '居住', '物业', 'housing_property', 2),
      _subcat(ownerID, 'expense', '居住', '水电燃气', 'housing_utility', 3),
      _subcat(ownerID, 'expense', '居住', '家政服务', 'housing_cleaning', 4),
      _subcat(ownerID, 'expense', '娱乐', '电影演出', 'entertainment_movie', 1),
      _subcat(ownerID, 'expense', '娱乐', '游戏', 'entertainment_game', 2),
      _subcat(ownerID, 'expense', '娱乐', '运动健身', 'entertainment_sport', 3),
      _subcat(ownerID, 'expense', '娱乐', '书籍', 'entertainment_book', 4),
      _subcat(ownerID, 'expense', '医疗', '门诊', 'medical_clinic', 1),
      _subcat(ownerID, 'expense', '医疗', '住院', 'medical_hospital', 2),
      _subcat(ownerID, 'expense', '医疗', '买药', 'medical_pharmacy', 3),
      _subcat(ownerID, 'expense', '医疗', '保健', 'medical_health', 4),
      _subcat(ownerID, 'expense', '教育', '培训课程', 'education_course', 1),
      _subcat(ownerID, 'expense', '教育', '书籍资料', 'education_book', 2),
      _subcat(ownerID, 'expense', '教育', '学费', 'education_tuition', 3),
      _subcat(ownerID, 'expense', '通讯', '话费', 'communication_phone', 1),
      _subcat(ownerID, 'expense', '通讯', '宽带', 'communication_broadband', 2),
      _subcat(
        ownerID,
        'expense',
        '通讯',
        '会员订阅',
        'communication_subscription',
        3,
      ),
      _subcat(ownerID, 'expense', '人情', '红包礼金', 'gift_red_packet', 1),
      _subcat(ownerID, 'expense', '人情', '请客', 'gift_treat', 2),
      _subcat(ownerID, 'expense', '人情', '份子钱', 'gift_wedding', 3),
      _subcat(ownerID, 'expense', '服饰', '衣服', 'clothing_clothes', 1),
      _subcat(ownerID, 'expense', '服饰', '鞋包', 'clothing_shoes', 2),
      _subcat(ownerID, 'expense', '服饰', '配饰', 'clothing_accessory', 3),
      _subcat(ownerID, 'expense', '日用', '清洁用品', 'daily_cleaning', 1),
      _subcat(ownerID, 'expense', '日用', '个人护理', 'daily_personal', 2),
      _subcat(ownerID, 'expense', '旅行', '住宿', 'travel_hotel', 1),
      _subcat(ownerID, 'expense', '旅行', '机票火车', 'travel_ticket', 2),
      _subcat(ownerID, 'expense', '旅行', '门票景点', 'travel_attraction', 3),
      _subcat(ownerID, 'expense', '宠物', '口粮用品', 'pet_food', 1),
      _subcat(ownerID, 'expense', '宠物', '宠物医疗', 'pet_medical', 2),
      _subcat(ownerID, 'income', '工资', '基本工资', 'salary_base', 1),
      _subcat(ownerID, 'income', '工资', '绩效', 'salary_performance', 2),
      _subcat(ownerID, 'income', '工资', '加班费', 'salary_overtime', 3),
      _subcat(ownerID, 'income', '奖金', '年终奖', 'bonus_annual', 1),
      _subcat(ownerID, 'income', '奖金', '项目奖', 'bonus_project', 2),
      _subcat(ownerID, 'income', '投资收益', '股票', 'investment_stock', 1),
      _subcat(ownerID, 'income', '投资收益', '基金', 'investment_fund', 2),
      _subcat(ownerID, 'income', '投资收益', '利息', 'investment_interest', 3),
    ];
    await _db.batch((b) => b.insertAllOnConflictUpdate(_db.categories, subs));
  }
}
