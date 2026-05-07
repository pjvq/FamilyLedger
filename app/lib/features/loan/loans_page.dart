import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart' as db;
import '../../core/widgets/widgets.dart';
import '../../domain/providers/loan_provider.dart';

class LoansPage extends ConsumerWidget {
  const LoansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    developer.log('[LoansPage] build called');
    final loanState = ref.watch(loanProvider);
    developer.log('[LoansPage] loanState: isLoading=${loanState.isLoading}, loans=${loanState.loans.length}, groups=${loanState.loanGroups.length}');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasData =
        loanState.loans.isNotEmpty || loanState.loanGroups.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('贷款管理'),
      ),
      body: loanState.isLoading && !hasData
          ? const SkeletonList(count: 5, itemHeight: 80)
          : loanState.error != null && !hasData
              ? ErrorState(
                  message: loanState.error!,
                  onRetry: () => ref.read(loanProvider.notifier).loadAll(),
                )
              : !hasData
              ? _EmptyState(theme: theme)
              : CustomRefreshIndicator(
                  onRefresh: () =>
                      ref.read(loanProvider.notifier).loadAll(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // Loan groups (combined loans)
                      ...loanState.loanGroups.map((group) =>
                          _LoanGroupCard(
                            group: group,
                            notifier: ref.read(loanProvider.notifier),
                            isDark: isDark,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRouter.loanGroupDetail,
                                arguments: group.group.id,
                              );
                            },
                          )),
                      // Standalone loans
                      ...loanState.loans.map((loan) => _LoanCard(
                            loan: loan,
                            notifier: ref.read(loanProvider.notifier),
                            isDark: isDark,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRouter.loanDetail,
                                arguments: loan.id,
                              );
                            },
                          )),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed(AppRouter.addLoan),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加贷款'),
      ),
    );
  }
}

// ── Loan Type Helpers ──

class LoanTypeInfo {
  final String label;
  final String emoji;
  final Color color;

  const LoanTypeInfo(this.label, this.emoji, this.color);
}

LoanTypeInfo getLoanTypeInfo(String type) {
  switch (type) {
    case 'mortgage':
      return const LoanTypeInfo('房贷', '🏠', Color(0xFF5B6EF5));
    case 'car_loan':
      return const LoanTypeInfo('车贷', '🚗', Color(0xFF34C759));
    case 'credit_card':
      return const LoanTypeInfo('信用卡', '💳', Color(0xFFFF9500));
    case 'consumer':
      return const LoanTypeInfo('消费贷', '💰', Color(0xFFFF6B6B));
    case 'business':
      return const LoanTypeInfo('经营贷', '🏢', Color(0xFFAF52DE));
    default:
      return const LoanTypeInfo('其他', '📋', Color(0xFF8E8E93));
  }
}

// ── Combined Loan Group Card ──

class _LoanGroupCard extends StatelessWidget {
  final LoanGroupDisplayItem group;
  final LoanNotifier notifier;
  final bool isDark;
  final VoidCallback onTap;

  const _LoanGroupCard({
    required this.group,
    required this.notifier,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comLoan = group.commercialLoan;
    final pvdLoan = group.providentLoan;
    final typeInfo = getLoanTypeInfo(group.group.loanType);

    // Commercial and provident monthly payments
    final comMonthly = comLoan != null ? notifier.getMonthlyPayment(comLoan) : 0;
    final pvdMonthly = pvdLoan != null ? notifier.getMonthlyPayment(pvdLoan) : 0;

    // Progress
    final comProgress = comLoan != null && comLoan.totalMonths > 0
        ? comLoan.paidMonths / comLoan.totalMonths
        : 0.0;
    final pvdProgress = pvdLoan != null && pvdLoan.totalMonths > 0
        ? pvdLoan.paidMonths / pvdLoan.totalMonths
        : 0.0;

    final comPrincipalWan = comLoan != null
        ? (comLoan.principal / 100 / 10000).toStringAsFixed(0)
        : '0';
    final pvdPrincipalWan = pvdLoan != null
        ? (pvdLoan.principal / 100 / 10000).toStringAsFixed(0)
        : '0';

    return Semantics(
      label: '${group.group.name}，组合贷，'
          '商贷$comPrincipalWan万加公积金$pvdPrincipalWan万，'
          '总月供${_formatCents(group.totalMonthlyPayment)}元',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: name + combined badge
                Row(
                  children: [
                    Text('🏘️', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.group.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeInfo.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '组合贷',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: typeInfo.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Builder(builder: (_) {
                                final isFamily = group.subLoans.isNotEmpty &&
                                    group.subLoans.first.familyId.isNotEmpty;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isFamily
                                        ? Colors.blue.withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isFamily ? Icons.family_restroom : Icons.person,
                                        size: 11,
                                        color: isFamily ? Colors.blue : Colors.grey,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        isFamily ? '家庭' : '个人',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: isFamily ? Colors.blue : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '商贷 $comPrincipalWan万 + 公积金 $pvdPrincipalWan万',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Total remaining
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '剩余本金',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          '¥${_formatCents(group.totalRemainingPrincipal)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark
                                ? AppColors.liabilityDark
                                : AppColors.liability,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Two-color progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        // Commercial progress (deep blue)
                        if (comLoan != null)
                          Expanded(
                            flex: comLoan.principal,
                            child: LinearProgressIndicator(
                              value: comProgress,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? const Color(0xFF3A3A3C)
                                  : const Color(0xFFE5E5EA),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF3D5AFE),
                              ),
                            ),
                          ),
                        if (comLoan != null && pvdLoan != null)
                          const SizedBox(width: 2),
                        // Provident progress (light blue)
                        if (pvdLoan != null)
                          Expanded(
                            flex: pvdLoan.principal,
                            child: LinearProgressIndicator(
                              value: pvdProgress,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? const Color(0xFF3A3A3C)
                                  : const Color(0xFFE5E5EA),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF448AFF),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Legend
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D5AFE),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('商贷',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4))),
                    const SizedBox(width: 12),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF448AFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('公积金',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4))),
                  ],
                ),
                const SizedBox(height: 10),
                // Bottom: monthly payment breakdown
                Row(
                  children: [
                    _InfoChip(
                      label: '总月供',
                      value:
                          '¥${_formatCents(group.totalMonthlyPayment)}',
                      theme: theme,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '(商贷 ¥${_formatCents(comMonthly)} + 公积金 ¥${_formatCents(pvdMonthly)})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Standalone Loan Card ──

class _LoanCard extends StatelessWidget {
  final db.Loan loan;
  final LoanNotifier notifier;
  final bool isDark;
  final VoidCallback onTap;

  const _LoanCard({
    required this.loan,
    required this.notifier,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeInfo = getLoanTypeInfo(loan.loanType);
    final monthlyPayment = notifier.getMonthlyPayment(loan);
    final nextPayment = notifier.getNextPaymentDate(loan);
    final progress = loan.totalMonths > 0
        ? loan.paidMonths / loan.totalMonths
        : 0.0;

    return Semantics(
      label: '${loan.name}，${typeInfo.label}，剩余本金${_formatCents(loan.remainingPrincipal)}元，'
          '还款进度第${loan.paidMonths}期共${loan.totalMonths}期',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: name + type badge
                Row(
                  children: [
                    Text(
                      typeInfo.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeInfo.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  typeInfo.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: typeInfo.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: loan.familyId.isNotEmpty
                                      ? Colors.blue.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      loan.familyId.isNotEmpty
                                          ? Icons.family_restroom
                                          : Icons.person,
                                      size: 11,
                                      color: loan.familyId.isNotEmpty
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      loan.familyId.isNotEmpty
                                          ? '家庭'
                                          : '个人',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: loan.familyId.isNotEmpty
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Remaining principal
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '剩余本金',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          '¥${_formatCents(loan.remainingPrincipal)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark
                                ? AppColors.liabilityDark
                                : AppColors.liability,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFE5E5EA),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Bottom row: monthly payment + progress + next date
                Row(
                  children: [
                    _InfoChip(
                      label: '月供',
                      value: '¥${_formatCents(monthlyPayment)}',
                      theme: theme,
                    ),
                    const SizedBox(width: 16),
                    _InfoChip(
                      label: '进度',
                      value: '第 ${loan.paidMonths}/${loan.totalMonths} 期',
                      theme: theme,
                    ),
                    const Spacer(),
                    if (nextPayment != null)
                      Text(
                        '下次 ${DateFormat('MM/dd').format(nextPayment)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ── Empty State ──

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
            Icons.account_balance_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无贷款记录',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持商业贷款、公积金贷款、组合贷款',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──

String _formatCents(int cents) {
  final yuan = cents / 100;
  if (yuan >= 10000) {
    final wan = yuan / 10000;
    if (wan == wan.truncateToDouble()) {
      return '${wan.toInt()}万';
    }
    return '${wan.toStringAsFixed(2)}万';
  }
  final formatter = NumberFormat('#,##0.00');
  return formatter.format(yuan);
}
