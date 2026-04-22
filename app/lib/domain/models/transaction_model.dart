enum TransactionType { income, expense }

class TransactionModel {
  final String id;
  final String userId;
  final String accountId;
  final String categoryId;
  final int amount; // 分
  final String currency;
  final int amountCny; // 人民币（分）
  final double exchangeRate;
  final TransactionType type;
  final String note;
  final DateTime txnDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    this.currency = 'CNY',
    required this.amountCny,
    this.exchangeRate = 1.0,
    required this.type,
    this.note = '',
    required this.txnDate,
    required this.createdAt,
    required this.updatedAt,
    this.synced = false,
  });

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? categoryId,
    int? amount,
    String? currency,
    int? amountCny,
    double? exchangeRate,
    TransactionType? type,
    String? note,
    DateTime? txnDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) =>
      TransactionModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        accountId: accountId ?? this.accountId,
        categoryId: categoryId ?? this.categoryId,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        amountCny: amountCny ?? this.amountCny,
        exchangeRate: exchangeRate ?? this.exchangeRate,
        type: type ?? this.type,
        note: note ?? this.note,
        txnDate: txnDate ?? this.txnDate,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        synced: synced ?? this.synced,
      );

  /// 格式化金额展示（元）
  String get formattedAmount {
    final yuan = amountCny / 100;
    return yuan.toStringAsFixed(2);
  }
}
