import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UpdateValuationDialog extends StatefulWidget {
  final String assetId;
  final Future<void> Function(int value) onSubmit;

  const UpdateValuationDialog({
    super.key,
    required this.assetId,
    required this.onSubmit,
  });

  @override
  State<UpdateValuationDialog> createState() => _UpdateValuationDialogState();
}

class _UpdateValuationDialogState extends State<UpdateValuationDialog> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final yuan = double.tryParse(text);
    if (yuan == null || yuan <= 0) return;

    setState(() => _isSubmitting = true);
    final valueCents = (yuan * 100).round();
    await widget.onSubmit(valueCents);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('更新估值'),
      content: Semantics(
        label: '输入新的估值金额',
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '当前估值（元）',
            prefixText: '¥ ',
            hintText: '0.00',
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          onSubmitted: (_) => _submit(),
        ),
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('确认'),
        ),
      ],
    );
  }
}
