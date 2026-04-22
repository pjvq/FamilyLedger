import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import '../../data/local/database.dart';
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/account.pbgrpc.dart' as pb;
import '../../generated/proto/account.pb.dart' as pb_model;
import '../../generated/proto/account.pbenum.dart' as pb_enum;
import 'app_providers.dart';

/// Account type helpers
class AccountTypeHelper {
  static const typeMap = {
    'cash': '现金',
    'bank_card': '银行卡',
    'credit_card': '信用卡',
    'alipay': '支付宝',
    'wechat_pay': '微信支付',
    'investment': '投资账户',
    'other': '其他',
  };

  static const iconMap = {
    'cash': '💵',
    'bank_card': '🏦',
    'credit_card': '💳',
    'alipay': '🔵',  // Alipay blue
    'wechat_pay': '🟢',  // WeChat green
    'investment': '📈',
    'other': '💰',
  };

  static String displayName(String type) => typeMap[type] ?? '其他';
  static String defaultIcon(String type) => iconMap[type] ?? '💰';

  static pb_enum.AccountType toProto(String type) {
    switch (type) {
      case 'cash':
        return pb_enum.AccountType.ACCOUNT_TYPE_CASH;
      case 'bank_card':
        return pb_enum.AccountType.ACCOUNT_TYPE_BANK_CARD;
      case 'credit_card':
        return pb_enum.AccountType.ACCOUNT_TYPE_CREDIT_CARD;
      case 'alipay':
        return pb_enum.AccountType.ACCOUNT_TYPE_ALIPAY;
      case 'wechat_pay':
        return pb_enum.AccountType.ACCOUNT_TYPE_WECHAT_PAY;
      case 'investment':
        return pb_enum.AccountType.ACCOUNT_TYPE_INVESTMENT;
      default:
        return pb_enum.AccountType.ACCOUNT_TYPE_OTHER;
    }
  }

  static String fromProto(pb_enum.AccountType type) {
    switch (type) {
      case pb_enum.AccountType.ACCOUNT_TYPE_CASH:
        return 'cash';
      case pb_enum.AccountType.ACCOUNT_TYPE_BANK_CARD:
        return 'bank_card';
      case pb_enum.AccountType.ACCOUNT_TYPE_CREDIT_CARD:
        return 'credit_card';
      case pb_enum.AccountType.ACCOUNT_TYPE_ALIPAY:
        return 'alipay';
      case pb_enum.AccountType.ACCOUNT_TYPE_WECHAT_PAY:
        return 'wechat_pay';
      case pb_enum.AccountType.ACCOUNT_TYPE_INVESTMENT:
        return 'investment';
      default:
        return 'other';
    }
  }

  static const allTypes = [
    'cash',
    'bank_card',
    'credit_card',
    'alipay',
    'wechat_pay',
    'investment',
    'other',
  ];
}

class AccountState {
  final List<Account> accounts;
  final bool isLoading;
  final String? error;

  const AccountState({
    this.accounts = const [],
    this.isLoading = false,
    this.error,
  });

  AccountState copyWith({
    List<Account>? accounts,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      AccountState(
        accounts: accounts ?? this.accounts,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );

  int get totalBalance =>
      accounts.fold<int>(0, (sum, a) => sum + a.balance);
}

class AccountNotifier extends StateNotifier<AccountState> {
  final AppDatabase _db;
  final String _userId;
  final String? _familyId;
  final pb.AccountServiceClient? _accountClient;
  final _uuid = const Uuid();

  AccountNotifier(this._db, this._userId, this._familyId, this._accountClient)
      : super(const AccountState()) {
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      List<Account> accounts;
      if (_familyId != null && _familyId.isNotEmpty) {
        accounts = await _db.getAccountsByFamily(_familyId);
      } else {
        accounts = await _db.getActiveAccounts(_userId);
      }
      state = state.copyWith(accounts: accounts, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<void> createAccount({
    required String name,
    required String accountType,
    String? icon,
    int initialBalance = 0,
    String? familyId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final effectiveIcon = icon ?? AccountTypeHelper.defaultIcon(accountType);
      final effectiveFamilyId = familyId ?? _familyId ?? '';

      // Try gRPC
      if (_accountClient != null) {
        try {
          final resp = await _accountClient.createAccount(
            pb_model.CreateAccountRequest()
              ..name = name
              ..type = AccountTypeHelper.toProto(accountType)
              ..currency = 'CNY'
              ..icon = effectiveIcon
              ..initialBalance = Int64(initialBalance)
              ..familyId = effectiveFamilyId,
          );
          final acc = resp.account;
          await _db.insertAccount(AccountsCompanion.insert(
            id: acc.id,
            userId: _userId,
            name: acc.name,
            icon: Value(acc.icon),
            balance: Value(acc.balance.toInt()),
            familyId: Value(effectiveFamilyId),
            accountType: Value(accountType),
          ));
          await _load();
          return;
        } catch (e) {
          dev.log('AccountNotifier: gRPC createAccount failed, fallback: $e',
              name: 'account');
        }
      }

      // Local fallback
      final id = _uuid.v4();
      await _db.insertAccount(AccountsCompanion.insert(
        id: id,
        userId: _userId,
        name: name,
        icon: Value(effectiveIcon),
        balance: Value(initialBalance),
        familyId: Value(effectiveFamilyId),
        accountType: Value(accountType),
      ));
      await _load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '创建账户失败: $e');
    }
  }

  Future<void> updateAccount({
    required String accountId,
    String? name,
    String? icon,
    bool? isActive,
  }) async {
    try {
      if (_accountClient != null) {
        try {
          final req = pb_model.UpdateAccountRequest()..accountId = accountId;
          if (name != null) req.name = name;
          if (icon != null) req.icon = icon;
          if (isActive != null) req.isActive = isActive;
          await _accountClient.updateAccount(req);
        } catch (e) {
          dev.log('AccountNotifier: gRPC updateAccount failed: $e',
              name: 'account');
        }
      }

      final companion = AccountsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      );
      await _db.updateAccountFields(accountId, companion);
      await _load();
    } catch (e) {
      state = state.copyWith(error: '更新账户失败: $e');
    }
  }

  Future<void> deleteAccount(String accountId) async {
    try {
      if (_accountClient != null) {
        try {
          await _accountClient.deleteAccount(
            pb_model.DeleteAccountRequest()..accountId = accountId,
          );
        } catch (e) {
          dev.log('AccountNotifier: gRPC deleteAccount failed: $e',
              name: 'account');
        }
      }
      await _db.softDeleteAccount(accountId);
      await _load();
    } catch (e) {
      state = state.copyWith(error: '删除账户失败: $e');
    }
  }

  Future<void> transferBetween({
    required String fromAccountId,
    required String toAccountId,
    required int amount,
    String note = '',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Try gRPC
      if (_accountClient != null) {
        try {
          await _accountClient.transferBetween(
            pb_model.TransferBetweenRequest()
              ..fromAccountId = fromAccountId
              ..toAccountId = toAccountId
              ..amount = Int64(amount)
              ..note = note,
          );
        } catch (e) {
          dev.log('AccountNotifier: gRPC transfer failed: $e',
              name: 'account');
        }
      }

      // Local: update balances
      await _db.updateAccountBalance(fromAccountId, -amount);
      await _db.updateAccountBalance(toAccountId, amount);

      // Record transfer
      await _db.insertTransfer(TransfersCompanion.insert(
        id: _uuid.v4(),
        userId: _userId,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        note: Value(note),
      ));

      await _load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '转账失败: $e');
    }
  }
}

final accountProvider =
    StateNotifierProvider<AccountNotifier, AccountState>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider);
  pb.AccountServiceClient? accountClient;
  try {
    accountClient = ref.watch(accountClientProvider);
  } catch (_) {}
  return AccountNotifier(db, userId ?? '', familyId, accountClient);
});
