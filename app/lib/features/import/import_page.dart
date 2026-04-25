import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart' as xl;
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart' as db;
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/transaction_provider.dart';
import '../../domain/providers/dashboard_provider.dart';

/// Import page — supports Alipay, WeChat, and generic CSV
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

enum ImportFormat { unknown, alipay, wechat, generic }

class _ParsedTransaction {
  final DateTime date;
  final String type; // income / expense
  final double amount; // yuan
  final String note;
  final String? rawCategory;
  String? matchedCategoryId;

  _ParsedTransaction({
    required this.date,
    required this.type,
    required this.amount,
    required this.note,
    this.rawCategory,
  });
}

class _ImportPageState extends ConsumerState<ImportPage> {
  int _currentStep = 0;

  // Step 0: file pick
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  ImportFormat _detectedFormat = ImportFormat.unknown;
  String? _parseError;
  bool _isParsing = false;

  // Step 1: preview
  List<_ParsedTransaction> _parsed = [];
  int _skippedRows = 0;

  // Step 2: import result
  bool _isImporting = false;
  bool _importDone = false;
  int _importedCount = 0;
  int _duplicateCount = 0;
  List<String> _importErrors = [];

  // Category matching
  Map<String, db.Category> _catByName = {};
  List<db.Category> _allCategories = [];
  db.Category? _defaultCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    final txnState = ref.read(transactionProvider);
    _allCategories = [
      ...txnState.expenseCategories,
      ...txnState.incomeCategories,
    ];
    // Build name→category map (including children)
    for (final c in _allCategories) {
      _catByName[c.name] = c;
    }
    // Default: "其他" expense category
    _defaultCategory = _allCategories.where((c) => c.name == '其他' && c.type == 'expense').firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('导入账单')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onContinue,
        onStepCancel: _currentStep > 0 && _currentStep < 2
            ? () => setState(() => _currentStep--)
            : null,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep == 0)
                  FilledButton(
                    onPressed: _pickedFile != null && !_isParsing ? details.onStepContinue : null,
                    child: const Text('解析文件'),
                  ),
                if (_currentStep == 1)
                  FilledButton(
                    onPressed: _parsed.isNotEmpty ? details.onStepContinue : null,
                    child: Text('导入 ${_parsed.length} 条记录'),
                  ),
                if (_currentStep == 2 && _importDone)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                if (_currentStep > 0 && _currentStep < 2) ...[
                  const SizedBox(width: 12),
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
          Step(
            title: const Text('选择文件'),
            content: _buildFileStep(theme),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('数据预览'),
            content: _buildPreviewStep(theme),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('导入结果'),
            content: _buildResultStep(theme),
            isActive: _currentStep >= 2,
            state: _importDone ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }

  Future<void> _onContinue() async {
    if (_currentStep == 0) {
      await _parseFile();
      if (_parseError == null && _parsed.isNotEmpty) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      setState(() => _currentStep = 2);
      await _doImport();
    }
  }

  // ── Step 0: File pick ──

  Widget _buildFileStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('支持支付宝账单、微信账单、通用 CSV/XLSX 文件',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('选择文件'),
        ),
        if (_pickedFile != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(_formatIcon(), color: _formatColor(), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_pickedFile!.name,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(_formatLabel(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _formatColor(),
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _pickedFile = null;
                      _fileBytes = null;
                      _detectedFormat = ImportFormat.unknown;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_isParsing)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_parseError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_parseError!, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );
  }

  IconData _formatIcon() => switch (_detectedFormat) {
    ImportFormat.alipay => Icons.account_balance_wallet_rounded,
    ImportFormat.wechat => Icons.chat_rounded,
    ImportFormat.generic => Icons.table_chart_rounded,
    ImportFormat.unknown => Icons.description_rounded,
  };

  Color _formatColor() => switch (_detectedFormat) {
    ImportFormat.alipay => const Color(0xFF1677FF),
    ImportFormat.wechat => const Color(0xFF07C160),
    _ => AppColors.primary,
  };

  String _formatLabel() => switch (_detectedFormat) {
    ImportFormat.alipay => '检测到：支付宝账单',
    ImportFormat.wechat => '检测到：微信账单',
    ImportFormat.generic => '通用 CSV/XLSX 文件',
    ImportFormat.unknown => '未知格式',
  };

  // ── Step 1: Preview ──

  Widget _buildPreviewStep(ThemeData theme) {
    if (_parsed.isEmpty) return const Text('无可导入的数据');

    final previewList = _parsed.take(20).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '共解析 ${_parsed.length} 条有效记录，跳过 $_skippedRows 行',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 40,
            columns: const [
              DataColumn(label: Text('日期', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('类型', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('金额', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('备注', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            ],
            rows: previewList.map((t) {
              final dateStr = '${t.date.month}/${t.date.day}';
              return DataRow(cells: [
                DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
                DataCell(Text(t.type == 'income' ? '收入' : '支出',
                    style: TextStyle(
                      fontSize: 12,
                      color: t.type == 'income' ? AppColors.income : AppColors.expense,
                    ))),
                DataCell(Text('¥${t.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                DataCell(Text(t.note, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]);
            }).toList(),
          ),
        ),
        if (_parsed.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('... 还有 ${_parsed.length - 20} 条',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                )),
          ),
      ],
    );
  }

  // ── Step 2: Result ──

  Widget _buildResultStep(ThemeData theme) {
    if (_isImporting) {
      return const Center(
        child: Column(children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在导入...'),
        ]),
      );
    }
    if (!_importDone) return const Text('等待导入...');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _importErrors.isEmpty ? Icons.check_circle_rounded : Icons.warning_rounded,
          size: 48,
          color: _importErrors.isEmpty ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 12),
        Text('导入完成', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _resultRow('成功导入', '$_importedCount 条', Colors.green),
        _resultRow('重复跳过', '$_duplicateCount 条', Colors.orange),
        if (_importErrors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('错误:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ..._importErrors.take(5).map((e) => Text('• $e',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.error))),
        ],
      ],
    );
  }

  Widget _resultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  // ── File picking & parsing ──

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      var bytes = file.bytes ?? (file.path != null ? File(file.path!).readAsBytesSync() : null);
      if (bytes == null) return;

      // Convert xlsx to CSV bytes before format detection
      if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B &&
          bytes[2] == 0x03 && bytes[3] == 0x04) {
        final csvBytes = _xlsxToCsvBytes(bytes);
        if (csvBytes == null) {
          setState(() { _parseError = 'xlsx 解析失败'; });
          return;
        }
        bytes = csvBytes;
      }

      final format = _detectFormat(bytes);
      setState(() {
        _pickedFile = file;
        _fileBytes = bytes;
        _detectedFormat = format;
        _parseError = null;
        _parsed = [];
      });
    }
  }

  ImportFormat _detectFormat(Uint8List bytes) {

    // Try UTF-8 first
    String content;
    try {
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      content = '';
    }

    // Check first few lines
    final firstChunk = content.length > 500 ? content.substring(0, 500) : content;

    if (firstChunk.contains('支付宝') || firstChunk.contains('交易号')) {
      return ImportFormat.alipay;
    }
    if (firstChunk.contains('微信支付') || firstChunk.contains('微信支付账单')) {
      return ImportFormat.wechat;
    }

    // Try GBK for Alipay files
    try {
      final gbkContent = gbk.decode(bytes);
      final gbkChunk = gbkContent.length > 500 ? gbkContent.substring(0, 500) : gbkContent;
      if (gbkChunk.contains('支付宝') || gbkChunk.contains('交易号')) {
        return ImportFormat.alipay;
      }
    } catch (_) {}

    return ImportFormat.generic;
  }

  /// Convert xlsx file bytes to CSV-formatted UTF-8 bytes.
  /// Reads the first sheet and joins cells with commas.
  Uint8List? _xlsxToCsvBytes(Uint8List xlsxBytes) {
    try {
      final excel = xl.Excel.decodeBytes(xlsxBytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) return null;

      final buffer = StringBuffer();
      for (final row in sheet.rows) {
        final cells = row.map((cell) {
          if (cell == null || cell.value == null) return '';
          final v = cell.value!;
          // Handle different cell value types
          if (v is xl.DateTimeCellValue) {
            final y = v.year.toString().padLeft(4, '0');
            final mo = v.month.toString().padLeft(2, '0');
            final d = v.day.toString().padLeft(2, '0');
            final hh = v.hour.toString().padLeft(2, '0');
            final mm = v.minute.toString().padLeft(2, '0');
            final ss = v.second.toString().padLeft(2, '0');
            return '$y-$mo-$d $hh:$mm:$ss';
          }
          if (v is xl.DateCellValue) {
            final y = v.year.toString().padLeft(4, '0');
            final mo = v.month.toString().padLeft(2, '0');
            final d = v.day.toString().padLeft(2, '0');
            return '$y-$mo-$d 00:00:00';
          }
          final str = v.toString();
          // Escape CSV: quote if contains comma, quote, or newline
          if (str.contains(',') || str.contains('"') || str.contains('\n')) {
            return '"${str.replaceAll('"', '""')}"';
          }
          return str;
        });
        buffer.writeln(cells.join(','));
      }
      return utf8.encode(buffer.toString());
    } catch (e) {
      debugPrint('xlsx parse error: $e');
      return null;
    }
  }

  Future<void> _parseFile() async {
    if (_fileBytes == null) return;
    setState(() { _isParsing = true; _parseError = null; });

    try {
      switch (_detectedFormat) {
        case ImportFormat.alipay:
          _parseAlipay(_fileBytes!);
        case ImportFormat.wechat:
          _parseWechat(_fileBytes!);
        case ImportFormat.generic:
        case ImportFormat.unknown:
          _parseGenericCsv(_fileBytes!);
      }
      _matchCategories();
      setState(() => _isParsing = false);
    } catch (e) {
      setState(() { _isParsing = false; _parseError = '解析失败: $e'; });
    }
  }

  void _parseAlipay(Uint8List bytes) {
    // Alipay uses GBK encoding
    String content;
    try {
      content = gbk.decode(bytes);
    } catch (_) {
      // Fallback to UTF-8
      content = utf8.decode(bytes, allowMalformed: true);
    }

    final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Find header line: must contain '交易' and '金额' and have multiple CSV columns
    int headerIdx = -1;
    for (int i = 0; i < lines.length && i < 30; i++) {
      if (lines[i].contains('交易') && lines[i].contains('金额')) {
        // Real header has multiple comma-separated columns (at least 4)
        final cols = _splitCsvLine(lines[i]);
        if (cols.length >= 4) {
          headerIdx = i;
          break;
        }
      }
    }
    if (headerIdx == -1) {
      _parseError = '未找到支付宝表头行';
      return;
    }

    final headers = _splitCsvLine(lines[headerIdx]);
    final dateIdx = _findCol(headers, ['交易创建时间', '交易时间', '付款时间']);
    final amountIdx = _findCol(headers, ['金额（元）', '金额(元)', '金额']);
    final typeIdx = _findCol(headers, ['收/支']);
    final noteIdx = _findCol(headers, ['商品名称', '商品说明']);
    final statusIdx = _findCol(headers, ['交易状态']);

    if (dateIdx == -1 || amountIdx == -1) {
      _parseError = '支付宝账单缺少必要列（日期/金额）';
      return;
    }

    _parsed = [];
    _skippedRows = 0;

    for (int i = headerIdx + 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      if (cols.length <= amountIdx) { _skippedRows++; continue; }

      // Skip non-successful transactions
      if (statusIdx != -1 && cols.length > statusIdx) {
        final status = cols[statusIdx].trim();
        if (status.isNotEmpty && !status.contains('成功')) { _skippedRows++; continue; }
      }

      // Skip non income/expense
      final typeStr = typeIdx != -1 && cols.length > typeIdx ? cols[typeIdx].trim() : '';
      if (typeStr != '支出' && typeStr != '收入') { _skippedRows++; continue; }

      final date = _parseDate(cols[dateIdx].trim());
      final amount = double.tryParse(cols[amountIdx].trim().replaceAll('¥', '').replaceAll(',', ''));
      final note = noteIdx != -1 && cols.length > noteIdx ? cols[noteIdx].trim() : '';

      if (date == null || amount == null || amount == 0) { _skippedRows++; continue; }

      _parsed.add(_ParsedTransaction(
        date: date,
        type: typeStr == '收入' ? 'income' : 'expense',
        amount: amount,
        note: note,
      ));
    }
  }

  void _parseWechat(Uint8List bytes) {
    String content = utf8.decode(bytes, allowMalformed: true);
    // Remove BOM
    if (content.startsWith('\uFEFF')) content = content.substring(1);

    final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Find header line
    int headerIdx = -1;
    for (int i = 0; i < lines.length && i < 30; i++) {
      if (lines[i].contains('交易时间') && lines[i].contains('金额')) {
        final cols = _splitCsvLine(lines[i]);
        if (cols.length >= 4) {
          headerIdx = i;
          break;
        }
      }
    }
    if (headerIdx == -1) {
      _parseError = '未找到微信表头行';
      return;
    }

    final headers = _splitCsvLine(lines[headerIdx]);
    final dateIdx = _findCol(headers, ['交易时间']);
    final amountIdx = _findCol(headers, ['金额(元)', '金额（元）', '金额']);
    final typeIdx = _findCol(headers, ['收/支']);
    final noteIdx = _findCol(headers, ['商品', '商品名称', '交易对方']);
    final statusIdx = _findCol(headers, ['当前状态']);

    if (dateIdx == -1 || amountIdx == -1) {
      _parseError = '微信账单缺少必要列（日期/金额）';
      return;
    }

    _parsed = [];
    _skippedRows = 0;

    for (int i = headerIdx + 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      if (cols.length <= amountIdx) { _skippedRows++; continue; }

      // Filter status
      if (statusIdx != -1 && cols.length > statusIdx) {
        final status = cols[statusIdx].trim();
        if (status.isNotEmpty && !status.contains('成功') && !status.contains('已收钱') && !status.contains('已存入')) {
          _skippedRows++;
          continue;
        }
      }

      final typeStr = typeIdx != -1 && cols.length > typeIdx ? cols[typeIdx].trim() : '';
      if (typeStr != '支出' && typeStr != '收入') { _skippedRows++; continue; }

      final date = _parseDate(cols[dateIdx].trim());
      final amountStr = cols[amountIdx].trim().replaceAll('¥', '').replaceAll(',', '').replaceAll('￥', '');
      final amount = double.tryParse(amountStr);
      final note = noteIdx != -1 && cols.length > noteIdx ? cols[noteIdx].trim() : '';

      if (date == null || amount == null || amount == 0) { _skippedRows++; continue; }

      _parsed.add(_ParsedTransaction(
        date: date,
        type: typeStr == '收入' ? 'income' : 'expense',
        amount: amount,
        note: note,
      ));
    }
  }

  void _parseGenericCsv(Uint8List bytes) {
    String content = utf8.decode(bytes, allowMalformed: true);
    if (content.startsWith('\uFEFF')) content = content.substring(1);

    final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) { _parseError = '文件为空'; return; }

    final headers = _splitCsvLine(lines[0]);
    final dateIdx = _findCol(headers, ['日期', 'date', '交易日期', '交易时间', 'time']);
    final amountIdx = _findCol(headers, ['金额', 'amount', '金额(元)', '金额（元）']);
    final typeIdx = _findCol(headers, ['类型', 'type', '收/支', '收支']);
    final noteIdx = _findCol(headers, ['备注', 'note', '说明', '描述', '商品名称']);
    final catIdx = _findCol(headers, ['分类', 'category', '类别']);

    if (dateIdx == -1 || amountIdx == -1) {
      _parseError = '缺少必要列：日期 和 金额';
      return;
    }

    _parsed = [];
    _skippedRows = 0;

    for (int i = 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      if (cols.length <= amountIdx) { _skippedRows++; continue; }

      final date = _parseDate(cols[dateIdx].trim());
      final amount = double.tryParse(cols[amountIdx].trim().replaceAll('¥', '').replaceAll(',', ''));
      if (date == null || amount == null || amount == 0) { _skippedRows++; continue; }

      String type = 'expense';
      if (typeIdx != -1 && cols.length > typeIdx) {
        final t = cols[typeIdx].trim();
        if (t.contains('收入') || t.toLowerCase() == 'income') type = 'income';
      } else if (amount < 0) {
        type = 'expense';
      }

      final note = noteIdx != -1 && cols.length > noteIdx ? cols[noteIdx].trim() : '';
      final rawCat = catIdx != -1 && cols.length > catIdx ? cols[catIdx].trim() : null;

      _parsed.add(_ParsedTransaction(
        date: date,
        type: type,
        amount: amount.abs(),
        note: note,
        rawCategory: rawCat,
      ));
    }
  }

  // ── Helpers ──

  int _findCol(List<String> headers, List<String> keywords) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      for (final k in keywords) {
        if (h.contains(k.toLowerCase())) return i;
      }
    }
    return -1;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final buf = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString());
    return result;
  }

  DateTime? _parseDate(String s) {
    // Try common formats
    try {
      // 2024-01-15 12:30:00 or 2024/01/15 12:30:00
      final cleaned = s.replaceAll('/', '-');
      return DateTime.parse(cleaned);
    } catch (_) {}
    try {
      // 2024-01-15 or 2024/1/5 with optional time
      final dtParts = s.trim().split(RegExp(r'\s+'));
      final datePart = dtParts[0];
      final parts = datePart.split(RegExp(r'[-/]'));
      if (parts.length >= 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        // Try to parse time part if present
        if (dtParts.length >= 2) {
          final timeParts = dtParts[1].split(':');
          final h = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
          final min = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
          final sec = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;
          return DateTime(y, m, d, h, min, sec);
        }
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  // ── Smart category matching ──

  static const _categoryKeywords = {
    // 餐饮
    '美团': '餐饮', '饿了么': '餐饮', '麦当劳': '餐饮', '肯德基': '餐饮', '星巴克': '餐饮',
    '瑞幸': '餐饮', '奶茶': '餐饮', '外卖': '餐饮', '餐厅': '餐饮', '食堂': '餐饮',
    '火锅': '餐饮', '烧烤': '餐饮', '面包': '餐饮', '蛋糕': '餐饮',
    // 交通
    '滴滴': '交通', '出租车': '交通', '打车': '交通', '高德': '交通',
    '地铁': '交通', '公交': '交通', '一卡通': '交通',
    '加油': '交通', '中石油': '交通', '中石化': '交通', '停车': '交通',
    '高铁': '交通', '火车票': '交通', '机票': '交通', '12306': '交通',
    // 购物
    '淘宝': '购物', '京东': '购物', '拼多多': '购物', '天猫': '购物', '唯品会': '购物',
    '超市': '购物', '便利店': '购物', '沃尔玛': '购物', '盒马': '购物',
    // 居住
    '水电': '居住', '燃气': '居住', '物业': '居住', '房租': '居住', '电费': '居住', '水费': '居住',
    // 通讯
    '话费': '通讯', '流量': '通讯', '中国移动': '通讯', '中国联通': '通讯', '中国电信': '通讯',
    // 娱乐
    '电影': '娱乐', '游戏': '娱乐', '视频会员': '娱乐', '爱奇艺': '娱乐', '优酷': '娱乐',
    '腾讯视频': '娱乐', 'Netflix': '娱乐', 'B站': '娱乐', '网易云': '娱乐', 'Spotify': '娱乐',
    // 医疗
    '医院': '医疗', '药店': '医疗', '药房': '医疗', '诊所': '医疗', '挂号': '医疗',
    // 教育
    '学费': '教育', '培训': '教育', '课程': '教育', '书店': '教育',
  };

  // Keywords to skip (transfers, not real expenses)
  static const _skipKeywords = ['转账', '红包', '还款', '信用卡还款', '余额宝', '理财'];

  void _matchCategories() {
    final toRemove = <int>[];
    for (int i = 0; i < _parsed.length; i++) {
      final t = _parsed[i];

      // Skip transfers
      if (_skipKeywords.any((k) => t.note.contains(k))) {
        toRemove.add(i);
        _skippedRows++;
        continue;
      }

      // Try raw category from CSV first
      if (t.rawCategory != null && _catByName.containsKey(t.rawCategory!)) {
        t.matchedCategoryId = _catByName[t.rawCategory!]!.id;
        continue;
      }

      // Keyword matching
      String? matchedCatName;
      for (final entry in _categoryKeywords.entries) {
        if (t.note.contains(entry.key)) {
          matchedCatName = entry.value;
          break;
        }
      }
      if (matchedCatName != null && _catByName.containsKey(matchedCatName)) {
        t.matchedCategoryId = _catByName[matchedCatName]!.id;
      } else {
        t.matchedCategoryId = _defaultCategory?.id;
      }
    }

    // Remove skipped in reverse order
    for (final idx in toRemove.reversed) {
      _parsed.removeAt(idx);
    }
  }

  // ── Import ──

  Future<void> _doImport() async {
    setState(() => _isImporting = true);
    final uuid = const Uuid();

    try {
      final database = ref.read(databaseProvider);
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        setState(() { _isImporting = false; _importDone = true; _importErrors = ['未登录']; });
        return;
      }

      // Get accounts for default
      final accounts = await database.getActiveAccounts(userId);
      final defaultAccId = accounts.isNotEmpty ? accounts.first.id : null;
      if (defaultAccId == null) {
        setState(() { _isImporting = false; _importDone = true; _importErrors = ['没有可用账户']; });
        return;
      }

      // Get existing transactions for dedup
      final existingTxns = await database.getRecentTransactions(userId, 100000);
      final existingKeys = <String>{};
      for (final t in existingTxns) {
        final key = '${t.txnDate.year}-${t.txnDate.month}-${t.txnDate.day}_${t.amountCny}_${t.note}';
        existingKeys.add(key);
      }

      int imported = 0;
      int duplicates = 0;
      final errors = <String>[];

      for (final t in _parsed) {
        try {
          final amountCents = (t.amount * 100).round();
          final key = '${t.date.year}-${t.date.month}-${t.date.day}_${amountCents}_${t.note}';

          if (existingKeys.contains(key)) {
            duplicates++;
            continue;
          }

          final catId = t.matchedCategoryId ?? _defaultCategory?.id ?? '';

          await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: uuid.v4(),
              userId: userId,
              accountId: defaultAccId,
              categoryId: catId,
              amount: amountCents,
              amountCny: amountCents,
              type: t.type,
              txnDate: t.date,
              note: Value(t.note),
            ),
          );

          // Update account balance
          final delta = t.type == 'income' ? amountCents : -amountCents;
          await database.updateAccountBalance(defaultAccId, delta);

          existingKeys.add(key);
          imported++;
        } catch (e) {
          errors.add('行 ${t.note}: $e');
        }
      }

      // Refresh data
      ref.read(transactionProvider.notifier).reload();
      ref.read(dashboardProvider.notifier).loadAll();

      setState(() {
        _isImporting = false;
        _importDone = true;
        _importedCount = imported;
        _duplicateCount = duplicates;
        _importErrors = errors;
      });
    } catch (e) {
      setState(() {
        _isImporting = false;
        _importDone = true;
        _importErrors = ['导入失败: $e'];
      });
    }
  }
}
