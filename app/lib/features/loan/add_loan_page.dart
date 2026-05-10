import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/account_provider.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/loan_provider.dart';
import '../shared/family_scope_selector.dart';
import '../transaction/widgets/number_pad.dart';
import 'loans_page.dart';

/// 贷款大类选择
enum LoanCategory {
  commercial, // 纯商业贷款
  provident, // 纯公积金贷款
  combined, // 组合贷款
}

class AddLoanPage extends ConsumerStatefulWidget {
  const AddLoanPage({super.key});

  @override
  ConsumerState<AddLoanPage> createState() => _AddLoanPageState();
}

class _AddLoanPageState extends ConsumerState<AddLoanPage> {
  LoanCategory _category = LoanCategory.commercial;

  // Common fields
  final _nameController = TextEditingController();
  String _loanType = 'mortgage';
  int _paymentDay = 1;
  DateTime _startDate = DateTime.now();
  String? _accountId;
  bool _isSubmitting = false;
  String? _scopeFamilyId; // null = personal, familyId = family
  bool _scopeInitialized = false;

  // ── Commercial loan fields ──
  final _comRateController = TextEditingController();
  final _comLprBaseController = TextEditingController(text: '3.45');
  final _comLprSpreadController = TextEditingController(text: '0');
  String _comAmountText = '';
  int _comTotalMonths = 360;
  String _comRepaymentMethod = 'equal_installment';
  String _comRateType = 'fixed';
  bool _showComNumberPad = false;

  // ── Provident loan fields ──
  final _pvdRateController = TextEditingController(text: '2.85');
  String _pvdAmountText = '';
  int _pvdTotalMonths = 360;
  String _pvdRepaymentMethod = 'equal_installment';
  bool _showPvdNumberPad = false;

  // ── Combined loan fields ──
  String _combTotalAmountText = '';
  String _combPvdAmountText = '';
  int _currentStep = 0;
  // Combined: provident part
  final _combPvdRateController = TextEditingController(text: '2.85');
  int _combPvdTotalMonths = 360;
  String _combPvdRepaymentMethod = 'equal_installment';
  // Combined: commercial part
  final _combComRateController = TextEditingController();
  final _combComLprBaseController = TextEditingController(text: '3.45');
  final _combComLprSpreadController = TextEditingController(text: '0');
  int _combComTotalMonths = 360;
  String _combComRepaymentMethod = 'equal_installment';
  String _combComRateType = 'fixed';
  bool _showCombNumberPad = false;
  String _combActiveField = 'total'; // total / pvd

  static const _loanTypes = [
    ('mortgage', '房贷', '🏠'),
    ('car_loan', '车贷', '🚗'),
    ('consumer', '消费贷', '💰'),
    ('business', '经营贷', '🏢'),
    ('other', '其他', '📋'),
  ];

  static const _commonMonths = [12, 24, 36, 60, 120, 240, 360];

  @override
  void dispose() {
    _nameController.dispose();
    _comRateController.dispose();
    _comLprBaseController.dispose();
    _comLprSpreadController.dispose();
    _pvdRateController.dispose();
    _combPvdRateController.dispose();
    _combComRateController.dispose();
    _combComLprBaseController.dispose();
    _combComLprSpreadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountState = ref.watch(accountProvider);

    if (!_scopeInitialized) {
      _scopeFamilyId = ref.read(currentFamilyIdProvider);
      _scopeInitialized = true;
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      appBar: AppBar(title: const Text('添加贷款')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 贷款大类选择 ──
                _SectionTitle(title: '贷款类别', theme: theme),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _categoryChip(LoanCategory.commercial, '商业贷款', '🏦', theme),
                    const SizedBox(width: 8),
                    _categoryChip(LoanCategory.provident, '公积金贷款', '🏠', theme),
                    const SizedBox(width: 8),
                    _categoryChip(LoanCategory.combined, '组合贷款', '🏘️', theme),
                  ],
                ),

                const SizedBox(height: 20),
                // ── 归属选择（个人/家庭）──
                FamilyScopeSelector(
                  initialFamilyId: _scopeFamilyId,
                  onChanged: (fid) => _scopeFamilyId = fid,
                ),
                // ── 贷款名称 ──
                _SectionTitle(title: '贷款名称', theme: theme),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: _category == LoanCategory.combined
                        ? '例如：XX小区房贷'
                        : '例如：XX银行房贷',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 20),
                // ── 贷款类型 ──
                _SectionTitle(title: '贷款类型', theme: theme),
                const SizedBox(height: 8),
                _buildLoanTypeSelector(theme),

                const SizedBox(height: 20),
                // ── 还款日 ──
                _buildPaymentDayAndDate(theme),

                const SizedBox(height: 20),
                // ── 关联还款账户 ──
                _SectionTitle(title: '关联还款账户（可选）', theme: theme),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    hintText: '不关联',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('不关联')),
                    ...accountState.accounts.map((acc) => DropdownMenuItem(
                          value: acc.id,
                          child: Text('${acc.icon} ${acc.name}'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // ── Category specific form ──
                if (_category == LoanCategory.commercial)
                  _buildCommercialForm(theme),
                if (_category == LoanCategory.provident)
                  _buildProvidentForm(theme),
                if (_category == LoanCategory.combined)
                  _buildCombinedForm(theme),

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
                      : Text(_category == LoanCategory.combined
                          ? '创建组合贷款'
                          : '创建贷款'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          // Number pads
          if (_showComNumberPad)
            _buildNumberPad(
              text: _comAmountText,
              onUpdate: (t) => setState(() => _comAmountText = t),
              onDone: () => setState(() => _showComNumberPad = false),
            ),
          if (_showPvdNumberPad)
            _buildNumberPad(
              text: _pvdAmountText,
              onUpdate: (t) => setState(() => _pvdAmountText = t),
              onDone: () => setState(() => _showPvdNumberPad = false),
            ),
          if (_showCombNumberPad)
            _buildNumberPad(
              text: _combActiveField == 'total'
                  ? _combTotalAmountText
                  : _combPvdAmountText,
              onUpdate: (t) {
                setState(() {
                  if (_combActiveField == 'total') {
                    _combTotalAmountText = t;
                  } else {
                    _combPvdAmountText = t;
                  }
                });
              },
              onDone: () => setState(() => _showCombNumberPad = false),
            ),
        ],
      ),
    ),
    );
  }

  // ── Category Chip ──
  Widget _categoryChip(
      LoanCategory cat, String label, String emoji, ThemeData theme) {
    final selected = _category == cat;
    return Expanded(
      child: Semantics(
        label: '$label类别',
        selected: selected,
        child: ChoiceChip(
          label: Text('$emoji $label', style: TextStyle(fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          selected: selected,
          onSelected: (_) => setState(() {
            _category = cat;
            _showComNumberPad = false;
            _showPvdNumberPad = false;
            _showCombNumberPad = false;
          }),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
      ),
    );
  }

  // ── Loan Type Selector ──
  Widget _buildLoanTypeSelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
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
                      ? Border.all(color: typeInfo.color, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? typeInfo.color
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Payment Day & Start Date ──
  Widget _buildPaymentDayAndDate(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: '每月还款日', theme: theme),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _paymentDay,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: '起始日期', theme: theme),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickStartDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.event_rounded),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(
                        DateFormat('yyyy/MM/dd').format(_startDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Commercial Loan Form ──
  Widget _buildCommercialForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('💰 商业贷款信息',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildAmountField(
          theme: theme,
          label: '贷款金额（元）',
          text: _comAmountText,
          onTap: () => setState(() {
            _showComNumberPad = true;
            _showPvdNumberPad = false;
            _showCombNumberPad = false;
          }),
        ),
        const SizedBox(height: 16),
        _buildRateTypeAndInput(
          theme: theme,
          rateType: _comRateType,
          onRateTypeChanged: (v) => setState(() => _comRateType = v),
          fixedRateController: _comRateController,
          lprBaseController: _comLprBaseController,
          lprSpreadController: _comLprSpreadController,
        ),
        const SizedBox(height: 16),
        _buildMonthsSelector(
          theme: theme,
          totalMonths: _comTotalMonths,
          onChanged: (v) => setState(() => _comTotalMonths = v),
        ),
        const SizedBox(height: 16),
        _buildRepaymentMethod(
          theme: theme,
          method: _comRepaymentMethod,
          onChanged: (v) => setState(() => _comRepaymentMethod = v),
        ),
      ],
    );
  }

  // ── Provident Loan Form ──
  Widget _buildProvidentForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🏠 公积金贷款信息',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildAmountField(
          theme: theme,
          label: '贷款金额（元）',
          text: _pvdAmountText,
          onTap: () => setState(() {
            _showPvdNumberPad = true;
            _showComNumberPad = false;
            _showCombNumberPad = false;
          }),
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: '年利率（%）— 公积金固定利率', theme: theme),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pvdRateController,
                decoration: const InputDecoration(
                  hintText: '2.85',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,3}')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('首套 2.85%'),
              onPressed: () => _pvdRateController.text = '2.85',
            ),
            const SizedBox(width: 4),
            ActionChip(
              label: const Text('二套 3.325%'),
              onPressed: () => _pvdRateController.text = '3.325',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildMonthsSelector(
          theme: theme,
          totalMonths: _pvdTotalMonths,
          onChanged: (v) => setState(() => _pvdTotalMonths = v),
        ),
        const SizedBox(height: 16),
        _buildRepaymentMethod(
          theme: theme,
          method: _pvdRepaymentMethod,
          onChanged: (v) => setState(() => _pvdRepaymentMethod = v),
        ),
      ],
    );
  }

  // ── Combined Loan Form (Stepper) ──
  Widget _buildCombinedForm(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    // Calculate commercial amount
    final totalAmount = double.tryParse(_combTotalAmountText) ?? 0;
    final pvdAmount = double.tryParse(_combPvdAmountText) ?? 0;
    final comAmount = totalAmount - pvdAmount;
    final comAmountStr = comAmount > 0 ? comAmount.toStringAsFixed(2) : '0.00';

    return Stepper(
      currentStep: _currentStep,
      onStepContinue: () {
        if (_currentStep < 2) {
          setState(() => _currentStep++);
        }
      },
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() => _currentStep--);
        }
      },
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              if (_currentStep < 2)
                FilledButton.tonal(
                  onPressed: details.onStepContinue,
                  child: const Text('下一步'),
                ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('上一步'),
                ),
              ],
            ],
          ),
        );
      },
      steps: [
        // Step 1: 总贷款信息
        Step(
          title: const Text('总贷款信息'),
          subtitle: _combTotalAmountText.isNotEmpty
              ? Text('总额 ¥$_combTotalAmountText')
              : null,
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAmountField(
                theme: theme,
                label: '总贷款金额（元）',
                text: _combTotalAmountText,
                onTap: () => setState(() {
                  _combActiveField = 'total';
                  _showCombNumberPad = true;
                  _showComNumberPad = false;
                  _showPvdNumberPad = false;
                }),
              ),
            ],
          ),
        ),
        // Step 2: 公积金部分
        Step(
          title: const Text('公积金部分'),
          subtitle: _combPvdAmountText.isNotEmpty
              ? Text('公积金 ¥$_combPvdAmountText')
              : null,
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAmountField(
                theme: theme,
                label: '公积金贷款金额（元）',
                text: _combPvdAmountText,
                onTap: () => setState(() {
                  _combActiveField = 'pvd';
                  _showCombNumberPad = true;
                  _showComNumberPad = false;
                  _showPvdNumberPad = false;
                }),
              ),
              const SizedBox(height: 16),
              _SectionTitle(title: '公积金年利率（%）', theme: theme),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _combPvdRateController,
                      decoration: const InputDecoration(
                        hintText: '2.85',
                        suffixText: '%',
                        prefixIcon: Icon(Icons.percent_rounded),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d{0,2}\.?\d{0,3}')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('首套'),
                    onPressed: () =>
                        _combPvdRateController.text = '2.85',
                  ),
                  const SizedBox(width: 4),
                  ActionChip(
                    label: const Text('二套'),
                    onPressed: () =>
                        _combPvdRateController.text = '3.325',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildMonthsSelector(
                theme: theme,
                totalMonths: _combPvdTotalMonths,
                onChanged: (v) => setState(() => _combPvdTotalMonths = v),
              ),
              const SizedBox(height: 16),
              _buildRepaymentMethod(
                theme: theme,
                method: _combPvdRepaymentMethod,
                onChanged: (v) =>
                    setState(() => _combPvdRepaymentMethod = v),
              ),
            ],
          ),
        ),
        // Step 3: 商贷部分
        Step(
          title: const Text('商贷部分'),
          subtitle: comAmount > 0
              ? Text('商贷 ¥$comAmountStr')
              : null,
          isActive: _currentStep >= 2,
          state: StepState.indexed,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show auto-calculated commercial amount
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '商贷金额 = 总额 - 公积金 = ¥$comAmountStr',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildRateTypeAndInput(
                theme: theme,
                rateType: _combComRateType,
                onRateTypeChanged: (v) =>
                    setState(() => _combComRateType = v),
                fixedRateController: _combComRateController,
                lprBaseController: _combComLprBaseController,
                lprSpreadController: _combComLprSpreadController,
              ),
              const SizedBox(height: 16),
              _buildMonthsSelector(
                theme: theme,
                totalMonths: _combComTotalMonths,
                onChanged: (v) => setState(() => _combComTotalMonths = v),
              ),
              const SizedBox(height: 16),
              _buildRepaymentMethod(
                theme: theme,
                method: _combComRepaymentMethod,
                onChanged: (v) =>
                    setState(() => _combComRepaymentMethod = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared Widgets ──

  Widget _buildAmountField({
    required ThemeData theme,
    required String label,
    required String text,
    required VoidCallback onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: label, theme: theme),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A3A3C) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  '¥',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.primaryDark : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.isEmpty ? '输入金额' : text,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: text.isEmpty
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateTypeAndInput({
    required ThemeData theme,
    required String rateType,
    required ValueChanged<String> onRateTypeChanged,
    required TextEditingController fixedRateController,
    required TextEditingController lprBaseController,
    required TextEditingController lprSpreadController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: '利率类型', theme: theme),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'fixed',
              label: Text('固定利率'),
              icon: Icon(Icons.lock_rounded, size: 16),
            ),
            ButtonSegment(
              value: 'lpr_floating',
              label: Text('LPR浮动'),
              icon: Icon(Icons.trending_up_rounded, size: 16),
            ),
          ],
          selected: {rateType},
          onSelectionChanged: (v) => onRateTypeChanged(v.first),
        ),
        const SizedBox(height: 12),
        if (rateType == 'fixed')
          TextField(
            controller: fixedRateController,
            decoration: const InputDecoration(
              hintText: '例如：3.20',
              suffixText: '%',
              prefixIcon: Icon(Icons.percent_rounded),
              labelText: '年利率',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,3}')),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: lprBaseController,
                  decoration: const InputDecoration(
                    labelText: 'LPR基准',
                    hintText: '3.45',
                    suffixText: '%',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,2}\.?\d{0,3}')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('+', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: lprSpreadController,
                  decoration: const InputDecoration(
                    labelText: '基点偏移',
                    hintText: '-20',
                    suffixText: 'BP',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d{0,4}\.?\d{0,2}')),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMonthsSelector({
    required ThemeData theme,
    required int totalMonths,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: '贷款期数', theme: theme),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonMonths.map((m) {
            final selected = totalMonths == m;
            final label = m >= 12 ? '${m ~/ 12}年' : '$m月';
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => onChanged(m),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRepaymentMethod({
    required ThemeData theme,
    required String method,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: '还款方式', theme: theme),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'equal_installment',
              label: Text('等额本息'),
              icon: Icon(Icons.balance_rounded, size: 16),
            ),
            ButtonSegment(
              value: 'equal_principal',
              label: Text('等额本金'),
              icon: Icon(Icons.trending_down_rounded, size: 16),
            ),
          ],
          selected: {method},
          onSelectionChanged: (v) => onChanged(v.first),
        ),
      ],
    );
  }

  Widget _buildNumberPad({
    required String text,
    required ValueChanged<String> onUpdate,
    required VoidCallback onDone,
  }) {
    return NumberPad(
      onKey: (key) {
        var newText = text;
        if (key == '.' && newText.contains('.')) return;
        if (key == '.' && newText.isEmpty) {
          newText = '0.';
        } else {
          if (newText.contains('.')) {
            final parts = newText.split('.');
            if (parts[1].length >= 2) return;
          }
          newText += key;
        }
        onUpdate(newText);
      },
      onDelete: () {
        if (text.isNotEmpty) {
          onUpdate(text.substring(0, text.length - 1));
        }
      },
      onConfirm: onDone,
      confirmEnabled: text.isNotEmpty,
    );
  }

  // ── Helpers ──

  double _parseRate({
    required String rateType,
    required TextEditingController fixedController,
    required TextEditingController lprBaseController,
    required TextEditingController lprSpreadController,
  }) {
    if (rateType == 'lpr_floating') {
      final base = double.tryParse(lprBaseController.text.trim()) ?? 0;
      final spreadBP = double.tryParse(lprSpreadController.text.trim()) ?? 0;
      return base + spreadBP / 100; // BP to percentage points
    }
    return double.tryParse(fixedController.text.trim()) ?? 0;
  }

  double _parseLprBase(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  double _parseLprSpread(TextEditingController controller) {
    final bpStr = controller.text.trim();
    final bp = double.tryParse(bpStr) ?? 0;
    return bp / 100; // BP to percentage points
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

    setState(() => _isSubmitting = true);

    try {
      switch (_category) {
        case LoanCategory.commercial:
          await _submitCommercial(name);
          break;
        case LoanCategory.provident:
          await _submitProvident(name);
          break;
        case LoanCategory.combined:
          await _submitCombined(name);
          break;
      }

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

  Future<void> _submitCommercial(String name) async {
    final amount = double.tryParse(_comAmountText);
    if (amount == null || amount <= 0) {
      throw Exception('请输入有效金额');
    }
    final rate = _parseRate(
      rateType: _comRateType,
      fixedController: _comRateController,
      lprBaseController: _comLprBaseController,
      lprSpreadController: _comLprSpreadController,
    );
    if (rate <= 0) throw Exception('请输入有效利率');

    await ref.read(loanProvider.notifier).createLoan(
          name: name,
          loanType: _loanType,
          principal: (amount * 100).round(),
          annualRate: rate,
          totalMonths: _comTotalMonths,
          repaymentMethod: _comRepaymentMethod,
          paymentDay: _paymentDay,
          startDate: _startDate,
          accountId: _accountId,
          rateType: _comRateType,
          lprBase: _comRateType == 'lpr_floating'
              ? _parseLprBase(_comLprBaseController)
              : null,
          lprSpread: _comRateType == 'lpr_floating'
              ? _parseLprSpread(_comLprSpreadController)
              : null,
          familyId: _scopeFamilyId,
        );
  }

  Future<void> _submitProvident(String name) async {
    final amount = double.tryParse(_pvdAmountText);
    if (amount == null || amount <= 0) {
      throw Exception('请输入有效金额');
    }
    final rate = double.tryParse(_pvdRateController.text.trim()) ?? 0;
    if (rate <= 0) throw Exception('请输入有效利率');

    await ref.read(loanProvider.notifier).createLoan(
          name: name,
          loanType: _loanType,
          principal: (amount * 100).round(),
          annualRate: rate,
          totalMonths: _pvdTotalMonths,
          repaymentMethod: _pvdRepaymentMethod,
          paymentDay: _paymentDay,
          startDate: _startDate,
          accountId: _accountId,
          rateType: 'fixed',
          familyId: _scopeFamilyId,
        );
  }

  Future<void> _submitCombined(String name) async {
    final totalAmount = double.tryParse(_combTotalAmountText);
    if (totalAmount == null || totalAmount <= 0) {
      throw Exception('请输入总贷款金额');
    }
    final pvdAmount = double.tryParse(_combPvdAmountText);
    if (pvdAmount == null || pvdAmount <= 0) {
      throw Exception('请输入公积金贷款金额');
    }
    if (pvdAmount >= totalAmount) {
      throw Exception('公积金金额需小于总额');
    }
    final comAmount = totalAmount - pvdAmount;

    // Provident rate
    final pvdRate =
        double.tryParse(_combPvdRateController.text.trim()) ?? 0;
    if (pvdRate <= 0) throw Exception('请输入有效的公积金利率');

    // Commercial rate
    final comRate = _parseRate(
      rateType: _combComRateType,
      fixedController: _combComRateController,
      lprBaseController: _combComLprBaseController,
      lprSpreadController: _combComLprSpreadController,
    );
    if (comRate <= 0) throw Exception('请输入有效的商贷利率');

    await ref.read(loanProvider.notifier).createLoanGroup(
      name: name,
      groupType: 'combined',
      loanType: _loanType,
      paymentDay: _paymentDay,
      startDate: _startDate,
      accountId: _accountId,
      familyId: _scopeFamilyId,
      subLoans: [
        SubLoanInput(
          name: '$name-公积金',
          subType: 'provident',
          principal: (pvdAmount * 100).round(),
          annualRate: pvdRate,
          totalMonths: _combPvdTotalMonths,
          repaymentMethod: _combPvdRepaymentMethod,
          rateType: 'fixed',
        ),
        SubLoanInput(
          name: '$name-商贷',
          subType: 'commercial',
          principal: (comAmount * 100).round(),
          annualRate: comRate,
          totalMonths: _combComTotalMonths,
          repaymentMethod: _combComRepaymentMethod,
          rateType: _combComRateType,
          lprBase: _combComRateType == 'lpr_floating'
              ? _parseLprBase(_combComLprBaseController)
              : 0.0,
          lprSpread: _combComRateType == 'lpr_floating'
              ? _parseLprSpread(_combComLprSpreadController)
              : 0.0,
        ),
      ],
    );
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
