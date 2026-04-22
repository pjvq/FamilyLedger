import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/loan_provider.dart';
import '../transaction/widgets/number_pad.dart';

class PrepaymentPage extends ConsumerStatefulWidget {
  final String loanId;
  const PrepaymentPage({super.key, required this.loanId});

  @override
  ConsumerState<PrepaymentPage> createState() => _PrepaymentPageState();
}

class _PrepaymentPageState extends ConsumerState<PrepaymentPage> {
  String _amountText = '';
  String _strategy = 'reduce_months';
  bool _showNewSchedule = false;

  @override
  void initState() {
    super.initState();
    // Ensure loan detail is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loan = ref.read(loanProvider).currentLoan;
      if (loan == null || loan.id != widget.loanId) {
        ref.read(loanProvider.notifier).getLoanDetail(widget.loanId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loanState = ref.watch(loanProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loan = loanState.currentLoan;
    final simulation = loanState.simulation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('提前还款模拟'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Amount input
                _SectionTitle(title: '提前还款金额（元）', theme: theme),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A3A3C)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _amountText.isEmpty ? '输入金额' : _amountText,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: _amountText.isEmpty
                                  ? theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (loan != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '剩余本金 ¥${_fmtCents(loan.remainingPrincipal)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                // Strategy selection
                _SectionTitle(title: '还款策略', theme: theme),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'reduce_months',
                      label: Text('缩短期限'),
                      icon: Icon(Icons.schedule_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: 'reduce_payment',
                      label: Text('减少月供'),
                      icon: Icon(Icons.trending_down_rounded, size: 18),
                    ),
                  ],
                  selected: {_strategy},
                  onSelectionChanged: (v) {
                    setState(() {
                      _strategy = v.first;
                      // Re-simulate if amount is available
                      _runSimulation();
                    });
                  },
                ),

                const SizedBox(height: 20),
                // Simulate button
                FilledButton.icon(
                  onPressed: _amountText.isNotEmpty ? _runSimulation : null,
                  icon: const Icon(Icons.calculate_rounded),
                  label: const Text('开始模拟'),
                ),

                // Results
                if (simulation != null) ...[
                  const SizedBox(height: 24),
                  _ComparisonCard(
                    simulation: simulation,
                    isDark: isDark,
                    theme: theme,
                    strategy: _strategy,
                  ),
                  const SizedBox(height: 16),
                  // New schedule toggle
                  if (simulation.newSchedule.isNotEmpty) ...[
                    InkWell(
                      onTap: () =>
                          setState(() => _showNewSchedule = !_showNewSchedule),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Icon(
                              _showNewSchedule
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: isDark
                                  ? AppColors.primaryDark
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '新还款计划（${simulation.newSchedule.length}期）',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.primaryDark
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _NewScheduleList(
                        schedule: simulation.newSchedule,
                        theme: theme,
                        isDark: isDark,
                      ),
                      crossFadeState: _showNewSchedule
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
          // Number pad
          NumberPad(
            onKey: (key) {
              setState(() {
                if (key == '.' && _amountText.contains('.')) return;
                if (key == '.' && _amountText.isEmpty) {
                  _amountText = '0.';
                  return;
                }
                if (_amountText.contains('.')) {
                  final parts = _amountText.split('.');
                  if (parts[1].length >= 2) return;
                }
                _amountText += key;
              });
            },
            onDelete: () {
              setState(() {
                if (_amountText.isNotEmpty) {
                  _amountText =
                      _amountText.substring(0, _amountText.length - 1);
                }
              });
            },
            onConfirm: _amountText.isNotEmpty ? _runSimulation : () {},
            confirmEnabled: _amountText.isNotEmpty,
          ),
        ],
      ),
    );
  }

  void _runSimulation() {
    final amount = double.tryParse(_amountText);
    if (amount == null || amount <= 0) return;

    ref.read(loanProvider.notifier).simulatePrepayment(
          loanId: widget.loanId,
          amount: (amount * 100).round(),
          strategy: _strategy,
        );
  }
}

// ── Comparison Card ──

class _ComparisonCard extends StatelessWidget {
  final PrepaymentSimulationResult simulation;
  final bool isDark;
  final ThemeData theme;
  final String strategy;

  const _ComparisonCard({
    required this.simulation,
    required this.isDark,
    required this.theme,
    required this.strategy,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '模拟结果：节省利息${_fmtCents(simulation.interestSaved)}元'
          '${strategy == "reduce_months" ? "，缩短${simulation.monthsReduced}个月" : "，新月供${_fmtCents(simulation.newMonthlyPayment)}元"}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Saved interest highlight
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.incomeDark : AppColors.income)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '节省利息',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.incomeDark
                            : AppColors.income,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${_fmtCents(simulation.interestSaved)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark
                            ? AppColors.incomeDark
                            : AppColors.income,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Comparison rows
              _ComparisonRow(
                label: '总利息',
                before: '¥${_fmtCents(simulation.totalInterestBefore)}',
                after: '¥${_fmtCents(simulation.totalInterestAfter)}',
                theme: theme,
                isDark: isDark,
              ),
              const Divider(height: 20),
              if (strategy == 'reduce_months') ...[
                _ComparisonRow(
                  label: '缩短期限',
                  before: '',
                  after: '${simulation.monthsReduced} 个月',
                  theme: theme,
                  isDark: isDark,
                  isHighlight: true,
                ),
              ] else ...[
                _ComparisonRow(
                  label: '新月供',
                  before: '',
                  after: '¥${_fmtCents(simulation.newMonthlyPayment)}',
                  theme: theme,
                  isDark: isDark,
                  isHighlight: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String before;
  final String after;
  final ThemeData theme;
  final bool isDark;
  final bool isHighlight;

  const _ComparisonRow({
    required this.label,
    required this.before,
    required this.after,
    required this.theme,
    required this.isDark,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        if (before.isNotEmpty)
          Expanded(
            flex: 3,
            child: Text(
              before,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                decoration: TextDecoration.lineThrough,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            after,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isHighlight
                  ? (isDark ? AppColors.primaryDark : AppColors.primary)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ── New Schedule List ──

class _NewScheduleList extends StatelessWidget {
  final List<LoanScheduleDisplayItem> schedule;
  final ThemeData theme;
  final bool isDark;

  const _NewScheduleList({
    required this.schedule,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: schedule.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
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
                width: 50,
                child: Text(
                  '第${item.monthNumber}期',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat('yyyy/MM').format(item.dueDate),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
              ),
              Text(
                '¥${_fmtCents(item.payment)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ThemeData theme;
  const _SectionTitle({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

String _fmtCents(int cents) {
  final yuan = cents / 100;
  final formatter = NumberFormat('#,##0.00');
  return formatter.format(yuan);
}
