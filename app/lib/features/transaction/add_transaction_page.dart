import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../generated/proto/transaction.pb.dart' as pb;
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/exchange_rate_provider.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../domain/providers/dashboard_provider.dart';
import '../../domain/providers/account_provider.dart';
import '../../core/widgets/success_animation.dart';
import 'widgets/number_pad.dart';
import 'widgets/category_grid.dart';

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
  final _imagePicker = ImagePicker();

  // Show detail panel
  bool _showDetails = false;

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

    return Semantics(
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
          // Detail toggle
          _buildDetailToggle(context),
          // Details panel (note, tags, images)
          if (_showDetails) _buildDetailsPanel(context),
          // Category selector
          Expanded(
            child: CategoryGrid(
              categories: categories,
              selectedId: _selectedCategoryId,
              onSelect: (id) {
                setState(() => _selectedCategoryId = id);
                HapticFeedback.selectionClick();
              },
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

  Widget _buildDetailsPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note input
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: '备注',
                prefixIcon: Icon(Icons.note_outlined, size: 18),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
            ),
            const SizedBox(height: 8),
            // Tags
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ..._tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )),
                SizedBox(
                  width: 100,
                  height: 32,
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: '+标签',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onSubmitted: _addTag,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Images
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._imagePaths.map((path) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(path),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 56, height: 56,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                                ),
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _imagePaths.remove(path)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  // Add image button
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
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

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked != null) {
      // 复制到 app 持久目录
      final appDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory('${appDir.path}/transaction_images');
      if (!imgDir.existsSync()) imgDir.createSync(recursive: true);
      final ext = p.extension(picked.path).isNotEmpty ? p.extension(picked.path) : '.jpg';
      final destPath = '${imgDir.path}/${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(picked.path).copy(destPath);
      setState(() => _imagePaths.add(destPath));
    }
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
