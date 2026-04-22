import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../data/local/database.dart' as db;
import '../../domain/providers/investment_provider.dart';
import '../../domain/providers/market_data_provider.dart';

class InvestmentsPage extends ConsumerStatefulWidget {
  const InvestmentsPage({super.key});

  @override
  ConsumerState<InvestmentsPage> createState() => _InvestmentsPageState();
}

class _InvestmentsPageState extends ConsumerState<InvestmentsPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh quotes every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshQuotes(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuotes());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshQuotes() {
    final investments = ref.read(investmentProvider).investments;
    if (investments.isEmpty) return;
    final requests = investments
        .map((inv) => (symbol: inv.symbol, marketType: inv.marketType))
        .toList();
    ref.read(marketDataProvider.notifier).batchGetQuotes(requests);
  }

  @override
  Widget build(BuildContext context) {
    final invState = ref.watch(investmentProvider);
    final marketState = ref.watch(marketDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('投资'),
        centerTitle: false,
      ),
      body: invState.isLoading && invState.investments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(investmentProvider.notifier).listInvestments();
                _refreshQuotes();
              },
              child: CustomScrollView(
                slivers: [
                  // Portfolio summary card
                  SliverToBoxAdapter(
                    child: _PortfolioSummaryCard(
                      portfolio: invState.portfolio,
                      isDark: isDark,
                      theme: theme,
                    ),
                  ),
                  // Investment list
                  if (invState.investments.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(theme: theme),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final inv = invState.investments[index];
                          final key = MarketDataState.quoteKey(
                              inv.symbol, inv.marketType);
                          final quote = marketState.quotes[key];
                          return _InvestmentListItem(
                            investment: inv,
                            quote: quote,
                            isDark: isDark,
                            theme: theme,
                            priceHistory: marketState.priceHistory,
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRouter.investmentDetail,
                              arguments: inv.id,
                            ),
                          );
                        },
                        childCount: invState.investments.length,
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRouter.addInvestment),
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加投资'),
      ),
    );
  }
}

// ── Portfolio Summary Card ──

class _PortfolioSummaryCard extends StatelessWidget {
  final PortfolioSummary portfolio;
  final bool isDark;
  final ThemeData theme;

  const _PortfolioSummaryCard({
    required this.portfolio,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = portfolio.totalProfit >= 0;

    return Semantics(
      label:
          '投资组合汇总，总市值${_fmtYuan(portfolio.totalValue)}元，'
          '${isUp ? "盈利" : "亏损"}${_fmtYuan(portfolio.totalProfit.abs())}元',
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A1A3A), const Color(0xFF0F0F2A)]
                : [AppColors.primary, const Color(0xFF4A5DE5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '总市值',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '¥${_fmtYuan(portfolio.totalValue)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
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
                  '${isUp ? "+" : ""}${_fmtYuan(portfolio.totalProfit)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${isUp ? "+" : ""}${(portfolio.totalReturn * 100).toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtYuan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }
}

// ── Investment List Item ──

class _InvestmentListItem extends StatelessWidget {
  final db.Investment investment;
  final QuoteDisplay? quote;
  final bool isDark;
  final ThemeData theme;
  final List<PricePoint> priceHistory;
  final VoidCallback onTap;

  const _InvestmentListItem({
    required this.investment,
    required this.quote,
    required this.isDark,
    required this.theme,
    required this.priceHistory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = quote?.currentPrice ?? 0;
    final changePercent = quote?.changePercent ?? 0.0;
    final isUp = changePercent >= 0;
    final changeColor = isUp
        ? (isDark ? AppColors.incomeDark : AppColors.income)
        : (isDark ? AppColors.expenseDark : AppColors.expense);
    final value = (investment.quantity * price).round();

    return Semantics(
      label:
          '${investment.name}，代码${investment.symbol}，'
          '当前价${_fmtPrice(price)}，涨跌幅${changePercent.toStringAsFixed(2)}%',
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Left: name + symbol + market tag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              investment.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                      const SizedBox(height: 2),
                      Text(
                        investment.symbol,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '持仓 ${_fmtQty(investment.quantity)} · ¥${_fmtYuan(value)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: price + change + mini chart
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Mini sparkline (placeholder — static for now)
                    SizedBox(
                      width: 60,
                      height: 24,
                      child: CustomPaint(
                        painter: _MiniSparklinePainter(
                          color: changeColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtPrice(price),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
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
                          fontFeatures: const [FontFeature.tabularFigures()],
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

  String _fmtPrice(int cents) {
    final yuan = cents / 100;
    return yuan.toStringAsFixed(2);
  }

  String _fmtYuan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }

  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(4);
  }
}

// ── Mini Sparkline Painter ──

class _MiniSparklinePainter extends CustomPainter {
  final Color color;

  _MiniSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Generate a placeholder sine-wave sparkline
    // In production, this would use real price history data
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const points = 20;
    final dx = size.width / (points - 1);
    // Simple ascending/descending pattern
    final isUp = color == AppColors.income || color == AppColors.incomeDark;
    for (int i = 0; i < points; i++) {
      final t = i / (points - 1);
      // Mix some noise with trend
      final noise = ((i * 7 + 3) % 5) / 10.0;
      final trend = isUp ? (1 - t) : t;
      final y = size.height * (0.15 + trend * 0.7 + noise * 0.15);
      if (i == 0) {
        path.moveTo(0, y);
      } else {
        path.lineTo(i * dx, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter old) =>
      old.color != color;
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
            Icons.trending_up_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有投资持仓',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加第一个投资',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
