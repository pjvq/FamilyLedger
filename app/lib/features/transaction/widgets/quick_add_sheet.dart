import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/amount_expression.dart';
import '../../../core/widgets/success_animation.dart';
import '../../../data/local/database.dart';
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
  /// Pass an existing transaction to enter edit mode.
  final Transaction? existingTransaction;

  const QuickAddSheet({super.key, this.existingTransaction});

  /// Barrier overlay opacity for the modal sheet.
  static const _barrierColor = Colors.black54;

  /// 从任意位置显示快速记账面板
  static Future<bool?> show(BuildContext context, {Transaction? transaction}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: _barrierColor,
      builder: (_) => QuickAddSheet(existingTransaction: transaction),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet>
    with SingleTickerProviderStateMixin {
  String _expression = '0';
  int _cachedCents = 0;
  String _note = '';
  int _typeIndex = 0; // 0=支出, 1=收入
  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _date = DateTime.now();
  bool _isSubmitting = false;
  bool _continuousMode = false;
  int _savedCount = 0;

  /// Animation controller for the "saved" flash feedback.
  late final AnimationController _flashController;
  late final Animation<double> _flashOpacity;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Flash: quick fade-in (0→1 over 20%) then slow fade-out (1→0 over 80%)
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(_flashController);
    // Default account
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = ref.read(accountProvider).accounts;
      if (accounts.isNotEmpty && _selectedAccountId == null) {
        setState(() => _selectedAccountId = accounts.first.id);
      }
      // Edit mode: populate fields from existing transaction
      final txn = widget.existingTransaction;
      if (txn != null) {
        setState(() {
          _expression = (txn.amount / 100).toStringAsFixed(
            txn.amount % 100 == 0 ? 0 : 2,
          );
          _cachedCents = txn.amount;
          _typeIndex = txn.type == 'income' ? 1 : 0;
          _selectedCategoryId = txn.categoryId;
          _selectedAccountId = txn.accountId;
          _date = txn.txnDate;
          _note = txn.note;
        });
      }
    });
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  int get _computedCents => _cachedCents;

  void _updateExpression(String newExpr) {
    _expression = newExpr;
    _cachedCents = AmountExpression.evaluateCents(newExpr);
  }

  bool get _canSubmit =>
      _computedCents > 0 && _selectedCategoryId != null && !_isSubmitting;

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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(RadiusTokens.xl)),
      ),
      child: Column(
        children: [
          // Drag handle + continuous mode toggle
          const SizedBox(height: SpacingTokens.md),
          _buildHeader(theme, isDark),
          const SizedBox(height: SpacingTokens.sm),

          // Top area: account pill + amount + note (20% of sheet)
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Account selector + date chip row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AccountPill(
                      accountName: selectedAccount?.name ?? '选择账户',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: _showAccountPicker,
                    ),
                    if (!_isToday(_date)) ...[
                      const SizedBox(width: SpacingTokens.sm),
                      GestureDetector(
                        onTap: _showDatePicker,
                        child: Chip(
                          avatar: const Icon(Icons.calendar_today, size: 14),
                          label: Text(
                            '${_date.month}月${_date.day}日 ${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: () => setState(() => _date = DateTime.now()),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: SpacingTokens.sm),

                // Amount display
                AnimatedAmountDisplay(
                  expression: _expression,
                  note: _note.isEmpty ? null : _note,
                  onNoteTap: _showNoteInput,
                ),
              ],
            ),
          ),

          // Bottom area: type selector + categories + keyboard (80%)
          Expanded(
            flex: 8,
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
                  confirmLabel: _isSubmitting ? '...' : (_isEditMode ? '保存' : (_continuousMode ? '下一笔' : '完成')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
      child: Row(
        children: [
          const Spacer(),
          const _DragHandle(),
          const Spacer(),
          if (!_isEditMode && _continuousMode && _savedCount > 0) ...[
            _SavedCountBadge(
              count: _savedCount,
              animation: _flashOpacity,
            ),
            const SizedBox(width: SpacingTokens.sm),
          ],
          if (!_isEditMode)
            _ContinuousModeToggle(
            isActive: _continuousMode,
            isDark: isDark,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _continuousMode = !_continuousMode;
                if (!_continuousMode) _savedCount = 0;
              });
            },
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


  bool get _isEditMode => widget.existingTransaction != null;

  Future<void> _onConfirm() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    try {
      final amountCents = _computedCents;
      final type = _typeIndex == 0 ? 'expense' : 'income';

      if (_isEditMode) {
        await ref.read(transactionProvider.notifier).updateTransaction(
          id: widget.existingTransaction!.id,
          categoryId: _selectedCategoryId!,
          amount: amountCents,
          type: type,
          note: _note,
          txnDate: _date,
        );
      } else {
        await ref.read(transactionProvider.notifier).addTransaction(
          categoryId: _selectedCategoryId!,
          accountId: _selectedAccountId,
          amount: amountCents,
          type: type,
          note: _note,
          txnDate: _date,
        );
      }

      // Refresh dashboard
      ref.invalidate(dashboardProvider);

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      if (_continuousMode) {
        // Stay open: reset amount + note, keep category & account
        setState(() {
          _isSubmitting = false;
          _savedCount++;
          _updateExpression('0');
          _note = '';
          _date = DateTime.now();
        });
        // Flash animation feedback
        _flashController.forward(from: 0);
      } else {
        final amountStr = AmountExpression.formatCents(_computedCents);
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
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_date),
      );
      setState(() {
        _date = DateTime(
          picked.year, picked.month, picked.day,
          time?.hour ?? _date.hour, time?.minute ?? _date.minute,
        );
      });
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

// ─── Extracted Header Widgets ──────────────────────────────────────────

/// Drag handle indicator at the top of the bottom sheet.
class _DragHandle extends StatelessWidget {
  static const double _width = 40;
  static const double _height = 4;

  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(_height / 2),
      ),
    );
  }
}

/// Saved count badge with fade-in/fade-out flash animation.
class _SavedCountBadge extends StatelessWidget {
  final int count;
  final Animation<double> animation;

  const _SavedCountBadge({required this.count, required this.animation});

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    return FadeTransition(
      opacity: animation,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.sm,
          vertical: SpacingTokens.xs,
        ),
        decoration: BoxDecoration(
          color: colors.income.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(RadiusTokens.full),
        ),
        child: Text(
          '✓ $count',
          style: TypographyTokens.caption(
            color: colors.income,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Toggle pill button for continuous booking mode.
class _ContinuousModeToggle extends StatelessWidget {
  static const double _borderWidth = 1;

  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ContinuousModeToggle({
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = isDark ? ColorTokens.primaryLight : ColorTokens.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final inactiveColor = onSurface.withValues(alpha: 0.4);
    final borderInactive = onSurface.withValues(alpha: 0.2);
    final color = isActive ? primaryColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.sm,
          vertical: SpacingTokens.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(RadiusTokens.full),
          border: Border.all(
            color: isActive ? primaryColor : borderInactive,
            width: _borderWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat_rounded, size: IconSizeTokens.xs, color: color),
            const SizedBox(width: SpacingTokens.xs),
            Text('连续', style: TypographyTokens.caption(color: color)),
          ],
        ),
      ),
    );
  }
}
