import 'dart:developer' as dev;

import '../../core/network/network.dart';
import '../../generated/proto/transaction.pbgrpc.dart' as pb;
import '../../generated/proto/transaction.pbenum.dart' as pbe;
import '../entities/entities.dart';
import '../interfaces/interfaces.dart';

/// Syncs categories from the remote server to local storage.
///
/// Depends on [ICategoryRepository] (DIP) for data access.
/// Stateless service — holds no mutable state. Safe to call from any isolate.
class CategorySyncService {
  final ICategoryRepository _repo;
  final pb.TransactionServiceClient _client;
  // ignore: unused_field
  final String _userId; // Retained for future seedForOwner() calls

  CategorySyncService(this._repo, this._client, this._userId);

  /// Fetch all categories from server and upsert locally.
  /// Returns true if sync succeeded, false on network failure.
  Future<bool> syncFromServer() async {
    try {
      final resp = await _client.getCategories(
        pb.GetCategoriesRequest(),
        options: defaultCallOptions,
      );
      // Top-level categories are independent — parallel upsert.
      await Future.wait(
        resp.categories.map((c) => _insertRecursive(c, null)),
      );
      return true;
    } catch (e) {
      dev.log('CategorySyncService: sync failed: $e', name: 'category_sync');
      return false;
    }
  }

  Future<void> _insertRecursive(pb.Category c, String? parentId) async {
    final type = c.type == pbe.TransactionType.TRANSACTION_TYPE_INCOME
        ? 'income'
        : 'expense';

    // Upsert this category via interface
    await _repo.upsert(CategoryEntity(
      id: c.id,
      name: c.name,
      type: type,
      parentId: parentId ?? (c.parentId.isNotEmpty ? c.parentId : null),
      iconKey: c.iconKey.isNotEmpty ? c.iconKey : '',
      sortOrder: c.sortOrder,
      isPreset: true,
    ));

    // Recurse for children
    for (final child in c.children) {
      await _insertRecursive(child, c.id);
    }
  }
}
