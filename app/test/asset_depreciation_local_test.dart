/// DB-integration tests for [AssetNotifier.runDepreciationCatchUp].
///
/// Verifies the launch-trigger path end-to-end against an in-memory Drift DB:
/// missing months are computed and persisted as `depreciation` valuations,
/// `current_value` is updated, and re-running is idempotent.
library;

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/generated/proto/asset.pbgrpc.dart' show AssetServiceClient;
import 'package:familyledger/domain/providers/asset_provider.dart';

void main() {
  late AppDatabase db;
  late AssetServiceClient client;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedCategoriesForOwner('u1');
    // A channel that never connects; runDepreciationCatchUp never calls it.
    client = AssetServiceClient(
      ClientChannel(
        'localhost',
        port: 1,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedAsset({
    required String id,
    required int price,
    required DateTime purchaseDate,
    required String method,
    int years = 5,
    double salvage = 0.05,
  }) async {
    await db.upsertFixedAsset(
      FixedAssetsCompanion.insert(
        id: id,
        userId: 'u1',
        name: 'asset-$id',
        purchasePrice: price,
        currentValue: price,
        purchaseDate: purchaseDate,
      ),
    );
    await db.upsertDepreciationRule(
      DepreciationRulesCompanion.insert(
        id: 'rule-$id',
        assetId: id,
        method: Value(method),
        usefulLifeYears: Value(years),
        salvageRate: Value(salvage),
      ),
    );
  }

  AssetNotifier notifier() =>
      AssetNotifier(db, client, 'u1', null, autoInit: false);

  List<AssetValuation> depValuations(List<AssetValuation> all) =>
      all.where((v) => v.source == 'depreciation').toList();

  test('straight_line: persists missing months and updates current_value',
      () async {
    await seedAsset(
      id: 'a1',
      price: 10000000,
      purchaseDate: DateTime(2026, 1, 10),
      method: 'straight_line',
    );

    await notifier().runDepreciationCatchUp(now: DateTime(2026, 4, 5));

    final vals = depValuations(await db.getAssetValuations('a1'));
    // Feb, Mar, Apr 2026.
    expect(vals.length, 3);
    final asset = await db.getFixedAssetById('a1');
    // 3 * 158333 deducted.
    expect(asset!.currentValue, 10000000 - 158333 * 3);
  });

  test('idempotent: running twice does not double-depreciate', () async {
    await seedAsset(
      id: 'a2',
      price: 10000000,
      purchaseDate: DateTime(2026, 1, 10),
      method: 'straight_line',
    );

    final n = notifier();
    await n.runDepreciationCatchUp(now: DateTime(2026, 3, 5));
    final afterFirst = await db.getFixedAssetById('a2');
    final countFirst =
        depValuations(await db.getAssetValuations('a2')).length;

    // Same month, run again — must be a no-op.
    await n.runDepreciationCatchUp(now: DateTime(2026, 3, 20));
    final afterSecond = await db.getFixedAssetById('a2');
    final countSecond =
        depValuations(await db.getAssetValuations('a2')).length;

    expect(countSecond, countFirst);
    expect(afterSecond!.currentValue, afterFirst!.currentValue);
  });

  test('catch-up after a gap only fills the missing months', () async {
    await seedAsset(
      id: 'a3',
      price: 10000000,
      purchaseDate: DateTime(2026, 1, 10),
      method: 'straight_line',
    );

    final n = notifier();
    await n.runDepreciationCatchUp(now: DateTime(2026, 2, 5)); // Feb only
    expect(depValuations(await db.getAssetValuations('a3')).length, 1);

    // App reopened in April: should add Mar + Apr.
    await n.runDepreciationCatchUp(now: DateTime(2026, 4, 5));
    expect(depValuations(await db.getAssetValuations('a3')).length, 3);
  });

  test('method none is skipped entirely', () async {
    await seedAsset(
      id: 'a4',
      price: 10000000,
      purchaseDate: DateTime(2026, 1, 10),
      method: 'none',
    );

    await notifier().runDepreciationCatchUp(now: DateTime(2026, 6, 5));

    expect(depValuations(await db.getAssetValuations('a4')), isEmpty);
    final asset = await db.getFixedAssetById('a4');
    expect(asset!.currentValue, 10000000);
  });

  test('double_declining persists steps and declines faster than SL',
      () async {
    await seedAsset(
      id: 'dd',
      price: 10000000,
      purchaseDate: DateTime(2026, 1, 1),
      method: 'double_declining',
    );
    await seedAsset(
      id: 'sl',
      price: 10000000,
      purchaseDate: DateTime(2026, 1, 1),
      method: 'straight_line',
    );

    await notifier().runDepreciationCatchUp(now: DateTime(2026, 4, 1));

    final dd = await db.getFixedAssetById('dd');
    final sl = await db.getFixedAssetById('sl');
    expect(depValuations(await db.getAssetValuations('dd')).length, 3);
    expect(dd!.currentValue, lessThan(sl!.currentValue));
  });
}
