import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/import.pbgrpc.dart' as pb;

/// CSV Import wizard — 4 steps
class CsvImportPage extends ConsumerStatefulWidget {
  const CsvImportPage({super.key});

  @override
  ConsumerState<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends ConsumerState<CsvImportPage> {
  int _currentStep = 0;

  // Step 1: File
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;

  // Step 2: Preview from server
  List<String> _headers = [];
  List<List<String>> _previewRows = [];
  int _totalRows = 0;
  String _sessionId = '';
  bool _isParsing = false;
  String? _parseError;

  // Step 3: Field mapping
  final Map<String, String?> _mappings = {
    'date': null,
    'amount': null,
    'type': null,
    'category': null,
    'note': null,
    'account': null,
  };
  static const _targetFieldLabels = {
    'date': '日期',
    'amount': '金额',
    'type': '类型（收入/支出）',
    'category': '分类',
    'note': '备注',
    'account': '账户',
  };

  // Smart matching keywords
  static const _smartMatchKeywords = {
    'date': ['date', '日期', 'time', '时间', '交易时间', '交易日期'],
    'amount': ['amount', '金额', '数额', 'money', '交易金额'],
    'type': ['type', '类型', '收支', '方向', 'direction'],
    'category': ['category', '分类', '类别', 'tag', '标签'],
    'note': ['note', '备注', '说明', 'description', 'memo', '摘要'],
    'account': ['account', '账户', '账号', 'bank', '银行'],
  };

  // Step 4: Import result
  bool _isImporting = false;
  int _importedCount = 0;
  int _skippedCount = 0;
  List<String> _importErrors = [];
  bool _importDone = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV 导入'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel:
            _currentStep > 0 ? () => setState(() => _currentStep--) : null,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep < 3)
                  FilledButton(
                    onPressed:
                        _canContinue() ? details.onStepContinue : null,
                    child: Text(_currentStep == 2 ? '开始导入' : '下一步'),
                  ),
                if (_currentStep == 3 && _importDone)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                if (_currentStep > 0 && _currentStep < 3) ...[
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
          // Step 1: Choose file
          Step(
            title: const Text('选择文件'),
            content: _buildFileStep(theme),
            isActive: _currentStep >= 0,
            state:
                _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          // Step 2: Preview
          Step(
            title: const Text('数据预览'),
            content: _buildPreviewStep(theme),
            isActive: _currentStep >= 1,
            state:
                _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          // Step 3: Field mapping
          Step(
            title: const Text('字段映射'),
            content: _buildMappingStep(theme),
            isActive: _currentStep >= 2,
            state:
                _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          // Step 4: Result
          Step(
            title: const Text('导入结果'),
            content: _buildResultStep(theme),
            isActive: _currentStep >= 3,
            state: _importDone ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }

  bool _canContinue() {
    switch (_currentStep) {
      case 0:
        return _pickedFile != null && !_isParsing;
      case 1:
        return _headers.isNotEmpty;
      case 2:
        // At minimum: date + amount must be mapped
        return _mappings['date'] != null && _mappings['amount'] != null;
      default:
        return false;
    }
  }

  Future<void> _onStepContinue() async {
    if (_currentStep == 0) {
      // Parse CSV
      await _parseCSV();
      if (_parseError == null && _headers.isNotEmpty) {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      // Auto-match fields
      _autoMatchFields();
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      // Start import
      setState(() => _currentStep = 3);
      await _doImport();
    }
  }

  Widget _buildFileStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('选择 CSV 文件'),
        ),
        if (_pickedFile != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded,
                      color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickedFile!.name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatFileSize(_pickedFile!.size),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _pickedFile = null;
                      _fileBytes = null;
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
            child: Text(
              _parseError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewStep(ThemeData theme) {
    if (_headers.isEmpty) {
      return const Text('请先选择并解析 CSV 文件');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '共 $_totalRows 行数据，预览前 ${_previewRows.length} 行',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 40,
            columns: _headers
                .map((h) => DataColumn(
                      label: Text(
                        h,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ))
                .toList(),
            rows: _previewRows
                .map((row) => DataRow(
                      cells: row
                          .map((cell) => DataCell(
                                Text(
                                  cell,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMappingStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '将 CSV 列映射到对应字段',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        ..._mappings.entries.map((entry) {
          final targetField = entry.key;
          final label = _targetFieldLabels[targetField] ?? targetField;
          final isRequired =
              targetField == 'date' || targetField == 'amount';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    '$label${isRequired ? ' *' : ''}',
                    style: TextStyle(
                      fontWeight: isRequired
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: entry.value,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('不映射',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      ..._headers.map((h) => DropdownMenuItem(
                            value: h,
                            child: Text(h,
                                style: const TextStyle(fontSize: 13)),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _mappings[targetField] = v);
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        // Summary
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导入摘要',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('总行数: $_totalRows'),
                ..._mappings.entries
                    .where((e) => e.value != null)
                    .map((e) => Text(
                        '${_targetFieldLabels[e.key]} → ${e.value}')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultStep(ThemeData theme) {
    if (_isImporting) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在导入...'),
          ],
        ),
      );
    }
    if (!_importDone) {
      return const Text('等待导入...');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _importErrors.isEmpty
              ? Icons.check_circle_rounded
              : Icons.warning_rounded,
          size: 48,
          color: _importErrors.isEmpty ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 12),
        Text(
          '导入完成',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _resultRow('成功导入', '$_importedCount 条', Colors.green),
        _resultRow('跳过', '$_skippedCount 条', Colors.orange),
        if (_importErrors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '错误详情:',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          ..._importErrors.take(10).map((e) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $e',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.error,
                  ),
                ),
              )),
          if (_importErrors.length > 10)
            Text(
              '... 还有 ${_importErrors.length - 10} 个错误',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ],
    );
  }

  Widget _resultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
        _fileBytes = _pickedFile!.bytes ??
            (_pickedFile!.path != null
                ? File(_pickedFile!.path!).readAsBytesSync()
                : null);
        _parseError = null;
      });
    }
  }

  Future<void> _parseCSV() async {
    if (_fileBytes == null) return;
    setState(() {
      _isParsing = true;
      _parseError = null;
    });

    try {
      final client = ref.read(importClientProvider);
      final resp = await client.parseCSV(pb.ParseCSVRequest()
        ..csvData = _fileBytes!
        ..encoding = 'utf8');

      setState(() {
        _headers = resp.headers.toList();
        _previewRows =
            resp.previewRows.map((r) => r.values.toList()).toList();
        _totalRows = resp.totalRows;
        _sessionId = resp.sessionId;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _parseError = '解析失败: $e';
      });
    }
  }

  void _autoMatchFields() {
    for (final entry in _smartMatchKeywords.entries) {
      final targetField = entry.key;
      final keywords = entry.value;
      for (final header in _headers) {
        final lower = header.toLowerCase();
        if (keywords.any((k) => lower.contains(k))) {
          _mappings[targetField] = header;
          break;
        }
      }
    }
  }

  Future<void> _doImport() async {
    setState(() => _isImporting = true);

    try {
      final client = ref.read(importClientProvider);
      final fieldMappings = _mappings.entries
          .where((e) => e.value != null)
          .map((e) => pb.FieldMapping()
            ..csvColumn = e.value!
            ..targetField = e.key)
          .toList();

      final resp =
          await client.confirmImport(pb.ConfirmImportRequest()
            ..sessionId = _sessionId
            ..mappings.addAll(fieldMappings));

      setState(() {
        _importedCount = resp.importedCount;
        _skippedCount = resp.skippedCount;
        _importErrors = resp.errors.toList();
        _isImporting = false;
        _importDone = true;
      });
    } catch (e) {
      setState(() {
        _isImporting = false;
        _importDone = true;
        _importErrors = ['导入失败: $e'];
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
