/// Domain entity for a financial transaction.
///
/// Framework-agnostic — no Drift, no proto dependencies.
/// Data layer maps between this and ORM/proto types.
class TransactionEntity {
  final String id;
  final String userId;
  final String accountId;
  final String categoryId;
  final int amount;
  final int amountCny;
  final String type; // 'income' | 'expense' | 'transfer'
  final String note;
  final DateTime txnDate;
  final String syncStatus;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TransactionEntity({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.amountCny,
    required this.type,
    this.note = '',
    required this.txnDate,
    this.syncStatus = 'pending',
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  TransactionEntity copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? categoryId,
    int? amount,
    int? amountCny,
    String? type,
    String? note,
    DateTime? txnDate,
    String? syncStatus,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      amountCny: amountCny ?? this.amountCny,
      type: type ?? this.type,
      note: note ?? this.note,
      txnDate: txnDate ?? this.txnDate,
      syncStatus: syncStatus ?? this.syncStatus,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Domain entity for a financial account.
class AccountEntity {
  final String id;
  final String userId;
  final String name;
  final String type;
  final int balance;
  final String currency;
  final String? familyId;

  const AccountEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'CNY',
    this.familyId,
  });
}

/// Domain entity for a transaction category.
class CategoryEntity {
  final String id;
  final String name;
  final String type; // 'income' | 'expense'
  final String? parentId;
  final String iconKey;
  final int sortOrder;
  final bool isPreset;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.iconKey = '',
    this.sortOrder = 0,
    this.isPreset = false,
  });
}
