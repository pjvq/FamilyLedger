import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/amount_expression.dart';
import '../../../core/widgets/success_animation.dart';
import '../../../domain/providers/account_provider.dart';
import '../../../domain/providers/dashboard_provider.dart';
import '../../../domain/providers/transaction_provider.dart';
import 'animated_amount_display.dart';
import 'quick_number_pad.dart';
import 'quick_add_components.dart';
import 'quick_category_selector.dart';

/// 快速记账 Bottom Sheet — Phase 2 核心体验
///
/// 设计目标：3 秒完成一笔记账
/// - 95% 屏幕高度 Bottom Sheet
/// - 所有交互元素在底部 60% 区域（单手可达）
/// - 内嵌数字键盘 + 表达式计算
/// - 2 行分类网格水平滚动
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  /// 从任意位置显示快速记账面板
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickAddSheet(),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  String _expression = '0';
  int _cachedCents = 0;
  String _note = '';
  int _typeIndex = 0; // 0=支出, 1=收入
  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _date = DateTime.now();
  bool _isSubmitting = false;

  int get _computedCents => _cachedCents;

  void _updateExpression(String newExpr) {
    _expression = newExpr;
    _cachedCents = AmountExpression.evaluateCents(newExpr);
  }

  bool get _canSubmit =>
      _computedCents > 0 && _selectedCategoryId != null && !_isSubmitting;

  @override
  void initState() {
    super.initState();
    // Default account
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = ref.read(accountProvider).accounts;
      if (accounts.isNotEmpty && _selectedAccountId == null) {
        setState(() => _selectedAccountId = accounts.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final accounts = ref.watch(accountProvider).accounts;
    final selectedAccount = accounts.where((a) => a.id == _selectedAccountId).firstOrNull;

    return Container(
      height: screenHeight * 0.92,
      decoration: BoxDecoration(
        color: isDark ? NeutralColorsDark.neutral1 : NeutralColorsLight.neutral0,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: SpacingTokens.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: SpacingTokens.base),

          // Top area: account pill + amount + note (40% of sheet)
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Account selector
                AccountPill(
                  accountName: selectedAccount?.name ?? '选择账户',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: _showAccountPicker,
                ),
                const SizedBox(height: SpacingTokens.xl),

                // Amount display
                AnimatedAmountDisplay(
                  expression: _expression,
                  note: _note.isEmpty ? null : _note,
                  onNoteTap: _showNoteInput,
                ),

                const SizedBox(height: SpacingTokens.md),

                // Date chip (if not today)
                if (!_isToday(_date))
                  Chip(
                    avatar: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      '${_date.month}月${_date.day}日',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onDeleted: () => setState(() => _date = DateTime.now()),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // Bottom area: type selector + categories + keyboard (60%)
          Expanded(
            flex: 6,
            child: Column(
              children: [
                // Type selector
                TransactionTypeSelector(
                  selectedIndex: _typeIndex,
                  onChanged: (i) => setState(() {
                    _typeIndex = i;
                    _selectedCategoryId = null;
                  }),
                ),
                const SizedBox(height: SpacingTokens.md),

                // Category grid (two-level with subcategory sheet)
                Expanded(
                  child: QuickCategorySelector(
                    typeIndex: _typeIndex,
                    selectedCategoryId: _selectedCategoryId,
                    onSelected: (id) => setState(() => _selectedCategoryId = id),
                  ),
                ),

                const SizedBox(height: SpacingTokens.sm),

                // Number pad
                QuickNumberPad(
                  onDigit: _onDigit,
                  onDelete: _onDelete,
                  onClear: _onClear,
                  onConfirm: _onConfirm,
                  onDateTap: _showDatePicker,
                  onOperator: _onOperator,
                  confirmEnabled: _canSubmit,
                  confirmLabel: _isSubmitting ? '...' : '完成',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Input Logic ─────────────────────────────────────────────────

  void _onDigit(String digit) {
    setState(() {
      if (_expression == '0' && digit != '.') {
        _updateExpression(digit);
      } else if (digit == '.') {
        // Prevent double dots in current segment
        final lastSegment = _expression.split(RegExp(r'[+\-]')).last;
        if (!lastSegment.contains('.')) {
          _updateExpression(_expression + digit);
        }
      } else {
        // Limit decimal places to 2
        final lastSegment = _expression.split(RegExp(r'[+\-]')).last;
        if (lastSegment.contains('.') && lastSegment.split('.').last.length >= 2) {
          return;
        }
        _updateExpression(_expression + digit);
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      final lastChar = _expression.isNotEmpty ? _expression[_expression.length - 1] : '';
      if (lastChar == '+' || lastChar == '-') {
        _updateExpression(_expression.substring(0, _expression.length - 1) + op);
      } else if (_expression != '0') {
        _updateExpression(_expression + op);
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_expression.length <= 1) {
        _updateExpression('0');
      } else {
        _updateExpression(_expression.substring(0, _expression.length - 1));
      }
    });
  }

  void _onClear() {
    setState(() => _updateExpression('0'));
  }
  // ─── Actions ─────────────────────────────────────────────────────


  Future<void> _onConfirm() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    try {
      final amountCents = _computedCents;
      final type = _typeIndex == 0 ? 'expense' : 'income';

      await ref.read(transactionProvider.notifier).addTransaction(
        categoryId: _selectedCategoryId!,
        accountId: _selectedAccountId,
        amount: amountCents,
        type: type,
        note: _note,
        txnDate: _date,
      );

      // Refresh dashboard
      ref.invalidate(dashboardProvider);

      if (mounted) {
        HapticFeedback.mediumImpact();
        final amountStr = AmountExpression.formatCents(_computedCents);
        // Capture parent overlay BEFORE pop (our context dies after pop)
        final overlayContext = Navigator.of(context).overlay?.context;
        Navigator.of(context).pop(true);
        if (overlayContext != null && overlayContext.mounted) {
          TransactionSuccessOverlay.show(overlayContext, amountStr);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _showNoteInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _NoteInputSheet(
          initialNote: _note,
          onConfirm: (value) {
            setState(() => _note = value);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  void _showAccountPicker() {
    final accounts = ref.read(accountProvider).accounts;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(SpacingTokens.base),
              child: Text('选择账户', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            if (accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(SpacingTokens.xl),
                child: Text('暂无账户，请先在资产页创建', style: TextStyle(color: Colors.grey)),
              )
            else
              ...accounts.map((account) => ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(account.name),
                trailing: account.id == _selectedAccountId
                    ? const Icon(Icons.check, color: ColorTokens.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedAccountId = account.id);
                  Navigator.of(ctx).pop();
                },
              )),
            const SizedBox(height: SpacingTokens.base),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

/// Separate StatefulWidget to properly manage TextEditingController lifecycle.
class _NoteInputSheet extends StatefulWidget {
  final String initialNote;
  final ValueChanged<String> onConfirm;

  const _NoteInputSheet({
    required this.initialNote,
    required this.onConfirm,
  });

  @override
  State<_NoteInputSheet> createState() => _NoteInputSheetState();
}

class _NoteInputSheetState extends State<_NoteInputSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 50,
            decoration: const InputDecoration(
              hintText: '添加备注...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => widget.onConfirm(v.trim()),
          ),
          const SizedBox(height: SpacingTokens.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onConfirm(_controller.text.trim()),
              child: const Text('确定'),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
        ],
      ),
    );
  }
}
