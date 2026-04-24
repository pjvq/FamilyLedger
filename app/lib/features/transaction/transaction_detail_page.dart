import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../../domain/providers/account_provider.dart';

/// 交易详情页面参数
class TransactionDetailArgs {
  final Transaction transaction;
  final Category? category;

  const TransactionDetailArgs({
    required this.transaction,
    this.category,
  });
}

class TransactionDetailPage extends ConsumerWidget {
  final TransactionDetailArgs args;

  const TransactionDetailPage({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txn = args.transaction;
    final category = args.category;
    final isIncome = txn.type == 'income';

    // 获取账户名称
        // 获取账户名称
    final accountState = ref.watch(accountProvider);
    final account = accountState.accounts.where((a) => a.id == txn.accountId).firstOrNull;
    final accountName = account?.name ?? txn.accountId;

    final amountColor = isIncome
        ? (isDark ? AppColors.incomeDark : AppColors.income)
        : (isDark ? AppColors.expenseDark : AppColors.expense);
    final prefix = isIncome ? '+' : '-';
    final yuan = txn.amountCny / 100;
    final amountText = yuan == yuan.truncateToDouble()
        ? '${yuan.toInt()}'
        : yuan.toStringAsFixed(2);

    return Semantics(
      label: '交易详情页面',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('交易详情'),
          centerTitle: false,
          actions: [
            Semantics(
              button: true,
              label: '编辑交易',
              child: IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑',
                onPressed: () async {
                  final edited = await Navigator.of(context)
                      .pushNamed(AppRouter.addTransaction, arguments: txn);
                  if (edited == true && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
        body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // ── 大金额显示 ──
                  Semantics(
                    label: '金额 $amountText元',
                    child: SharedElement(
                      tag: HeroTags.transaction(txn.id),
                      child: Text(
                        '$prefix¥$amountText',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: amountColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  if (txn.currency != 'CNY') ...[
                    const SizedBox(height: 4),
                    Text(
                      '${txn.currency} ${txn.amount / 100}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── 分类卡片 ──
                  Semantics(
                    label: '分类：${category?.name ?? "未分类"}，${isIncome ? "收入" : "支出"}',
                    child: _buildCard(
                      isDark: isDark,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3A3A3C)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              category?.icon ?? '📦',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category?.name ?? '未分类',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isIncome ? '收入' : '支出',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── 详情卡片 ──
                  _buildCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _detailRow(
                          isDark: isDark,
                          icon: Icons.access_time_rounded,
                          label: '时间',
                          value: DateFormat('yyyy-MM-dd HH:mm')
                              .format(txn.txnDate),
                        ),
                        _divider(isDark),
                        _detailRow(
                          isDark: isDark,
                          icon: Icons.account_balance_wallet_outlined,
                          label: '账户',
                          value: accountName,
                        ),
                        if (txn.note.isNotEmpty) ...[
                          _divider(isDark),
                          _detailRow(
                            isDark: isDark,
                            icon: Icons.note_outlined,
                            label: '备注',
                            value: txn.note,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── 标签 ──
                  if (txn.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.label_outline_rounded,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                '标签',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _parseTags(txn.tags)
                                .map(
                                  (tag) => Chip(
                                    label: Text(tag,
                                        style: const TextStyle(fontSize: 13)),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── 图片 ──
                  if (txn.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.photo_library_outlined,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                '图片',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 80,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _parseImageUrls(txn.imageUrls)
                                  .map(
                                    (path) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                            width: 80,
                                            height: 80,
                                            color: isDark
                                                ? const Color(0xFF3A3A3C)
                                                : const Color(0xFFF2F2F7),
                                            alignment: Alignment.center,
                                            child: const Icon(
                                                Icons.broken_image_outlined,
                                                size: 28),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── 底部删除按钮 ──
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Semantics(
                button: true,
                label: '删除交易',
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeleteConfirm(context, ref, txn),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text('删除交易'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? AppColors.expenseDark : AppColors.expense,
                      side: BorderSide(
                        color: (isDark ? AppColors.expenseDark : AppColors.expense)
                            .withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: isDark
            ? null
            : Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }

  Widget _detailRow({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color:
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: isDark ? AppColors.dividerDark : AppColors.divider,
    );
  }

  List<String> _parseTags(String tags) {
    if (tags.isEmpty) return [];
    try {
      final decoded = jsonDecode(tags);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    // Fallback: comma-separated or single tag
    return tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  List<String> _parseImageUrls(String urls) {
    if (urls.isEmpty) return [];
    try {
      final decoded = jsonDecode(urls);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }

  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, Transaction txn) {
    final yuan = txn.amountCny / 100;
    final amountText = yuan == yuan.truncateToDouble()
        ? '${yuan.toInt()}'
        : yuan.toStringAsFixed(2);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('确定删除这笔交易？'),
        content: Text(
          '${txn.type == 'income' ? '收入' : '支出'} ¥$amountText',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(transactionProvider.notifier)
                  .deleteTransaction(txn.id);
              // 刷新 Dashboard 和 Account
              ref.read(dashboardProvider.notifier).loadAll();
              ref.read(accountProvider.notifier).refresh();
              if (context.mounted) {
                Navigator.of(context).pop(); // 返回列表页
              }
            },
          ),
        ],
      ),
    );
  }
}
