import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart' as db;
import '../../core/widgets/widgets.dart';
import '../../domain/providers/loan_provider.dart';

class LoanGroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  const LoanGroupDetailPage({super.key, required this.groupId});

  @override
  ConsumerState<LoanGroupDetailPage> createState() =>
      _LoanGroupDetailPageState();
}

class _LoanGroupDetailPageState extends ConsumerState<LoanGroupDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Sub-loan schedules loaded async
  List<LoanScheduleDisplayItem> _comSchedule = [];
  List<LoanScheduleDisplayItem> _pvdSchedule = [];
  bool _schedulesLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loanProvider.notifier).getLoanGroupDetail(widget.groupId);
      _loadSchedules();
    });
  }

  Future<void> _loadSchedules() async {
    final notifier = ref.read(loanProvider.notifier);
    // Wait for group to be loaded
    await Future.delayed(const Duration(milliseconds: 200));
    final group = ref.read(loanProvider).currentGroup;
    if (group == null) return;

    final comLoan = group.commercialLoan;
    final pvdLoan = group.providentLoan;

    if (comLoan != null) {
      _comSchedule = await notifier.getScheduleForLoan(comLoan.id);
    }
    if (pvdLoan != null) {
      _pvdSchedule = await notifier.getScheduleForLoan(pvdLoan.id);
    }

    if (mounted) {
      setState(() => _schedulesLoaded = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loanState = ref.watch(loanProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final group = loanState.currentGroup;

    if (loanState.isLoading && group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('贷款详情')),
        body: const SkeletonList(count: 5, itemHeight: 72),
      );
    }

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('贷款详情')),
        body: ErrorState(
          message: loanState.error ?? '贷款组不存在',
          onRetry: () => ref.read(loanProvider.notifier).getLoanGroupDetail(widget.groupId),
        ),
      );
    }

    final comLoan = group.commercialLoan;
    final pvdLoan = group.providentLoan;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.group.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _onMenuAction(v, group.group.id),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除贷款组',
                    style: TextStyle(color: AppColors.expense)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary card
          _GroupSummaryCard(
            group: group,
            isDark: isDark,
            theme: theme,
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.speed_rounded,
                    label: '提前还款',
                    semanticLabel: '提前还款模拟',
                    sublabel: '推荐先还商贷',
                    onTap: () {
                      // Default to commercial loan (higher rate)
                      final targetLoan = comLoan ?? pvdLoan;
                      if (targetLoan != null) {
                        Navigator.of(context).pushNamed(
                          AppRouter.prepayment,
                          arguments: targetLoan.id,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (comLoan != null)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.account_balance_rounded,
                      label: '商贷详情',
                      semanticLabel: '查看商业贷款详情',
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRouter.loanDetail,
                        arguments: comLoan.id,
                      ),
                    ),
                  ),
                if (pvdLoan != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.home_rounded,
                      label: '公积金详情',
                      semanticLabel: '查看公积金贷款详情',
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRouter.loanDetail,
                        arguments: pvdLoan.id,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Tab bar
          AnimatedTabBar(
            tabs: const ['总览', '商贷', '公积金'],
            selectedIndex: _selectedTabIndex,
            onTap: (index) {
              setState(() => _selectedTabIndex = index);
              _tabController.animateTo(index);
            },
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Overview
                _OverviewTab(
                  comSchedule: _comSchedule,
                  pvdSchedule: _pvdSchedule,
                  loaded: _schedulesLoaded,
                  isDark: isDark,
                  theme: theme,
                ),
                // Tab 2: Commercial
                _SubLoanTab(
                  loan: comLoan,
                  schedule: _comSchedule,
                  loaded: _schedulesLoaded,
                  label: '商贷',
                  color: const Color(0xFF3D5AFE),
                  isDark: isDark,
                  theme: theme,
                ),
                // Tab 3: Provident
                _SubLoanTab(
                  loan: pvdLoan,
                  schedule: _pvdSchedule,
                  loaded: _schedulesLoaded,
                  label: '公积金',
                  color: const Color(0xFF448AFF),
                  isDark: isDark,
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onMenuAction(String action, String groupId) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除贷款组'),
          content: const Text('确定要删除此组合贷款（包含所有子贷款）吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.expense),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await ref.read(loanProvider.notifier).deleteLoanGroup(groupId);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }
}

// ── Group Summary Card ──

class _GroupSummaryCard extends StatelessWidget {
  final LoanGroupDisplayItem group;
  final bool isDark;
  final ThemeData theme;

  const _GroupSummaryCard({
    required this.group,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final comLoan = group.commercialLoan;
    final pvdLoan = group.providentLoan;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [
                  const Color(0xFF5B6EF5).withValues(alpha: 0.08),
                  const Color(0xFF448AFF).withValues(alpha: 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5B6EF5).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Type badge
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B6EF5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🏘️ 组合贷',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5B6EF5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Total monthly payment
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('总月供',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5))),
                    const SizedBox(height: 4),
                    Text(
                      '¥${_fmtCents(group.totalMonthlyPayment)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark
                            ? AppColors.liabilityDark
                            : AppColors.liability,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('剩余本金',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5))),
                    const SizedBox(height: 2),
                    Text(
                      '¥${_fmtCents(group.totalRemainingPrincipal)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              // Progress ring
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _ProgressRingPainter(
                    progress: group.overallProgress,
                    color: const Color(0xFF5B6EF5),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 10,
                  ),
                  child: Center(
                    child: Text(
                      '${(group.overallProgress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5B6EF5),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sub-loan summary row
          Row(
            children: [
              if (comLoan != null)
                _SubLoanSummaryChip(
                  label: '商贷',
                  color: const Color(0xFF3D5AFE),
                  rate: '${comLoan.annualRate.toStringAsFixed(2)}%',
                  principal: '¥${_fmtCents(comLoan.principal)}',
                  theme: theme,
                ),
              if (comLoan != null && pvdLoan != null)
                const SizedBox(width: 8),
              if (pvdLoan != null)
                _SubLoanSummaryChip(
                  label: '公积金',
                  color: const Color(0xFF448AFF),
                  rate: '${pvdLoan.annualRate.toStringAsFixed(2)}%',
                  principal: '¥${_fmtCents(pvdLoan.principal)}',
                  theme: theme,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubLoanSummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final String rate;
  final String principal;
  final ThemeData theme;

  const _SubLoanSummaryChip({
    required this.label,
    required this.color,
    required this.rate,
    required this.principal,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(principal,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w500,
                )),
            Text('利率 $rate',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      ),
    );
  }
}

// ── Overview Tab: merged timeline ──

class _OverviewTab extends StatelessWidget {
  final List<LoanScheduleDisplayItem> comSchedule;
  final List<LoanScheduleDisplayItem> pvdSchedule;
  final bool loaded;
  final bool isDark;
  final ThemeData theme;

  const _OverviewTab({
    required this.comSchedule,
    required this.pvdSchedule,
    required this.loaded,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const SingleChildScrollView(
        child: SkeletonList(count: 3, itemHeight: 64),
      );
    }
    final maxMonths =
        math.max(comSchedule.length, pvdSchedule.length);
    if (maxMonths == 0) {
      return const Center(child: Text('暂无还款计划'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: maxMonths,
      itemBuilder: (context, index) {
        final comItem =
            index < comSchedule.length ? comSchedule[index] : null;
        final pvdItem =
            index < pvdSchedule.length ? pvdSchedule[index] : null;

        final totalPayment =
            (comItem?.payment ?? 0) + (pvdItem?.payment ?? 0);
        final totalPrincipal = (comItem?.principalPart ?? 0) +
            (pvdItem?.principalPart ?? 0);
        final totalInterest = (comItem?.interestPart ?? 0) +
            (pvdItem?.interestPart ?? 0);
        final dueDate = comItem?.dueDate ?? pvdItem!.dueDate;
        final isPaid = (comItem?.isPaid ?? true) && (pvdItem?.isPaid ?? true);

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isPaid
                ? (isDark
                    ? Colors.green.withValues(alpha: 0.05)
                    : Colors.green.withValues(alpha: 0.02))
                : null,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF3A3A3C)
                    : const Color(0xFFE5E5EA),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Period
              SizedBox(
                width: 55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第 ${index + 1} 期',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isPaid
                            ? theme.colorScheme.onSurface
                                .withValues(alpha: 0.4)
                            : null,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy/MM').format(dueDate),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              // Stacked bar
              SizedBox(
                width: 40,
                height: 16,
                child: Row(
                  children: [
                    if (comItem != null)
                      Expanded(
                        flex: comItem.payment,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3D5AFE)
                                .withValues(alpha: isPaid ? 0.3 : 0.7),
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(3)),
                          ),
                        ),
                      ),
                    if (pvdItem != null)
                      Expanded(
                        flex: pvdItem.payment,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF448AFF)
                                .withValues(alpha: isPaid ? 0.3 : 0.7),
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(3)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Total
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '¥${_fmtCents(totalPayment)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isPaid
                            ? theme.colorScheme.onSurface
                                .withValues(alpha: 0.4)
                            : null,
                      ),
                    ),
                    Text(
                      '本金 ${_fmtCents(totalPrincipal)}  利息 ${_fmtCents(totalInterest)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (isPaid)
                Icon(Icons.check_circle_rounded,
                    size: 16,
                    color: isDark
                        ? AppColors.incomeDark
                        : AppColors.income),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-Loan Tab ──

class _SubLoanTab extends StatelessWidget {
  final db.Loan? loan;
  final List<LoanScheduleDisplayItem> schedule;
  final bool loaded;
  final String label;
  final Color color;
  final bool isDark;
  final ThemeData theme;

  const _SubLoanTab({
    required this.loan,
    required this.schedule,
    required this.loaded,
    required this.label,
    required this.color,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (loan == null) {
      return Center(child: Text('无$label贷款'));
    }

    if (!loaded) {
      return const SingleChildScrollView(
        child: SkeletonList(count: 3, itemHeight: 64),
      );
    }

    final progress = loan!.totalMonths > 0
        ? loan!.paidMonths / loan!.totalMonths
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sub-loan summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('本金',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                        Text('¥${_fmtCents(loan!.principal)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('年利率',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                        Text(
                          '${loan!.annualRate.toStringAsFixed(2)}%'
                          '${loan!.rateType == "lpr_floating" ? " (LPR)" : ""}',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ]),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('进度',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                        Text(
                          '${loan!.paidMonths}/${loan!.totalMonths}期',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('还款计划',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        // Schedule list
        ...schedule.map((item) {
          final isCurrent =
              item.monthNumber == loan!.paidMonths + 1;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isCurrent
                  ? color.withValues(alpha: 0.06)
                  : null,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFE5E5EA),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 55,
                  child: Text(
                    '第${item.monthNumber}期',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                      color: item.isPaid
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    DateFormat('yyyy/MM').format(item.dueDate),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Text(
                  '¥${_fmtCents(item.payment)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: item.isPaid
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                if (item.isPaid)
                  Icon(Icons.check_circle_rounded,
                      size: 14,
                      color: isDark
                          ? AppColors.incomeDark
                          : AppColors.income)
                else
                  const SizedBox(width: 14),
              ],
            ),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Action Button ──

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final String? sublabel;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 22,
                    color:
                        isDark ? AppColors.primaryDark : AppColors.primary),
                const SizedBox(height: 4),
                Text(label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w500)),
                if (sublabel != null)
                  Text(sublabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4))),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

// ── Progress Ring ──

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

String _fmtCents(int cents) {
  final yuan = cents / 100;
  if (yuan >= 10000) {
    final wan = yuan / 10000;
    return '${wan.toStringAsFixed(2)}万';
  }
  final formatter = NumberFormat('#,##0.00');
  return formatter.format(yuan);
}
