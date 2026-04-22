import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/account_provider.dart';
import '../transaction/widgets/number_pad.dart';

class AddAccountPage extends ConsumerStatefulWidget {
  const AddAccountPage({super.key});

  @override
  ConsumerState<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends ConsumerState<AddAccountPage> {
  final _nameController = TextEditingController();
  String _selectedType = 'cash';
  String _amountStr = '0';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加账户'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account name input
                  Text(
                    '账户名称',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: '例如：招商银行储蓄卡',
                      prefixIcon: Icon(Icons.edit_rounded),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),

                  // Account type selector
                  Text(
                    '账户类型',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: AccountTypeHelper.allTypes.map((type) {
                        final isSelected = type == _selectedType;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _TypeChip(
                            type: type,
                            isSelected: isSelected,
                            isDark: isDark,
                            onTap: () => setState(() => _selectedType = type),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Initial balance display
                  Text(
                    '初始余额',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
          ),
          // Number pad
          NumberPad(
            onKey: _onKey,
            onDelete: _onDelete,
            onConfirm: _onConfirm,
            confirmEnabled: _nameController.text.trim().isNotEmpty,
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入账户名称')),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final amount = (double.tryParse(_amountStr) ?? 0) * 100;
      await ref.read(accountProvider.notifier).createAccount(
            name: name,
            accountType: _selectedType,
            initialBalance: amount.round(),
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = AccountTypeHelper.defaultIcon(type);
    final name = AccountTypeHelper.displayName(type);

    return Semantics(
      label: name,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 72,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primaryDark.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1))
                : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppColors.primaryDark : AppColors.primary)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? (isDark ? AppColors.primaryDark : AppColors.primary)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
