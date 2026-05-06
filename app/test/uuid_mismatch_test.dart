import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/core/utils/category_uuid.dart';

void main() {
  test('Seed and server subcategory UUIDs now match', () {
    final parentFood = CategoryUUID.generate('test-user', 'expense', '餐饮');
    
    // New seed formula: parentUUID:childName (same as server)
    final seedId = CategoryUUID.generate('test-user', 'expense', '$parentFood:早餐');
    
    // Server formula: parentUUID:childName
    final serverId = CategoryUUID.generate('test-user', 'expense', '$parentFood:早餐');
    
    expect(seedId, equals(serverId),
        reason: 'Seed and server should use the same UUID formula');
  });

  test('Old seed formula was different (regression guard)', () {
    // Old formula used parentName/childName
    final oldSeedId = CategoryUUID.generate('test-user', 'expense', '餐饮/早餐');
    
    // New formula uses parentUUID:childName
    final parentFood = CategoryUUID.generate('test-user', 'expense', '餐饮');
    final newSeedId = CategoryUUID.generate('test-user', 'expense', '$parentFood:早餐');
    
    expect(oldSeedId, isNot(equals(newSeedId)),
        reason: 'Old and new formulas should produce different UUIDs');
  });

  test('All preset subcategories: seed matches server formula', () {
    const subcats = [
      ('expense', '餐饮', '早餐'), ('expense', '餐饮', '午餐'),
      ('expense', '餐饮', '晚餐'), ('expense', '交通', '地铁公交'),
      ('expense', '购物', '电器数码'), ('expense', '居住', '房租'),
      ('expense', '娱乐', '电影演出'), ('expense', '医疗', '门诊'),
      ('expense', '教育', '培训课程'), ('expense', '通讯', '话费'),
      ('expense', '人情', '红包礼金'), ('expense', '服饰', '衣服'),
      ('expense', '日用', '清洁用品'), ('expense', '旅行', '住宿'),
      ('expense', '宠物', '口粮用品'), ('income', '工资', '基本工资'),
    ];

    for (final (type, parentName, childName) in subcats) {
      final parentId = CategoryUUID.generate('test-user', type, parentName);
      // Seed formula (new)
      final seedId = CategoryUUID.generate('test-user', type, '$parentId:$childName');
      // Server formula (CreateCategory RPC)
      final serverId = CategoryUUID.generate('test-user', type, '$parentId:$childName');
      
      expect(seedId, equals(serverId),
          reason: '$parentName/$childName: seed=$seedId server=$serverId');
    }
  });
}
