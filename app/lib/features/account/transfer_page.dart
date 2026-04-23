import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../transaction/widgets/number_pad.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  String? _fromAccountId;
  String? _toAccountId;
  String _amountStr = '0';
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('转账'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From → To
                  Row(
                    children: [
                      Expanded(
                        child: _AccountSelector(
                          label: '从',
                          accounts: accountState.accounts,
                          selectedId: _fromAccountId,
                          excludeId: _toAccountId,
                          isDark: isDark,
                          onChanged: (id) =>
                              setState(() => _fromAccountId = id),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primaryDark.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _AccountSelector(
                          label: '到',
                          accounts: accountState.accounts,
                          selectedId: _toAccountId,
                          excludeId: _fromAccountId,
                          isDark: isDark,
                          onChanged: (id) =>
                              setState(() => _toAccountId = id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Amount display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¥',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _amountStr,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Note
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: '备注（可选）',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Number pad
          NumberPad(
            onKey: _onKey,
            onDelete: _onDelete,
            onConfirm: _onConfirm,
            confirmEnabled: _fromAccountId != null &&
                _toAccountId != null &&
                _amountStr != '0',
          ),
        ],
      ),
    );
  }

  void _onKey(String key) {
    setState(() {
      if (_amountStr == '0' && key != '.') {
        _amountStr = key;
      } else if (key == '.' && _amountStr.contains('.')) {
        return;
      } else if (_amountStr.contains('.') &&
          _amountStr.split('.').last.length >= 2) {
        return;
      } else {
        _amountStr += key;
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_amountStr.length <= 1) {
        _amountStr = '0';
      } else {
        _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      }
    });
  }

  Future<void> _onConfirm() async {
    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择来源和目标账户')),
      );
      return;
    }

    final amount = ((double.tryParse(_amountStr) ?? 0) * 100).round();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入转账金额')),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(accountProvider.notifier).transferBetween(
            fromAccountId: _fromAccountId!,
            toAccountId: _toAccountId!,
            amount: amount,
            note: _noteController.text.trim(),
          );
      // 刷新账户和仪表盘
      ref.read(accountProvider.notifier).refresh();
      ref.read(dashboardProvider.notifier).loadAll();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('转账成功')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _AccountSelector extends StatelessWidget {
  final String label;
  final List<Account> accounts;
  final String? selectedId;
  final String? excludeId;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _AccountSelector({
    required this.label,
    required this.accounts,
    required this.selectedId,
    this.excludeId,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredAccounts =
        accounts.where((a) => a.id != excludeId).toList();

    return Semantics(
      label: '$label账户选择',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedId,
                hint: const Text('选择账户'),
                items: filteredAccounts.map((a) {
                  return DropdownMenuItem(
                    value: a.id,
                    child: Row(
                      children: [
                        Text(a.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            a.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
