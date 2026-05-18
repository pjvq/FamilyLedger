import 'dart:convert';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../generated/proto/transaction.pb.dart' as pb;
import '../../generated/proto/transaction.pbgrpc.dart' as pbgrpc;
import '../../core/utils/input_sanitizer.dart' show maxNoteLength;
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../data/remote/grpc_clients.dart';
import '../../domain/providers/exchange_rate_provider.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../../domain/providers/account_provider.dart';
import '../../core/widgets/success_animation.dart';
import 'widgets/number_pad.dart';
import 'widgets/category_grid.dart';
import 'widgets/transaction_details_panel.dart';
import 'widgets/icon_picker_sheet.dart';
import '../../core/constants/category_icons.dart';
import '../../core/constants/category_icon_widget.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  /// 传入已有 transaction 时进入编辑模式
  final Transaction? existingTransaction;

  const AddTransactionPage({super.key, this.existingTransaction});

  @override
  ConsumerState<AddTransactionPage> createState() =>
      _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _amountStr = '0';
  String? _selectedCategoryId;
  bool _isSubmitting = false;

  // Multi-currency
  String _selectedCurrency = 'CNY';

  // Note
  final _noteController = TextEditingController();

  // Tags
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  // Image attachments
  final List<String> _imagePaths = [];

  // Show detail panel
  bool _showDetails = false;

  // Transaction date/time (null = use current time)
  DateTime? _selectedDate;

  bool get _isEditMode => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 编辑模式：预填已有数据
    final txn = widget.existingTransaction;
    if (txn != null) {
      // 金额：分→元
      final yuan = txn.amount / 100;
      _amountStr = yuan == yuan.truncateToDouble()
          ? '${yuan.toInt()}'
          : yuan.toStringAsFixed(2);
      _selectedCategoryId = txn.categoryId;
      _selectedCurrency = txn.currency;
      _noteController.text = txn.note;
      if (txn.tags.isNotEmpty) {
        try {
          _tags.addAll(List<String>.from(jsonDecode(txn.tags)));
        } catch (_) {
          // tags 不是 JSON，当作单个标签
          _tags.add(txn.tags);
        }
      }
      if (txn.imageUrls.isNotEmpty) {
        try {
          _imagePaths.addAll(List<String>.from(jsonDecode(txn.imageUrls)));
        } catch (_) {}
      }
      _showDetails = _noteController.text.isNotEmpty ||
          _tags.isNotEmpty ||
          _imagePaths.isNotEmpty;
      // 编辑模式：预填交易日期
      _selectedDate = txn.txnDate;
      // 设置 tab（收入 or 支出）— 必须在 addListener 前设置
      if (txn.type == 'income') {
        _tabController.index = 1;
      }
    }

    // Tab 切换时清空分类（只在用户手动切换时清，不在 initState 预填时清）
    _tabController.addListener(() => setState(() {
          _selectedCategoryId = null;
        }));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  bool get _isExpense => _tabController.index == 0;

  String get _type => _isExpense ? 'expense' : 'income';

  @override
  Widget build(BuildContext context) {
    final txnState = ref.watch(transactionProvider);
    final categories =
        _isExpense ? txnState.expenseCategories : txnState.incomeCategories;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Semantics(
      label: _isEditMode ? '编辑交易页面' : '记一笔页面',
      child: Scaffold(
        appBar: AppBar(
          leading: Semantics(
            button: true,
            label: '关闭',
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 24),
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          title: Text(_isEditMode ? '编辑交易' : '记一笔'),
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
          // Amount display + currency selector
          _buildAmountRow(context),
          // CNY equivalent (when foreign currency)
          if (_selectedCurrency != 'CNY') _buildCnyEquivalent(),
          const SizedBox(height: 4),
          // Date/time picker row
          _buildDateRow(context),
          // Detail toggle
          _buildDetailToggle(context),
          // Details panel (note, tags, images)
          if (_showDetails) TransactionDetailsPanel(
            noteController: _noteController,
            tagController: _tagController,
            tags: _tags,
            imagePaths: _imagePaths,
            onTagAdded: () => _addTag(_tagController.text),
            onTagRemoved: (tag) => setState(() => _tags.remove(tag)),
            onImageRemoved: (path) => setState(() => _imagePaths.remove(path)),
            onPickImage: _pickImage,
          ),
          // Category selector
          Expanded(
            child: CategoryGrid(
              categories: categories,
              selectedId: _selectedCategoryId,
              onSelect: (id) {
                setState(() => _selectedCategoryId = id);
                HapticFeedback.selectionClick();
              },
              onAddCategory: (parentId) => _addNewCategory(parentId),
            ),
          ),
          // Number pad
          NumberPad(
            onKey: _handleKey,
            onDelete: _handleDelete,
            onClear: () {
              HapticFeedback.mediumImpact();
              setState(() => _amountStr = '0');
            },
            onConfirm: _handleConfirm,
                        confirmEnabled:
                _selectedCategoryId != null &&
                _amountStr != '0' &&
                (double.tryParse(_amountStr) ?? 0) > 0 &&
                !_isSubmitting,
          ),
        ],
        ),
      ),
    ),
    );
  }

  Widget _buildAmountRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _isExpense
        ? (isDark ? AppColors.expenseDark : AppColors.expense)
        : (isDark ? AppColors.incomeDark : AppColors.income);
    final symbol = currencySymbols[_selectedCurrency] ?? _selectedCurrency;

    return Semantics(
      label: '金额 $_amountStr元',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Currency selector button
          GestureDetector(
            onTap: _showCurrencyPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedCurrency,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: color, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Amount
          Text(
            symbol,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _amountStr,
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
      ),
    );
  }

  Widget _buildCnyEquivalent() {
    // Watch rates to rebuild on changes
    ref.watch(exchangeRateProvider);
    final rateNotifier = ref.read(exchangeRateProvider.notifier);
    final rate = rateNotifier.getRate(_selectedCurrency, 'CNY');
    final yuan = double.tryParse(_amountStr) ?? 0;
    final cnyYuan = yuan * rate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '≈ ¥${cnyYuan.toStringAsFixed(2)}',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.45),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(1 $_selectedCurrency = ${rate.toStringAsFixed(4)} CNY)',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // TODO: i18n — date format strings are hardcoded in Chinese
  static const _kToday = '今天';

  String _formatDateLabel(DateTime? date, DateTime now) {
    if (date == null) return _kToday;
    final hourStr = date.hour.toString().padLeft(2, '0');
    final minStr = date.minute.toString().padLeft(2, '0');
    final time = '$hourStr:$minStr';

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '$_kToday $time';
    } else if (date.year == now.year) {
      return '${date.month}月${date.day}日 $time';
    } else {
      return '${date.year}/${date.month}/${date.day} $time';
    }
  }

  bool _isSelectedToday(DateTime now) {
    if (_selectedDate == null) return true;
    return _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;
  }

  Widget _buildDateRow(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = _isSelectedToday(now);
    final label = _formatDateLabel(_selectedDate, now);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return InkWell(
      onTap: () => _pickDateTime(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: isToday ? muted : theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isToday ? muted : theme.colorScheme.primary,
                  fontWeight: isToday ? FontWeight.normal : FontWeight.w500,
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => setState(() => _selectedDate = null),
                  icon: Icon(Icons.close_rounded, size: 14, color: muted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      // Small buffer to prevent cross-midnight edge case where
      // DatePicker render time causes 'today' to become invalid.
      lastDate: now.add(const Duration(minutes: 5)),
      locale: const Locale('zh', 'CN'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    // User cancelled time picker → don't change anything
    if (time == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Widget _buildDetailToggle(BuildContext context) {
    final theme = Theme.of(context);
    final hasDetails =
        _noteController.text.isNotEmpty || _tags.isNotEmpty || _imagePaths.isNotEmpty;

    return GestureDetector(
      onTap: () => setState(() => _showDetails = !_showDetails),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showDetails
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 4),
            Text(
              hasDetails ? '备注/标签/图片 (已添加)' : '添加备注/标签/图片',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择币种',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...supportedCurrencies.map((c) {
              final symbol = currencySymbols[c] ?? c;
              final isSelected = c == _selectedCurrency;
              return ListTile(
                leading: Text(symbol,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600)),
                title: Text(c),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _selectedCurrency = c);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _tagController.clear();
      });
    }
  }

    final _imageService = TransactionImageService();

  Future<void> _pickImage() async {
    final path = await _imageService.pickAndSave(context);
    if (path != null && mounted) {
      setState(() => _imagePaths.add(path));
    }
  }

  Future<void> _addNewCategory(String? parentId) async {
    final result = await _showQuickCategoryEditor(context);
    if (result == null) return;

    try {
      final client = ref.read(transactionClientProvider);
      final type = _isExpense
          ? pb.TransactionType.TRANSACTION_TYPE_EXPENSE
          : pb.TransactionType.TRANSACTION_TYPE_INCOME;
      await client.createCategory(pbgrpc.CreateCategoryRequest(
        name: result.$1,
        iconKey: result.$2,
        type: type,
        parentId: parentId ?? '',
      ));
      ref.read(transactionProvider.notifier).reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分类「${result.$1}」创建成功'),
            behavior: SnackBarBehavior.fixed,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), behavior: SnackBarBehavior.fixed),
        );
      }
    }
  }

  /// 简化版分类编辑器（名称 + 图标）
  Future<(String, String)?> _showQuickCategoryEditor(BuildContext context) async {
    final theme = Theme.of(context);
    String name = '';
    String iconKey = 'other';
    final nameController = TextEditingController();

    return showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final color = CategoryIcons.getColor(iconKey);
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;

          return Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 12,
              bottom: 16 + bottom + MediaQuery.of(ctx).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('新建分类',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        showIconPickerSheet(ctx,
                            selectedKey: iconKey, onSelect: (key) {
                          setLocalState(() => iconKey = key);
                        });
                      },
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                        ),
                        child: CategoryIconWidget(
                            iconKey: iconKey, size: 24, showBackground: false),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        maxLength: 15,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '输入分类名称',
                          counterText: '',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onChanged: (v) => setLocalState(() => name = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: name.trim().isEmpty
                        ? null
                        : () => Navigator.pop(ctx, (name.trim(), iconKey)),
                    child: const Text('添加'),
                  ),
                ),
              ],
            ),
          );
        },
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
          // Max two decimal places
          if (_amountStr.contains('.')) {
            final decimals = _amountStr.split('.')[1];
            if (decimals.length >= 2) return;
          }
          // Max amount limit
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

    try {
      // Yuan → fen
      final yuan = double.tryParse(_amountStr) ?? 0;
      final cents = (yuan * 100).round();

      // CNY equivalent
      final rateNotifier = ref.read(exchangeRateProvider.notifier);
      final amountCny = rateNotifier.toCny(cents, _selectedCurrency);

      // 上传图片到服务端，拿到 server URL
      final List<String> imageUrls = [];
      for (final path in _imagePaths) {
        if (path.startsWith('http')) {
          // 已是服务端 URL（编辑模式下已有图片）
          imageUrls.add(path);
        } else {
          // 本地文件，尝试上传
          try {
            final file = File(path);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final ext = p.extension(path).toLowerCase();
              final contentType = {
                '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
                '.png': 'image/png', '.webp': 'image/webp',
                '.heic': 'image/heic',
              }[ext] ?? 'image/jpeg';
              final uploadReq = pb.UploadTransactionImageRequest(
                filename: p.basename(path),
                data: bytes,
                contentType: contentType,
              );
              final resp = await ref.read(transactionProvider.notifier).uploadImage(uploadReq);
              if (resp != null) {
                imageUrls.add(resp);
                continue;
              }
            }
          } catch (_) {}
          // 上传失败时保留本地路径（offline-first）
          imageUrls.add(path);
        }
      }
      final imageUrlsStr = imageUrls.isNotEmpty ? jsonEncode(imageUrls) : '';

      if (_isEditMode) {
        // 编辑模式：更新已有交易
        await ref.read(transactionProvider.notifier).updateTransaction(
              id: widget.existingTransaction!.id,
              categoryId: _selectedCategoryId!,
              amount: cents,
              type: _type,
              note: _noteController.text.trim(),
              currency: _selectedCurrency,
              amountCny: amountCny,
              tags: _tags.isNotEmpty ? jsonEncode(_tags) : '',
              imageUrls: imageUrlsStr,
              txnDate: _selectedDate,
            );
      } else {
        // 新建模式：创建交易
        await ref.read(transactionProvider.notifier).addTransaction(
              categoryId: _selectedCategoryId!,
              amount: cents,
              type: _type,
              note: _noteController.text.trim(),
              currency: _selectedCurrency,
              amountCny: amountCny,
              tags: _tags.isNotEmpty ? jsonEncode(_tags) : '',
              imageUrls: imageUrlsStr,
              txnDate: _selectedDate,
            );
      }

      HapticFeedback.mediumImpact();

      // 记账/编辑成功后刷新 Dashboard 和 Account
      ref.read(dashboardProvider.notifier).loadAll();
      ref.read(accountProvider.notifier).refresh();

      if (mounted) {
        final formattedAmount = '¥${(cents / 100).toStringAsFixed(2)}';
        await TransactionSuccessOverlay.show(context, formattedAmount);
        if (mounted) {
          Navigator.of(context).pop(_isEditMode ? true : null);
        }
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('日期无效: ${e.message}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
