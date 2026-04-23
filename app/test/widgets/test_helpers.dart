/// Shared test utilities for FamilyLedger widget tests.
///
/// Provides fake StateNotifier implementations for all providers,
/// avoiding the need to construct real gRPC clients or databases.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Notifier, FamilyNotifier;
import 'package:familyledger/domain/providers/auth_provider.dart';
import 'package:familyledger/domain/providers/account_provider.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/domain/providers/family_provider.dart';
import 'package:familyledger/domain/providers/loan_provider.dart';
import 'package:familyledger/domain/providers/notification_provider.dart';
import 'package:familyledger/domain/providers/budget_provider.dart';
import 'package:familyledger/domain/providers/dashboard_provider.dart';
import 'package:familyledger/domain/providers/sync_status_provider.dart';
import 'package:familyledger/domain/providers/investment_provider.dart';
import 'package:familyledger/domain/providers/market_data_provider.dart';
import 'package:familyledger/domain/providers/asset_provider.dart';

// ─── Fake Notifiers ──────────────────────────────────────────

class FakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  FakeAuthNotifier([AuthState? s])
      : super(s ?? const AuthState(status: AuthStatus.unauthenticated));
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeAccountNotifier extends StateNotifier<AccountState>
    implements AccountNotifier {
  FakeAccountNotifier([AccountState? s]) : super(s ?? const AccountState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeTransactionNotifier extends StateNotifier<TransactionState>
    implements TransactionNotifier {
  FakeTransactionNotifier([TransactionState? s])
      : super(s ?? const TransactionState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeFamilyNotifier extends StateNotifier<FamilyState>
    implements FamilyNotifier {
  FakeFamilyNotifier([FamilyState? s]) : super(s ?? const FamilyState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeLoanNotifier extends StateNotifier<LoanState>
    implements LoanNotifier {
  FakeLoanNotifier([LoanState? s]) : super(s ?? const LoanState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeNotificationNotifier extends StateNotifier<NotificationState>
    implements NotificationNotifier {
  FakeNotificationNotifier([NotificationState? s])
      : super(s ?? const NotificationState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeBudgetNotifier extends StateNotifier<BudgetState>
    implements BudgetNotifier {
  FakeBudgetNotifier([BudgetState? s]) : super(s ?? const BudgetState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeDashboardNotifier extends StateNotifier<DashboardState>
    implements DashboardNotifier {
  FakeDashboardNotifier([DashboardState? s])
      : super(s ?? const DashboardState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncStatusNotifier {
  FakeSyncNotifier([SyncState? s])
      : super(s ?? const SyncState(status: SyncStatus.synced));
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeInvestmentNotifier extends StateNotifier<InvestmentState>
    implements InvestmentNotifier {
  FakeInvestmentNotifier([InvestmentState? s])
      : super(s ?? const InvestmentState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeMarketDataNotifier extends StateNotifier<MarketDataState>
    implements MarketDataNotifier {
  FakeMarketDataNotifier([MarketDataState? s])
      : super(s ?? const MarketDataState());

  @override
  Future<QuoteDisplay?> getQuote(String symbol, String marketType) async {
    final key = MarketDataState.quoteKey(symbol, marketType);
    return state.quotes[key];
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

class FakeAssetNotifier extends StateNotifier<AssetState>
    implements AssetNotifier {
  FakeAssetNotifier([AssetState? s]) : super(s ?? const AssetState());
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.isMethod ? Future<void>.value() : null;
}

// ─── Default overrides ──────────────────────────────────────

/// Returns a standard set of provider overrides for widget tests.
/// Optional parameters allow customizing individual states.
List<Override> testOverrides({
  AuthState? auth,
  AccountState? account,
  TransactionState? transaction,
  FamilyState? family,
  LoanState? loan,
  NotificationState? notification,
  BudgetState? budget,
  DashboardState? dashboard,
  SyncState? sync,
  InvestmentState? investment,
  MarketDataState? marketData,
  AssetState? asset,
}) {
  return [
    authProvider.overrideWith((_) => FakeAuthNotifier(auth)),
    accountProvider.overrideWith((_) => FakeAccountNotifier(account)),
    transactionProvider
        .overrideWith((_) => FakeTransactionNotifier(transaction)),
    familyProvider.overrideWith((_) => FakeFamilyNotifier(family)),
    loanProvider.overrideWith((_) => FakeLoanNotifier(loan)),
    notificationProvider
        .overrideWith((_) => FakeNotificationNotifier(notification)),
    budgetProvider.overrideWith((_) => FakeBudgetNotifier(budget)),
    dashboardProvider.overrideWith((_) => FakeDashboardNotifier(dashboard)),
    syncStatusProvider.overrideWith((_) => FakeSyncNotifier(sync)),
    investmentProvider
        .overrideWith((_) => FakeInvestmentNotifier(investment)),
    marketDataProvider
        .overrideWith((_) => FakeMarketDataNotifier(marketData)),
    assetProvider.overrideWith((_) => FakeAssetNotifier(asset)),
  ];
}

/// Wraps a widget in MaterialApp + ProviderScope with all faked providers.
Widget wrapWithProviders(
  Widget child, {
  List<Override> extra = const [],
  AuthState? auth,
  AccountState? account,
  TransactionState? transaction,
  FamilyState? family,
  LoanState? loan,
  NotificationState? notification,
  BudgetState? budget,
  DashboardState? dashboard,
  SyncState? sync,
  InvestmentState? investment,
  MarketDataState? marketData,
  AssetState? asset,
  ThemeData? theme,
  Map<String, WidgetBuilder>? routes,
}) {
  return ProviderScope(
    overrides: [
      ...testOverrides(
        auth: auth,
        account: account,
        transaction: transaction,
        family: family,
        loan: loan,
        notification: notification,
        budget: budget,
        dashboard: dashboard,
        sync: sync,
        investment: investment,
        marketData: marketData,
        asset: asset,
      ),
      ...extra,
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      routes: routes ?? {},
      home: child,
    ),
  );
}
