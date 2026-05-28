import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart';
import '../../domain/models/dashboard_models.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/asset_provider.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../../domain/providers/investment_provider.dart';
import '../../domain/providers/loan_provider.dart';

/// 资产 Tab 页 — 净资产 hero + 分组展示（现金/投资/负债/实物资产）。
///
/// 设计意图：用户一眼看清"我有什么、欠什么"，
/// 每个分组可点入对应详情页。
class AssetsTabPage extends ConsumerWidget {
  const AssetsTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dashState = ref.watch(dashboardProvider);
    final accountState = ref.watch(accountProvider);
    final loanState = ref.watch(loanProvider);
    final invState = ref.watch(investmentProvider);
    final assetState = ref.watch(assetProvider);

    final isLoading = dashState.isLoading &&
        accountState.isLoading &&
        loanState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加账户',
            onPressed: () => context.push('/assets/accounts/add'),
          ),
        ],
      ),
      body: isLoading
          ? const SkeletonList(count: 6, itemHeight: 72)
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.read(accountProvider.notifier).refresh(),
                  ref.read(dashboardProvider.notifier).loadAll(),
                  ref.read(loanProvider.notifier).listLoans(),
                  ref.read(investmentProvider.notifier).listInvestments(),
                  ref.read(assetProvider.notifier).listAssets(),
                ]);
              },
              child: CustomScrollView(
                slivers: [
                  // ── Net Worth Hero Card ──
                  SliverToBoxAdapter(
                    child: _NetWorthHero(
                      netWorth: dashState.netWorth,
                      isDark: isDark,
                    ),
                  ),

                  // ── 现金与存款 ──
                  if (accountState.accounts.isNotEmpty) ...[
                    _SectionHeader(
                      title: '现金与存款',
                      icon: Icons.account_balance_wallet_rounded,
                      total: accountState.accounts
                          .fold<int>(0, (s, a) => s + a.balance),
                      color: context.semanticColors.income,
                      onTap: () => context.push('/assets/accounts'),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final account = accountState.accounts[i];
                          return _AccountItem(
                            account: account,
                            isDark: isDark,
                            onTap: () => context
                                .push(AppRouter.accountDetail(account.id)),
                          );
                        },
                        childCount:
                            accountState.accounts.length.clamp(0, 5),
                      ),
                    ),
                    if (accountState.accounts.length > 5)
                      SliverToBoxAdapter(
                        child: _ShowMoreButton(
                          label: '查看全部 ${accountState.accounts.length} 个账户',
                          onTap: () => context.push('/assets/accounts'),
                        ),
                      ),
                  ],

                  // ── 投资 ──
                  if (invState.investments.isNotEmpty) ...[
                    _SectionHeader(
                      title: '投资',
                      icon: Icons.trending_up_rounded,
                      total: invState.portfolio.totalValue,
                      color: context.semanticColors.asset,
                      onTap: () => context.push('/assets/investments'),
                    ),
                    SliverToBoxAdapter(
                      child: _InvestmentSummaryCard(
                        portfolio: invState.portfolio,
                        isDark: isDark,
                        onTap: () => context.push('/assets/investments'),
                      ),
                    ),
                  ],

                  // ── 负债 ──
                  if (loanState.loans.isNotEmpty) ...[
                    _SectionHeader(
                      title: '负债',
                      icon: Icons.credit_card_rounded,
                      total: -loanState.loans.fold<int>(
                          0, (s, l) => s + l.remainingPrincipal),
                      color: context.semanticColors.liability,
                      onTap: () => context.push('/assets/loans'),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final loan = loanState.loans[i];
                          return _LoanItem(
                            loan: loan,
                            isDark: isDark,
                            onTap: () =>
                                context.push(AppRouter.loanDetail(loan.id)),
                          );
                        },
                        childCount: loanState.loans.length.clamp(0, 3),
                      ),
                    ),
                    if (loanState.loans.length > 3)
                      SliverToBoxAdapter(
                        child: _ShowMoreButton(
                          label: '查看全部 ${loanState.loans.length} 笔贷款',
                          onTap: () => context.push('/assets/loans'),
                        ),
                      ),
                  ],

                  // ── 实物资产 ──
                  if (assetState.assets.isNotEmpty) ...[
                    _SectionHeader(
                      title: '实物资产',
                      icon: Icons.home_work_rounded,
                      total: assetState.assets
                          .fold<int>(0, (s, a) => s + a.currentValue),
                      color: ChartColors.slot7,
                      onTap: () => context.push('/assets/fixed'),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final asset = assetState.assets[i];
                          return _FixedAssetItem(
                            asset: asset,
                            isDark: isDark,
                            onTap: () =>
                                context.push(AppRouter.assetDetail(asset.id)),
                          );
                        },
                        childCount: assetState.assets.length.clamp(0, 3),
                      ),
                    ),
                    if (assetState.assets.length > 3)
                      SliverToBoxAdapter(
                        child: _ShowMoreButton(
                          label: '查看全部 ${assetState.assets.length} 项资产',
                          onTap: () => context.push('/assets/fixed'),
                        ),
                      ),
                  ],

                  // ── Empty state ──
                  if (accountState.accounts.isEmpty &&
                      invState.investments.isEmpty &&
                      loanState.loans.isEmpty &&
                      assetState.assets.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.account_balance_wallet_rounded,
                        title: '暂无资产数据',
                        subtitle: '添加账户、投资或贷款开始管理资产',
                        actionLabel: '添加账户',
                        onAction: () => context.push('/assets/accounts/add'),
                      ),
                    ),

                  // Bottom padding for FAB
                  const SliverPadding(
                      padding: EdgeInsets.only(bottom: 96)),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Net Worth Hero Card
// ═══════════════════════════════════════════════════════════════════════

class _NetWorthHero extends StatelessWidget {
  final NetWorthData netWorth;
  final bool isDark;

  const _NetWorthHero({required this.netWorth, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUp = netWorth.changeFromLastMonth >= 0;
    final totalAssets =
        netWorth.cashAndBank + netWorth.investmentValue + netWorth.fixedAssetValue;
    final totalLiabilities = netWorth.loanBalance.abs();

    return Semantics(
      label: '净资产${_fmtWan(netWorth.total)}，'
          '总资产${_fmtWan(totalAssets)}，负债${_fmtWan(totalLiabilities)}，'
          '较上月${isUp ? "增加" : "减少"}${_fmtWan(netWorth.changeFromLastMonth.abs())}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          SpacingTokens.base,
          SpacingTokens.sm,
          SpacingTokens.base,
          SpacingTokens.base,
        ),
        padding: const EdgeInsets.all(SpacingTokens.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [DarkCardGradients.netWorthStart, DarkCardGradients.netWorthEnd]
                : [ColorTokens.primary, GradientTokens.primaryGradientSoft],
          ),
          borderRadius: BorderRadius.circular(RadiusTokens.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Text(
              '净资产',
              style: TypographyTokens.bodySm(
                  color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: SpacingTokens.xs),
            // Amount
            AnimatedCounter(
              value: netWorth.total,
              prefix: '¥',
              useWanUnit: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            // Month-over-month change
            Row(
              children: [
                Icon(
                  isUp
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
                Text(
                  '较上月 ${isUp ? "+" : ""}${_fmtWan(netWorth.changeFromLastMonth)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (netWorth.changePercent != 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isUp ? "+" : ""}${(netWorth.changePercent * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: SpacingTokens.base),
            // Assets vs Liabilities bar
            _AssetLiabilityBar(
              totalAssets: totalAssets,
              totalLiabilities: totalLiabilities,
            ),
            const SizedBox(height: SpacingTokens.sm),
            // Legend row
            Row(
              children: [
                _LegendDot(color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 4),
                Text(
                  '资产 ¥${_fmtWan(totalAssets)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                _LegendDot(
                    color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text(
                  '负债 ¥${_fmtWan(totalLiabilities)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtWan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }
}

class _AssetLiabilityBar extends StatelessWidget {
  final int totalAssets;
  final int totalLiabilities;

  const _AssetLiabilityBar({
    required this.totalAssets,
    required this.totalLiabilities,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalAssets + totalLiabilities;
    final assetRatio = total > 0 ? totalAssets / total : 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: (assetRatio * 100).round().clamp(1, 99),
              child: Container(
                  color: Colors.white.withValues(alpha: 0.9)),
            ),
            Expanded(
              flex: ((1 - assetRatio) * 100).round().clamp(1, 99),
              child: Container(
                  color: Colors.white.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Section Header (sliver)
// ═══════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int total;
  final Color color;
  final VoidCallback? onTap;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.total,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = total < 0;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpacingTokens.base,
          SpacingTokens.lg,
          SpacingTokens.base,
          SpacingTokens.sm,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RadiusTokens.sm),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: SpacingTokens.sm),
              Text(
                title,
                style: TypographyTokens.titleMd().copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${isNegative ? "-" : ""}¥${formatCentsCompact(total.abs())}',
                style: TypographyTokens.bodyMd().copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Account Item
// ═══════════════════════════════════════════════════════════════════════

class _AccountItem extends StatelessWidget {
  final Account account;
  final bool isDark;
  final VoidCallback? onTap;

  const _AccountItem({
    required this.account,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = account.balance >= 0;
    final amountColor = isPositive
        ? context.semanticColors.income
        : context.semanticColors.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
      child: Card(
        margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.base,
              vertical: SpacingTokens.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? NeutralColorsDark.neutral2
                        : NeutralColorsLight.neutral2,
                    borderRadius: BorderRadius.circular(RadiusTokens.md),
                  ),
                  child: Center(
                    child: Text(account.icon,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Text(
                    account.name,
                    style: TypographyTokens.bodyMd().copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '¥${formatCentsCompact(account.balance)}',
                  style: TypographyTokens.amount(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Investment Summary Card
// ═══════════════════════════════════════════════════════════════════════

class _InvestmentSummaryCard extends StatelessWidget {
  final PortfolioSummary portfolio;
  final bool isDark;
  final VoidCallback onTap;

  const _InvestmentSummaryCard({
    required this.portfolio,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final isUp = portfolio.totalProfit >= 0;
    final profitColor = isUp ? colors.income : colors.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.base),
            child: Row(
              children: [
                // Left: total value
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '总市值',
                        style: TypographyTokens.caption(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${_fmtCompact(portfolio.totalValue)}',
                        style: TypographyTokens.headlineMd().copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${portfolio.holdings.length} 只持仓',
                        style: TypographyTokens.caption(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: profit
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '累计收益',
                      style: TypographyTokens.caption(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isUp ? "+" : ""}¥${_fmtCompact(portfolio.totalProfit)}',
                      style: TypographyTokens.titleLg().copyWith(
                        fontWeight: FontWeight.w700,
                        color: profitColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: profitColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isUp ? "+" : ""}${(portfolio.totalReturn * 100).toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: profitColor,
                        ),
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

  String _fmtCompact(int cents) {
    final yuan = cents.abs() / 100;
    final sign = cents < 0 ? '-' : '';
    if (yuan >= 10000) {
      return '$sign${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return '$sign${yuan.toStringAsFixed(2)}';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Loan Item
// ═══════════════════════════════════════════════════════════════════════

class _LoanItem extends StatelessWidget {
  final Loan loan;
  final bool isDark;
  final VoidCallback? onTap;

  const _LoanItem({
    required this.loan,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final progress = loan.principal > 0
        ? (loan.principal - loan.remainingPrincipal) / loan.principal
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
      child: Card(
        margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.base,
              vertical: SpacingTokens.md,
            ),
            child: Row(
              children: [
                // Progress indicator
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3.5,
                        backgroundColor: isDark
                            ? NeutralColorsDark.neutral3
                            : NeutralColorsLight.neutral3,
                        valueColor: AlwaysStoppedAnimation(colors.liability),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                // Name + info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.name,
                        style: TypographyTokens.bodyMd().copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${loan.paidMonths}/${loan.totalMonths}期 · ${loan.annualRate.toStringAsFixed(2)}%',
                        style: TypographyTokens.caption(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Remaining principal
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${_fmtCompact(loan.remainingPrincipal)}',
                      style: TypographyTokens.amount(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.liability,
                      ),
                    ),
                    Text(
                      '剩余本金',
                      style: TypographyTokens.caption(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
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

  String _fmtCompact(int cents) {
    final yuan = cents / 100;
    if (yuan >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Fixed Asset Item
// ═══════════════════════════════════════════════════════════════════════

class _FixedAssetItem extends StatelessWidget {
  final AssetDisplayItem asset;
  final bool isDark;
  final VoidCallback? onTap;

  const _FixedAssetItem({
    required this.asset,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valueChange = asset.currentValue - asset.purchasePrice;
    final isAppreciated = valueChange >= 0;
    final valueColor = isAppreciated
        ? context.semanticColors.income
        : context.semanticColors.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
      child: Card(
        margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.base,
              vertical: SpacingTokens.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? NeutralColorsDark.neutral2
                        : NeutralColorsLight.neutral2,
                    borderRadius: BorderRadius.circular(RadiusTokens.md),
                  ),
                  child: Icon(
                    _assetTypeIcon(asset.assetType),
                    size: 20,
                    color: ChartColors.slot7,
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        style: TypographyTokens.bodyMd().copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _assetTypeLabel(asset.assetType),
                        style: TypographyTokens.caption(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '¥${_fmtCompact(asset.currentValue)}',
                  style: TypographyTokens.amount(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _assetTypeIcon(String type) {
    switch (type) {
      case 'real_estate':
        return Icons.home_rounded;
      case 'vehicle':
        return Icons.directions_car_rounded;
      case 'electronics':
        return Icons.devices_rounded;
      case 'jewelry':
        return Icons.diamond_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  String _assetTypeLabel(String type) {
    switch (type) {
      case 'real_estate':
        return '房产';
      case 'vehicle':
        return '车辆';
      case 'electronics':
        return '电子设备';
      case 'jewelry':
        return '珠宝首饰';
      case 'furniture':
        return '家具家电';
      case 'collectible':
        return '收藏品';
      default:
        return '其他';
    }
  }

  String _fmtCompact(int cents) {
    final yuan = cents / 100;
    if (yuan >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Show More Button
// ═══════════════════════════════════════════════════════════════════════

class _ShowMoreButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ShowMoreButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.base,
        vertical: SpacingTokens.xs,
      ),
      child: TextButton(
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
