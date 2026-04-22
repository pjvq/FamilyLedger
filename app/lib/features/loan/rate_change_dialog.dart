import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers/loan_provider.dart';

class RateChangeDialog extends ConsumerStatefulWidget {
  final String loanId;
  const RateChangeDialog({super.key, required this.loanId});

  @override
  ConsumerState<RateChangeDialog> createState() => _RateChangeDialogState();
}

class _RateChangeDialogState extends ConsumerState<RateChangeDialog> {
  final _rateController = TextEditingController();
  DateTime _effectiveDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current rate
    final loan = ref.read(loanProvider).currentLoan;
    if (loan != null) {
      _rateController.text = loan.annualRate.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('利率变动'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '新年利率（%）',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rateController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '例如：3.85',
              suffixText: '%',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,2}\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '生效日期',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.event_rounded),
              ),
              child: Text(
                DateFormat('yyyy年MM月dd日').format(_effectiveDate),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('确认'),
        ),
      ],
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _effectiveDate = picked);
    }
  }

  void _submit() async {
    final rate = double.tryParse(_rateController.text.trim());
    if (rate == null || rate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效利率')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(loanProvider.notifier).recordRateChange(
            loanId: widget.loanId,
            newRate: rate,
            effectiveDate: _effectiveDate,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
