import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/database.dart' show Loan;
import '../../domain/models/loan_models.dart' show LoanGroupDisplayItem;
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/asset_provider.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../../domain/providers/investment_provider.dart';
import '../../domain/providers/loan_provider.dart';
import 'widgets/net_worth_hero.dart';
import 'widgets/section_header.dart';
import 'widgets/account_item.dart';
import 'widgets/investment_summary_card.dart';
import 'widgets/loan_item.dart';
import 'widgets/loan_group_item.dart';
import 'widgets/fixed_asset_item.dart';
import 'widgets/show_more_button.dart';

/// 资产 Tab 页 — 净资产 hero + 分组展示（现金/投资/负债/实物资产）。
///
/// 设计意图：用户一眼看清"我有什么、欠什么"，
/// 每个分组可点入对应详情页。
///
/// 各 section 用 [Consumer] 包裹独立 watch，避免全页 rebuild (review #7)。
class AssetsTabPage extends StatelessWidget {
  const AssetsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '添加账户',
            onPressed: () => context.push(AppRouter.addAccount),
          ),
        ],
      ),
      body: const _AssetsBody(),
    );
  }
}

class _AssetsBody extends ConsumerWidget {
  const _AssetsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only use dashboard loading for the initial full-screen skeleton.
    // Each section handles its own empty/loading state independently.
    final dashLoading = ref.watch(
      dashboardProvider.select((s) => s.isLoading && s.netWorth.total == 0),
    );

    if (dashLoading) {
      return const SkeletonList(count: 6, itemHeight: 72);
    }

    return CustomRefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(accountProvider.notifier).refresh(),
          ref.read(dashboardProvider.notifier).loadAll(),
          // loadAll() = standalone loans + loan groups。
          // 负债总额需要组合贷（loan group）的剩余本金，
          // 以前只调 listLoans() 会漏掉组合贷。
          ref.read(loanProvider.notifier).loadAll(),
          ref.read(investmentProvider.notifier).listInvestments(),
          ref.read(assetProvider.notifier).listAssets(),
        ]);
      },
      child: CustomScrollView(
        slivers: [
          // ── Net Worth Hero ──
          Consumer(
            builder: (ctx, ref, _) {
              final netWorth = ref.watch(
                dashboardProvider.select((s) => s.netWorth),
              );
              return SliverToBoxAdapter(
                child: NetWorthHero(netWorth: netWorth),
              );
            },
          ),

          // ── 现金与存款 ──
          Consumer(
            builder: (ctx, ref, _) {
              final accounts = ref.watch(
                accountProvider.select((s) => s.accounts),
              );
              if (accounts.isEmpty)
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              return _AccountsSection(accounts: accounts);
            },
          ),

          // ── 投资 ──
          Consumer(
            builder: (ctx, ref, _) {
              final portfolio = ref.watch(
                investmentProvider.select((s) => s.portfolio),
              );
              final hasInvestments = ref.watch(
                investmentProvider.select((s) => s.investments.isNotEmpty),
              );
              if (!hasInvestments)
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              return _InvestmentSection(portfolio: portfolio);
            },
          ),

          // ── 负债 ──
          Consumer(
            builder: (ctx, ref, _) {
              final loans = ref.watch(loanProvider.select((s) => s.loans));
              final loanGroups = ref.watch(
                loanProvider.select((s) => s.loanGroups),
              );
              // 独立贷款和组合贷任一非空都要展示负债区。
              if (loans.isEmpty && loanGroups.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return _LoanSection(loans: loans, loanGroups: loanGroups);
            },
          ),

          // ── 实物资产 ──
          Consumer(
            builder: (ctx, ref, _) {
              final assets = ref.watch(assetProvider.select((s) => s.assets));
              if (assets.isEmpty)
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              return _FixedAssetSection(assets: assets);
            },
          ),

          // ── Empty state ──
          Consumer(
            builder: (ctx, ref, _) {
              final hasAccounts = ref.watch(
                accountProvider.select((s) => s.accounts.isNotEmpty),
              );
              final hasInvestments = ref.watch(
                investmentProvider.select((s) => s.investments.isNotEmpty),
              );
              final hasLoans = ref.watch(
                loanProvider.select((s) => s.loans.isNotEmpty),
              );
              final hasAssets = ref.watch(
                assetProvider.select((s) => s.assets.isNotEmpty),
              );

              if (hasAccounts || hasInvestments || hasLoans || hasAssets) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.account_balance_wallet_rounded,
                  title: '暂无资产数据',
                  subtitle: '添加账户、投资或贷款开始管理资产',
                  actionLabel: '添加账户',
                  onAction: () => ctx.push(AppRouter.addAccount),
                ),
              );
            },
          ),

          // Bottom padding for FAB
          const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
        ],
      ),
    );
  }
}

// ─── Section Wrappers (multi-sliver) ───

class _AccountsSection extends StatelessWidget {
  final List accounts;
  const _AccountsSection({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<int>(0, (s, a) => s + (a.balance as int));
    final displayCount = accounts.length.clamp(0, 5);

    return SliverMainAxisGroup(
      slivers: [
        SectionHeader(
          title: '现金与存款',
          icon: Icons.account_balance_wallet_rounded,
          total: total,
          color: context.semanticColors.income,
          onTap: () => context.push(AppRouter.accounts),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => AccountItem(
              account: accounts[i],
              onTap: () => ctx.push(AppRouter.accountDetail(accounts[i].id)),
            ),
            childCount: displayCount,
          ),
        ),
        if (accounts.length > 5)
          SliverToBoxAdapter(
            child: ShowMoreButton(
              label: '查看全部 ${accounts.length} 个账户',
              onTap: () => context.push(AppRouter.accounts),
            ),
          ),
      ],
    );
  }
}

class _InvestmentSection extends StatelessWidget {
  final PortfolioSummary portfolio;
  const _InvestmentSection({required this.portfolio});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SectionHeader(
          title: '投资',
          icon: Icons.trending_up_rounded,
          total: portfolio.totalValue,
          color: context.semanticColors.asset,
          onTap: () => context.push(AppRouter.investments),
        ),
        SliverToBoxAdapter(
          child: InvestmentSummaryCard(
            portfolio: portfolio,
            onTap: () => context.push(AppRouter.investments),
          ),
        ),
      ],
    );
  }
}

class _LoanSection extends StatelessWidget {
  final List<Loan> loans;
  final List<LoanGroupDisplayItem> loanGroups;
  const _LoanSection({required this.loans, this.loanGroups = const []});

  @override
  Widget build(BuildContext context) {
    // 负债总额 = 独立贷款剩余本金 + 组合贷剩余本金。
    // 单位均为「分(cents)」：
    //   - Loan.remainingPrincipal: int 分
    //   - LoanGroupDisplayItem.totalRemainingPrincipal: int 分（其子贷款
    //     剩余本金之和，独立于 standalone loans 维护，不能漏加）。
    // 两个集合不相交（getStandaloneLoans 已排除 groupId 非空的子贷款），
    // 直接相加不会重复计数。
    final standaloneDebt = loans.fold<int>(
      0,
      (s, l) => s + l.remainingPrincipal,
    );
    final groupDebt = loanGroups.fold<int>(
      0,
      (s, g) => s + g.totalRemainingPrincipal,
    );
    final totalDebt = standaloneDebt + groupDebt;

    // 列表展示：组合贷优先（通常是房贷大头），再独立贷款；统一取前 3 项，
    // 使可见行与“查看全部 N 笔”的计数口径一致，避免“显示 N 笔却空列表”。
    const maxRows = 3;
    final groupRows = loanGroups.length.clamp(0, maxRows);
    final loanRows = (maxRows - groupRows).clamp(0, loans.length);
    final totalCount = loans.length + loanGroups.length;

    return SliverMainAxisGroup(
      slivers: [
        SectionHeader(
          title: '负债',
          icon: Icons.credit_card_rounded,
          total: -totalDebt,
          color: context.semanticColors.liability,
          onTap: () => context.push(AppRouter.loans),
        ),
        // 组合贷行（汇总展示，点击进组合贷详情）。
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => LoanGroupItem(
              item: loanGroups[i],
              onTap: () =>
                  ctx.push(AppRouter.loanGroupDetail(loanGroups[i].group.id)),
            ),
            childCount: groupRows,
          ),
        ),
        // 独立贷款行。
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => LoanItem(
              loan: loans[i],
              onTap: () => ctx.push(AppRouter.loanDetail(loans[i].id)),
            ),
            childCount: loanRows,
          ),
        ),
        if (totalCount > maxRows)
          SliverToBoxAdapter(
            child: ShowMoreButton(
              label: '查看全部 $totalCount 笔贷款',
              onTap: () => context.push(AppRouter.loans),
            ),
          ),
      ],
    );
  }
}

class _FixedAssetSection extends StatelessWidget {
  final List assets;
  const _FixedAssetSection({required this.assets});

  @override
  Widget build(BuildContext context) {
    final total = assets.fold<int>(0, (s, a) => s + (a.currentValue as int));
    final displayCount = assets.length.clamp(0, 3);

    return SliverMainAxisGroup(
      slivers: [
        SectionHeader(
          title: '实物资产',
          icon: Icons.home_work_rounded,
          total: total,
          color: ChartColors.slot7,
          onTap: () => context.push(AppRouter.fixedAssets),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => FixedAssetItem(
              asset: assets[i],
              onTap: () => ctx.push(AppRouter.assetDetail(assets[i].id)),
            ),
            childCount: displayCount,
          ),
        ),
        if (assets.length > 3)
          SliverToBoxAdapter(
            child: ShowMoreButton(
              label: '查看全部 ${assets.length} 项资产',
              onTap: () => context.push(AppRouter.fixedAssets),
            ),
          ),
      ],
    );
  }
}
