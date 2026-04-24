import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart' as db;
import '../../core/widgets/widgets.dart';
import '../../domain/providers/loan_provider.dart';
import 'loans_page.dart';
import 'rate_change_dialog.dart';

class LoanDetailPage extends ConsumerStatefulWidget {
  final String loanId;
  const LoanDetailPage({super.key, required this.loanId});

  @override
  ConsumerState<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends ConsumerState<LoanDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loanProvider.notifier).getLoanDetail(widget.loanId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loanState = ref.watch(loanProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loan = loanState.currentLoan;

    if (loanState.isLoading && loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('贷款详情')),
        body: const SkeletonList(count: 5, itemHeight: 72),
      );
    }

    if (loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('贷款详情')),
        body: ErrorState(
          message: loanState.error ?? '贷款不存在',
          onRetry: () => ref.read(loanProvider.notifier).getLoanDetail(widget.loanId),
        ),
      );
    }

    final typeInfo = getLoanTypeInfo(loan.loanType);
    final progress = loan.totalMonths > 0
        ? loan.paidMonths / loan.totalMonths
        : 0.0;
    final monthlyPayment =
        ref.read(loanProvider.notifier).getMonthlyPayment(loan);

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _onMenuAction(v, loan.id),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除贷款', style: TextStyle(color: AppColors.expense)),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Summary card with progress ring
          SliverToBoxAdapter(
            child: _SummaryCard(
              loan: loan,
              typeInfo: typeInfo,
              progress: progress,
              monthlyPayment: monthlyPayment,
              isDark: isDark,
              theme: theme,
            ),
          ),
          // Action buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.speed_rounded,
                      label: '提前还款',
                      semanticLabel: '提前还款模拟',
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRouter.prepayment,
                        arguments: loan.id,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.trending_up_rounded,
                      label: '利率变动',
                      semanticLabel: '利率变动',
                      onTap: () => _showRateChangeDialog(context, ref, loan.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.check_circle_outline_rounded,
                      label: '记录还款',
                      semanticLabel: '记录还款',
                      onTap: () => _showPaymentBottomSheet(
                        context,
                        loan,
                        loan.paidMonths + 1,
                        loanState.schedule,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Schedule timeline header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                '还款计划',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Timeline
          if (loanState.schedule.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: SkeletonList(count: 3, itemHeight: 64),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = loanState.schedule[index];
                  final isFirst = index == 0;
                  final isLast = index == loanState.schedule.length - 1;
                  final isCurrent =
                      item.monthNumber == loan.paidMonths + 1;

                  return _TimelineNode(
                    item: item,
                    isFirst: isFirst,
                    isLast: isLast,
                    isCurrent: isCurrent,
                    isDark: isDark,
                    theme: theme,
                    onTap: item.isPaid
                        ? null
                        : () => _showPaymentBottomSheet(
                              context,
                              loan,
                              item.monthNumber,
                              loanState.schedule,
                            ),
                  );
                },
                childCount: loanState.schedule.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  void _onMenuAction(String action, String loanId) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除贷款'),
          content: const Text('确定要删除此贷款吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        await ref.read(loanProvider.notifier).deleteLoan(loanId);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  void _showRateChangeDialog(
      BuildContext context, WidgetRef ref, String loanId) {
    showDialog(
      context: context,
      builder: (ctx) => RateChangeDialog(loanId: loanId),
    );
  }

  /// Show a BottomSheet to confirm payment for a specific month
  void _showPaymentBottomSheet(
    BuildContext context,
    db.Loan loan,
    int monthNumber,
    List<LoanScheduleDisplayItem> schedule,
  ) {
    if (monthNumber > loan.totalMonths) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('贷款已全部还清 🎉')),
      );
      return;
    }

    // Only allow recording the next unpaid month (sequential payment)
    final nextUnpaid = loan.paidMonths + 1;
    if (monthNumber != nextUnpaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先还清第 $nextUnpaid 期')),
      );
      return;
    }

    final item = schedule
        .where((s) => s.monthNumber == monthNumber)
        .firstOrNull;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF48484A)
                        : const Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  '确认还款',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Payment detail card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '第 $monthNumber/${loan.totalMonths} 期',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('yyyy年MM月dd日').format(item.dueDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '¥${_fmtCents(item.payment)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '本金 ¥${_fmtCents(item.principalPart)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '利息 ¥${_fmtCents(item.interestPart)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ref.read(loanProvider.notifier).recordPayment(
                                loanId: loan.id,
                                monthNumber: monthNumber,
                              );
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('确认还款'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Summary Card with Progress Ring ──

class _SummaryCard extends StatelessWidget {
  final dynamic loan;
  final LoanTypeInfo typeInfo;
  final double progress;
  final int monthlyPayment;
  final bool isDark;
  final ThemeData theme;

  const _SummaryCard({
    required this.loan,
    required this.typeInfo,
    required this.progress,
    required this.monthlyPayment,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${loan.name}，剩余本金${_fmtCents(loan.remainingPrincipal)}元，'
          '还款进度第${loan.paidMonths}期共${loan.totalMonths}期，'
          '月供${_fmtCents(monthlyPayment)}元',
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2A1A1A), const Color(0xFF1A0F0F)]
                : [
                    typeInfo.color.withValues(alpha: 0.08),
                    typeInfo.color.withValues(alpha: 0.03),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: typeInfo.color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge + rate
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeInfo.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${typeInfo.emoji} ${typeInfo.label}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: typeInfo.color,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${loan.annualRate.toStringAsFixed(2)}%',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  ' 年利率',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Main content: remaining principal + progress ring
            Row(
              children: [
                // Left: remaining principal + monthly payment
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '剩余本金',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${_fmtCents(loan.remainingPrincipal)}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isDark
                              ? AppColors.liabilityDark
                              : AppColors.liability,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '月供',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¥${_fmtCents(monthlyPayment)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: progress ring
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CustomPaint(
                    painter: _ProgressRingPainter(
                      progress: progress,
                      color: typeInfo.color,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      strokeWidth: 10,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: typeInfo.color,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          Text(
                            '第 ${loan.paidMonths}/${loan.totalMonths} 期',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              fontSize: 10,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bottom stats
            Row(
              children: [
                _StatItem(
                  label: '还款方式',
                  value: loan.repaymentMethod == 'equal_principal'
                      ? '等额本金'
                      : '等额本息',
                  theme: theme,
                ),
                _StatItem(
                  label: '开始日期',
                  value: DateFormat('yyyy/MM').format(loan.startDate),
                  theme: theme,
                ),
                _StatItem(
                  label: '还款日',
                  value: '每月 ${loan.paymentDay} 日',
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress Ring Painter (same style as budget page) ──

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

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start from top
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _StatItem({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Button ──

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, size: 22,
                    color: isDark ? AppColors.primaryDark : AppColors.primary),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
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

// ── Timeline Node (tappable for unpaid months) ──

class _TimelineNode extends StatelessWidget {
  final LoanScheduleDisplayItem item;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _TimelineNode({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    required this.isDark,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color nodeColor;
    final double nodeSize;

    if (item.isPaid) {
      nodeColor = isDark ? AppColors.incomeDark : AppColors.income;
      nodeSize = 12;
    } else if (isCurrent) {
      nodeColor = isDark ? AppColors.primaryDark : AppColors.primary;
      nodeSize = 16;
    } else {
      nodeColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6);
      nodeSize = 10;
    }

    return Semantics(
      label: '第${item.monthNumber}期，'
          '${item.isPaid ? "已还" : (isCurrent ? "当前期" : "未还")}，'
          '还款${_fmtCents(item.payment)}元，'
          '本金${_fmtCents(item.principalPart)}元，利息${_fmtCents(item.interestPart)}元，'
          '剩余本金${_fmtCents(item.remainingPrincipal)}元',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timeline column
                SizedBox(
                  width: 40,
                  child: CustomPaint(
                    painter: _TimelinePainter(
                      nodeColor: nodeColor,
                      nodeSize: nodeSize,
                      lineColor: isDark
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFD1D1D6),
                      isFirst: isFirst,
                      isLast: isLast,
                      isPaid: item.isPaid,
                      isCurrent: isCurrent,
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      top: isFirst ? 0 : 4,
                      bottom: isLast ? 0 : 4,
                    ),
                    padding: EdgeInsets.all(isCurrent ? 14 : 10),
                    decoration: isCurrent
                        ? BoxDecoration(
                            color: (isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primary)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isDark
                                      ? AppColors.primaryDark
                                      : AppColors.primary)
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          )
                        : null,
                    child: Row(
                      children: [
                        // Period + date
                        SizedBox(
                          width: 70,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '第 ${item.monthNumber} 期',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: isCurrent ? 13 : 12,
                                  color: item.isPaid
                                      ? theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4)
                                      : null,
                                ),
                              ),
                              Text(
                                DateFormat('yyyy/MM').format(item.dueDate),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: item.isPaid ? 0.3 : 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Payment breakdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '¥${_fmtCents(item.payment)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  fontSize: isCurrent ? 16 : 14,
                                  color: item.isPaid
                                      ? theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '本金 ${_fmtCents(item.principalPart)}  利息 ${_fmtCents(item.interestPart)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: item.isPaid ? 0.25 : 0.4),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '剩余 ¥${_fmtCents(item.remainingPrincipal)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Status icon
                        const SizedBox(width: 8),
                        if (item.isPaid)
                          Icon(Icons.check_circle_rounded,
                              size: 20,
                              color: isDark
                                  ? AppColors.incomeDark
                                  : AppColors.income)
                        else if (isCurrent)
                          Icon(Icons.radio_button_checked_rounded,
                              size: 20,
                              color: isDark
                                  ? AppColors.primaryDark
                                  : AppColors.primary)
                        else
                          const SizedBox(width: 20),
                      ],
                    ),
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

// ── Timeline Painter ──

class _TimelinePainter extends CustomPainter {
  final Color nodeColor;
  final double nodeSize;
  final Color lineColor;
  final bool isFirst;
  final bool isLast;
  final bool isPaid;
  final bool isCurrent;

  _TimelinePainter({
    required this.nodeColor,
    required this.nodeSize,
    required this.lineColor,
    required this.isFirst,
    required this.isLast,
    required this.isPaid,
    required this.isCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, centerY - nodeSize / 2),
        linePaint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, centerY + nodeSize / 2),
        Offset(centerX, size.height),
        linePaint,
      );
    }

    // Node
    final nodePaint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, centerY), nodeSize / 2, nodePaint);

    // Ring for current
    if (isCurrent) {
      final ringPaint = Paint()
        ..color = nodeColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(centerX, centerY), nodeSize / 2 + 4, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      nodeColor != oldDelegate.nodeColor ||
      nodeSize != oldDelegate.nodeSize ||
      isCurrent != oldDelegate.isCurrent;
}

// ── Format ──

String _fmtCents(int cents) {
  final yuan = cents / 100;
  final formatter = NumberFormat('#,##0.00');
  return formatter.format(yuan);
}
