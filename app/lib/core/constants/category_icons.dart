import 'package:flutter/material.dart';

/// 内置分类图标库
/// key 格式: "food_breakfast", "transport_metro" 等
/// 与数据库 icon_key 字段一一对应
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> _icons = {
    // ── 餐饮 ──
    'food': Icons.restaurant,
    'food_breakfast': Icons.free_breakfast,
    'food_lunch': Icons.lunch_dining,
    'food_dinner': Icons.dinner_dining,
    'food_midnight': Icons.nightlight_round,
    'food_drink': Icons.local_cafe,
    'food_snack': Icons.apple,

    // ── 交通 ──
    'transport': Icons.directions_car,
    'transport_metro': Icons.subway,
    'transport_taxi': Icons.local_taxi,
    'transport_fuel': Icons.local_gas_station,
    'transport_parking': Icons.local_parking,

    // ── 购物 ──
    'shopping': Icons.shopping_bag,
    'shopping_digital': Icons.devices,
    'shopping_daily': Icons.shopping_cart,
    'shopping_beauty': Icons.face_retouching_natural,

    // ── 居住 ──
    'housing': Icons.home,
    'housing_rent': Icons.house,
    'housing_property': Icons.apartment,
    'housing_utility': Icons.lightbulb,
    'housing_cleaning': Icons.cleaning_services,

    // ── 娱乐 ──
    'entertainment': Icons.sports_esports,
    'entertainment_movie': Icons.movie,
    'entertainment_game': Icons.videogame_asset,
    'entertainment_sport': Icons.fitness_center,
    'entertainment_book': Icons.menu_book,

    // ── 医疗 ──
    'medical': Icons.local_hospital,
    'medical_clinic': Icons.medical_services,
    'medical_hospital': Icons.hotel,
    'medical_pharmacy': Icons.medication,
    'medical_health': Icons.self_improvement,

    // ── 教育 ──
    'education': Icons.school,
    'education_course': Icons.cast_for_education,
    'education_book': Icons.auto_stories,
    'education_tuition': Icons.account_balance,

    // ── 通讯 ──
    'communication': Icons.phone_android,
    'communication_phone': Icons.phone,
    'communication_broadband': Icons.wifi,
    'communication_subscription': Icons.subscriptions,

    // ── 人情 ──
    'gift': Icons.card_giftcard,
    'gift_red_packet': Icons.redeem,
    'gift_treat': Icons.local_bar,
    'gift_wedding': Icons.favorite,

    // ── 服饰 ──
    'clothing': Icons.checkroom,
    'clothing_clothes': Icons.dry_cleaning,
    'clothing_shoes': Icons.ice_skating,
    'clothing_accessory': Icons.watch,

    // ── 日用 ──
    'daily': Icons.category,
    'daily_cleaning': Icons.soap,
    'daily_personal': Icons.brush,

    // ── 旅行 ──
    'travel': Icons.flight,
    'travel_hotel': Icons.hotel,
    'travel_ticket': Icons.train,
    'travel_attraction': Icons.attractions,

    // ── 宠物 ──
    'pet': Icons.pets,
    'pet_food': Icons.set_meal,
    'pet_medical': Icons.healing,

    // ── 工资 ──
    'salary': Icons.payments,
    'salary_base': Icons.account_balance_wallet,
    'salary_performance': Icons.trending_up,
    'salary_overtime': Icons.more_time,

    // ── 奖金 ──
    'bonus': Icons.emoji_events,
    'bonus_annual': Icons.celebration,
    'bonus_project': Icons.military_tech,

    // ── 投资收益 ──
    'investment_income': Icons.show_chart,
    'investment_stock': Icons.candlestick_chart,
    'investment_fund': Icons.pie_chart,
    'investment_interest': Icons.savings,

    // ── 其他收入 ──
    'freelance': Icons.work,
    'red_packet': Icons.redeem,
    'reimbursement': Icons.receipt_long,
    'other': Icons.more_horiz,
  };

  /// 图标分组（用于图标选择器 Tab）
  static const Map<String, List<String>> kIconGroups = {
    '餐饮': ['food', 'food_breakfast', 'food_lunch', 'food_dinner', 'food_midnight', 'food_drink', 'food_snack'],
    '交通': ['transport', 'transport_metro', 'transport_taxi', 'transport_fuel', 'transport_parking'],
    '购物': ['shopping', 'shopping_digital', 'shopping_daily', 'shopping_beauty'],
    '居住': ['housing', 'housing_rent', 'housing_property', 'housing_utility', 'housing_cleaning'],
    '娱乐': ['entertainment', 'entertainment_movie', 'entertainment_game', 'entertainment_sport', 'entertainment_book'],
    '健康': ['medical', 'medical_clinic', 'medical_hospital', 'medical_pharmacy', 'medical_health'],
    '教育': ['education', 'education_course', 'education_book', 'education_tuition'],
    '生活': ['communication', 'communication_phone', 'communication_broadband', 'communication_subscription',
             'daily', 'daily_cleaning', 'daily_personal'],
    '社交': ['gift', 'gift_red_packet', 'gift_treat', 'gift_wedding',
             'clothing', 'clothing_clothes', 'clothing_shoes', 'clothing_accessory'],
    '出行': ['travel', 'travel_hotel', 'travel_ticket', 'travel_attraction',
             'pet', 'pet_food', 'pet_medical'],
    '收入': ['salary', 'salary_base', 'salary_performance', 'salary_overtime',
             'bonus', 'bonus_annual', 'bonus_project',
             'investment_income', 'investment_stock', 'investment_fund', 'investment_interest',
             'freelance', 'red_packet', 'reimbursement'],
    '通用': ['other'],
  };

  /// 图标分组中文名 → 颜色
  static const Map<String, Color> _groupColors = {
    '餐饮': Color(0xFFFF6B35),
    '交通': Color(0xFF4A90D9),
    '购物': Color(0xFFE91E63),
    '居住': Color(0xFF8BC34A),
    '娱乐': Color(0xFF9C27B0),
    '健康': Color(0xFFFF5252),
    '教育': Color(0xFF3F51B5),
    '生活': Color(0xFF00BCD4),
    '社交': Color(0xFFFF9800),
    '出行': Color(0xFF009688),
    '收入': Color(0xFF4CAF50),
    '通用': Color(0xFF607D8B),
  };

  /// icon_key → 分组名
  static final Map<String, String> _keyToGroup = () {
    final map = <String, String>{};
    for (final entry in kIconGroups.entries) {
      for (final key in entry.value) {
        map[key] = entry.key;
      }
    }
    return map;
  }();

  /// 图标中文标签
  static const Map<String, String> _labels = {
    'food': '餐饮',
    'food_breakfast': '早餐',
    'food_lunch': '午餐',
    'food_dinner': '晚餐',
    'food_midnight': '夜宵',
    'food_drink': '饮品',
    'food_snack': '零食',
    'transport': '交通',
    'transport_metro': '地铁',
    'transport_taxi': '打车',
    'transport_fuel': '加油',
    'transport_parking': '停车',
    'shopping': '购物',
    'shopping_digital': '数码',
    'shopping_daily': '百货',
    'shopping_beauty': '美妆',
    'housing': '居住',
    'housing_rent': '房租',
    'housing_property': '物业',
    'housing_utility': '水电',
    'housing_cleaning': '家政',
    'entertainment': '娱乐',
    'entertainment_movie': '电影',
    'entertainment_game': '游戏',
    'entertainment_sport': '运动',
    'entertainment_book': '书籍',
    'medical': '医疗',
    'medical_clinic': '门诊',
    'medical_hospital': '住院',
    'medical_pharmacy': '买药',
    'medical_health': '保健',
    'education': '教育',
    'education_course': '课程',
    'education_book': '书籍',
    'education_tuition': '学费',
    'communication': '通讯',
    'communication_phone': '话费',
    'communication_broadband': '宽带',
    'communication_subscription': '订阅',
    'gift': '人情',
    'gift_red_packet': '红包',
    'gift_treat': '请客',
    'gift_wedding': '份子',
    'clothing': '服饰',
    'clothing_clothes': '衣服',
    'clothing_shoes': '鞋包',
    'clothing_accessory': '配饰',
    'daily': '日用',
    'daily_cleaning': '清洁',
    'daily_personal': '护理',
    'travel': '旅行',
    'travel_hotel': '住宿',
    'travel_ticket': '车票',
    'travel_attraction': '景点',
    'pet': '宠物',
    'pet_food': '口粮',
    'pet_medical': '看病',
    'salary': '工资',
    'salary_base': '底薪',
    'salary_performance': '绩效',
    'salary_overtime': '加班',
    'bonus': '奖金',
    'bonus_annual': '年终',
    'bonus_project': '项目',
    'investment_income': '投资',
    'investment_stock': '股票',
    'investment_fund': '基金',
    'investment_interest': '利息',
    'freelance': '兼职',
    'red_packet': '红包',
    'reimbursement': '报销',
    'other': '其他',
  };

  /// 获取图标，找不到返回 Icons.category
  static IconData getIcon(String key) => _icons[key] ?? Icons.category;

  /// 获取图标颜色（基于分组）
  static Color getColor(String key) {
    final group = _keyToGroup[key];
    if (group != null) {
      return _groupColors[group] ?? const Color(0xFF607D8B);
    }
    return const Color(0xFF607D8B);
  }

  /// 获取中文标签
  static String getLabel(String key) => _labels[key] ?? key;

  /// 获取分组颜色
  static Color getGroupColor(String groupName) =>
      _groupColors[groupName] ?? const Color(0xFF607D8B);

  /// 所有图标 keys
  static List<String> get allKeys => _icons.keys.toList();
}
