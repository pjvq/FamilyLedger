import 'package:uuid/uuid.dart';

/// Deterministic UUID v5 for category IDs.
///
/// Both Flutter client and Go server use the same namespace + formula,
/// guaranteeing identical UUIDs without network communication.
///
/// Formula: UUIDv5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "{ownerID}:{type}:{name}")
///
/// [ownerID] is the userId (personal mode) or familyId (family mode).
/// This ensures different users/families have unique UUIDs for same-named categories.
class CategoryUUID {
  CategoryUUID._();

  static const _namespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
  static const _uuid = Uuid();

  /// Generate a deterministic UUID for a category.
  ///
  /// [ownerID] is userId (personal) or familyId (family mode).
  /// [type] is "expense" or "income".
  /// [name] is the category name, e.g. "餐饮", "工资".
  /// For subcategories, [name] should be "$parentUUID:$childName".
  static String generate(String ownerID, String type, String name) {
    return _uuid.v5(_namespace, '$ownerID:$type:$name');
  }
}
