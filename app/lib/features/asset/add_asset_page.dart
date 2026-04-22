import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/asset_provider.dart';

class AddAssetPage extends ConsumerStatefulWidget {
  const AddAssetPage({super.key});

  @override
  ConsumerState<AddAssetPage> createState() => _AddAssetPageState();
}

class _AddAssetPageState extends ConsumerState<AddAssetPage> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedType = 'other';
  DateTime _purchaseDate = DateTime.now();

  // Depreciation settings
  String _depreciationMethod = 'none';
  int _usefulLifeYears = 5;
  double _salvageRate = 0.05;
  bool _showDepreciationSettings = false;

  static const _assetTypes = [
    ('real_estate', '🏠', '房产'),
    ('vehicle', '🚗', '车辆'),
    ('electronics', '📱', '电子'),
    ('furniture', '🛋️', '家具'),
    ('jewelry', '💎', '珠宝'),
    ('other', '📦', '其他'),
  ];

  static const _yearPresets = [3, 5, 10, 20, 30];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price = (double.tryParse(_priceController.text) ?? 0) * 100;
    if (price <= 0) return;

    await ref.read(assetProvider.notifier).createAsset(
          name: _nameController.text.trim(),
          assetType: _selectedType,
          purchasePrice: price.round(),
          purchaseDate: _purchaseDate,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          depreciationMethod: _depreciationMethod,
          usefulLifeYears: _usefulLifeYears,
          salvageRate: _salvageRate,
        );

    if (mounted) Navigator.of(context).pop();
  }

  void _applyPreset(String label, int years, double rate) {
    setState(() {
      _depreciationMethod = 'straight_line';
      _usefulLifeYears = years;
      _salvageRate = rate;
      _showDepreciationSettings = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final assetState = ref.watch(assetProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加资产'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // Asset name
            Semantics(
              label: '资产名称',
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '资产名称',
                  hintText: '例如：MacBook Pro 2024',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '请输入资产名称' : null,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 20),

            // Type selector
            Text(
              '资产类型',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _assetTypes.map((t) {
                  final (type, icon, label) = t;
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      label: '$label${isSelected ? "，已选中" : ""}',
                      button: true,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 72,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.assetDark.withValues(alpha: 0.2)
                                    : AppColors.asset.withValues(alpha: 0.1))
                                : (isDark
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFF2F2F7)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.assetDark
                                      : AppColors.asset)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(icon,
                                  style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? (isDark
                                          ? AppColors.assetDark
                                          : AppColors.asset)
                                      : theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Purchase price
            Semantics(
              label: '购入价格',
              child: TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: '购入价格（元）',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                  prefixText: '¥ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入购入价格';
                  final val = double.tryParse(v);
                  if (val == null || val <= 0) return '请输入有效金额';
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 20),

            // Purchase date
            Semantics(
              label:
                  '购入日期 ${DateFormat('yyyy年M月d日').format(_purchaseDate)}',
              button: true,
              child: ListTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: const Text('购入日期'),
                trailing: Text(
                  DateFormat('yyyy-MM-dd').format(_purchaseDate),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _purchaseDate = picked);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // Description
            Semantics(
              label: '描述（选填）',
              child: TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '描述（选填）',
                  hintText: '型号、颜色、配置等备注',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(height: 24),

            // Depreciation section
            _DepreciationSection(
              isExpanded: _showDepreciationSettings,
              method: _depreciationMethod,
              usefulLifeYears: _usefulLifeYears,
              salvageRate: _salvageRate,
              yearPresets: _yearPresets,
              isDark: isDark,
              theme: theme,
              onToggle: () => setState(
                  () => _showDepreciationSettings = !_showDepreciationSettings),
              onMethodChanged: (m) =>
                  setState(() => _depreciationMethod = m),
              onYearsChanged: (y) =>
                  setState(() => _usefulLifeYears = y),
              onSalvageRateChanged: (r) =>
                  setState(() => _salvageRate = r),
              onPresetApplied: _applyPreset,
            ),
            const SizedBox(height: 32),

            // Submit button
            FilledButton.icon(
              onPressed: assetState.isLoading ? null : _submit,
              icon: assetState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('添加资产'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Depreciation Settings Section ──

class _DepreciationSection extends StatelessWidget {
  final bool isExpanded;
  final String method;
  final int usefulLifeYears;
  final double salvageRate;
  final List<int> yearPresets;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onToggle;
  final ValueChanged<String> onMethodChanged;
  final ValueChanged<int> onYearsChanged;
  final ValueChanged<double> onSalvageRateChanged;
  final void Function(String label, int years, double rate) onPresetApplied;

  const _DepreciationSection({
    required this.isExpanded,
    required this.method,
    required this.usefulLifeYears,
    required this.salvageRate,
    required this.yearPresets,
    required this.isDark,
    required this.theme,
    required this.onToggle,
    required this.onMethodChanged,
    required this.onYearsChanged,
    required this.onSalvageRateChanged,
    required this.onPresetApplied,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Header
          Semantics(
            label: '折旧设置${isExpanded ? "，已展开" : "，点击展开"}',
            button: true,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_down_rounded,
                      color: isDark ? AppColors.assetDark : AppColors.asset,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '折旧设置',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            method == 'none'
                                ? '不折旧'
                                : '${depreciationMethodLabel(method)} · $usefulLifeYears年 · 残值${(salvageRate * 100).toStringAsFixed(0)}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presets
                  Row(
                    children: [
                      _PresetChip(
                        label: '车辆(5年/5%)',
                        onTap: () => onPresetApplied('车辆', 5, 0.05),
                      ),
                      const SizedBox(width: 8),
                      _PresetChip(
                        label: '电子设备(3年/5%)',
                        onTap: () => onPresetApplied('电子设备', 3, 0.05),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Method selector
                  Text(
                    '折旧方式',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'none',
                          label: Text('不折旧',
                              style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: 'straight_line',
                          label: Text('直线法',
                              style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: 'double_declining',
                          label: Text('双倍余额',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      selected: {method},
                      onSelectionChanged: (s) => onMethodChanged(s.first),
                    ),
                  ),
                  if (method != 'none') ...[
                    const SizedBox(height: 16),
                    // Years
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '使用年限',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$usefulLifeYears 年',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? AppColors.assetDark : AppColors.asset,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: usefulLifeYears.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '$usefulLifeYears年',
                      onChanged: (v) => onYearsChanged(v.round()),
                    ),
                    // Year preset buttons
                    Wrap(
                      spacing: 8,
                      children: yearPresets.map((y) {
                        final isSelected = usefulLifeYears == y;
                        return Semantics(
                          label: '$y年${isSelected ? "，已选中" : ""}',
                          child: ChoiceChip(
                            label: Text('$y年',
                                style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (_) => onYearsChanged(y),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Salvage rate
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '残值率',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${(salvageRate * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? AppColors.assetDark : AppColors.asset,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: salvageRate,
                      min: 0,
                      max: 0.30,
                      divisions: 30,
                      label: '${(salvageRate * 100).toStringAsFixed(0)}%',
                      onChanged: onSalvageRateChanged,
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '预设：$label',
      button: true,
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        avatar: const Icon(Icons.auto_fix_high_rounded, size: 14),
        onPressed: onTap,
      ),
    );
  }
}
