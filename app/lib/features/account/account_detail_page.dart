import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/transaction_flow_provider.dart';
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

  /// Reload transactions when transaction state changes (new/edited/deleted).
  @override
  void didUpdateWidget(covariant AccountDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) {
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    final db = ref.read(databaseProvider);
    final txns = await db.getTransactionsByAccountId(widget.accountId);
    if (mounted) {
      setState(() {
        _transactions = txns;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reload when global transaction state changes (add/edit/delete elsewhere)
    ref.listen(transactionProvider, (_, __) => _loadTransactions());

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

    final categoryMap = ref.watch(flowCategoryMapProvider);

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
          SliverToBoxAdapter(child: _AccountInfoCard(account: account)),
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: SpacingTokens.sm),
                      Text(
                        '暂无交易记录',
                        style: TypographyTokens.bodySm(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final txn = _transactions[index];
                final category = categoryMap[txn.categoryId];
                return _TransactionListItem(
                  transaction: txn,
                  category: category,
                );
              }, childCount: _transactions.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Transaction List Item ───

class _TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final Category? category;

  const _TransactionListItem({
    required this.transaction,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.amount > 0;
    final amountColor = isIncome
        ? context.semanticColors.income
        : context.semanticColors.expense;

    final categoryLabel = category?.name ?? '未分类';
    final categoryInitial = categoryLabel.isNotEmpty
        ? categoryLabel.characters.first
        : '?';

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: isDark
            ? NeutralColorsDark.neutral2
            : NeutralColorsLight.neutral2,
        child: Text(categoryInitial, style: const TextStyle(fontSize: 16)),
      ),
      title: Text(categoryLabel, style: TypographyTokens.bodyMd()),
      subtitle: transaction.note.isNotEmpty
          ? Text(
              transaction.note,
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
        formatCents(transaction.amount, showSign: true),
        style: TypographyTokens.amount(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: amountColor,
        ),
      ),
    );
  }
}

// ─── Account Info Card ───

class _AccountInfoCard extends StatelessWidget {
  final Account account;

  const _AccountInfoCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = account.balance >= 0;
    final amountColor = isPositive
        ? context.semanticColors.income
        : context.semanticColors.expense;

    return Container(
      margin: const EdgeInsets.all(SpacingTokens.base),
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: isDark
            ? NeutralColorsDark.neutral2
            : NeutralColorsLight.neutral1,
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
                      accountTypeDisplayName(account.accountType),
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
                '¥ ${formatCents(account.balance, showSign: true)}',
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
}

/// 账户类型的显示名称映射。
const _accountTypeLabels = <String, String>{
  'cash': '现金',
  'debit': '储蓄卡',
  'credit': '信用卡',
  'alipay': '支付宝',
  'wechat': '微信',
  'investment': '投资账户',
};

/// 获取账户类型的中文标签。
String accountTypeDisplayName(String type) => _accountTypeLabels[type] ?? '其他';
