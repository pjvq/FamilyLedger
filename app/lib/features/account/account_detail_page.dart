import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/transaction_provider.dart';

/// 账户详情页 — 展示账户信息及最近交易。
class AccountDetailPage extends ConsumerStatefulWidget {
  final String accountId;
  const AccountDetailPage({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final db = ref.read(databaseProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final familyId = ref.read(currentFamilyIdProvider);
    // Get recent transactions and filter by this account
    final allTxns = await db.getTransactionPage(
      userId,
      familyId: familyId,
      limit: 50,
      offset: 0,
    );
    final filtered = allTxns
        .where((t) => t.accountId == widget.accountId && t.deletedAt == null)
        .toList();
    if (mounted) {
      setState(() {
        _transactions = filtered;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accountState = ref.watch(accountProvider);
    final account = accountState.accounts
        .where((a) => a.id == widget.accountId)
        .firstOrNull;

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('账户详情')),
        body: const ErrorState(message: '账户不存在'),
      );
    }

    final txnState = ref.watch(transactionProvider);
    final categories = [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: '编辑账户',
            onPressed: () {
              // TODO: Navigate to edit account page
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Account info card
          SliverToBoxAdapter(
            child: _AccountInfoCard(
              account: account,
              isDark: isDark,
            ),
          ),
          // Recent transactions header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.base,
                SpacingTokens.lg,
                SpacingTokens.base,
                SpacingTokens.sm,
              ),
              child: Text(
                '最近交易',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Transaction list
          if (_isLoading)
            const SliverToBoxAdapter(
              child: SkeletonList(count: 5, itemHeight: 64),
            )
          else if (_transactions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.xl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      Text(
                        '暂无交易记录',
                        style: TypographyTokens.bodySm(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final txn = _transactions[index];
                  final category = categories
                      .where((c) => c.id == txn.categoryId)
                      .firstOrNull;
                  final isIncome = txn.amount > 0;
                  final amountColor = isIncome
                      ? (isDark ? SemanticColorsDark.income : SemanticColorsLight.income)
                      : (isDark ? SemanticColorsDark.expense : SemanticColorsLight.expense);
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark
                          ? NeutralColorsDark.neutral2
                          : NeutralColorsLight.neutral2,
                      child: Text(
                        category?.name.characters.first ?? '?',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    title: Text(
                      category?.name ?? '未分类',
                      style: TypographyTokens.bodyMd(),
                    ),
                    subtitle: txn.note.isNotEmpty
                        ? Text(
                            txn.note,
                            style: TypographyTokens.caption(
                              color: isDark
                                  ? NeutralColorsDark.neutral4
                                  : NeutralColorsLight.neutral4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: Text(
                      formatCents(txn.amount, showSign: true),
                      style: TypographyTokens.amount(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: amountColor,
                      ),
                    ),
                  );
                },
                childCount: _transactions.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Account Info Card ───

class _AccountInfoCard extends StatelessWidget {
  final Account account;
  final bool isDark;

  const _AccountInfoCard({
    required this.account,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = account.balance >= 0;
    final amountColor = isPositive
        ? (isDark ? SemanticColorsDark.income : SemanticColorsLight.income)
        : (isDark ? SemanticColorsDark.expense : SemanticColorsLight.expense);

    return Container(
      margin: const EdgeInsets.all(SpacingTokens.base),
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: isDark ? NeutralColorsDark.neutral2 : NeutralColorsLight.neutral1,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        border: Border.all(
          color: isDark
              ? NeutralColorsDark.neutral3
              : NeutralColorsLight.neutral3,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Icon + name
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? NeutralColorsDark.neutral3
                      : NeutralColorsLight.neutral2,
                  borderRadius: BorderRadius.circular(RadiusTokens.md),
                ),
                child: Center(
                  child: Text(
                    account.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: SpacingTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: TypographyTokens.bodyLg().copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _accountTypeLabel(account.accountType),
                      style: TypographyTokens.caption(
                        color: isDark
                            ? NeutralColorsDark.neutral4
                            : NeutralColorsLight.neutral4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.lg),
          // Balance
          Row(
            children: [
              Text(
                '余额',
                style: TypographyTokens.bodySm(
                  color: isDark
                      ? NeutralColorsDark.neutral4
                      : NeutralColorsLight.neutral4,
                ),
              ),
              const Spacer(),
              Text(
                '¥ ${formatCentsCompact(account.balance)}',
                style: TypographyTokens.amount(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _accountTypeLabel(String type) {
    switch (type) {
      case 'cash':
        return '现金';
      case 'debit':
        return '储蓄卡';
      case 'credit':
        return '信用卡';
      case 'alipay':
        return '支付宝';
      case 'wechat':
        return '微信';
      case 'investment':
        return '投资账户';
      default:
        return '其他';
    }
  }
}
