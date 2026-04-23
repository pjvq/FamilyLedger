// integration_test/e2e_grpc_test.dart
// ════════════════════════════════════════════════════════════
// FamilyLedger Phase 2 — End-to-End gRPC Integration Tests
// Connects to REAL backend (localhost:50051)
// ════════════════════════════════════════════════════════════
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grpc/grpc.dart';
import 'package:fixnum/fixnum.dart';

import 'package:familyledger/main.dart' show FamilyLedgerApp;
import 'package:familyledger/domain/providers/app_providers.dart';
import 'package:familyledger/data/remote/grpc_clients.dart';
import 'package:familyledger/generated/proto/auth.pbgrpc.dart';
import 'package:familyledger/generated/proto/account.pbgrpc.dart';
import 'package:familyledger/generated/proto/transaction.pbgrpc.dart';
import 'package:familyledger/generated/proto/loan.pbgrpc.dart';
import 'package:familyledger/generated/proto/budget.pbgrpc.dart';
import 'package:familyledger/generated/proto/investment.pbgrpc.dart';
import 'package:familyledger/generated/proto/asset.pbgrpc.dart';
import 'package:familyledger/generated/proto/dashboard.pbgrpc.dart';
import 'package:familyledger/generated/proto/google/protobuf/timestamp.pb.dart' as ts;

// ── Helpers ──────────────────────────────────────────────

/// Pump frames without tester.pumpAndSettle (avoids timer hangs)
Future<void> _pump(WidgetTester tester, {int frames = 30}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tap back button if present
Future<bool> _goBack(WidgetTester tester) async {
  for (final finder in [
    find.byTooltip('Back'),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.arrow_back_ios),
    find.byIcon(Icons.close),
    find.byIcon(Icons.close_rounded),
  ]) {
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await _pump(tester, frames: 15);
      return true;
    }
  }
  return false;
}

// ── Test Suite ───────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Unique test user per run
  final suffix = Random().nextInt(999999).toString().padLeft(6, '0');
  final testEmail = 'e2e-phase2-$suffix@test.com';
  const testPassword = 'TestPass123!';

  // Real gRPC channel to localhost
  late ClientChannel channel;

  setUpAll(() {
    channel = ClientChannel(
      'localhost',
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectionTimeout: Duration(seconds: 10),
      ),
    );
  });

  tearDownAll(() async {
    await channel.shutdown();
  });

  // ════════════════════════════════════════════════════════
  //  Group 1: Raw gRPC Service Tests (no Flutter UI)
  // ════════════════════════════════════════════════════════
  group('gRPC Services — direct calls', () {
    late String accessToken;
    late String userId;
    late CallOptions authOpts;

    test('1.1 Register', () async {
      final client = AuthServiceClient(channel);
      final resp = await client.register(RegisterRequest()
        ..email = testEmail
        ..password = testPassword);
      expect(resp.userId, isNotEmpty);
      expect(resp.accessToken, isNotEmpty);
      userId = resp.userId;
      accessToken = resp.accessToken;
      authOpts = CallOptions(metadata: {'authorization': 'Bearer $accessToken'});
    });

    test('1.2 Login', () async {
      final client = AuthServiceClient(channel);
      final resp = await client.login(LoginRequest()
        ..email = testEmail
        ..password = testPassword);
      expect(resp.accessToken, isNotEmpty);
      // Update token in case it changed
      accessToken = resp.accessToken;
      authOpts = CallOptions(metadata: {'authorization': 'Bearer $accessToken'});
    });

    late String accountId;
    late String expenseCategoryId;

    test('1.3 CreateAccount', () async {
      final client = AccountServiceClient(channel);
      final resp = await client.createAccount(
        CreateAccountRequest()
          ..name = '测试银行卡'
          ..type = AccountType.ACCOUNT_TYPE_BANK_CARD
          ..initialBalance = Int64(50000000), // ¥500,000.00
        options: authOpts,
      );
      expect(resp.account.id, isNotEmpty);
      accountId = resp.account.id;
    });

    test('1.3b GetCategories', () async {
      final client = TransactionServiceClient(channel);
      final resp = await client.getCategories(
        GetCategoriesRequest(),
        options: authOpts,
      );
      // Pick the first expense category
      final expenseCats = resp.categories.where((c) => c.type == TransactionType.TRANSACTION_TYPE_EXPENSE).toList();
      expect(expenseCats, isNotEmpty);
      expenseCategoryId = expenseCats.first.id;
    });

    test('1.4 ListAccounts', () async {
      final client = AccountServiceClient(channel);
      final resp = await client.listAccounts(
        ListAccountsRequest(),
        options: authOpts,
      );
      expect(resp.accounts.length, greaterThanOrEqualTo(1));
      expect(resp.accounts.any((a) => a.id == accountId), isTrue);
    });

    late String txnId;

    test('1.5 CreateTransaction (expense)', () async {
      final client = TransactionServiceClient(channel);
      final resp = await client.createTransaction(
        CreateTransactionRequest()
          ..accountId = accountId
          ..categoryId = expenseCategoryId
          ..amount = Int64(150000) // ¥1,500.00
          ..type = TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = '测试记账-午餐',
        options: authOpts,
      );
      expect(resp.transaction.id, isNotEmpty);
      txnId = resp.transaction.id;
    });

    test('1.6 ListTransactions', () async {
      final client = TransactionServiceClient(channel);
      final resp = await client.listTransactions(
        ListTransactionsRequest()..accountId = accountId,
        options: authOpts,
      );
      expect(resp.transactions.length, greaterThanOrEqualTo(1));
      expect(resp.transactions.any((t) => t.id == txnId), isTrue);
    });

    late String loanId;

    test('1.7 CreateLoan', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.createLoan(
        CreateLoanRequest()
          ..name = 'E2E测试房贷'
          ..loanType = LoanType.LOAN_TYPE_MORTGAGE
          ..principal = Int64(200000000) // ¥2,000,000
          ..annualRate = 3.85
          ..totalMonths = 360
          ..repaymentMethod = RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT
          ..paymentDay = 15
          ..startDate = ts.Timestamp.fromDateTime(DateTime(2024, 1, 1))
          ..accountId = accountId,
        options: authOpts,
      );
      expect(resp.id, isNotEmpty);
      loanId = resp.id;
    });

    test('1.8 GetLoanSchedule', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.getLoanSchedule(
        GetLoanScheduleRequest()..loanId = loanId,
        options: authOpts,
      );
      expect(resp.items.length, equals(360));
    });

    late String investmentId;

    test('1.9 CreateInvestment', () async {
      final client = InvestmentServiceClient(channel);
      final resp = await client.createInvestment(
        CreateInvestmentRequest()
          ..name = '贵州茅台'
          ..symbol = '600519'
          ..marketType = MarketType.MARKET_TYPE_A_SHARE,
        options: authOpts,
      );
      expect(resp.id, isNotEmpty);
      investmentId = resp.id;
    });

    late String assetId;

    test('1.10 CreateAsset', () async {
      final client = AssetServiceClient(channel);
      final resp = await client.createAsset(
        CreateAssetRequest()
          ..name = 'E2E测试房产'
          ..assetType = AssetType.ASSET_TYPE_REAL_ESTATE
          ..purchasePrice = Int64(500000000) // ¥5,000,000
          ..purchaseDate = ts.Timestamp.fromDateTime(DateTime(2020, 6, 1)),
        options: authOpts,
      );
      expect(resp.id, isNotEmpty);
      assetId = resp.id;
    });

    test('1.11 CreateBudget', () async {
      final client = BudgetServiceClient(channel);
      final now = DateTime.now();
      final resp = await client.createBudget(
        CreateBudgetRequest()
          ..year = now.year
          ..month = now.month
          ..totalAmount = Int64(800000), // ¥8,000
        options: authOpts,
      );
      expect(resp.budget.id, isNotEmpty);
    });

    test('1.12 GetNetWorth (Dashboard)', () async {
      final client = DashboardServiceClient(channel);
      final resp = await client.getNetWorth(
        GetNetWorthRequest(),
        options: authOpts,
      );
      // Should include our account balance + asset - loan
      expect(resp.total, isNonZero);
      expect(resp.composition.length, greaterThanOrEqualTo(1));
    });

    // Cleanup
    test('1.13 DeleteLoan', () async {
      final client = LoanServiceClient(channel);
      await client.deleteLoan(
        DeleteLoanRequest()..loanId = loanId,
        options: authOpts,
      );
    });

    test('1.14 DeleteInvestment', () async {
      final client = InvestmentServiceClient(channel);
      await client.deleteInvestment(
        DeleteInvestmentRequest()..investmentId = investmentId,
        options: authOpts,
      );
    });

    test('1.15 DeleteAsset', () async {
      final client = AssetServiceClient(channel);
      await client.deleteAsset(
        DeleteAssetRequest()..assetId = assetId,
        options: authOpts,
      );
    });
  });

  // ════════════════════════════════════════════════════════
  //  Group 2: Full UI E2E with real backend
  // ════════════════════════════════════════════════════════
  testWidgets('E2E UI — Register → Dashboard → Add Transaction', (tester) async {
    final uiEmail = 'e2e-ui-$suffix@test.com';

    // Start with empty prefs (not logged in)
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Real gRPC channel
    final uiChannel = ClientChannel(
      'localhost',
      port: 50051,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectionTimeout: Duration(seconds: 10),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          grpcChannelProvider.overrideWithValue(uiChannel),
        ],
        child: const FamilyLedgerApp(),
      ),
    );
    await _pump(tester);

    // ── Should land on Login page ──
    expect(find.text('登录'), findsWidgets);

    // ── Navigate to Register ──
    final registerLink = find.text('注册');
    if (registerLink.evaluate().isNotEmpty) {
      await tester.tap(registerLink.first);
      await _pump(tester);
    }

    // ── Fill registration form ──
    final textFields = find.byType(TextField);
    if (textFields.evaluate().length >= 2) {
      await tester.enterText(textFields.at(0), uiEmail);
      await tester.enterText(textFields.at(1), testPassword);
      // If there's a confirm password field
      if (textFields.evaluate().length >= 3) {
        await tester.enterText(textFields.at(2), testPassword);
      }
    }
    await _pump(tester, frames: 10);

    // ── Tap Register button ──
    final registerBtn = find.widgetWithText(ElevatedButton, '注册');
    if (registerBtn.evaluate().isNotEmpty) {
      await tester.tap(registerBtn.first);
      await _pump(tester, frames: 50); // Wait for gRPC round-trip
    }

    // ── Should navigate to Dashboard after successful registration ──
    // Give extra time for navigation + data loading
    await _pump(tester, frames: 100);

    // Verify we're on the main page (Dashboard) or still on auth
    final isDashboard = find.text('仪表盘').evaluate().isNotEmpty ||
        find.text('净资产').evaluate().isNotEmpty ||
        find.text('FamilyLedger').evaluate().isNotEmpty ||
        find.text('账户').evaluate().isNotEmpty;
    expect(isDashboard, isTrue, reason: 'Should be on Dashboard after registration');

    // ── Tap 记账 tab if available ──
    // The tab bar might say '记账' or we might need to look for FAB
    await _pump(tester, frames: 10);
    final addTxnTab = find.text('记账');
    if (addTxnTab.evaluate().isNotEmpty) {
      await tester.tap(addTxnTab.first);
      await _pump(tester, frames: 30);

      // Verify transaction page loaded
      final hasTxnPage = find.text('支出').evaluate().isNotEmpty ||
          find.text('收入').evaluate().isNotEmpty;
      expect(hasTxnPage, isTrue, reason: 'Transaction page should show 支出/收入 tabs');
    }

    // Cleanup
    await uiChannel.shutdown();
  });
}
