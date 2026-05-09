import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/investment_provider.dart';
import '../../domain/providers/market_data_provider.dart';
import '../shared/family_scope_selector.dart';

class AddInvestmentPage extends ConsumerStatefulWidget {
  const AddInvestmentPage({super.key});

  @override
  ConsumerState<AddInvestmentPage> createState() => _AddInvestmentPageState();
}

class _AddInvestmentPageState extends ConsumerState<AddInvestmentPage> {
  String _selectedMarket = 'a_share';
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _scopeFamilyId;

  // After user selects a symbol, show buy form
  SymbolSearchResult? _selectedSymbol;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _feeController = TextEditingController(text: '0');
  DateTime _tradeDate = DateTime.now();

  static const _marketOptions = [
    ('a_share', 'A股'),
    ('hk_stock', '港股'),
    ('us_stock', '美股'),
    ('crypto', '加密货币'),
    ('fund', '基金'),
    ('precious_metal', '贵金属'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _feeController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(marketDataProvider.notifier).searchSymbol(
            query,
            marketType: _selectedMarket,
          );
    });
  }

  // Precious metal catalog (matches server preciousMetalList)
  static const _preciousMetals = [
    SymbolSearchResult(symbol: 'Au99.99', name: '黄金9999', marketType: 'precious_metal'),
    SymbolSearchResult(symbol: 'Au99.95', name: '黄金9995', marketType: 'precious_metal'),
    SymbolSearchResult(symbol: 'Au100g', name: '黄金100克', marketType: 'precious_metal'),
    SymbolSearchResult(symbol: 'Au(T+D)', name: '黄金T+D', marketType: 'precious_metal'),
    SymbolSearchResult(symbol: 'mAu(T+D)', name: '迷你黄金T+D', marketType: 'precious_metal'),
    SymbolSearchResult(symbol: 'Ag99.99', name: '白银9999', marketType: 'precious_metal'),
    SymbolSearchResult(symbol: 'Ag(T+D)', name: '白银T+D', marketType: 'precious_metal'),
    SymbolSearchResult(symbol: 'Pt99.95', name: '铂金9995', marketType: 'precious_metal'),
  ];

  Widget _buildPreciousMetalChooser(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('选择品种', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _preciousMetals.map((pm) {
            final isGold = pm.symbol.startsWith('Au') || pm.symbol.startsWith('mAu');
            final isSilver = pm.symbol.startsWith('Ag');
            final icon = isGold
                ? Icons.hexagon_rounded
                : isSilver
                    ? Icons.hexagon_outlined
                    : Icons.diamond_rounded;
            final color = isGold
                ? const Color(0xFFD4AF37)
                : isSilver
                    ? const Color(0xFFC0C0C0)
                    : const Color(0xFFE5E4E2);
            return ActionChip(
              avatar: Icon(icon, size: 18, color: color),
              label: Text(pm.name),
              labelStyle: theme.textTheme.bodyMedium,
              backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
              side: BorderSide(
                color: isDark ? AppColors.dividerDark : AppColors.divider,
              ),
              onPressed: () => _selectSymbol(pm),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _selectSymbol(SymbolSearchResult result) {
    setState(() {
      _selectedSymbol = result;
      _searchController.text = '${result.name} (${result.symbol})';
    });
    // Try to get current price
    ref.read(marketDataProvider.notifier).getQuote(result.symbol, result.marketType).then((quote) {
      if (quote != null && mounted) {
        _priceController.text = (quote.currentPrice / 100).toStringAsFixed(2);
      }
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _submit() async {
    if (_selectedSymbol == null) return;

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    var priceYuan = double.tryParse(_priceController.text) ?? 0;
    final feeYuan = double.tryParse(_feeController.text) ?? 0;

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的数量')),
      );
      return;
    }

    // For precious metals, if price is empty, fetch latest real-time price
    if (priceYuan <= 0 && _selectedMarket == 'precious_metal') {
      final quote = await ref.read(marketDataProvider.notifier).getQuote(
            _selectedSymbol!.symbol, _selectedSymbol!.marketType);
      if (quote != null && quote.currentPrice > 0) {
        priceYuan = quote.currentPrice / 100;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('获取实时价格失败，请手动输入成交价')),
          );
        }
        return;
      }
    } else if (priceYuan <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的价格')),
      );
      return;
    }

    final priceCents = (priceYuan * 100).round();
    final feeCents = (feeYuan * 100).round();

    // Create investment
    await ref.read(investmentProvider.notifier).createInvestment(
          symbol: _selectedSymbol!.symbol,
          name: _selectedSymbol!.name,
          marketType: _selectedSymbol!.marketType,
          familyId: _scopeFamilyId,
        );

    // Find the newly created investment and record trade
    final investments = ref.read(investmentProvider).investments;
    final newInv = investments
        .where((inv) => inv.symbol == _selectedSymbol!.symbol)
        .firstOrNull;

    if (newInv != null) {
      await ref.read(investmentProvider.notifier).recordTrade(
            investmentId: newInv.id,
            tradeType: 'buy',
            quantity: quantity,
            price: priceCents,
            fee: feeCents,
            tradeDate: _tradeDate,
          );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final marketState = ref.watch(marketDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加投资'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Family/personal scope selector
            FamilyScopeSelector(
              onChanged: (fid) => _scopeFamilyId = fid,
            ),
            // Market selector
            Semantics(
              label: '选择市场类型',
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: _marketOptions.map((opt) {
                    return ButtonSegment<String>(
                      value: opt.$1,
                      label: Text(opt.$2, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  selected: {_selectedMarket},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _selectedMarket = selected.first;
                      _selectedSymbol = null;
                    });
                    if (_searchController.text.isNotEmpty) {
                      _onSearchChanged(_searchController.text);
                    }
                  },
                  style: SegmentedButton.styleFrom(
                    selectedForegroundColor:
                        isDark ? AppColors.primaryDark : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Precious metal: show chooser grid; others: search field
            if (_selectedMarket == 'precious_metal' && _selectedSymbol == null)
              _buildPreciousMetalChooser(theme, isDark)
            else if (_selectedMarket != 'precious_metal') ...[
              // Search field
              Semantics(
                label: '搜索股票代码或名称',
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: '搜索代码或名称',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            tooltip: '清除搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _selectedSymbol = null);
                              ref
                                  .read(marketDataProvider.notifier)
                                  .searchSymbol('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (query) {
                    _onSearchChanged(query);
                    setState(() {});
                  },
                ),
              ),

              // Search results dropdown
              if (marketState.searchResults.isNotEmpty &&
                  _selectedSymbol == null)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: marketState.searchResults.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: isDark ? AppColors.dividerDark : AppColors.divider,
                    ),
                    itemBuilder: (context, index) {
                      final result = marketState.searchResults[index];
                      return Semantics(
                        label: '${result.name}，代码${result.symbol}',
                        button: true,
                        child: ListTile(
                          dense: true,
                          title: Text(
                            result.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${result.symbol} · ${marketTypeLabel(result.marketType)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          trailing: const Icon(Icons.add_circle_outline_rounded,
                              size: 20),
                          onTap: () => _selectSymbol(result),
                        ),
                      );
                    },
                  ),
                ),
            ],

            // Buy form (shown after selecting a symbol)
            if (_selectedSymbol != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '买入 ${_selectedSymbol!.name}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedSymbol = null;
                        _searchController.clear();
                        _priceController.clear();
                        _quantityController.clear();
                        _feeController.clear();
                      });
                    },
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('换品种'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quantity
              Semantics(
                label: '输入买入数量',
                child: TextField(
                  controller: _quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _selectedMarket == 'precious_metal' ? '重量（克）' : '数量',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixText: _selectedMarket == 'precious_metal' ? '克' : '股/份',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),

              // Price
              Semantics(
                label: '输入买入价格',
                child: TextField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _selectedMarket == 'precious_metal' ? '成交价（元/克）' : '成交价',
                    hintText: _selectedMarket == 'precious_metal' ? '留空则使用实时价格' : null,
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

              // Total amount display
              _TotalAmountDisplay(
                quantity: double.tryParse(_quantityController.text) ?? 0,
                price: double.tryParse(_priceController.text) ?? 0,
                fee: double.tryParse(_feeController.text) ?? 0,
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('确认买入', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TotalAmountDisplay extends StatelessWidget {
  final double quantity;
  final double price;
  final double fee;
  final bool isDark;
  final ThemeData theme;

  const _TotalAmountDisplay({
    required this.quantity,
    required this.price,
    required this.fee,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final total = quantity * price + fee;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '总金额',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            '¥ ${total.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
