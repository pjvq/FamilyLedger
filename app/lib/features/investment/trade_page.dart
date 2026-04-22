import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/investment_provider.dart';
import '../../domain/providers/market_data_provider.dart';

class TradePage extends ConsumerStatefulWidget {
  final String investmentId;
  const TradePage({super.key, required this.investmentId});

  @override
  ConsumerState<TradePage> createState() => _TradePageState();
}

class _TradePageState extends ConsumerState<TradePage> {
  bool _isBuy = true;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _feeController = TextEditingController(text: '0');
  DateTime _tradeDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentPrice());
  }

  void _loadCurrentPrice() {
    final inv = ref
        .read(investmentProvider)
        .investments
        .where((i) => i.id == widget.investmentId)
        .firstOrNull;
    if (inv == null) return;

    ref.read(marketDataProvider.notifier).getQuote(inv.symbol, inv.marketType).then((quote) {
      if (quote != null && mounted) {
        _priceController.text = (quote.currentPrice / 100).toStringAsFixed(2);
      }
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final priceYuan = double.tryParse(_priceController.text) ?? 0;
    final feeYuan = double.tryParse(_feeController.text) ?? 0;

    if (quantity <= 0 || priceYuan <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的数量和价格')),
      );
      return;
    }

    // Validate sell quantity
    if (!_isBuy) {
      final inv = ref
          .read(investmentProvider)
          .investments
          .where((i) => i.id == widget.investmentId)
          .firstOrNull;
      if (inv != null && quantity > inv.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('卖出数量不能超过持仓 (${inv.quantity})')),
        );
        return;
      }
    }

    await ref.read(investmentProvider.notifier).recordTrade(
          investmentId: widget.investmentId,
          tradeType: _isBuy ? 'buy' : 'sell',
          quantity: quantity,
          price: (priceYuan * 100).round(),
          fee: (feeYuan * 100).round(),
          tradeDate: _tradeDate,
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final invState = ref.watch(investmentProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final investment = invState.investments
        .where((i) => i.id == widget.investmentId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(investment?.name ?? '交易'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buy / Sell toggle
            Semantics(
              label: '选择买入或卖出',
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment<bool>(
                      value: true,
                      label: const Text('买入'),
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: const Text('卖出'),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                  selected: {_isBuy},
                  onSelectionChanged: (selected) {
                    setState(() => _isBuy = selected.first);
                  },
                  style: SegmentedButton.styleFrom(
                    selectedForegroundColor: _isBuy
                        ? (isDark ? AppColors.expenseDark : AppColors.expense)
                        : (isDark ? AppColors.incomeDark : AppColors.income),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Current holding info
            if (investment != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '当前持仓',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '${_fmtQty(investment.quantity)} 股',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Quantity
            Semantics(
              label: '输入${_isBuy ? "买入" : "卖出"}数量',
              child: TextField(
                controller: _quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixText: '股/份',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // Price
            Semantics(
              label: '输入成交价',
              child: TextField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '成交价',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixText: '¥ ',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // Fee
            Semantics(
              label: '输入手续费',
              child: TextField(
                controller: _feeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '手续费',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixText: '¥ ',
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Trade date
            Semantics(
              label: '选择交易日期',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('交易日期'),
                trailing: Text(
                  '${_tradeDate.year}-${_tradeDate.month.toString().padLeft(2, '0')}-${_tradeDate.day.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _tradeDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _tradeDate = date);
                },
              ),
            ),
            const SizedBox(height: 8),

            // Total
            _TotalRow(
              quantity: double.tryParse(_quantityController.text) ?? 0,
              price: double.tryParse(_priceController.text) ?? 0,
              fee: double.tryParse(_feeController.text) ?? 0,
              isBuy: _isBuy,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _isBuy
                      ? (isDark ? AppColors.expenseDark : AppColors.expense)
                      : (isDark ? AppColors.incomeDark : AppColors.income),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isBuy ? '确认买入' : '确认卖出',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(4);
  }
}

class _TotalRow extends StatelessWidget {
  final double quantity;
  final double price;
  final double fee;
  final bool isBuy;
  final bool isDark;
  final ThemeData theme;

  const _TotalRow({
    required this.quantity,
    required this.price,
    required this.fee,
    required this.isBuy,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = quantity * price;
    final total = isBuy ? subtotal + fee : subtotal - fee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('金额',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  )),
              Text(
                '¥${subtotal.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('手续费',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  )),
              Text(
                '¥${fee.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('总计',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
              Text(
                '¥${total.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
