import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

import '../../../data/local/database.dart';
import 'category_usage_profile.dart';

/// Slot type 枚举，避免裸字符串
abstract final class SlotType {
  static const hour = 'hour';
  static const weekday = 'weekday';
  static const amount = 'amount';

  static const all = [hour, weekday, amount];
}

/// 分类使用画像统计引擎
/// 负责从 transactions 聚合使用数据到 category_usage_slots / category_usage_summary
///
/// ⚠️ 必须以单例方式使用（通过 DI 容器注入同一实例）。
/// 内部互斥锁是实例级别的，多实例会导致锁失效。
class CategoryUsageProfiler {
  final AppDatabase _db;

  /// 互斥锁：防止 rebuildAll 并发执行
  Completer<void>? _rebuildLock;

  CategoryUsageProfiler(this._db);

  // ──────────── 全量重建 ────────────

  /// 全量重建所有分类的使用画像（首次启动 / 导入后 / 周期性后台刷新）
  /// 通过互斥锁防止并发执行
  Future<void> rebuildAll() async {
    if (_rebuildLock != null) {
      await _rebuildLock!.future;
      return;
    }

    _rebuildLock = Completer<void>();
    try {
      await _doRebuildAll();
    } finally {
      _rebuildLock!.complete();
      _rebuildLock = null;
    }
  }

  Future<void> _doRebuildAll() async {
    final categories = await (_db.select(_db.categories)
          ..where((c) => c.deletedAt.isNull()))
        .get();
    final categoryIds = categories.map((c) => c.id).toSet();

    final allTxns = await (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull()))
        .get();

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final grouped = <String, List<Transaction>>{};
    for (final txn in allTxns) {
      if (!categoryIds.contains(txn.categoryId)) continue;
      grouped.putIfAbsent(txn.categoryId, () => []).add(txn);
    }

    await _db.transaction(() async {
      await _db.delete(_db.categoryUsageSlots).go();
      await _db.delete(_db.categoryUsageSummary).go();

      for (final catId in categoryIds) {
        final txns = grouped[catId] ?? [];

        final hourCounts = List<int>.filled(24, 0);
        final weekdayCounts = List<int>.filled(7, 0);
        final amountCounts = List<int>.filled(6, 0);
        int last7d = 0;
        int last30d = 0;
        DateTime? lastUsed;
        final noteTexts = <String>[];

        for (final txn in txns) {
          hourCounts[txn.txnDate.hour]++;
          weekdayCounts[txn.txnDate.weekday % 7]++;
          amountCounts[CategoryUsageProfile.amountToBucket(txn.amountCny.abs())]++;

          if (txn.txnDate.isAfter(sevenDaysAgo)) last7d++;
          if (txn.txnDate.isAfter(thirtyDaysAgo)) last30d++;

          if (lastUsed == null || txn.txnDate.isAfter(lastUsed)) {
            lastUsed = txn.txnDate;
          }
          final note = txn.note;
          if (note.isNotEmpty) noteTexts.add(note);
        }

        await _db.batch((b) {
          for (var i = 0; i < 24; i++) {
            if (hourCounts[i] > 0) {
              b.insert(
                _db.categoryUsageSlots,
                CategoryUsageSlotsCompanion.insert(
                  categoryId: catId,
                  slotType: SlotType.hour,
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
                  slotType: SlotType.weekday,
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
                  slotType: SlotType.amount,
                  slotIndex: i,
                  count: Value(amountCounts[i]),
                ),
              );
            }
          }
        });

        final keywords = extractTopKeywords(noteTexts);

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
  /// 注意：仅更新 total_count 和 last_used_at
  /// last_7d/last_30d 由 refreshRecencyCounts() 定期刷新
  Future<void> onTransactionCreated({
    required String categoryId,
    required DateTime txnDate,
    required int amountCents,
  }) async {
    final hour = txnDate.hour;
    final weekday = txnDate.weekday % 7;
    final bucket = CategoryUsageProfile.amountToBucket(amountCents.abs());

    // Upsert slots — 使用 insertOnConflictUpdate 保持原子性并触发 Stream 通知
    await _upsertSlot(categoryId, SlotType.hour, hour);
    await _upsertSlot(categoryId, SlotType.weekday, weekday);
    await _upsertSlot(categoryId, SlotType.amount, bucket);

    // Upsert summary — 原子 INSERT ON CONFLICT (nit #1)
    await _db.customInsert(
      'INSERT INTO category_usage_summary (category_id, total_count, last_7d_count, last_30d_count, top_keywords, last_used_at, updated_at) '
      'VALUES (?, 1, 0, 0, \'[]\', ?, ?) '
      'ON CONFLICT(category_id) DO UPDATE SET '
      'total_count = total_count + 1, '
      'last_used_at = CASE WHEN excluded.last_used_at > last_used_at THEN excluded.last_used_at ELSE last_used_at END, '
      'updated_at = excluded.updated_at',
      variables: [
        Variable.withString(categoryId),
        Variable.withDateTime(txnDate),
        Variable.withDateTime(DateTime.now()),
      ],
      updates: {_db.categoryUsageSummary},
    );
  }

  /// Upsert slot — 使用 Drift insertOnConflictUpdate 保持原子性（MAJOR #A）
  Future<void> _upsertSlot(String categoryId, String slotType, int slotIndex) async {
    assert(SlotType.all.contains(slotType), 'Invalid slotType: $slotType');

    // 先尝试 insertOnConflictUpdate，但因为需要 count+1 语义，
    // 用 customInsert + updates 声明来确保原子性并触发 Stream 通知
    await _db.customInsert(
      'INSERT INTO category_usage_slots (category_id, slot_type, slot_index, count) '
      'VALUES (?, ?, ?, 1) '
      'ON CONFLICT(category_id, slot_type, slot_index) DO UPDATE SET count = count + 1',
      variables: [
        Variable.withString(categoryId),
        Variable.withString(slotType),
        Variable.withInt(slotIndex),
      ],
      updates: {_db.categoryUsageSlots},
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

    return _buildProfile(categoryId, summary, slots);
  }

  /// 获取所有有使用记录的分类画像
  Future<Map<String, CategoryUsageProfile>> getAllProfiles() async {
    final summaries = await _db.select(_db.categoryUsageSummary).get();
    final allSlots = await _db.select(_db.categoryUsageSlots).get();

    final slotsByCategory = <String, List<CategoryUsageSlot>>{};
    for (final slot in allSlots) {
      slotsByCategory.putIfAbsent(slot.categoryId, () => []).add(slot);
    }

    final profiles = <String, CategoryUsageProfile>{};
    for (final summary in summaries) {
      final catId = summary.categoryId;
      profiles[catId] = _buildProfile(
        catId,
        summary,
        slotsByCategory[catId] ?? [],
      );
    }

    return profiles;
  }

  CategoryUsageProfile _buildProfile(
    String categoryId,
    CategoryUsageSummaryData? summary,
    List<CategoryUsageSlot> slots,
  ) {
    final hourDist = List<int>.filled(24, 0);
    final weekdayDist = List<int>.filled(7, 0);
    final amountDist = List<int>.filled(6, 0);

    for (final slot in slots) {
      switch (slot.slotType) {
        case SlotType.hour:
          if (slot.slotIndex >= 0 && slot.slotIndex < 24) {
            hourDist[slot.slotIndex] = slot.count;
          }
        case SlotType.weekday:
          if (slot.slotIndex >= 0 && slot.slotIndex < 7) {
            weekdayDist[slot.slotIndex] = slot.count;
          }
        case SlotType.amount:
          if (slot.slotIndex >= 0 && slot.slotIndex < 6) {
            amountDist[slot.slotIndex] = slot.count;
          }
        default:
          // 未知 slotType（可能是历史脏数据），静默跳过
          break;
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

  // ──────────── 关键词提取 ────────────

  static const _stopwords = {
    '的', '了', '在', '是', '我', '一', '个', '不', '这', '那',
    '有', '和', '与', '等', '到', '也', '就', '都', '而', '及',
    '年', '月', '日', '号', '时',
  };

  static final _latinRegex = RegExp(r'[a-zA-Z]+');
  static final _cjkStripRegex = RegExp(r'[^\u4e00-\u9fff]');
  static final _punctSpaceRegex = RegExp(r'[\s\p{P}]', unicode: true);
  static final _numericRegex = RegExp(r'^\d+$');
  static final _dateRegex = RegExp(r'^\d{2,4}[/-]\d{1,2}([/-]\d{1,2})?$');

  /// 从交易备注中提取高频关键词
  @visibleForTesting
  static List<String> extractTopKeywords(List<String> allNotes, {int maxCount = 20}) {
    final freq = <String, int>{};

    for (final note in allNotes) {
      if (note.isEmpty) continue;
      final tokens = tokenize(note);
      for (final token in tokens) {
        if (_stopwords.contains(token)) continue;
        if (_isNumericOrDate(token)) continue;
        freq[token] = (freq[token] ?? 0) + 1;
      }
    }

    freq.removeWhere((_, count) => count < 2);

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(maxCount).map((e) => e.key).toList();
  }

  /// 分词器
  @visibleForTesting
  static List<String> tokenize(String text) {
    final tokens = <String>[];

    // 拉丁文单词（>=2 字符）
    for (final m in _latinRegex.allMatches(text)) {
      final word = m.group(0)!;
      if (word.length >= 2) tokens.add(word.toLowerCase());
    }

    // 中文 2-gram
    final cjk = text.replaceAll(_cjkStripRegex, '');
    for (var i = 0; i < cjk.length - 1; i++) {
      tokens.add(cjk.substring(i, i + 2));
    }

    // 完整匹配（备注本身，去空格/标点，2-6 字）
    final clean = text.replaceAll(_punctSpaceRegex, '');
    if (clean.length >= 2 && clean.length <= 6) tokens.add(clean);

    return tokens;
  }

  @visibleForTesting
  static bool isNumericOrDate(String token) => _isNumericOrDate(token);

  static bool _isNumericOrDate(String token) {
    if (_numericRegex.hasMatch(token)) return true;
    if (_dateRegex.hasMatch(token)) return true;
    return false;
  }

  // ──────────── 周期性刷新 ────────────

  /// 刷新 last_7d_count 和 last_30d_count（每天后台运行一次）
  /// 单条 GROUP BY 聚合 + batch UPDATE（无 N+1）
  Future<void> refreshRecencyCounts() async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // 单条 SQL 完成所有分类的 7d/30d 计数
    final rows = await _db.customSelect(
      '''
      SELECT
        category_id,
        SUM(CASE WHEN txn_date >= ? THEN 1 ELSE 0 END) as cnt_7d,
        SUM(CASE WHEN txn_date >= ? THEN 1 ELSE 0 END) as cnt_30d
      FROM transactions
      WHERE deleted_at IS NULL AND txn_date >= ?
      GROUP BY category_id
      ''',
      variables: [
        Variable.withDateTime(sevenDaysAgo),
        Variable.withDateTime(thirtyDaysAgo),
        Variable.withDateTime(thirtyDaysAgo),
      ],
      readsFrom: {_db.transactions},
    ).get();

    final countMap = <String, (int, int)>{};
    for (final row in rows) {
      final catId = row.data['category_id'] as String;
      final cnt7d = row.data['cnt_7d'] as int? ?? 0;
      final cnt30d = row.data['cnt_30d'] as int? ?? 0;
      countMap[catId] = (cnt7d, cnt30d);
    }

    // 批量 UPDATE 只更新 last_7d/last_30d/updated_at（nit #2 — 不覆盖其他字段）
    final summaries = await _db.select(_db.categoryUsageSummary).get();
    await _db.batch((b) {
      for (final summary in summaries) {
        final counts = countMap[summary.categoryId] ?? (0, 0);
        b.customStatement(
          'UPDATE category_usage_summary '
          'SET last_7d_count = ?, last_30d_count = ?, updated_at = ? '
          'WHERE category_id = ?',
          [
            Variable.withInt(counts.$1),
            Variable.withInt(counts.$2),
            Variable.withDateTime(now),
            Variable.withString(summary.categoryId),
          ],
        );
      }
    });
  }
}
