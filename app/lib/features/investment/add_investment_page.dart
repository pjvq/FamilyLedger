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
  final _searchFocus = FocusNode();
  Timer? _debounce;
  String? _scopeFamilyId;
  SymbolSearchResult? _selectedSymbol;
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _feeController = TextEditingController(text: '0');
  DateTime _tradeDate = DateTime.now();
  bool _isLoadingPrice = false;

  static const _marketCategories = [
    _MarketCategory('stocks', '股票', Icons.candlestick_chart_rounded, [
      ('a_share', 'A股'),
      ('hk_stock', '港股'),
      ('us_stock', '美股'),
    ]),
    _MarketCategory('others', '其他', Icons.account_balance_rounded, [
      ('fund', '基金'),
      ('crypto', '加密货币'),
      ('precious_metal', '贵金属'),
    ]),
  ];

  static const _preciousMetals = [
    _PreciousMetalOption('Au99.99', '黄金9999', 'gold'),
    _PreciousMetalOption('Au99.95', '黄金9995', 'gold'),
    _PreciousMetalOption('Au100g', '黄金100克', 'gold'),
    _PreciousMetalOption('Au(T+D)', '黄金T+D', 'gold'),
    _PreciousMetalOption('mAu(T+D)', '迷你黄金T+D', 'gold'),
    _PreciousMetalOption('Ag99.99', '白银9999', 'silver'),
    _PreciousMetalOption('Ag(T+D)', '白银T+D', 'silver'),
    _PreciousMetalOption('Pt99.95', '铂金9995', 'platinum'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
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

  void _selectMarket(String market) {
    setState(() {
      _selectedMarket = market;
      _selectedSymbol = null;
      _searchController.clear();
    });
    ref.read(marketDataProvider.notifier).searchSymbol('');
  }

  void _selectSymbol(SymbolSearchResult result) {
    setState(() {
      _selectedSymbol = result;
      _isLoadingPrice = true;
    });
    ref.read(marketDataProvider.notifier).getQuote(result.symbol, result.marketType).then((quote) {
      if (mounted) {
        setState(() => _isLoadingPrice = false);
        if (quote != null) {
          _priceController.text = (quote.currentPrice / 100).toStringAsFixed(2);
        }
      }
    });
    FocusScope.of(context).unfocus();
  }

  void _selectPreciousMetal(_PreciousMetalOption pm) {
    _selectSymbol(SymbolSearchResult(
      symbol: pm.symbol,
      name: pm.name,
      marketType: 'precious_metal',
    ));
  }

  void _clearSelection() {
    setState(() {
      _selectedSymbol = null;
      _searchController.clear();
      _priceController.clear();
      _quantityController.clear();
      _feeController.clear();
    });
  }

  Future<void> _submit() async {
    if (_selectedSymbol == null) return;

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    var priceYuan = double.tryParse(_priceController.text) ?? 0;
    final feeYuan = double.tryParse(_feeController.text) ?? 0;

    if (quantity <= 0) {
      _showError('请输入有效的数量');
      return;
    }

    if (priceYuan <= 0 && _selectedMarket == 'precious_metal') {
      final quote = await ref.read(marketDataProvider.notifier).getQuote(
            _selectedSymbol!.symbol, _selectedSymbol!.marketType);
      if (quote != null && quote.currentPrice > 0) {
        priceYuan = quote.currentPrice / 100;
      } else {
        _showError('获取实时价格失败，请手动输入');
        return;
      }
    } else if (priceYuan <= 0) {
      _showError('请输入有效的价格');
      return;
    }

    final priceCents = (priceYuan * 100).round();
    final feeCents = (feeYuan * 100).round();

    await ref.read(investmentProvider.notifier).createInvestment(
          symbol: _selectedSymbol!.symbol,
          name: _selectedSymbol!.name,
          marketType: _selectedSymbol!.marketType,
          familyId: _scopeFamilyId,
        );

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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  bool get _isPreciousMetal => _selectedMarket == 'precious_metal';
  String get _unitLabel => _isPreciousMetal ? '克' : '股/份';

  @override
  Widget build(BuildContext context) {
    final marketState = ref.watch(marketDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加投资'),
        centerTitle: true,
      ),
      body: _selectedSymbol == null
          ? _buildSelectionStep(theme, isDark, marketState)
          : _buildTradeForm(theme, isDark),
    );
  }

  // ─── Step 1: Select Asset ───────────────────────────────────────────────────

  Widget _buildSelectionStep(ThemeData theme, bool isDark, MarketDataState marketState) {
    return Column(
      children: [
        // Scope selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: FamilyScopeSelector(
            onChanged: (fid) => _scopeFamilyId = fid,
          ),
        ),

        // Market type chips (scrollable row)
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final cat in _marketCategories)
                for (final opt in cat.markets)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(opt.$2),
                      selected: _selectedMarket == opt.$1,
                      onSelected: (_) => _selectMarket(opt.$1),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedMarket == opt.$1
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Content area
        Expanded(
          child: _isPreciousMetal
              ? _buildPreciousMetalGrid(theme, isDark)
              : _buildSearchView(theme, isDark, marketState),
        ),
      ],
    );
  }

  Widget _buildSearchView(ThemeData theme, bool isDark, MarketDataState marketState) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: '搜索代码或名称',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: isDark ? AppColors.cardDark : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(marketDataProvider.notifier).searchSymbol('');
                        setState(() {});
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

        const SizedBox(height: 8),

        // Results
        Expanded(
          child: marketState.isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : marketState.searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty
                                ? '输入代码或名称开始搜索'
                                : '未找到相关结果',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: marketState.searchResults.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = marketState.searchResults[index];
                        return _SearchResultTile(
                          result: result,
                          onTap: () => _selectSymbol(result),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPreciousMetalGrid(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择品种',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: _preciousMetals.map((pm) {
                return _PreciousMetalCard(
                  option: pm,
                  isDark: isDark,
                  onTap: () => _selectPreciousMetal(pm),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Trade Form ─────────────────────────────────────────────────────

  Widget _buildTradeForm(ThemeData theme, bool isDark) {
    final total = (double.tryParse(_quantityController.text) ?? 0) *
            (double.tryParse(_priceController.text) ?? 0) +
        (double.tryParse(_feeController.text) ?? 0);

    return Column(
      children: [
        // Selected asset header
        _AssetHeader(
          symbol: _selectedSymbol!,
          isLoadingPrice: _isLoadingPrice,
          currentPrice: _priceController.text,
          isPreciousMetal: _isPreciousMetal,
          isDark: isDark,
          onClear: _clearSelection,
        ),

        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Quantity + Price row
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        controller: _quantityController,
                        label: _isPreciousMetal ? '重量' : '数量',
                        suffix: _unitLabel,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FormField(
                        controller: _priceController,
                        label: _isPreciousMetal ? '单价 (元/克)' : '成交价',
                        prefix: '¥',
                        hint: _isPreciousMetal ? '留空用实时价' : null,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fee + Date row
                Row(
                  children: [
                    Expanded(
                      child: _FormField(
                        controller: _feeController,
                        label: '手续费',
                        prefix: '¥',
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        date: _tradeDate,
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
                  ],
                ),
                const SizedBox(height: 24),

                // Total
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '总金额',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        '¥ ${total.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Submit button (sticky bottom)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('确认买入', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _MarketCategory {
  final String id;
  final String label;
  final IconData icon;
  final List<(String, String)> markets;
  const _MarketCategory(this.id, this.label, this.icon, this.markets);
}

class _PreciousMetalOption {
  final String symbol;
  final String name;
  final String metal; // gold, silver, platinum
  const _PreciousMetalOption(this.symbol, this.name, this.metal);

  Color get color => switch (metal) {
        'gold' => const Color(0xFFD4AF37),
        'silver' => const Color(0xFFA8A9AD),
        'platinum' => const Color(0xFFE5E4E2),
        _ => Colors.grey,
      };

  IconData get icon => switch (metal) {
        'gold' => Icons.hexagon_rounded,
        'silver' => Icons.hexagon_outlined,
        'platinum' => Icons.diamond_rounded,
        _ => Icons.circle,
      };
}

class _PreciousMetalCard extends StatelessWidget {
  final _PreciousMetalOption option;
  final bool isDark;
  final VoidCallback onTap;

  const _PreciousMetalCard({
    required this.option,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E8E8),
            ),
          ),
          child: Row(
            children: [
              Icon(option.icon, size: 24, color: option.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      option.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      option.symbol,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SymbolSearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          result.symbol.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        result.name,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Text(
        '${result.symbol} · ${marketTypeLabel(result.marketType)}',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Icon(
        Icons.add_circle_rounded,
        color: theme.colorScheme.primary,
        size: 22,
      ),
      onTap: onTap,
    );
  }
}

class _AssetHeader extends StatelessWidget {
  final SymbolSearchResult symbol;
  final bool isLoadingPrice;
  final String currentPrice;
  final bool isPreciousMetal;
  final bool isDark;
  final VoidCallback onClear;

  const _AssetHeader({
    required this.symbol,
    required this.isLoadingPrice,
    required this.currentPrice,
    required this.isPreciousMetal,
    required this.isDark,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE),
          ),
        ),
      ),
      child: Row(
        children: [
          // Asset info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      symbol.symbol,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        marketTypeLabel(symbol.marketType),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Price badge
          if (isLoadingPrice)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          else if (currentPrice.isNotEmpty)
            Text(
              '¥$currentPrice',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

          // Change button
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: '更换标的',
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? prefix;
  final String? suffix;
  final String? hint;
  final VoidCallback onChanged;

  const _FormField({
    required this.controller,
    required this.label,
    this.prefix,
    this.suffix,
    this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix != null ? '$prefix ' : null,
            suffixText: suffix,
            filled: true,
            fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '交易日期',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text(
                  '${date.month}/${date.day}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
