import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../data/local/database.dart' as db;
import '../../domain/providers/investment_provider.dart';
import '../../domain/providers/market_data_provider.dart';

class InvestmentDetailPage extends ConsumerStatefulWidget {
  final String investmentId;
  const InvestmentDetailPage({super.key, required this.investmentId});

  @override
  ConsumerState<InvestmentDetailPage> createState() =>
      _InvestmentDetailPageState();
}

class _InvestmentDetailPageState extends ConsumerState<InvestmentDetailPage> {
  String _timeRange = '1M';
  int _returnMode = 0; // 0=total, 1=annualized, 2=IRR

  static const _timeRanges = ['1W', '1M', '3M', '6M', '1Y', '全部'];
  static const _returnLabels = ['总收益率', '年化收益率', 'IRR'];

  // Touch crosshair data
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(investmentProvider.notifier).loadTrades(widget.investmentId);
      _loadHistory();
    });
  }

  void _loadHistory() {
    final inv = ref
        .read(investmentProvider)
        .investments
        .where((i) => i.id == widget.investmentId)
        .firstOrNull;
    if (inv == null) return;

    final now = DateTime.now();
    DateTime start;
    switch (_timeRange) {
      case '1W':
        start = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        start = now.subtract(const Duration(days: 30));
        break;
      case '3M':
        start = now.subtract(const Duration(days: 90));
        break;
      case '6M':
        start = now.subtract(const Duration(days: 180));
        break;
      case '1Y':
        start = now.subtract(const Duration(days: 365));
        break;
      default:
        start = now.subtract(const Duration(days: 365 * 5));
    }

    ref.read(marketDataProvider.notifier).getPriceHistory(
          inv.symbol,
          inv.marketType,
          startDate: start,
          endDate: now,
        );
  }

  @override
  Widget build(BuildContext context) {
    final invState = ref.watch(investmentProvider);
    final marketState = ref.watch(marketDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final investment = invState.investments
        .where((i) => i.id == widget.investmentId)
        .firstOrNull;
    if (investment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('投资不存在')),
      );
    }

    final key =
        MarketDataState.quoteKey(investment.symbol, investment.marketType);
    final quote = marketState.quotes[key];
    final price = quote?.currentPrice ?? 0;
    final changePercent = quote?.changePercent ?? 0.0;
    final isUp = changePercent >= 0;
    final changeColor = isUp
        ? (isDark ? AppColors.incomeDark : AppColors.income)
        : (isDark ? AppColors.expenseDark : AppColors.expense);

    final currentValue = (investment.quantity * price).round();
    final profit = currentValue - investment.costBasis;
    final returnRate =
        investment.costBasis > 0 ? profit / investment.costBasis : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(investment.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('删除投资'),
                    content: Text('确定要删除"${investment.name}"吗？所有交易记录也会被删除。'),
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
                  await ref
                      .read(investmentProvider.notifier)
                      .deleteInvestment(widget.investmentId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                    SizedBox(width: 8),
                    Text('删除'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: price + change
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        investment.symbol,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF3A3A3C)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          marketTypeLabel(investment.marketType),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    label: '当前价格${_fmtPrice(price)}',
                    child: Text(
                      '¥${_fmtPrice(price)}',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isUp
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        color: changeColor,
                        size: 20,
                      ),
                      Text(
                        '${isUp ? "+" : ""}${(quote?.changeAmount ?? 0) / 100}',
                        style: TextStyle(
                          color: changeColor,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: changeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${isUp ? "+" : ""}${changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Price chart
            const SizedBox(height: 16),
            _PriceChart(
              priceHistory: marketState.priceHistory,
              isUp: isUp,
              changeColor: changeColor,
              isDark: isDark,
              theme: theme,
              touchedIndex: _touchedIndex,
              onTouched: (index) => setState(() => _touchedIndex = index),
            ),

            // Time range selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: _timeRanges
                      .map((r) => ButtonSegment<String>(
                            value: r,
                            label: Text(r, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  selected: {_timeRange},
                  onSelectionChanged: (selected) {
                    setState(() => _timeRange = selected.first);
                    _loadHistory();
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Holding info card
            _HoldingInfoCard(
              investment: investment,
              currentValue: currentValue,
              profit: profit,
              returnRate: returnRate,
              returnMode: _returnMode,
              returnLabels: _returnLabels,
              onReturnModeChanged: (mode) =>
                  setState(() => _returnMode = mode),
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: 16),

            // Trade records
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '交易记录',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRouter.investmentTrade,
                      arguments: widget.investmentId,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('买入/卖出'),
                  ),
                ],
              ),
            ),
            _TradeList(trades: invState.currentTrades, theme: theme, isDark: isDark),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _fmtPrice(int cents) => (cents / 100).toStringAsFixed(2);
}

// ── Price Chart with Touch Crosshair ──

class _PriceChart extends StatelessWidget {
  final List<PricePoint> priceHistory;
  final bool isUp;
  final Color changeColor;
  final bool isDark;
  final ThemeData theme;
  final int? touchedIndex;
  final ValueChanged<int?> onTouched;

  const _PriceChart({
    required this.priceHistory,
    required this.isUp,
    required this.changeColor,
    required this.isDark,
    required this.theme,
    required this.touchedIndex,
    required this.onTouched,
  });

  @override
  Widget build(BuildContext context) {
    if (priceHistory.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            '暂无走势数据',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final spots = priceHistory.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.price / 100);
    }).toList();

    return Semantics(
      label: '走势图，共${priceHistory.length}个数据点',
      child: SizedBox(
        height: 200,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.spotIndex;
                      if (idx >= 0 && idx < priceHistory.length) {
                        final point = priceHistory[idx];
                        final dateStr = DateFormat('MM/dd').format(point.timestamp);
                        return LineTooltipItem(
                          '¥${(point.price / 100).toStringAsFixed(2)}\n$dateStr',
                          TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
                getTouchedSpotIndicator: (data, indexes) {
                  return indexes.map((i) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: changeColor.withValues(alpha: 0.4),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: changeColor,
                          strokeWidth: 2,
                          strokeColor: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    );
                  }).toList();
                },
                handleBuiltInTouches: true,
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: changeColor,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        changeColor.withValues(alpha: 0.2),
                        changeColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
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

// ── Holding Info Card ──

class _HoldingInfoCard extends StatelessWidget {
  final db.Investment investment;
  final int currentValue;
  final int profit;
  final double returnRate;
  final int returnMode;
  final List<String> returnLabels;
  final ValueChanged<int> onReturnModeChanged;
  final bool isDark;
  final ThemeData theme;

  const _HoldingInfoCard({
    required this.investment,
    required this.currentValue,
    required this.profit,
    required this.returnRate,
    required this.returnMode,
    required this.returnLabels,
    required this.onReturnModeChanged,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = profit >= 0;
    final profitColor = isPositive
        ? (isDark ? AppColors.incomeDark : AppColors.income)
        : (isDark ? AppColors.expenseDark : AppColors.expense);

    // Compute display return based on mode
    double displayReturn;
    switch (returnMode) {
      case 1: // annualized
        displayReturn = InvestmentNotifier.annualizedReturn(
          costBasis: investment.costBasis,
          currentValue: currentValue,
          firstTradeDate: investment.createdAt,
        );
        break;
      case 2: // IRR (simplified — same as annualized for now)
        displayReturn = InvestmentNotifier.annualizedReturn(
          costBasis: investment.costBasis,
          currentValue: currentValue,
          firstTradeDate: investment.createdAt,
        );
        break;
      default:
        displayReturn = returnRate;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '持仓信息',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('持有数量', _fmtQty(investment.quantity), theme),
            _infoRow('成本', '¥${_fmtYuan(investment.costBasis)}', theme),
            _infoRow('市值', '¥${_fmtYuan(currentValue)}', theme),
            _infoRow(
              '盈亏',
              '${isPositive ? "+" : ""}¥${_fmtYuan(profit)}',
              theme,
              valueColor: profitColor,
            ),
            const SizedBox(height: 8),
            // Return rate toggle
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: returnLabels.asMap().entries.map((e) {
                      return ButtonSegment<int>(
                        value: e.key,
                        label: Text(e.value,
                            style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                    selected: {returnMode},
                    onSelectionChanged: (s) => onReturnModeChanged(s.first),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${isPositive ? "+" : ""}${(displayReturn * 100).toStringAsFixed(2)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: profitColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(4);
  }

  String _fmtYuan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }
}

// ── Trade List ──

class _TradeList extends StatelessWidget {
  final List<db.InvestmentTrade> trades;
  final ThemeData theme;
  final bool isDark;

  const _TradeList({
    required this.trades,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            '暂无交易记录',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trades.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final trade = trades[index];
        final isBuy = trade.tradeType == 'buy';
        final color = isBuy
            ? (isDark ? AppColors.expenseDark : AppColors.expense)
            : (isDark ? AppColors.incomeDark : AppColors.income);

        return Semantics(
          label:
              '${isBuy ? "买入" : "卖出"}${trade.quantity}股，价格${trade.price / 100}',
          child: Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        isBuy
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: color,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBuy ? '买入' : '卖出',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        Text(
                          '${_fmtQty(trade.quantity)}股 × ¥${(trade.price / 100).toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${(trade.totalAmount / 100).toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd').format(trade.tradeDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(4);
  }
}
