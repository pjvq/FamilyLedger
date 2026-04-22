import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/loan_provider.dart';
import '../transaction/widgets/number_pad.dart';
import 'loans_page.dart';

class AddLoanPage extends ConsumerStatefulWidget {
  const AddLoanPage({super.key});

  @override
  ConsumerState<AddLoanPage> createState() => _AddLoanPageState();
}

class _AddLoanPageState extends ConsumerState<AddLoanPage> {
  final _nameController = TextEditingController();
  final _rateController = TextEditingController();

  String _loanType = 'mortgage';
  String _amountText = '';
  int _totalMonths = 360;
  String _repaymentMethod = 'equal_installment';
  int _paymentDay = 1;
  DateTime _startDate = DateTime.now();
  String? _accountId;
  bool _showNumberPad = false;
  bool _isSubmitting = false;

  static const _loanTypes = [
    ('mortgage', '房贷', '🏠'),
    ('car_loan', '车贷', '🚗'),
    ('credit_card', '信用卡', '💳'),
    ('consumer', '消费贷', '💰'),
    ('business', '经营贷', '🏢'),
    ('other', '其他', '📋'),
  ];

  static const _commonMonths = [12, 24, 36, 60, 120, 240, 360];

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accountState = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加贷款'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 贷款名称
                _SectionTitle(title: '贷款名称', theme: theme),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: '例如：XX银行房贷',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 20),
                // 贷款类型
                _SectionTitle(title: '贷款类型', theme: theme),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _loanTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final (type, label, emoji) = _loanTypes[index];
                      final selected = _loanType == type;
                      final typeInfo = getLoanTypeInfo(type);
                      return Semantics(
                        label: '$label贷款类型',
                        selected: selected,
                        child: GestureDetector(
                          onTap: () => setState(() => _loanType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 72,
                            decoration: BoxDecoration(
                              color: selected
                                  ? typeInfo.color.withValues(alpha: 0.12)
                                  : (isDark
                                      ? const Color(0xFF2C2C2E)
                                      : const Color(0xFFF2F2F7)),
                              borderRadius: BorderRadius.circular(14),
                              border: selected
                                  ? Border.all(
                                      color: typeInfo.color, width: 2)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(emoji,
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selected
                                        ? typeInfo.color
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),
                // 贷款金额
                _SectionTitle(title: '贷款金额（元）', theme: theme),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _showNumberPad = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A3A3C)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.primaryDark
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _amountText.isEmpty ? '输入金额' : _amountText,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: _amountText.isEmpty
                                  ? theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                // 年利率
                _SectionTitle(title: '年利率（%）', theme: theme),
                const SizedBox(height: 8),
                TextField(
                  controller: _rateController,
                  decoration: const InputDecoration(
                    hintText: '例如：4.20',
                    suffixText: '%',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,2}\.?\d{0,2}')),
                  ],
                ),

                const SizedBox(height: 20),
                // 贷款期数
                _SectionTitle(title: '贷款期数（月）', theme: theme),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonMonths.map((m) {
                    final selected = _totalMonths == m;
                    final label =
                        m >= 12 ? '${m ~/ 12}年 ($m月)' : '$m月';
                    return Semantics(
                      label: '贷款期数$label',
                      selected: selected,
                      child: ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _totalMonths = m),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                // 还款方式
                _SectionTitle(title: '还款方式', theme: theme),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'equal_installment',
                      label: Text('等额本息'),
                      icon: Icon(Icons.balance_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: 'equal_principal',
                      label: Text('等额本金'),
                      icon: Icon(Icons.trending_down_rounded, size: 18),
                    ),
                  ],
                  selected: {_repaymentMethod},
                  onSelectionChanged: (v) =>
                      setState(() => _repaymentMethod = v.first),
                ),

                const SizedBox(height: 20),
                // 还款日
                _SectionTitle(title: '每月还款日', theme: theme),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _paymentDay,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  items: List.generate(
                    28,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('每月 ${i + 1} 日'),
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentDay = v);
                  },
                ),

                const SizedBox(height: 20),
                // 起始日期
                _SectionTitle(title: '起始日期', theme: theme),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickStartDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.event_rounded),
                    ),
                    child: Text(
                      DateFormat('yyyy年MM月dd日').format(_startDate),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                // 关联还款账户
                _SectionTitle(title: '关联还款账户（可选）', theme: theme),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    hintText: '不关联',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('不关联'),
                    ),
                    ...accountState.accounts.map((acc) => DropdownMenuItem(
                          value: acc.id,
                          child: Text('${acc.icon} ${acc.name}'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),

                const SizedBox(height: 32),
                // 创建按钮
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('创建贷款'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          // Number pad
          if (_showNumberPad)
            NumberPad(
              onKey: (key) {
                setState(() {
                  if (key == '.' && _amountText.contains('.')) return;
                  if (key == '.' && _amountText.isEmpty) {
                    _amountText = '0.';
                    return;
                  }
                  // Max 2 decimal places
                  if (_amountText.contains('.')) {
                    final parts = _amountText.split('.');
                    if (parts[1].length >= 2) return;
                  }
                  _amountText += key;
                });
              },
              onDelete: () {
                setState(() {
                  if (_amountText.isNotEmpty) {
                    _amountText =
                        _amountText.substring(0, _amountText.length - 1);
                  }
                });
              },
              onConfirm: () {
                setState(() => _showNumberPad = false);
              },
              confirmEnabled: _amountText.isNotEmpty,
            ),
        ],
      ),
    );
  }

  void _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  void _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('请输入贷款名称');
      return;
    }
    if (_amountText.isEmpty) {
      _showError('请输入贷款金额');
      return;
    }
    final amount = double.tryParse(_amountText);
    if (amount == null || amount <= 0) {
      _showError('请输入有效金额');
      return;
    }
    final rate = double.tryParse(_rateController.text.trim());
    if (rate == null || rate < 0) {
      _showError('请输入有效利率');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(loanProvider.notifier).createLoan(
            name: name,
            loanType: _loanType,
            principal: (amount * 100).round(),
            annualRate: rate,
            totalMonths: _totalMonths,
            repaymentMethod: _repaymentMethod,
            paymentDay: _paymentDay,
            startDate: _startDate,
            accountId: _accountId,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ThemeData theme;
  const _SectionTitle({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}
