import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../sync/sync_engine.dart';
import 'widgets/balance_card.dart';
import 'widgets/transaction_list_item.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // 启动同步引擎
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncEngineProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final txnState = ref.watch(transactionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyLedger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRouter.login);
              }
            },
          ),
        ],
      ),
      body: txnState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(syncEngineProvider).syncNow();
              },
              child: CustomScrollView(
                slivers: [
                  // Balance card
                  SliverToBoxAdapter(
                    child: BalanceCard(
                      totalBalance: txnState.totalBalance,
                      todayExpense: txnState.todayExpense,
                      monthExpense: txnState.monthExpense,
                    ),
                  ),
                  // Section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text(
                        '最近交易',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Transaction list
                  if (txnState.transactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(theme: theme),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final txn = txnState.transactions[index];
                          // 找到对应分类
                          final allCats = [
                            ...txnState.expenseCategories,
                            ...txnState.incomeCategories,
                          ];
                          final cat = allCats
                              .where((c) => c.id == txn.categoryId)
                              .firstOrNull;
                          return TransactionListItem(
                            transaction: txn,
                            categoryName: cat?.name ?? '未知',
                            categoryIcon: cat?.icon ?? '📦',
                          );
                        },
                        childCount: txnState.transactions.length,
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRouter.addTransaction);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('记一笔'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有交易记录',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮开始记账',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
