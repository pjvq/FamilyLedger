/// Test fixture factories for FamilyLedger.
///
/// Usage:
///   final user = UserFixture.build();
///   final account = AccountFixture.build(userId: user.id);
///   final txn = TransactionFixture.build(accountId: account.id);
library;

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// User fixture builder
class UserFixture {
  static int _seq = 0;

  static Map<String, dynamic> build({
    String? id,
    String? email,
    String? name,
    String? passwordHash,
  }) {
    _seq++;
    return {
      'id': id ?? _uuid.v4(),
      'email': email ?? 'test_user_$_seq@familyledger.test',
      'name': name ?? 'Test User $_seq',
      'password_hash': passwordHash ?? '\$2a\$10\$fakehash$_seq',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static void reset() => _seq = 0;
}

/// Account fixture builder
class AccountFixture {
  static int _seq = 0;

  static Map<String, dynamic> build({
    String? id,
    required String userId,
    String? name,
    String accountType = 'cash',
    int balanceCents = 0,
    String currency = 'CNY',
    String? familyId,
    int? billingDay,
  }) {
    _seq++;
    return {
      'id': id ?? _uuid.v4(),
      'user_id': userId,
      'name': name ?? 'Test Account $_seq',
      'account_type': accountType,
      'balance_cents': balanceCents,
      'currency': currency,
      'family_id': familyId ?? '',
      'billing_day': billingDay,
      'is_deleted': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static void reset() => _seq = 0;
}

/// Transaction fixture builder
class TransactionFixture {
  static int _seq = 0;

  static Map<String, dynamic> build({
    String? id,
    required String userId,
    required String accountId,
    String type = 'expense',
    int amountCents = 1000,
    String currency = 'CNY',
    String? categoryId,
    String? note,
    DateTime? txnDate,
    String? familyId,
  }) {
    _seq++;
    final date = txnDate ?? DateTime.now();
    return {
      'id': id ?? _uuid.v4(),
      'user_id': userId,
      'account_id': accountId,
      'type': type,
      'amount_cents': amountCents,
      'currency': currency,
      'category_id': categoryId ?? _uuid.v4(),
      'note': note ?? 'Test transaction $_seq',
      'txn_date': date.toIso8601String(),
      'family_id': familyId ?? '',
      'is_deleted': false,
      'created_at': date.toIso8601String(),
      'updated_at': date.toIso8601String(),
    };
  }

  static void reset() => _seq = 0;
}

/// Loan fixture builder
class LoanFixture {
  static int _seq = 0;

  static Map<String, dynamic> build({
    String? id,
    required String userId,
    String loanType = 'equal_installment',
    int principalCents = 100000000, // 100万
    double annualRate = 0.049,
    int termMonths = 360,
    String? familyId,
    String? accountId,
  }) {
    _seq++;
    return {
      'id': id ?? _uuid.v4(),
      'user_id': userId,
      'loan_type': loanType,
      'principal_cents': principalCents,
      'annual_rate': annualRate,
      'term_months': termMonths,
      'family_id': familyId ?? '',
      'account_id': accountId ?? _uuid.v4(),
      'name': 'Test Loan $_seq',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static void reset() => _seq = 0;
}

/// Family fixture builder
class FamilyFixture {
  static int _seq = 0;

  static Map<String, dynamic> build({
    String? id,
    required String ownerId,
    String? name,
  }) {
    _seq++;
    return {
      'id': id ?? _uuid.v4(),
      'owner_id': ownerId,
      'name': name ?? 'Test Family $_seq',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static void reset() => _seq = 0;
}

/// SyncOperation fixture builder
class SyncOpFixture {
  static int _seq = 0;

  static Map<String, dynamic> build({
    String? id,
    required String userId,
    String opType = 'CREATE',
    String entityType = 'transaction',
    String? entityId,
    String? payload,
    String? clientId,
  }) {
    _seq++;
    final entityIdVal = entityId ?? _uuid.v4();
    return {
      'id': id ?? _uuid.v4(),
      'user_id': userId,
      'op_type': opType,
      'entity_type': entityType,
      'entity_id': entityIdVal,
      'payload': payload ?? '{"id":"$entityIdVal","note":"sync_test_$_seq"}',
      'client_id': clientId ?? 'client_test',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  static void reset() => _seq = 0;
}

/// Reset all fixture sequences (call in setUp)
void resetAllFixtures() {
  UserFixture.reset();
  AccountFixture.reset();
  TransactionFixture.reset();
  LoanFixture.reset();
  FamilyFixture.reset();
  SyncOpFixture.reset();
}
