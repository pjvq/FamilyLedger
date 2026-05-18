/// Category icon name → iconKey mappings.
///
/// Used by migration backfill and category seeding.
/// Extracted to avoid polluting AppDatabase with 100+ static map entries.
library;

/// Full mapping (subcategories included) — used in `_backfillEmptyIconKeys`.
const categoryIconMap = <String, String>{
  '餐饮': 'food', '交通': 'transport', '购物': 'shopping',
  '居住': 'housing', '娱乐': 'entertainment', '医疗': 'medical',
  '教育': 'education', '通讯': 'communication', '人情': 'gift',
  '服饰': 'clothing', '日用': 'daily', '旅行': 'travel',
  '宠物': 'pet', '工资': 'salary', '奖金': 'bonus',
  '投资收益': 'investment_income', '兼职': 'freelance',
  '红包': 'red_packet', '报销': 'reimbursement', '其他': 'other',
  '早餐': 'food_breakfast', '午餐': 'food_lunch', '晚餐': 'food_dinner',
  '夜宵': 'food_midnight', '饮品': 'food_drink', '零食': 'food_snack',
  '外卖': 'food_takeout', '咖啡': 'food_drink', '快餐': 'food_fastfood',
  '地铁': 'transport_metro', '打车': 'transport_taxi', '加油': 'transport_fuel',
  '停车': 'transport_parking', '公交': 'transport_bus',
  '数码': 'shopping_digital', '美妆': 'shopping_beauty', '网购': 'shopping_online',
  '超市': 'shopping_daily', '百货': 'shopping_daily',
  '房租': 'housing_rent', '物业': 'housing_property',
  '水电': 'housing_utility', '水费': 'housing_water', '电费': 'housing_utility',
  '燃气': 'housing_fire', '家政': 'housing_cleaning',
  '电影': 'entertainment_movie', '游戏': 'entertainment_game',
  '运动': 'entertainment_sport', '健身': 'entertainment_sport',
  '音乐': 'entertainment_music', '书籍': 'entertainment_book',
  '看病': 'medical_clinic', '买药': 'medical_pharmacy',
  '牙科': 'medical_dental',
  '学费': 'education_tuition', '课程': 'education_course',
  '话费': 'communication_phone', '宽带': 'communication_broadband',
  '订阅': 'communication_subscription',
  '请客': 'gift_treat', '份子': 'gift_wedding',
  '生日': 'gift_birthday', '聚会': 'gift_party',
  '衣服': 'clothing_clothes', '鞋包': 'clothing_shoes', '配饰': 'clothing_accessory',
  '清洁': 'daily_cleaning', '护理': 'daily_personal', '快递': 'daily_package',
  '住宿': 'travel_hotel', '景点': 'travel_attraction',
  '酒店': 'travel_hotel', '机票': 'transport_flight', '车票': 'travel_ticket',
  '底薪': 'salary_base', '绩效': 'salary_performance',
  '加班': 'salary_overtime', '提成': 'salary_commission',
  '年终': 'bonus_annual', '股票': 'investment_stock',
  '基金': 'investment_fund', '利息': 'investment_interest',
  '分红': 'investment_dividend',
  '结婚': 'gift_wedding', '婚礼': 'gift_wedding', '订婚': 'gift_wedding',
  '水果': 'food_snack', '饮料': 'food_drink',
  '出租': 'transport_taxi', '出租车': 'transport_taxi',
  '日常': 'daily', '生活': 'daily',
};

/// Parent-level only mapping — derived from `categoryIconMap`.
/// Used in `_backfillParentIconKeys`.
final Map<String, String> parentCategoryIconMap = Map.unmodifiable({
  for (final name in const [
    '餐饮', '交通', '购物', '居住', '娱乐', '医疗', '教育', '通讯',
    '人情', '服饰', '日用', '旅行', '宠物', '工资', '奖金',
    '投资收益', '兼职', '红包', '报销', '其他',
  ])
    name: categoryIconMap[name]!,
});

/// Entries sorted by key length descending — longest-match-first
/// for fuzzy `contains()` matching in `_backfillEmptyIconKeys`.
///
/// Example: "日常清洁" matches "清洁" (len=2, daily_cleaning)
///          before "日常" (len=2, daily) since "清洁" appears first
///          when same-length entries are sorted by insertion order.
final List<MapEntry<String, String>> categoryIconEntriesByLength =
    List.unmodifiable(
      categoryIconMap.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length)),
    );
