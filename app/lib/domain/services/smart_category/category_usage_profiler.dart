import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/local/database.dart';
import 'category_usage_profile.dart';

/// 分类使用画像统计引擎
/// 负责从 transactions 聚合使用数据到 category_usage_slots / category_usage_summary
class CategoryUsageProfiler {
  final AppDatabase _db;

  CategoryUsageProfiler(this._db);

  // ──────────── 全量重建 ────────────

  /// 全量重建所有分类的使用画像（首次启动 / 导入后 / 周期性后台刷新）
  Future<void> rebuildAll() async {
    // 获取所有未删除分类
    final categories = await (_db.select(_db.categories)
          ..where((c) => c.deletedAt.isNull()))
        .get();
    final categoryIds = categories.map((c) => c.id).toSet();

    // 获取所有未删除交易
    final allTxns = await (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull()))
        .get();

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // 按 categoryId 分组
    final grouped = <String, List<Transaction>>{};
    for (final txn in allTxns) {
      if (!categoryIds.contains(txn.categoryId)) continue;
      grouped.putIfAbsent(txn.categoryId, () => []).add(txn);
    }

    await _db.transaction(() async {
      // 清空旧数据
      await _db.delete(_db.categoryUsageSlots).go();
      await _db.delete(_db.categoryUsageSummary).go();

      for (final catId in categoryIds) {
        final txns = grouped[catId] ?? [];

        // 计算 slot 分布
        final hourCounts = List<int>.filled(24, 0);
        final weekdayCounts = List<int>.filled(7, 0);
        final amountCounts = List<int>.filled(6, 0);
        int last7d = 0;
        int last30d = 0;
        DateTime? lastUsed;
        final noteTexts = <String>[];

        for (final txn in txns) {
          hourCounts[txn.txnDate.hour]++;
          weekdayCounts[txn.txnDate.weekday % 7]++; // 0=Sun,1=Mon...6=Sat
          amountCounts[CategoryUsageProfile.amountToBucket(txn.amountCny.abs())]++;

          if (txn.txnDate.isAfter(sevenDaysAgo)) last7d++;
          if (txn.txnDate.isAfter(thirtyDaysAgo)) last30d++;

          if (lastUsed == null || txn.txnDate.isAfter(lastUsed)) {
            lastUsed = txn.txnDate;
          }
          final note = txn.note;
          if (note.isNotEmpty) noteTexts.add(note);
        }

        // 写入 slots
        await _db.batch((b) {
          for (var i = 0; i < 24; i++) {
            if (hourCounts[i] > 0) {
              b.insert(
                _db.categoryUsageSlots,
                CategoryUsageSlotsCompanion.insert(
                  categoryId: catId,
                  slotType: 'hour',
                  slotIndex: i,
                  count: Value(hourCounts[i]),
                ),
              );
            }
          }
          for (var i = 0; i < 7; i++) {
            if (weekdayCounts[i] > 0) {
              b.insert(
                _db.categoryUsageSlots,
                CategoryUsageSlotsCompanion.insert(
                  categoryId: catId,
                  slotType: 'weekday',
                  slotIndex: i,
                  count: Value(weekdayCounts[i]),
                ),
              );
            }
          }
          for (var i = 0; i < 6; i++) {
            if (amountCounts[i] > 0) {
              b.insert(
                _db.categoryUsageSlots,
                CategoryUsageSlotsCompanion.insert(
                  categoryId: catId,
                  slotType: 'amount',
                  slotIndex: i,
                  count: Value(amountCounts[i]),
                ),
              );
            }
          }
        });

        // 提取 topKeywords
        final keywords = extractTopKeywords(noteTexts);

        // 写入 summary
        await _db.into(_db.categoryUsageSummary).insert(
          CategoryUsageSummaryCompanion.insert(
            categoryId: catId,
            totalCount: Value(txns.length),
            last30dCount: Value(last30d),
            last7dCount: Value(last7d),
            topKeywords: Value(jsonEncode(keywords)),
            lastUsedAt: Value(lastUsed),
          ),
        );
      }
    });
  }

  // ──────────── 增量更新 ────────────

  /// 记一笔交易后增量更新对应分类的统计
  Future<void> onTransactionCreated({
    required String categoryId,
    required DateTime txnDate,
    required int amountCents,
  }) async {
    final hour = txnDate.hour;
    final weekday = txnDate.weekday % 7;
    final bucket = CategoryUsageProfile.amountToBucket(amountCents.abs());

    // Upsert slots (INSERT OR UPDATE count = count + 1)
    await _upsertSlot(categoryId, 'hour', hour);
    await _upsertSlot(categoryId, 'weekday', weekday);
    await _upsertSlot(categoryId, 'amount', bucket);

    // Update summary
    await _db.customStatement(
      'INSERT INTO category_usage_summary (category_id, total_count, last_30d_count, last_7d_count, top_keywords, last_used_at, updated_at) '
      'VALUES (?, 1, 1, 1, \'[]\', ?, CURRENT_TIMESTAMP) '
      'ON CONFLICT(category_id) DO UPDATE SET '
      'total_count = total_count + 1, '
      'last_30d_count = last_30d_count + 1, '
      'last_7d_count = last_7d_count + 1, '
      'last_used_at = CASE WHEN excluded.last_used_at > last_used_at THEN excluded.last_used_at ELSE last_used_at END, '
      'updated_at = CURRENT_TIMESTAMP',
      [Variable.withString(categoryId), Variable.withDateTime(txnDate)],
    );
  }

  Future<void> _upsertSlot(String categoryId, String slotType, int slotIndex) async {
    await _db.customStatement(
      'INSERT INTO category_usage_slots (category_id, slot_type, slot_index, count) '
      'VALUES (?, ?, ?, 1) '
      'ON CONFLICT(category_id, slot_type, slot_index) DO UPDATE SET count = count + 1',
      [
        Variable.withString(categoryId),
        Variable.withString(slotType),
        Variable.withInt(slotIndex),
      ],
    );
  }

  // ──────────── 读取画像 ────────────

  /// 获取单个分类的使用画像
  Future<CategoryUsageProfile> getProfile(String categoryId) async {
    final summary = await (_db.select(_db.categoryUsageSummary)
          ..where((s) => s.categoryId.equals(categoryId)))
        .getSingleOrNull();

    final slots = await (_db.select(_db.categoryUsageSlots)
          ..where((s) => s.categoryId.equals(categoryId)))
        .get();

    final hourDist = List<int>.filled(24, 0);
    final weekdayDist = List<int>.filled(7, 0);
    final amountDist = List<int>.filled(6, 0);

    for (final slot in slots) {
      switch (slot.slotType) {
        case 'hour':
          hourDist[slot.slotIndex] = slot.count;
        case 'weekday':
          weekdayDist[slot.slotIndex] = slot.count;
        case 'amount':
          amountDist[slot.slotIndex] = slot.count;
      }
    }

    List<String> keywords = [];
    if (summary != null) {
      try {
        keywords = (jsonDecode(summary.topKeywords) as List).cast<String>();
      } catch (_) {}
    }

    return CategoryUsageProfile(
      categoryId: categoryId,
      totalCount: summary?.totalCount ?? 0,
      last30dCount: summary?.last30dCount ?? 0,
      last7dCount: summary?.last7dCount ?? 0,
      hourDistribution: hourDist,
      weekdayDistribution: weekdayDist,
      amountBuckets: amountDist,
      topKeywords: keywords,
      lastUsedAt: summary?.lastUsedAt,
    );
  }

  /// 获取所有有使用记录的分类画像
  Future<Map<String, CategoryUsageProfile>> getAllProfiles() async {
    final summaries = await _db.select(_db.categoryUsageSummary).get();
    final allSlots = await _db.select(_db.categoryUsageSlots).get();

    // 按 categoryId 分组 slots
    final slotsByCategory = <String, List<CategoryUsageSlot>>{};
    for (final slot in allSlots) {
      slotsByCategory.putIfAbsent(slot.categoryId, () => []).add(slot);
    }

    final profiles = <String, CategoryUsageProfile>{};
    for (final summary in summaries) {
      final catId = summary.categoryId;
      final slots = slotsByCategory[catId] ?? [];

      final hourDist = List<int>.filled(24, 0);
      final weekdayDist = List<int>.filled(7, 0);
      final amountDist = List<int>.filled(6, 0);

      for (final slot in slots) {
        switch (slot.slotType) {
          case 'hour':
            hourDist[slot.slotIndex] = slot.count;
          case 'weekday':
            weekdayDist[slot.slotIndex] = slot.count;
          case 'amount':
            amountDist[slot.slotIndex] = slot.count;
        }
      }

      List<String> keywords = [];
      try {
        keywords = (jsonDecode(summary.topKeywords) as List).cast<String>();
      } catch (_) {}

      profiles[catId] = CategoryUsageProfile(
        categoryId: catId,
        totalCount: summary.totalCount,
        last30dCount: summary.last30dCount,
        last7dCount: summary.last7dCount,
        hourDistribution: hourDist,
        weekdayDistribution: weekdayDist,
        amountBuckets: amountDist,
        topKeywords: keywords,
        lastUsedAt: summary.lastUsedAt,
      );
    }

    return profiles;
  }

  // ──────────── 关键词提取 ────────────

  /// 从交易备注中提取高频关键词
  static List<String> extractTopKeywords(List<String> allNotes, {int maxCount = 20}) {
    final freq = <String, int>{};
    const stopwords = {'的', '了', '在', '是', '我', '一', '个', '不', '这', '那', '有', '和', '与', '等'};

    for (final note in allNotes) {
      if (note.isEmpty) continue;
      final tokens = tokenize(note);
      for (final token in tokens) {
        if (stopwords.contains(token)) continue;
        if (_isNumericOrDate(token)) continue;
        freq[token] = (freq[token] ?? 0) + 1;
      }
    }

    // 至少出现 2 次才有意义
    freq.removeWhere((_, count) => count < 2);

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(maxCount).map((e) => e.key).toList();
  }

  /// 分词器：中文用 2-char sliding window，拉丁文用空格分割
  static List<String> tokenize(String text) {
    final tokens = <String>[];
    final latin = RegExp(r'[a-zA-Z]+');

    // 拉丁文单词
    for (final m in latin.allMatches(text)) {
      if (m.group(0)!.length >= 2) tokens.add(m.group(0)!.toLowerCase());
    }

    // 中文 2-gram
    final cjk = text.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
    for (var i = 0; i < cjk.length - 1; i++) {
      tokens.add(cjk.substring(i, i + 2));
    }

    // 完整匹配（备注本身，去空格/标点，2-6 字）
    final clean = text.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
    if (clean.length >= 2 && clean.length <= 6) tokens.add(clean);

    return tokens;
  }

  static bool _isNumericOrDate(String token) {
    if (RegExp(r'^\d+$').hasMatch(token)) return true;
    if (RegExp(r'^\d{2,4}[/-]\d{1,2}([/-]\d{1,2})?$').hasMatch(token)) return true;
    return false;
  }

  // ──────────── 周期性刷新 ────────────

  /// 刷新 last_7d_count 和 last_30d_count（每天后台运行一次）
  Future<void> refreshRecencyCounts() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final summaries = await _db.select(_db.categoryUsageSummary).get();
    for (final summary in summaries) {
      final catId = summary.categoryId;

      final last7d = await _db.customSelect(
        'SELECT COUNT(*) as cnt FROM transactions WHERE category_id = ? AND deleted_at IS NULL AND txn_date >= ?',
        variables: [Variable.withString(catId), Variable.withDateTime(sevenDaysAgo)],
        readsFrom: {_db.transactions},
      ).getSingle();

      final last30d = await _db.customSelect(
        'SELECT COUNT(*) as cnt FROM transactions WHERE category_id = ? AND deleted_at IS NULL AND txn_date >= ?',
        variables: [Variable.withString(catId), Variable.withDateTime(thirtyDaysAgo)],
        readsFrom: {_db.transactions},
      ).getSingle();

      await (_db.update(_db.categoryUsageSummary)
            ..where((s) => s.categoryId.equals(catId)))
          .write(CategoryUsageSummaryCompanion(
        last7dCount: Value(last7d.data['cnt'] as int? ?? 0),
        last30dCount: Value(last30d.data['cnt'] as int? ?? 0),
        updatedAt: Value(now),
      ));
    }
  }
}
