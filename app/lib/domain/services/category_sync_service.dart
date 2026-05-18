import 'dart:developer' as dev;

import '../../core/network/network.dart';
import '../../generated/proto/transaction.pbgrpc.dart' as pb;
import '../../generated/proto/transaction.pbenum.dart' as pbe;
import '../repositories/transaction_repository.dart';

/// Syncs categories from the remote server to local storage.
///
/// Stateless service — holds no mutable state. Safe to call from any isolate
/// (if we move to multi-isolate architecture in the future).
class CategorySyncService {
  final TransactionRepository _repo;
  final pb.TransactionServiceClient _client;
  final String _userId;

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
    final children = c.children
        .map((child) => CategoryChild(
              id: child.id,
              name: child.name,
              sortOrder: child.sortOrder,
              iconKey: child.iconKey.isNotEmpty ? child.iconKey : null,
              children: _mapChildren(child.children),
            ))
        .toList();
    await _repo.upsertCategoryTree(
      c.id,
      c.name,
      type,
      c.sortOrder,
      parentId ?? (c.parentId.isNotEmpty ? c.parentId : null),
      c.iconKey.isNotEmpty ? c.iconKey : null,
      _userId,
      children,
    );
  }

  List<CategoryChild> _mapChildren(List<pb.Category> cats) {
    return cats.map((c) => CategoryChild(
      id: c.id,
      name: c.name,
      sortOrder: c.sortOrder,
      iconKey: c.iconKey.isNotEmpty ? c.iconKey : null,
      children: _mapChildren(c.children),
    )).toList();
  }
}
