import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/export.pb.dart' as pb;
import '../../generated/proto/export.pbgrpc.dart';
import 'app_providers.dart';

// ── State ──

class ExportState {
  final bool isExporting;
  final String? error;
  final Uint8List? lastExportData;
  final String? lastFilename;
  final String? lastContentType;

  const ExportState({
    this.isExporting = false,
    this.error,
    this.lastExportData,
    this.lastFilename,
    this.lastContentType,
  });

  ExportState copyWith({
    bool? isExporting,
    String? error,
    Uint8List? lastExportData,
    String? lastFilename,
    String? lastContentType,
    bool clearError = false,
    bool clearData = false,
  }) =>
      ExportState(
        isExporting: isExporting ?? this.isExporting,
        error: clearError ? null : (error ?? this.error),
        lastExportData:
            clearData ? null : (lastExportData ?? this.lastExportData),
        lastFilename: clearData ? null : (lastFilename ?? this.lastFilename),
        lastContentType:
            clearData ? null : (lastContentType ?? this.lastContentType),
      );
}

// ── Notifier ──

class ExportNotifier extends StateNotifier<ExportState> {
  final db.AppDatabase _db;
  final ExportServiceClient _client;
  final String? _userId;
  final String? _familyId;

  ExportNotifier(this._db, this._client, this._userId, this._familyId)
      : super(const ExportState());

  /// Export transactions to the specified format
  Future<Uint8List?> exportTransactions({
    required String format, // csv, excel, pdf
    required DateTime startDate,
    required DateTime endDate,
    List<String> categoryIds = const [],
  }) async {
    if (_userId == null) return null;
    state = state.copyWith(isExporting: true, clearError: true, clearData: true);

    try {
      final resp = await _client.exportTransactions(
        pb.ExportRequest()
          ..userId = _userId
          ..familyId = _familyId ?? ''
          ..format = format
          ..startDate = startDate.toIso8601String().split('T')[0]
          ..endDate = endDate.toIso8601String().split('T')[0]
          ..categoryIds.addAll(categoryIds),
      );
      final data = Uint8List.fromList(resp.data);
      state = state.copyWith(
        isExporting: false,
        lastExportData: data,
        lastFilename: resp.filename,
        lastContentType: resp.contentType,
      );
      return data;
    } catch (_) {
      // Fallback: generate CSV locally
    }

    if (format != 'csv') {
      state = state.copyWith(
        isExporting: false,
        error: '离线模式仅支持CSV格式导出',
      );
      return null;
    }

    return await _generateLocalCsv(startDate, endDate, categoryIds);
  }

  Future<Uint8List?> _generateLocalCsv(
    DateTime startDate,
    DateTime endDate,
    List<String> categoryIds,
  ) async {
    if (_userId == null) return null;

    try {
      final allTxns = await _db.getRecentTransactions(_userId, 100000,
          familyId: _familyId);
      final categories = await _db.getAllCategories();
      final catMap = {for (final c in categories) c.id: c};
      List<db.Account> accounts;
      if (_familyId != null && _familyId.isNotEmpty) {
        accounts = await _db.getAccountsByFamily(_familyId);
      } else {
        accounts = await _db.getActiveAccounts(_userId);
      }
      final accMap = {for (final a in accounts) a.id: a};

      // Filter by date range and categories
      final filtered = allTxns.where((t) {
        if (t.txnDate.isBefore(startDate) || t.txnDate.isAfter(endDate)) {
          return false;
        }
        if (categoryIds.isNotEmpty && !categoryIds.contains(t.categoryId)) {
          return false;
        }
        return true;
      }).toList();

      // Sort by date
      filtered.sort((a, b) => a.txnDate.compareTo(b.txnDate));

      // Build CSV
      final buffer = StringBuffer();
      buffer.writeln('日期,类型,分类,金额(元),账户,备注');

      for (final t in filtered) {
        final cat = catMap[t.categoryId];
        final acc = accMap[t.accountId];
        final date = '${t.txnDate.year}-'
            '${t.txnDate.month.toString().padLeft(2, '0')}-'
            '${t.txnDate.day.toString().padLeft(2, '0')}';
        final typeLabel = t.type == 'income' ? '收入' : '支出';
        final catName = cat?.name ?? '未知';
        final yuan = (t.amountCny / 100).toStringAsFixed(2);
        final accName = acc?.name ?? '未知';
        final note = t.note.replaceAll(',', '，'); // Escape commas

        buffer.writeln('$date,$typeLabel,$catName,$yuan,$accName,$note');
      }

      final csvString = buffer.toString();
      final bytes = Uint8List.fromList(utf8.encode(csvString));
      final now = DateTime.now();
      final filename =
          'transactions_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';

      state = state.copyWith(
        isExporting: false,
        lastExportData: bytes,
        lastFilename: filename,
        lastContentType: 'text/csv',
      );
      return bytes;
    } catch (e) {
      state = state.copyWith(isExporting: false, error: e.toString());
      return null;
    }
  }

  void clearExportData() {
    state = state.copyWith(clearData: true);
  }
}

// ── Provider ──

final exportProvider =
    StateNotifierProvider<ExportNotifier, ExportState>((ref) {
  final database = ref.watch(databaseProvider);
  final client = ref.watch(exportClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider);
  return ExportNotifier(database, client, userId, familyId);
});
