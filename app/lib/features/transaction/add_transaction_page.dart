import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/transaction_provider.dart';
import 'widgets/number_pad.dart';
import 'widgets/category_grid.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  const AddTransactionPage({super.key});

  @override
  ConsumerState<AddTransactionPage> createState() =>
      _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _amountStr = '0';
  String? _selectedCategoryId;
  final String _note = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {
          _selectedCategoryId = null;
        }));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isExpense => _tabController.index == 0;

  String get _type => _isExpense ? 'expense' : 'income';

  @override
  Widget build(BuildContext context) {
    final txnState = ref.watch(transactionProvider);
    final categories =
        _isExpense ? txnState.expenseCategories : txnState.incomeCategories;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24),
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('记一笔'),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '收入'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 金额显示
          _AmountDisplay(
            amountStr: _amountStr,
            isExpense: _isExpense,
          ),
          const SizedBox(height: 8),
          // 分类选择器
          Expanded(
            child: CategoryGrid(
              categories: categories,
              selectedId: _selectedCategoryId,
              onSelect: (id) {
                setState(() => _selectedCategoryId = id);
                HapticFeedback.selectionClick();
              },
            ),
          ),
          // 数字键盘
          NumberPad(
            onKey: _handleKey,
            onDelete: _handleDelete,
            onConfirm: _handleConfirm,
            confirmEnabled:
                _selectedCategoryId != null && _amountStr != '0' && !_isSubmitting,
          ),
        ],
      ),
    );
  }

  void _handleKey(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == '.') {
        if (_amountStr.contains('.')) return;
        _amountStr += '.';
      } else {
        if (_amountStr == '0' && key != '.') {
          _amountStr = key;
        } else {
          // 最多两位小数
          if (_amountStr.contains('.')) {
            final decimals = _amountStr.split('.')[1];
            if (decimals.length >= 2) return;
          }
          // 最大金额限制
          if (_amountStr.replaceAll('.', '').length >= 10) return;
          _amountStr += key;
        }
      }
    });
  }

  void _handleDelete() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_amountStr.length <= 1) {
        _amountStr = '0';
      } else {
        _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      }
    });
  }

  Future<void> _handleConfirm() async {
    if (_selectedCategoryId == null || _amountStr == '0') return;
    setState(() => _isSubmitting = true);

    // 元 → 分
    final yuan = double.tryParse(_amountStr) ?? 0;
    final cents = (yuan * 100).round();

    await ref.read(transactionProvider.notifier).addTransaction(
          categoryId: _selectedCategoryId!,
          amount: cents,
          type: _type,
          note: _note,
        );

    HapticFeedback.mediumImpact();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _AmountDisplay extends StatelessWidget {
  final String amountStr;
  final bool isExpense;

  const _AmountDisplay({
    required this.amountStr,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isExpense
        ? (isDark ? AppColors.expenseDark : AppColors.expense)
        : (isDark ? AppColors.incomeDark : AppColors.income);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '¥',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            amountStr,
            style: TextStyle(
              color: color,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -2,
            ),
          ),
        ],
      ),
    );
  }
}
