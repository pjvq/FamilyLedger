class AccountModel {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final int balance; // 分
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    this.icon = '💳',
    this.balance = 0,
    this.currency = 'CNY',
    required this.createdAt,
    required this.updatedAt,
  });

  String get formattedBalance {
    final yuan = balance / 100;
    return yuan.toStringAsFixed(2);
  }
}
