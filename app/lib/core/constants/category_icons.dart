import 'package:flutter/material.dart';

/// 内置分类图标库
/// key 格式: "food_breakfast", "transport_metro" 等
/// 与数据库 icon_key 字段一一对应
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> _icons = {
    // ── 餐饮 (18) ──
    'food': Icons.restaurant,
    'food_breakfast': Icons.free_breakfast,
    'food_lunch': Icons.lunch_dining,
    'food_dinner': Icons.dinner_dining,
    'food_midnight': Icons.nightlight_round,
    'food_drink': Icons.local_cafe,
    'food_snack': Icons.apple,
    'food_fastfood': Icons.fastfood,
    'food_noodle': Icons.ramen_dining,
    'food_cake': Icons.cake,
    'food_icecream': Icons.icecream,
    'food_wine': Icons.wine_bar,
    'food_beer': Icons.sports_bar,
    'food_tea': Icons.emoji_food_beverage,
    'food_takeout': Icons.takeout_dining,
    'food_kitchen': Icons.kitchen,
    'food_brunch': Icons.brunch_dining,
    'food_bakery': Icons.bakery_dining,

    // ── 交通 (15) ──
    'transport': Icons.directions_car,
    'transport_metro': Icons.subway,
    'transport_taxi': Icons.local_taxi,
    'transport_fuel': Icons.local_gas_station,
    'transport_parking': Icons.local_parking,
    'transport_bus': Icons.directions_bus,
    'transport_bike': Icons.pedal_bike,
    'transport_train': Icons.train,
    'transport_flight': Icons.flight,
    'transport_ship': Icons.directions_boat,
    'transport_ev': Icons.ev_station,
    'transport_motorcycle': Icons.two_wheeler,
    'transport_walk': Icons.directions_walk,
    'transport_toll': Icons.toll,
    'transport_carwash': Icons.local_car_wash,

    // ── 购物 (15) ──
    'shopping': Icons.shopping_bag,
    'shopping_digital': Icons.devices,
    'shopping_daily': Icons.shopping_cart,
    'shopping_beauty': Icons.face_retouching_natural,
    'shopping_phone': Icons.smartphone,
    'shopping_laptop': Icons.laptop_mac,
    'shopping_headphone': Icons.headphones,
    'shopping_camera': Icons.camera_alt,
    'shopping_tv': Icons.tv,
    'shopping_watch': Icons.watch,
    'shopping_furniture': Icons.chair,
    'shopping_toy': Icons.toys,
    'shopping_flower': Icons.local_florist,
    'shopping_mall': Icons.local_mall,
    'shopping_online': Icons.add_shopping_cart,

    // ── 居住 (15) ──
    'housing': Icons.home,
    'housing_rent': Icons.house,
    'housing_property': Icons.apartment,
    'housing_utility': Icons.lightbulb,
    'housing_cleaning': Icons.cleaning_services,
    'housing_water': Icons.water_drop,
    'housing_fire': Icons.local_fire_department,
    'housing_repair': Icons.build,
    'housing_furniture': Icons.weekend,
    'housing_garden': Icons.yard,
    'housing_key': Icons.vpn_key,
    'housing_ac': Icons.ac_unit,
    'housing_laundry': Icons.local_laundry_service,
    'housing_bed': Icons.bed,
    'housing_kitchen': Icons.countertops,

    // ── 娱乐 (18) ──
    'entertainment': Icons.sports_esports,
    'entertainment_movie': Icons.movie,
    'entertainment_game': Icons.videogame_asset,
    'entertainment_sport': Icons.fitness_center,
    'entertainment_book': Icons.menu_book,
    'entertainment_music': Icons.music_note,
    'entertainment_karaoke': Icons.mic,
    'entertainment_photo': Icons.photo_camera,
    'entertainment_art': Icons.palette,
    'entertainment_dance': Icons.nightlife,
    'entertainment_swim': Icons.pool,
    'entertainment_ski': Icons.downhill_skiing,
    'entertainment_golf': Icons.golf_course,
    'entertainment_basketball': Icons.sports_basketball,
    'entertainment_soccer': Icons.sports_soccer,
    'entertainment_tennis': Icons.sports_tennis,
    'entertainment_bowling': Icons.sports_cricket,
    'entertainment_theater': Icons.theater_comedy,

    // ── 医疗 (15) ──
    'medical': Icons.local_hospital,
    'medical_clinic': Icons.medical_services,
    'medical_hospital': Icons.hotel,
    'medical_pharmacy': Icons.medication,
    'medical_health': Icons.self_improvement,
    'medical_dental': Icons.sentiment_very_satisfied,
    'medical_eye': Icons.visibility,
    'medical_heart': Icons.monitor_heart,
    'medical_vaccine': Icons.vaccines,
    'medical_emergency': Icons.emergency,
    'medical_insurance': Icons.health_and_safety,
    'medical_yoga': Icons.spa,
    'medical_run': Icons.directions_run,
    'medical_nutrition': Icons.restaurant_menu,
    'medical_psychology': Icons.psychology,

    // ── 教育 (15) ──
    'education': Icons.school,
    'education_course': Icons.cast_for_education,
    'education_book': Icons.auto_stories,
    'education_tuition': Icons.account_balance,
    'education_exam': Icons.quiz,
    'education_lab': Icons.science,
    'education_math': Icons.calculate,
    'education_language': Icons.translate,
    'education_art': Icons.draw,
    'education_music': Icons.piano,
    'education_laptop': Icons.laptop_chromebook,
    'education_library': Icons.local_library,
    'education_graduation': Icons.workspace_premium,
    'education_pen': Icons.edit,
    'education_backpack': Icons.backpack,

    // ── 通讯 (12) ──
    'communication': Icons.phone_android,
    'communication_phone': Icons.phone,
    'communication_broadband': Icons.wifi,
    'communication_subscription': Icons.subscriptions,
    'communication_email': Icons.email,
    'communication_chat': Icons.chat,
    'communication_cloud': Icons.cloud,
    'communication_vpn': Icons.vpn_lock,
    'communication_sim': Icons.sim_card,
    'communication_5g': Icons.five_g,
    'communication_tv': Icons.connected_tv,
    'communication_app': Icons.apps,

    // ── 人情 (12) ──
    'gift': Icons.card_giftcard,
    'gift_red_packet': Icons.redeem,
    'gift_treat': Icons.local_bar,
    'gift_wedding': Icons.favorite,
    'gift_birthday': Icons.cake,
    'gift_baby': Icons.child_care,
    'gift_funeral': Icons.local_florist,
    'gift_party': Icons.celebration,
    'gift_volunteer': Icons.volunteer_activism,
    'gift_handshake': Icons.handshake,
    'gift_group': Icons.groups,
    'gift_couple': Icons.people,

    // ── 服饰 (12) ──
    'clothing': Icons.checkroom,
    'clothing_clothes': Icons.dry_cleaning,
    'clothing_shoes': Icons.ice_skating,
    'clothing_accessory': Icons.watch,
    'clothing_hat': Icons.face,
    'clothing_glasses': Icons.remove_red_eye,
    'clothing_jewelry': Icons.diamond,
    'clothing_bag': Icons.luggage,
    'clothing_iron': Icons.iron,
    'clothing_laundry': Icons.local_laundry_service,
    'clothing_tailor': Icons.content_cut,
    'clothing_umbrella': Icons.umbrella,

    // ── 日用 (12) ──
    'daily': Icons.category,
    'daily_cleaning': Icons.soap,
    'daily_personal': Icons.brush,
    'daily_tissue': Icons.inventory_2,
    'daily_battery': Icons.battery_charging_full,
    'daily_tool': Icons.hardware,
    'daily_print': Icons.print,
    'daily_package': Icons.inventory,
    'daily_recycle': Icons.recycling,
    'daily_bulb': Icons.emoji_objects,
    'daily_scissors': Icons.content_cut,
    'daily_tape': Icons.straighten,

    // ── 旅行 (15) ──
    'travel': Icons.flight,
    'travel_hotel': Icons.hotel,
    'travel_ticket': Icons.train,
    'travel_attraction': Icons.attractions,
    'travel_beach': Icons.beach_access,
    'travel_mountain': Icons.terrain,
    'travel_camping': Icons.cabin,
    'travel_luggage': Icons.luggage,
    'travel_passport': Icons.badge,
    'travel_map': Icons.map,
    'travel_compass': Icons.explore,
    'travel_photo': Icons.photo_library,
    'travel_souvenir': Icons.shopping_bag,
    'travel_food': Icons.tapas,
    'travel_cruise': Icons.sailing,

    // ── 宠物 (12) ──
    'pet': Icons.pets,
    'pet_food': Icons.set_meal,
    'pet_medical': Icons.healing,
    'pet_groom': Icons.content_cut,
    'pet_toy': Icons.smart_toy,
    'pet_walk': Icons.directions_walk,
    'pet_cage': Icons.house,
    'pet_fish': Icons.water,
    'pet_bird': Icons.flutter_dash,
    'pet_bug': Icons.bug_report,
    'pet_paw': Icons.cruelty_free,
    'pet_nature': Icons.park,

    // ── 工资 (10) ──
    'salary': Icons.payments,
    'salary_base': Icons.account_balance_wallet,
    'salary_performance': Icons.trending_up,
    'salary_overtime': Icons.more_time,
    'salary_commission': Icons.price_check,
    'salary_subsidy': Icons.attach_money,
    'salary_pension': Icons.elderly,
    'salary_stipend': Icons.paid,
    'salary_tip': Icons.monetization_on,
    'salary_contract': Icons.description,

    // ── 奖金 (8) ──
    'bonus': Icons.emoji_events,
    'bonus_annual': Icons.celebration,
    'bonus_project': Icons.military_tech,
    'bonus_patent': Icons.stars,
    'bonus_award': Icons.workspace_premium,
    'bonus_trophy': Icons.emoji_events,
    'bonus_medal': Icons.shield,
    'bonus_crown': Icons.auto_awesome,

    // ── 投资收益 (10) ──
    'investment_income': Icons.show_chart,
    'investment_stock': Icons.candlestick_chart,
    'investment_fund': Icons.pie_chart,
    'investment_interest': Icons.savings,
    'investment_dividend': Icons.account_balance,
    'investment_realestate': Icons.real_estate_agent,
    'investment_crypto': Icons.currency_bitcoin,
    'investment_gold': Icons.diamond,
    'investment_bond': Icons.receipt_long,
    'investment_forex': Icons.currency_exchange,

    // ── 其他收入 ──
    'freelance': Icons.work,
    'red_packet': Icons.redeem,
    'reimbursement': Icons.receipt_long,

    // ── 通用 (15) ──
    'other': Icons.more_horiz,
    'other_star': Icons.star,
    'other_heart': Icons.favorite,
    'other_flag': Icons.flag,
    'other_bookmark': Icons.bookmark,
    'other_lock': Icons.lock,
    'other_timer': Icons.timer,
    'other_calendar': Icons.calendar_today,
    'other_alarm': Icons.alarm,
    'other_target': Icons.gps_fixed,
    'other_idea': Icons.lightbulb,
    'other_rocket': Icons.rocket_launch,
    'other_fire': Icons.local_fire_department,
    'other_leaf': Icons.eco,
    'other_bolt': Icons.bolt,
  };

  /// 图标分组（用于图标选择器 Tab）
  static const Map<String, List<String>> kIconGroups = {
    '餐饮': ['food', 'food_breakfast', 'food_lunch', 'food_dinner', 'food_midnight', 'food_drink', 'food_snack',
             'food_fastfood', 'food_noodle', 'food_cake', 'food_icecream', 'food_wine', 'food_beer',
             'food_tea', 'food_takeout', 'food_kitchen', 'food_brunch', 'food_bakery'],
    '交通': ['transport', 'transport_metro', 'transport_taxi', 'transport_fuel', 'transport_parking',
             'transport_bus', 'transport_bike', 'transport_train', 'transport_flight', 'transport_ship',
             'transport_ev', 'transport_motorcycle', 'transport_walk', 'transport_toll', 'transport_carwash'],
    '购物': ['shopping', 'shopping_digital', 'shopping_daily', 'shopping_beauty', 'shopping_phone',
             'shopping_laptop', 'shopping_headphone', 'shopping_camera', 'shopping_tv', 'shopping_watch',
             'shopping_furniture', 'shopping_toy', 'shopping_flower', 'shopping_mall', 'shopping_online'],
    '居住': ['housing', 'housing_rent', 'housing_property', 'housing_utility', 'housing_cleaning',
             'housing_water', 'housing_fire', 'housing_repair', 'housing_furniture', 'housing_garden',
             'housing_key', 'housing_ac', 'housing_laundry', 'housing_bed', 'housing_kitchen'],
    '娱乐': ['entertainment', 'entertainment_movie', 'entertainment_game', 'entertainment_sport', 'entertainment_book',
             'entertainment_music', 'entertainment_karaoke', 'entertainment_photo', 'entertainment_art',
             'entertainment_dance', 'entertainment_swim', 'entertainment_ski', 'entertainment_golf',
             'entertainment_basketball', 'entertainment_soccer', 'entertainment_tennis',
             'entertainment_bowling', 'entertainment_theater'],
    '健康': ['medical', 'medical_clinic', 'medical_hospital', 'medical_pharmacy', 'medical_health',
             'medical_dental', 'medical_eye', 'medical_heart', 'medical_vaccine', 'medical_emergency',
             'medical_insurance', 'medical_yoga', 'medical_run', 'medical_nutrition', 'medical_psychology'],
    '教育': ['education', 'education_course', 'education_book', 'education_tuition', 'education_exam',
             'education_lab', 'education_math', 'education_language', 'education_art', 'education_music',
             'education_laptop', 'education_library', 'education_graduation', 'education_pen', 'education_backpack'],
    '生活': ['communication', 'communication_phone', 'communication_broadband', 'communication_subscription',
             'communication_email', 'communication_chat', 'communication_cloud', 'communication_vpn',
             'communication_sim', 'communication_5g', 'communication_tv', 'communication_app',
             'daily', 'daily_cleaning', 'daily_personal', 'daily_tissue', 'daily_battery',
             'daily_tool', 'daily_print', 'daily_package', 'daily_recycle', 'daily_bulb'],
    '社交': ['gift', 'gift_red_packet', 'gift_treat', 'gift_wedding', 'gift_birthday', 'gift_baby',
             'gift_funeral', 'gift_party', 'gift_volunteer', 'gift_handshake', 'gift_group', 'gift_couple',
             'clothing', 'clothing_clothes', 'clothing_shoes', 'clothing_accessory', 'clothing_hat',
             'clothing_glasses', 'clothing_jewelry', 'clothing_bag', 'clothing_iron', 'clothing_tailor', 'clothing_umbrella'],
    '出行': ['travel', 'travel_hotel', 'travel_ticket', 'travel_attraction', 'travel_beach', 'travel_mountain',
             'travel_camping', 'travel_luggage', 'travel_passport', 'travel_map', 'travel_compass',
             'travel_photo', 'travel_souvenir', 'travel_food', 'travel_cruise',
             'pet', 'pet_food', 'pet_medical', 'pet_groom', 'pet_toy', 'pet_walk',
             'pet_cage', 'pet_fish', 'pet_bird', 'pet_bug', 'pet_paw', 'pet_nature'],
    '收入': ['salary', 'salary_base', 'salary_performance', 'salary_overtime', 'salary_commission',
             'salary_subsidy', 'salary_pension', 'salary_stipend', 'salary_tip', 'salary_contract',
             'bonus', 'bonus_annual', 'bonus_project', 'bonus_patent', 'bonus_award', 'bonus_medal', 'bonus_crown',
             'investment_income', 'investment_stock', 'investment_fund', 'investment_interest',
             'investment_dividend', 'investment_realestate', 'investment_crypto', 'investment_gold',
             'investment_bond', 'investment_forex',
             'freelance', 'red_packet', 'reimbursement'],
    '通用': ['other', 'other_star', 'other_heart', 'other_flag', 'other_bookmark', 'other_lock',
             'other_timer', 'other_calendar', 'other_alarm', 'other_target',
             'other_idea', 'other_rocket', 'other_fire', 'other_leaf', 'other_bolt'],
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
    'food': '餐饮', 'food_breakfast': '早餐', 'food_lunch': '午餐', 'food_dinner': '晚餐',
    'food_midnight': '夜宵', 'food_drink': '饮品', 'food_snack': '零食', 'food_fastfood': '快餐',
    'food_noodle': '面食', 'food_cake': '蛋糕', 'food_icecream': '冰淇淋', 'food_wine': '红酒',
    'food_beer': '啤酒', 'food_tea': '茶饮', 'food_takeout': '外卖', 'food_kitchen': '厨房',
    'food_brunch': '早午餐', 'food_bakery': '面包',

    'transport': '交通', 'transport_metro': '地铁', 'transport_taxi': '打车', 'transport_fuel': '加油',
    'transport_parking': '停车', 'transport_bus': '公交', 'transport_bike': '骑行', 'transport_train': '火车',
    'transport_flight': '飞机', 'transport_ship': '轮船', 'transport_ev': '充电', 'transport_motorcycle': '摩托',
    'transport_walk': '步行', 'transport_toll': '过路费', 'transport_carwash': '洗车',

    'shopping': '购物', 'shopping_digital': '数码', 'shopping_daily': '百货', 'shopping_beauty': '美妆',
    'shopping_phone': '手机', 'shopping_laptop': '电脑', 'shopping_headphone': '耳机', 'shopping_camera': '相机',
    'shopping_tv': '电视', 'shopping_watch': '手表', 'shopping_furniture': '家具', 'shopping_toy': '玩具',
    'shopping_flower': '鲜花', 'shopping_mall': '商场', 'shopping_online': '网购',

    'housing': '居住', 'housing_rent': '房租', 'housing_property': '物业', 'housing_utility': '水电',
    'housing_cleaning': '家政', 'housing_water': '水费', 'housing_fire': '燃气', 'housing_repair': '维修',
    'housing_furniture': '家居', 'housing_garden': '花园', 'housing_key': '钥匙', 'housing_ac': '空调',
    'housing_laundry': '洗衣', 'housing_bed': '卧室', 'housing_kitchen': '厨卫',

    'entertainment': '娱乐', 'entertainment_movie': '电影', 'entertainment_game': '游戏',
    'entertainment_sport': '运动', 'entertainment_book': '书籍', 'entertainment_music': '音乐',
    'entertainment_karaoke': 'KTV', 'entertainment_photo': '摄影', 'entertainment_art': '艺术',
    'entertainment_dance': '夜生活', 'entertainment_swim': '游泳', 'entertainment_ski': '滑雪',
    'entertainment_golf': '高尔夫', 'entertainment_basketball': '篮球', 'entertainment_soccer': '足球',
    'entertainment_tennis': '网球', 'entertainment_bowling': '保龄球', 'entertainment_theater': '话剧',

    'medical': '医疗', 'medical_clinic': '门诊', 'medical_hospital': '住院', 'medical_pharmacy': '买药',
    'medical_health': '保健', 'medical_dental': '牙科', 'medical_eye': '眼科', 'medical_heart': '心脏',
    'medical_vaccine': '疫苗', 'medical_emergency': '急诊', 'medical_insurance': '医保',
    'medical_yoga': '瑜伽', 'medical_run': '跑步', 'medical_nutrition': '营养', 'medical_psychology': '心理',

    'education': '教育', 'education_course': '课程', 'education_book': '书籍', 'education_tuition': '学费',
    'education_exam': '考试', 'education_lab': '实验', 'education_math': '数学', 'education_language': '语言',
    'education_art': '美术', 'education_music': '音乐', 'education_laptop': '网课',
    'education_library': '图书馆', 'education_graduation': '毕业', 'education_pen': '文具', 'education_backpack': '书包',

    'communication': '通讯', 'communication_phone': '话费', 'communication_broadband': '宽带',
    'communication_subscription': '订阅', 'communication_email': '邮件', 'communication_chat': '聊天',
    'communication_cloud': '云存储', 'communication_vpn': 'VPN', 'communication_sim': 'SIM卡',
    'communication_5g': '5G', 'communication_tv': '电视', 'communication_app': '应用',

    'gift': '人情', 'gift_red_packet': '红包', 'gift_treat': '请客', 'gift_wedding': '份子',
    'gift_birthday': '生日', 'gift_baby': '满月', 'gift_funeral': '丧葬', 'gift_party': '聚会',
    'gift_volunteer': '公益', 'gift_handshake': '合作', 'gift_group': '团建', 'gift_couple': '约会',

    'clothing': '服饰', 'clothing_clothes': '衣服', 'clothing_shoes': '鞋包', 'clothing_accessory': '配饰',
    'clothing_hat': '帽子', 'clothing_glasses': '眼镜', 'clothing_jewelry': '珠宝', 'clothing_bag': '箱包',
    'clothing_iron': '熨烫', 'clothing_laundry': '洗衣', 'clothing_tailor': '裁剪', 'clothing_umbrella': '雨伞',

    'daily': '日用', 'daily_cleaning': '清洁', 'daily_personal': '护理', 'daily_tissue': '纸巾',
    'daily_battery': '电池', 'daily_tool': '工具', 'daily_print': '打印', 'daily_package': '快递',
    'daily_recycle': '回收', 'daily_bulb': '灯泡', 'daily_scissors': '剪刀', 'daily_tape': '胶带',

    'travel': '旅行', 'travel_hotel': '住宿', 'travel_ticket': '车票', 'travel_attraction': '景点',
    'travel_beach': '海滩', 'travel_mountain': '登山', 'travel_camping': '露营', 'travel_luggage': '行李',
    'travel_passport': '证件', 'travel_map': '地图', 'travel_compass': '探索', 'travel_photo': '相册',
    'travel_souvenir': '纪念品', 'travel_food': '特产', 'travel_cruise': '帆船',

    'pet': '宠物', 'pet_food': '口粮', 'pet_medical': '看病', 'pet_groom': '美容',
    'pet_toy': '玩具', 'pet_walk': '遛宠', 'pet_cage': '笼舍', 'pet_fish': '水族',
    'pet_bird': '鸟类', 'pet_bug': '爬虫', 'pet_paw': '用品', 'pet_nature': '户外',

    'salary': '工资', 'salary_base': '底薪', 'salary_performance': '绩效', 'salary_overtime': '加班',
    'salary_commission': '提成', 'salary_subsidy': '补贴', 'salary_pension': '养老金',
    'salary_stipend': '津贴', 'salary_tip': '小费', 'salary_contract': '合同',

    'bonus': '奖金', 'bonus_annual': '年终', 'bonus_project': '项目', 'bonus_patent': '专利',
    'bonus_award': '表彰', 'bonus_trophy': '冠军', 'bonus_medal': '勋章', 'bonus_crown': '杰出',

    'investment_income': '投资', 'investment_stock': '股票', 'investment_fund': '基金',
    'investment_interest': '利息', 'investment_dividend': '分红', 'investment_realestate': '房产',
    'investment_crypto': '加密', 'investment_gold': '黄金', 'investment_bond': '债券', 'investment_forex': '外汇',

    'freelance': '兼职', 'red_packet': '红包', 'reimbursement': '报销',

    'other': '其他', 'other_star': '收藏', 'other_heart': '喜欢', 'other_flag': '标记',
    'other_bookmark': '书签', 'other_lock': '安全', 'other_timer': '计时', 'other_calendar': '日历',
    'other_alarm': '提醒', 'other_target': '目标', 'other_idea': '灵感', 'other_rocket': '飞速',
    'other_fire': '热门', 'other_leaf': '环保', 'other_bolt': '闪电',
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
