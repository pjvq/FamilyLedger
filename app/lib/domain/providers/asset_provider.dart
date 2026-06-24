import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import 'package:drift/drift.dart' show Value;
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/asset.pb.dart' as pb;
import '../../generated/proto/asset.pbgrpc.dart';
import '../../generated/proto/asset.pbenum.dart' as pb_enum;
import '../../generated/proto/google/protobuf/timestamp.pb.dart' as ts_pb;
import '../services/depreciation_calculator.dart';
import 'app_providers.dart';

// ── Display models ──

class AssetDisplayItem {
  final String id;
  final String name;
  final String assetType;
  final int purchasePrice; // 分
  final int currentValue; // 分
  final DateTime purchaseDate;
  final String description;
  final String depreciationMethod; // none / straight_line / double_declining
  final int usefulLifeYears;
  final double salvageRate;
  final double depreciationProgress; // 0-1, 已折旧占购入价比例

  const AssetDisplayItem({
    required this.id,
    required this.name,
    required this.assetType,
    required this.purchasePrice,
    required this.currentValue,
    required this.purchaseDate,
    this.description = '',
    this.depreciationMethod = 'none',
    this.usefulLifeYears = 5,
    this.salvageRate = 0.05,
    this.depreciationProgress = 0.0,
  });
}

class ValuationRecord {
  final String id;
  final int value; // 分
  final String source; // manual / depreciation
  final DateTime valuationDate;

  const ValuationRecord({
    required this.id,
    required this.value,
    required this.source,
    required this.valuationDate,
  });
}

// ── Asset type helpers ──

const assetTypeLabels = {
  'real_estate': '房产',
  'vehicle': '车辆',
  'electronics': '电子设备',
  'furniture': '家具家电',
  'jewelry': '珠宝收藏',
  'other': '其他',
};

const assetTypeIcons = {
  'real_estate': '🏠',
  'vehicle': '🚗',
  'electronics': '📱',
  'furniture': '🛋️',
  'jewelry': '💎',
  'other': '📦',
};

String assetTypeLabel(String type) => assetTypeLabels[type] ?? type;
String assetTypeIcon(String type) => assetTypeIcons[type] ?? '📦';

const depreciationMethodLabels = {
  'none': '不折旧',
  'straight_line': '直线法',
  'double_declining': '双倍余额递减法',
};

String depreciationMethodLabel(String method) =>
    depreciationMethodLabels[method] ?? method;

// ── Proto helpers ──

String _assetTypeToString(pb_enum.AssetType type) {
  switch (type) {
    case pb_enum.AssetType.ASSET_TYPE_REAL_ESTATE:
      return 'real_estate';
    case pb_enum.AssetType.ASSET_TYPE_VEHICLE:
      return 'vehicle';
    case pb_enum.AssetType.ASSET_TYPE_ELECTRONICS:
      return 'electronics';
    case pb_enum.AssetType.ASSET_TYPE_FURNITURE:
      return 'furniture';
    case pb_enum.AssetType.ASSET_TYPE_JEWELRY:
      return 'jewelry';
    case pb_enum.AssetType.ASSET_TYPE_OTHER:
      return 'other';
    default:
      return 'other';
  }
}

pb_enum.AssetType _stringToAssetType(String type) {
  switch (type) {
    case 'real_estate':
      return pb_enum.AssetType.ASSET_TYPE_REAL_ESTATE;
    case 'vehicle':
      return pb_enum.AssetType.ASSET_TYPE_VEHICLE;
    case 'electronics':
      return pb_enum.AssetType.ASSET_TYPE_ELECTRONICS;
    case 'furniture':
      return pb_enum.AssetType.ASSET_TYPE_FURNITURE;
    case 'jewelry':
      return pb_enum.AssetType.ASSET_TYPE_JEWELRY;
    case 'other':
      return pb_enum.AssetType.ASSET_TYPE_OTHER;
    default:
      return pb_enum.AssetType.ASSET_TYPE_OTHER;
  }
}

pb_enum.DepreciationMethod _stringToDepreciationMethod(String method) {
  switch (method) {
    case 'straight_line':
      return pb_enum.DepreciationMethod.DEPRECIATION_METHOD_STRAIGHT_LINE;
    case 'double_declining':
      return pb_enum.DepreciationMethod.DEPRECIATION_METHOD_DOUBLE_DECLINING;
    case 'none':
      return pb_enum.DepreciationMethod.DEPRECIATION_METHOD_NONE;
    default:
      return pb_enum.DepreciationMethod.DEPRECIATION_METHOD_NONE;
  }
}

ts_pb.Timestamp _toTimestamp(DateTime dt) {
  final seconds = dt.millisecondsSinceEpoch ~/ 1000;
  return ts_pb.Timestamp(seconds: Int64(seconds));
}

// ── State ──

class AssetState {
  final List<AssetDisplayItem> assets;
  final AssetDisplayItem? currentAsset;
  final List<ValuationRecord> valuations;
  final int totalNetValue; // 分
  final bool isLoading;
  final String? error;

  const AssetState({
    this.assets = const [],
    this.currentAsset,
    this.valuations = const [],
    this.totalNetValue = 0,
    this.isLoading = false,
    this.error,
  });

  AssetState copyWith({
    List<AssetDisplayItem>? assets,
    AssetDisplayItem? currentAsset,
    List<ValuationRecord>? valuations,
    int? totalNetValue,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearCurrentAsset = false,
  }) => AssetState(
    assets: assets ?? this.assets,
    currentAsset: clearCurrentAsset
        ? null
        : (currentAsset ?? this.currentAsset),
    valuations: valuations ?? this.valuations,
    totalNetValue: totalNetValue ?? this.totalNetValue,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

// ── Notifier ──

class AssetNotifier extends StateNotifier<AssetState> {
  final db.AppDatabase _db;
  final AssetServiceClient _assetClient;
  final String? _userId;
  final String? _familyId;
  final DepreciationCalculator _depreciation;

  AssetNotifier(
    this._db,
    this._assetClient,
    this._userId,
    this._familyId, {
    DepreciationCalculator depreciation = const DepreciationCalculator(),
    bool autoInit = true,
  }) : _depreciation = depreciation,
       super(const AssetState()) {
    if (_userId != null && autoInit) {
      _init();
    }
  }

  /// Launch sequence: run any missing monthly depreciation locally, then load.
  Future<void> _init() async {
    await runDepreciationCatchUp();
    await listAssets();
  }

  /// List all assets (gRPC first, local fallback)
  Future<void> listAssets() async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final assetReq = pb.ListAssetsRequest();
      if (_familyId != null && _familyId.isNotEmpty) {
        assetReq.familyId = _familyId;
      }
      final resp = await _assetClient.listAssets(assetReq);
      for (final asset in resp.assets) {
        await _db.upsertFixedAsset(
          db.FixedAssetsCompanion.insert(
            id: asset.id,
            userId: asset.userId,
            familyId: Value(asset.familyId),
            name: asset.name,
            assetType: Value(_assetTypeToString(asset.assetType)),
            purchasePrice: asset.purchasePrice.toInt(),
            currentValue: asset.currentValue.toInt(),
            purchaseDate: asset.purchaseDate.toDateTime(),
            description: Value(asset.description),
          ),
        );
      }
    } catch (_) {
      // Offline fallback
    }

    try {
      final assets = await _db.getFixedAssets(_userId, familyId: _familyId);
      final displayItems = <AssetDisplayItem>[];
      int totalNet = 0;

      for (final asset in assets) {
        final rule = await _db.getDepreciationRule(asset.id);
        final method = rule?.method ?? 'none';
        final years = rule?.usefulLifeYears ?? 5;
        final salvageRate = rule?.salvageRate ?? 0.05;

        // current_value is kept up to date by runDepreciationCatchUp (run on
        // launch) and by manual valuations, so it is authoritative here.
        final currentVal = asset.currentValue;

        final depreciated = asset.purchasePrice - currentVal;
        final progress = asset.purchasePrice > 0
            ? (depreciated / asset.purchasePrice).clamp(0.0, 1.0)
            : 0.0;

        totalNet += currentVal;

        displayItems.add(
          AssetDisplayItem(
            id: asset.id,
            name: asset.name,
            assetType: asset.assetType,
            purchasePrice: asset.purchasePrice,
            currentValue: currentVal,
            purchaseDate: asset.purchaseDate,
            description: asset.description,
            depreciationMethod: method,
            usefulLifeYears: years,
            salvageRate: salvageRate,
            depreciationProgress: progress,
          ),
        );
      }

      state = state.copyWith(
        assets: displayItems,
        totalNetValue: totalNet,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new fixed asset
  Future<void> createAsset({
    required String name,
    required String assetType,
    required int purchasePrice,
    required DateTime purchaseDate,
    String? description,
    String depreciationMethod = 'none',
    int usefulLifeYears = 5,
    double salvageRate = 0.05,
    String? familyId,
  }) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    String assetId = const Uuid().v4();

    try {
      final resp = await _assetClient.createAsset(
        pb.CreateAssetRequest()
          ..name = name
          ..assetType = _stringToAssetType(assetType)
          ..purchasePrice = Int64(purchasePrice)
          ..purchaseDate = _toTimestamp(purchaseDate)
          ..description = description ?? ''
          ..familyId = familyId ?? '',
      );
      assetId = resp.id;

      await _db.upsertFixedAsset(
        db.FixedAssetsCompanion.insert(
          id: resp.id,
          userId: resp.userId,
          familyId: Value(familyId ?? ''),
          name: resp.name,
          assetType: Value(_assetTypeToString(resp.assetType)),
          purchasePrice: resp.purchasePrice.toInt(),
          currentValue: resp.currentValue.toInt(),
          purchaseDate: resp.purchaseDate.toDateTime(),
          description: Value(resp.description),
        ),
      );
    } catch (_) {
      // Offline: save locally
      await _db.upsertFixedAsset(
        db.FixedAssetsCompanion.insert(
          id: assetId,
          userId: _userId,
          familyId: Value(familyId ?? ''),
          name: name,
          assetType: Value(assetType),
          purchasePrice: purchasePrice,
          currentValue: purchasePrice,
          purchaseDate: purchaseDate,
          description: Value(description ?? ''),
        ),
      );
    }

    // Save initial valuation record
    await _db.insertAssetValuation(
      db.AssetValuationsCompanion.insert(
        id: const Uuid().v4(),
        assetId: assetId,
        value: purchasePrice,
        source: Value('manual'),
        valuationDate: purchaseDate,
      ),
    );

    // Save depreciation rule
    if (depreciationMethod != 'none') {
      await _db.upsertDepreciationRule(
        db.DepreciationRulesCompanion.insert(
          id: const Uuid().v4(),
          assetId: assetId,
          method: Value(depreciationMethod),
          usefulLifeYears: Value(usefulLifeYears),
          salvageRate: Value(salvageRate),
        ),
      );

      try {
        await _assetClient.setDepreciationRule(
          pb.SetDepreciationRuleRequest()
            ..assetId = assetId
            ..method = _stringToDepreciationMethod(depreciationMethod)
            ..usefulLifeYears = usefulLifeYears
            ..salvageRate = salvageRate,
        );
      } catch (_) {}
    }

    await listAssets();
  }

  /// Get asset detail + valuations
  Future<void> getAsset(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final resp = await _assetClient.listValuations(
        pb.ListValuationsRequest()..assetId = id,
      );
      // Store remote valuations if needed
      for (final _ in resp.valuations) {
        // We don't batch-persist these for simplicity
      }
    } catch (_) {}

    final asset = await _db.getFixedAssetById(id);
    if (asset == null) {
      state = state.copyWith(isLoading: false, error: '资产不存在');
      return;
    }

    final rule = await _db.getDepreciationRule(id);
    final method = rule?.method ?? 'none';
    final years = rule?.usefulLifeYears ?? 5;
    final salvageRate = rule?.salvageRate ?? 0.05;

    // Authoritative: kept current by runDepreciationCatchUp + manual updates.
    final currentVal = asset.currentValue;

    final depreciated = asset.purchasePrice - currentVal;
    final progress = asset.purchasePrice > 0
        ? (depreciated / asset.purchasePrice).clamp(0.0, 1.0)
        : 0.0;

    final displayItem = AssetDisplayItem(
      id: asset.id,
      name: asset.name,
      assetType: asset.assetType,
      purchasePrice: asset.purchasePrice,
      currentValue: currentVal,
      purchaseDate: asset.purchaseDate,
      description: asset.description,
      depreciationMethod: method,
      usefulLifeYears: years,
      salvageRate: salvageRate,
      depreciationProgress: progress,
    );

    final dbValuations = await _db.getAssetValuations(id);
    final valuations = dbValuations
        .map(
          (v) => ValuationRecord(
            id: v.id,
            value: v.value,
            source: v.source,
            valuationDate: v.valuationDate,
          ),
        )
        .toList();

    state = state.copyWith(
      currentAsset: displayItem,
      valuations: valuations,
      isLoading: false,
    );
  }

  /// Update asset info
  Future<void> updateAsset(
    String id, {
    String? name,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _assetClient.updateAsset(
        pb.UpdateAssetRequest()
          ..assetId = id
          ..name = name ?? ''
          ..description = description ?? '',
      );
    } catch (_) {}

    if (name != null) {
      await _db.updateFixedAssetFields(
        id,
        db.FixedAssetsCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    if (description != null) {
      await _db.updateFixedAssetFields(
        id,
        db.FixedAssetsCompanion(
          description: Value(description),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    await listAssets();
    await getAsset(id);
  }

  /// Delete an asset (soft delete)
  Future<void> deleteAsset(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _assetClient.deleteAsset(pb.DeleteAssetRequest()..assetId = id);
    } catch (_) {}

    await _db.softDeleteFixedAsset(id);
    await listAssets();
  }

  /// Update valuation (manual)
  Future<void> updateValuation(String assetId, int value, DateTime date) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _assetClient.updateValuation(
        pb.UpdateValuationRequest()
          ..assetId = assetId
          ..value = Int64(value)
          ..source = 'manual',
      );
    } catch (_) {}

    await _db.insertAssetValuation(
      db.AssetValuationsCompanion.insert(
        id: const Uuid().v4(),
        assetId: assetId,
        value: value,
        source: Value('manual'),
        valuationDate: date,
      ),
    );

    // Update asset current value
    await _db.updateFixedAssetFields(
      assetId,
      db.FixedAssetsCompanion(
        currentValue: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await listAssets();
    await getAsset(assetId);
  }

  /// Set depreciation rule
  Future<void> setDepreciationRule(
    String assetId, {
    required String method,
    required int usefulLifeYears,
    required double salvageRate,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _assetClient.setDepreciationRule(
        pb.SetDepreciationRuleRequest()
          ..assetId = assetId
          ..method = _stringToDepreciationMethod(method)
          ..usefulLifeYears = usefulLifeYears
          ..salvageRate = salvageRate,
      );
    } catch (_) {}

    await _db.upsertDepreciationRule(
      db.DepreciationRulesCompanion.insert(
        id: const Uuid().v4(),
        assetId: assetId,
        method: Value(method),
        usefulLifeYears: Value(usefulLifeYears),
        salvageRate: Value(salvageRate),
      ),
    );

    await listAssets();
    await getAsset(assetId);
  }

  // ── Local depreciation computation ──

  /// Detect months that have not yet been depreciated and persist them.
  ///
  /// Idempotent: each asset's prior `depreciation` valuations identify the
  /// months already processed, so re-running within the same month (or after
  /// multiple missed months) never double-depreciates. Runs purely on the
  /// local DB — no server dependency. Safe to call on every app launch.
  Future<void> runDepreciationCatchUp({DateTime? now}) async {
    if (_userId == null) return;
    final reference = now ?? DateTime.now();

    final List<db.FixedAsset> assets;
    try {
      assets = await _db.getFixedAssets(_userId, familyId: _familyId);
    } catch (_) {
      return;
    }

    for (final asset in assets) {
      final rule = await _db.getDepreciationRule(asset.id);
      if (rule == null) continue;
      final method = rule.method;
      if (method != 'straight_line' && method != 'double_declining') continue;

      // Months already covered by a depreciation valuation = idempotency guard.
      final valuations = await _db.getAssetValuations(asset.id);
      final doneMonths = <DateTime>{};
      for (final v in valuations) {
        if (v.source == 'depreciation') {
          doneMonths.add(DepreciationCalculator.monthKey(v.valuationDate));
        }
      }

      final steps = _depreciation.computeMissingSteps(
        purchasePrice: asset.purchasePrice,
        currentValue: asset.currentValue,
        purchaseDate: asset.purchaseDate,
        method: method,
        usefulLifeYears: rule.usefulLifeYears,
        salvageRate: rule.salvageRate,
        alreadyDepreciatedMonths: doneMonths,
        now: reference,
      );

      if (steps.isEmpty) continue;

      for (final step in steps) {
        await _db.insertAssetValuation(
          db.AssetValuationsCompanion.insert(
            id: const Uuid().v4(),
            assetId: asset.id,
            value: step.value,
            source: const Value('depreciation'),
            valuationDate: step.month,
          ),
        );
      }

      // Persist the final book value as the asset's current value.
      await _db.updateFixedAssetFields(
        asset.id,
        db.FixedAssetsCompanion(
          currentValue: Value(steps.last.value),
          updatedAt: Value(reference),
        ),
      );
    }
  }
}

// ── Provider ──

final assetProvider = StateNotifierProvider<AssetNotifier, AssetState>((ref) {
  final database = ref.watch(databaseProvider);
  final client = ref.watch(assetClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider);
  return AssetNotifier(database, client, userId, familyId);
});
