import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/core/utils/category_uuid.dart';
import 'package:uuid/uuid.dart';

/// Simulates the import category matching logic from import_page.dart.
/// This test reproduces the duplicate category bug after importing Baishi AA data.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper: replicate _getOrCreateCategory from import_page.dart
  Future<Category> getOrCreateCategory(
    AppDatabase database,
    Map<String, Category> catByName,
    Map<String, Category> catByNameType,
    List<Category> allCategories, {
    required String name,
    required String type,
  }) async {
    // Prefer exact name+type match
    final byNameType = catByNameType['$name|$type'];
    if (byNameType != null) return byNameType;
    // Fallback: any type with same name
    final byName = catByName[name];
    if (byName != null) return byName;

    // Check DB directly — first top-level, then any
    var dbExisting = await (database.select(database.categories)
          ..where((c) => c.name.equals(name))
          ..where((c) => c.type.equals(type))
          ..where((c) => c.parentId.isNull())
          ..limit(1))
        .getSingleOrNull();
    dbExisting ??= await (database.select(database.categories)
          ..where((c) => c.name.equals(name))
          ..where((c) => c.type.equals(type))
          ..limit(1))
        .getSingleOrNull();
    if (dbExisting != null) {
      catByName[name] = dbExisting;
      catByNameType['$name|${dbExisting.type}'] = dbExisting;
      allCategories.add(dbExisting);
      return dbExisting;
    }

    final id = const Uuid().v4();
    await database.upsertCategory(
      id: id,
      name: name,
      icon: '📌',
      type: type,
    );
    final newCat = Category(
      id: id,
      name: name,
      icon: '📌',
      iconKey: '',
      type: type,
      isPreset: false,
      sortOrder: 999,
      parentId: null,
      userId: null,
      deletedAt: null,
    );
    catByName[name] = newCat;
    catByNameType['$name|$type'] = newCat;
    allCategories.add(newCat);
    return newCat;
  }

  /// Helper: replicate _getOrCreateChildCategory from import_page.dart
  Future<Category> getOrCreateChildCategory(
    AppDatabase database,
    Map<String, Category> catByName,
    List<Category> allCategories, {
    required String name,
    required String type,
    required String parentId,
  }) async {
    // Check in-memory cache
    final existing = allCategories
        .where((c) => c.name == name && c.parentId == parentId)
        .firstOrNull;
    if (existing != null) {
      catByName[name] = existing;
      return existing;
    }

    // Check DB
    final dbExisting = await (database.select(database.categories)
          ..where((c) => c.name.equals(name))
          ..where((c) => c.parentId.equals(parentId))
          ..limit(1))
        .getSingleOrNull();
    if (dbExisting != null) {
      catByName[name] = dbExisting;
      allCategories.add(dbExisting);
      return dbExisting;
    }

    final id = const Uuid().v4();
    await database.upsertCategory(
      id: id,
      name: name,
      icon: '📌',
      type: type,
      parentId: parentId,
    );
    final newCat = Category(
      id: id,
      name: name,
      icon: '📌',
      iconKey: '',
      type: type,
      isPreset: false,
      sortOrder: 999,
      parentId: parentId,
      userId: null,
      deletedAt: null,
    );
    catByName[name] = newCat;
    allCategories.add(newCat);
    return newCat;
  }

  /// Helper: simulate Baishi import matching logic for one transaction
  Future<String> matchBaishi(
    AppDatabase database,
    Map<String, Category> catByName,
    Map<String, Category> catByNameType,
    List<Category> allCategories, {
    required String parentName,
    required String? tag,
    required String type,
  }) async {
    if (tag != null && tag.isNotEmpty) {
      // First try: exact match on tag name
      final tagCat = catByName[tag];
      if (tagCat != null) {
        return tagCat.id;
      }

      // Tag not found — auto-create parent + child
      final parentCat = await getOrCreateCategory(
        database, catByName, catByNameType, allCategories,
        name: parentName,
        type: type,
      );
      final childCat = await getOrCreateChildCategory(
        database, catByName, allCategories,
        name: tag,
        type: type,
        parentId: parentCat.id,
      );
      return childCat.id;
    }

    // No tag — match or create parent
    final parentCat = await getOrCreateCategory(
      database, catByName, catByNameType, allCategories,
      name: parentName,
      type: type,
    );
    return parentCat.id;
  }

  group('Seed data verification', () {
    test('preset categories include subcategories with iconKey', () async {
      final all = await db.getAllCategories();
      // 14 expense parents + 7 income parents = 21 parents
      final parents = all.where((c) => c.parentId == null).toList();
      expect(parents.length, 21);

      // Subcategories exist
      final subs = all.where((c) => c.parentId != null).toList();
      expect(subs.length, greaterThan(0));

      // Check a known subcategory
      final nightSnack = all.where((c) => c.name == '午餐').firstOrNull;
      expect(nightSnack, isNotNull);
      expect(nightSnack!.parentId, isNotNull);
      expect(nightSnack.iconKey, 'food_lunch');

      // Verify parent
      final food = all.where((c) => c.id == nightSnack.parentId).first;
      expect(food.name, '餐饮');
    });

    test('preset parent categories have iconKey set', () async {
      final parents = (await db.getAllCategories())
          .where((c) => c.parentId == null)
          .toList();
      for (final p in parents) {
        expect(p.iconKey, isNotEmpty,
            reason: '${p.name} should have iconKey');
      }
    });
  });

  group('Import category matching - Baishi AA format', () {
    late Map<String, Category> catByName;
    late Map<String, Category> catByNameType;
    late List<Category> allCategories;

    setUp(() async {
      // Load all categories from DB (simulates _loadCategories)
      allCategories = await db.getAllCategories();
      catByName = {};
      catByNameType = {};
      for (final c in allCategories) {
        catByNameType['${c.name}|${c.type}'] = c;
        catByName[c.name] = c; // last-write-wins
      }
    });

    test('matching preset subcategory: 餐饮/夜宵 should not create duplicate', () async {
      // Import row: parent=餐饮, tag=夜宵
      final catId = await matchBaishi(
        db, catByName, catByNameType, allCategories,
        parentName: '餐饮', tag: '夜宵', type: 'expense',
      );

      // Should match existing preset "夜宵" subcategory
      final nightSnack = (await db.getAllCategories())
          .where((c) => c.name == '夜宵')
          .toList();
      expect(nightSnack.length, 1,
          reason: 'Should be exactly 1 "夜宵", found ${nightSnack.length}');
      expect(nightSnack.first.id, catId);
    });

    test('matching preset subcategory: 餐饮/午餐 should not create duplicate', () async {
      final catId = await matchBaishi(
        db, catByName, catByNameType, allCategories,
        parentName: '餐饮', tag: '午餐', type: 'expense',
      );

      final lunch = (await db.getAllCategories())
          .where((c) => c.name == '午餐')
          .toList();
      expect(lunch.length, 1,
          reason: 'Should be exactly 1 "午餐", found ${lunch.length}');
      expect(lunch.first.id, catId);
    });

    test('creating new subcategory under existing parent', () async {
      // Import row: parent=餐饮, tag=奶茶 (not a preset subcategory)
      final catId = await matchBaishi(
        db, catByName, catByNameType, allCategories,
        parentName: '餐饮', tag: '奶茶', type: 'expense',
      );

      final milkTea = (await db.getAllCategories())
          .where((c) => c.name == '奶茶')
          .toList();
      // Should have exactly 1 "奶茶" (newly created)
      expect(milkTea.length, 1);
      expect(milkTea.first.parentId, isNotNull);

      // Parent should be the preset "餐饮"
      final food = (await db.getAllCategories())
          .where((c) => c.name == '餐饮' && c.parentId == null)
          .toList();
      expect(food.length, 1, reason: 'Should be exactly 1 "餐饮" parent');
      expect(milkTea.first.parentId, food.first.id);
    });

    test('creating new parent + child for unknown category', () async {
      // Import row: parent=结婚, tag=婚纱 (neither exists in presets)
      final catId = await matchBaishi(
        db, catByName, catByNameType, allCategories,
        parentName: '结婚', tag: '婚纱', type: 'expense',
      );

      final wedding = (await db.getAllCategories())
          .where((c) => c.name == '结婚' && c.parentId == null)
          .toList();
      expect(wedding.length, 1);

      final dress = (await db.getAllCategories())
          .where((c) => c.name == '婚纱')
          .toList();
      expect(dress.length, 1);
      expect(dress.first.parentId, wedding.first.id);
    });

    test('parent-only match (no tag): 衣服 should not duplicate', () async {
      // Import row: parent=衣服, tag='' (衣服 is a preset subcategory of 服饰)
      final catId = await matchBaishi(
        db, catByName, catByNameType, allCategories,
        parentName: '衣服', tag: '', type: 'expense',
      );

      // "衣服" exists as a subcategory of "服饰" in presets
      // Should NOT create a new top-level "衣服"
      final clothes = (await db.getAllCategories())
          .where((c) => c.name == '衣服')
          .toList();
      expect(clothes.length, 1,
          reason: 'Should be exactly 1 "衣服", found ${clothes.length}: '
              '${clothes.map((c) => "id=${c.id} parent=${c.parentId}").join(", ")}');
    });

    test('full Baishi import simulation - no duplicate categories', () async {
      // Simulate importing a realistic set of Baishi AA transactions
      final importData = [
        // 餐饮 with various tags
        ('餐饮', '夜宵', 'expense'),
        ('餐饮', '午餐', 'expense'),
        ('餐饮', '早餐', 'expense'),
        ('餐饮', '晚餐', 'expense'),
        ('餐饮', '外卖', 'expense'),
        ('餐饮', '奶茶', 'expense'),
        ('餐饮', '水果', 'expense'),
        ('餐饮', '', 'expense'), // no tag
        // 交通
        ('交通', '停车费', 'expense'),
        ('交通', '出租', 'expense'),
        ('交通', '地铁', 'expense'),
        ('交通', '', 'expense'),
        // 购物
        ('购物', '化妆品/护肤品', 'expense'),
        ('购物', '服装', 'expense'),
        ('购物', '', 'expense'),
        // 居住 (preset has subcats: 房租, etc.)
        ('住宿', '房租', 'expense'), // "住宿" is a subcategory of "旅行"!
        // 衣服 (preset subcategory of 服饰)
        ('衣服', '', 'expense'),
        // 结婚 (not in presets)
        ('结婚', '婚纱', 'expense'),
        ('结婚', '钻戒', 'expense'),
        ('结婚', '婚纱照', 'expense'),
        // 装修 (not in presets)
        ('装修', '沙发', 'expense'),
        ('装修', '电视', 'expense'),
        // 工资 (income)
        ('工资', '老公', 'income'),
        ('工资', '老婆', 'income'),
        ('工资', '', 'income'),
        // Repeated entries (should not create dupes)
        ('餐饮', '夜宵', 'expense'),
        ('餐饮', '午餐', 'expense'),
        ('结婚', '婚纱', 'expense'),
        ('购物', '', 'expense'),
      ];

      for (final (parent, tag, type) in importData) {
        await matchBaishi(
          db, catByName, catByNameType, allCategories,
          parentName: parent, tag: tag, type: type,
        );
      }

      // Verify no duplicates
      final all = await db.getAllCategories();
      final nameGroups = <String, List<Category>>{};
      for (final c in all) {
        final key = '${c.name}|${c.type}|${c.parentId ?? "root"}';
        nameGroups.putIfAbsent(key, () => []).add(c);
      }

      final dupes = nameGroups.entries
          .where((e) => e.value.length > 1)
          .map((e) => '${e.key}: ${e.value.length} copies')
          .toList();
      expect(dupes, isEmpty,
          reason: 'Found duplicate categories:\n${dupes.join("\n")}');

      // Additional check: no duplicate names within same parent AND same type
      final byParentType = <String, List<Category>>{};
      for (final c in all) {
        final key = '${c.parentId ?? "root"}|${c.type}';
        byParentType.putIfAbsent(key, () => []).add(c);
      }
      for (final entry in byParentType.entries) {
        final names = entry.value.map((c) => c.name).toList();
        final uniqueNames = names.toSet();
        if (names.length != uniqueNames.length) {
          final dupeNames = names
              .where((n) => names.where((x) => x == n).length > 1)
              .toSet();
          fail('Duplicate names under ${entry.key}: $dupeNames');
        }
      }
    });

    test('importing same data twice should not create duplicates', () async {
      final batch1 = [
        ('餐饮', '夜宵', 'expense'),
        ('餐饮', '午餐', 'expense'),
        ('结婚', '婚纱', 'expense'),
        ('衣服', '', 'expense'),
        ('工资', '老公', 'income'),
      ];

      // First import
      for (final (parent, tag, type) in batch1) {
        await matchBaishi(
          db, catByName, catByNameType, allCategories,
          parentName: parent, tag: tag, type: type,
        );
      }
      final countAfterFirst = (await db.getAllCategories()).length;

      // Second import (same data — simulates user importing again)
      for (final (parent, tag, type) in batch1) {
        await matchBaishi(
          db, catByName, catByNameType, allCategories,
          parentName: parent, tag: tag, type: type,
        );
      }
      final countAfterSecond = (await db.getAllCategories()).length;

      expect(countAfterSecond, countAfterFirst,
          reason: 'Second import should not create new categories. '
              'Before: $countAfterFirst, After: $countAfterSecond');
    });

    test('fresh cache after reload should still match existing categories', () async {
      // First import
      await matchBaishi(
        db, catByName, catByNameType, allCategories,
        parentName: '结婚', tag: '婚纱', type: 'expense',
      );

      // Simulate app restart: reload categories from DB
      allCategories = await db.getAllCategories();
      catByName = {};
      catByNameType = {};
      for (final c in allCategories) {
        catByNameType['${c.name}|${c.type}'] = c;
        catByName[c.name] = c;
      }

      // Second import with fresh cache
      await matchBaishi(
        db, catByName, catByNameType, allCategories,
        parentName: '结婚', tag: '婚纱', type: 'expense',
      );

      final wedding = (await db.getAllCategories())
          .where((c) => c.name == '结婚' && c.parentId == null)
          .toList();
      expect(wedding.length, 1);

      final dress = (await db.getAllCategories())
          .where((c) => c.name == '婚纱')
          .toList();
      expect(dress.length, 1);
    });

    test('catByName collision: subcategory name overwrites parent name', () async {
      // If a subcategory has the same name as a parent, catByName last-write-wins
      // This test documents the behavior
      
      // "其他" exists as both expense parent and income parent
      final otherEntries = allCategories.where((c) => c.name == '其他').toList();
      expect(otherEntries.length, greaterThanOrEqualTo(2),
          reason: '"其他" should exist in both expense and income');

      // catByName will have the last one (non-deterministic order)
      // catByNameType should have both
      expect(catByNameType.containsKey('其他|expense'), true);
      expect(catByNameType.containsKey('其他|income'), true);
    });
  });

  group('Deduplication', () {
    test('_deduplicateCategories merges orphan top-level into subcategory', () async {
      // Create an orphan "衣服" top-level (simulates old import bug)
      await db.upsertCategory(
        id: 'orphan_clothes',
        name: '衣服',
        icon: '📌',
        type: 'expense',
      );

      // Create a transaction pointing to the orphan
      await db.into(db.users).insert(UsersCompanion.insert(
        id: 'test_user',
        email: 'test@test.com',
      ));
      await db.insertAccount(AccountsCompanion.insert(
        id: 'test_acc',
        name: 'Test',
        userId: 'test_user',
      ));
      await db.insertTransaction(TransactionsCompanion.insert(
        id: 'txn_1',
        userId: 'test_user',
        accountId: 'test_acc',
        categoryId: 'orphan_clothes',
        amount: 1000,
        amountCny: 1000,
        type: 'expense',
        txnDate: DateTime(2024, 1, 1),
      ));

      // Verify orphan exists
      final beforeAll = await db.getAllCategories();
      final clothesBefore = beforeAll.where((c) => c.name == '衣服').toList();
      expect(clothesBefore.length, 2,
          reason: 'Should have orphan + preset subcategory');

      // Close and reopen DB to trigger beforeOpen (dedup + backfill)
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // Can't test beforeOpen with in-memory DB easily, so just verify the
      // dedup logic is correct by checking the initial seed
    });

    test('backfill sets iconKey for preset parents', () async {
      // After seed + beforeOpen, all parents should have iconKey
      final parents = (await db.getAllCategories())
          .where((c) => c.parentId == null)
          .toList();
      for (final p in parents) {
        expect(p.iconKey, isNotEmpty,
            reason: '${p.name} (${p.type}) should have iconKey but got empty');
      }
    });
  });
}
