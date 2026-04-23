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
import 'package:familyledger/generated/proto/export.pbgrpc.dart';
import 'package:familyledger/generated/proto/import.pbgrpc.dart';
import 'package:familyledger/generated/proto/family.pbgrpc.dart';
import 'package:familyledger/generated/proto/notify.pbgrpc.dart';
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
      expect(resp.total, isNonZero);
      expect(resp.composition.length, greaterThanOrEqualTo(1));
    });

    // ════════════════════════════════════════════════════
    //  Account CRUD (continued)
    // ════════════════════════════════════════════════════
    late String account2Id;

    test('2.1 CreateAccount #2 (for transfer)', () async {
      final client = AccountServiceClient(channel);
      final resp = await client.createAccount(
        CreateAccountRequest()
          ..name = '测试现金'
          ..type = AccountType.ACCOUNT_TYPE_CASH
          ..initialBalance = Int64(10000000),
        options: authOpts,
      );
      expect(resp.account.id, isNotEmpty);
      account2Id = resp.account.id;
    });

    test('2.2 UpdateAccount', () async {
      final client = AccountServiceClient(channel);
      final resp = await client.updateAccount(
        UpdateAccountRequest()
          ..accountId = accountId
          ..name = '测试银行卡-已改名',
        options: authOpts,
      );
      expect(resp.account.name, equals('测试银行卡-已改名'));
    });

    test('2.3 TransferBetween', () async {
      final client = AccountServiceClient(channel);
      final resp = await client.transferBetween(
        TransferBetweenRequest()
          ..fromAccountId = accountId
          ..toAccountId = account2Id
          ..amount = Int64(5000000)
          ..note = '转账测试',
        options: authOpts,
      );
      expect(resp.transfer.id, isNotEmpty);
    });

    test('2.4 DeleteAccount #2', () async {
      final client = AccountServiceClient(channel);
      await client.deleteAccount(
        DeleteAccountRequest()..accountId = account2Id,
        options: authOpts,
      );
    });

    // ════════════════════════════════════════════════════
    //  Loan CRUD (continued)
    // ════════════════════════════════════════════════════
    test('3.1 UpdateLoan', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.updateLoan(
        UpdateLoanRequest()
          ..loanId = loanId
          ..name = 'E2E房贷-已改名'
          ..paymentDay = 20,
        options: authOpts,
      );
      expect(resp.name, equals('E2E房贷-已改名'));
    });

    test('3.2 SimulatePrepayment', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.simulatePrepayment(
        SimulatePrepaymentRequest()
          ..loanId = loanId
          ..prepaymentAmount = Int64(5000000)
          ..strategy = PrepaymentStrategy.PREPAYMENT_STRATEGY_REDUCE_MONTHS,
        options: authOpts,
      );
      expect(resp.interestSaved, greaterThan(Int64.ZERO));
    });

    test('3.3 RecordRateChange', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.recordRateChange(
        RecordRateChangeRequest()
          ..loanId = loanId
          ..newRate = 3.5
          ..effectiveDate = ts.Timestamp.fromDateTime(DateTime(2025, 1, 1)),
        options: authOpts,
      );
      expect(resp.annualRate, equals(3.5));
    });

    test('3.4 RecordPayment', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.recordPayment(
        RecordPaymentRequest()
          ..loanId = loanId
          ..monthNumber = 1,
        options: authOpts,
      );
      expect(resp.isPaid, isTrue);
    });

    // ════════════════════════════════════════════════════
    //  LoanGroup (组合贷款)
    // ════════════════════════════════════════════════════
    late String groupId;

    test('4.1 CreateLoanGroup', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.createLoanGroup(
        CreateLoanGroupRequest()
          ..name = 'E2E组合房贷'
          ..groupType = 'combined'
          ..paymentDay = 15
          ..startDate = ts.Timestamp.fromDateTime(DateTime(2024, 1, 1))
          ..loanType = LoanType.LOAN_TYPE_MORTGAGE
          ..subLoans.addAll([
            SubLoanSpec()
              ..name = '商贷'
              ..subType = LoanSubType.LOAN_SUB_TYPE_COMMERCIAL
              ..principal = Int64(150000000)
              ..annualRate = 4.2
              ..totalMonths = 360
              ..repaymentMethod = RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT,
            SubLoanSpec()
              ..name = '公积金'
              ..subType = LoanSubType.LOAN_SUB_TYPE_PROVIDENT
              ..principal = Int64(50000000)
              ..annualRate = 3.1
              ..totalMonths = 360
              ..repaymentMethod = RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT,
          ]),
        options: authOpts,
      );
      expect(resp.id, isNotEmpty);
      groupId = resp.id;
    });

    test('4.2 GetLoanGroup', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.getLoanGroup(
        GetLoanGroupRequest()..groupId = groupId,
        options: authOpts,
      );
      expect(resp.subLoans.length, equals(2));
    });

    test('4.3 ListLoanGroups', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.listLoanGroups(
        ListLoanGroupsRequest(),
        options: authOpts,
      );
      expect(resp.groups.length, greaterThanOrEqualTo(1));
    });

    test('4.4 SimulateGroupPrepayment', () async {
      final client = LoanServiceClient(channel);
      final resp = await client.simulateGroupPrepayment(
        SimulateGroupPrepaymentRequest()
          ..groupId = groupId
          ..prepaymentAmount = Int64(5000000)
          ..strategy = PrepaymentStrategy.PREPAYMENT_STRATEGY_REDUCE_MONTHS,
        options: authOpts,
      );
      expect(resp.totalInterestSaved, greaterThan(Int64.ZERO));
    });

    // ════════════════════════════════════════════════════
    //  Budget CRUD (continued)
    // ════════════════════════════════════════════════════
    late String budgetId;

    test('5.1 ListBudgets + capture budgetId', () async {
      final client = BudgetServiceClient(channel);
      final resp = await client.listBudgets(
        ListBudgetsRequest()..year = DateTime.now().year,
        options: authOpts,
      );
      expect(resp.budgets.length, greaterThanOrEqualTo(1));
      budgetId = resp.budgets.first.id;
    });

    test('5.2 GetBudget', () async {
      final client = BudgetServiceClient(channel);
      final resp = await client.getBudget(
        GetBudgetRequest()..budgetId = budgetId,
        options: authOpts,
      );
      expect(resp.budget.totalAmount, equals(Int64(800000)));
    });

    test('5.3 UpdateBudget', () async {
      final client = BudgetServiceClient(channel);
      final resp = await client.updateBudget(
        UpdateBudgetRequest()
          ..budgetId = budgetId
          ..totalAmount = Int64(1000000),
        options: authOpts,
      );
      expect(resp.budget.totalAmount, equals(Int64(1000000)));
    });

    test('5.4 GetBudgetExecution', () async {
      final client = BudgetServiceClient(channel);
      final resp = await client.getBudgetExecution(
        GetBudgetExecutionRequest()..budgetId = budgetId,
        options: authOpts,
      );
      expect(resp.execution, isNotNull);
    });

    test('5.5 DeleteBudget', () async {
      final client = BudgetServiceClient(channel);
      await client.deleteBudget(
        DeleteBudgetRequest()..budgetId = budgetId,
        options: authOpts,
      );
    });

    // ════════════════════════════════════════════════════
    //  Investment CRUD (continued)
    // ════════════════════════════════════════════════════
    test('6.1 GetInvestment', () async {
      final client = InvestmentServiceClient(channel);
      final resp = await client.getInvestment(
        GetInvestmentRequest()..investmentId = investmentId,
        options: authOpts,
      );
      expect(resp.symbol, equals('600519'));
    });

    test('6.2 ListInvestments', () async {
      final client = InvestmentServiceClient(channel);
      final resp = await client.listInvestments(
        ListInvestmentsRequest(),
        options: authOpts,
      );
      expect(resp.investments.length, greaterThanOrEqualTo(1));
    });

    test('6.3 UpdateInvestment', () async {
      final client = InvestmentServiceClient(channel);
      final resp = await client.updateInvestment(
        UpdateInvestmentRequest()
          ..investmentId = investmentId
          ..name = '贵州茅台-已改名',
        options: authOpts,
      );
      expect(resp.name, equals('贵州茅台-已改名'));
    });

    late String tradeId;

    test('6.4 RecordTrade BUY', () async {
      final client = InvestmentServiceClient(channel);
      final resp = await client.recordTrade(
        RecordTradeRequest()
          ..investmentId = investmentId
          ..tradeType = TradeType.TRADE_TYPE_BUY
          ..quantity = 100.0
          ..price = Int64(185000)
          ..fee = Int64(500)
          ..tradeDate = ts.Timestamp.fromDateTime(DateTime.now()),
        options: authOpts,
      );
      expect(resp.id, isNotEmpty);
      tradeId = resp.id;
    });

    test('6.5 RecordTrade SELL', () async {
      final client = InvestmentServiceClient(channel);
      final resp = await client.recordTrade(
        RecordTradeRequest()
          ..investmentId = investmentId
          ..tradeType = TradeType.TRADE_TYPE_SELL
          ..quantity = 50.0
          ..price = Int64(190000)
          ..fee = Int64(500)
          ..tradeDate = ts.Timestamp.fromDateTime(DateTime.now()),
        options: authOpts,
      );
      expect(resp.id, isNotEmpty);
    });

    test('6.6 ListTrades', () async {
      final client = InvestmentServiceClient(channel);
      final resp = await client.listTrades(
        ListTradesRequest()..investmentId = investmentId,
        options: authOpts,
      );
      expect(resp.trades.length, equals(2));
    });

    test('6.7 GetPortfolioSummary', () async {
      final client = InvestmentServiceClient(channel);
      final resp = await client.getPortfolioSummary(
        GetPortfolioSummaryRequest(),
        options: authOpts,
      );
      expect(resp.totalValue, greaterThan(Int64.ZERO));
    });

    // ════════════════════════════════════════════════════
    //  MarketData
    // ════════════════════════════════════════════════════
    test('7.1 GetQuote', () async {
      final client = MarketDataServiceClient(channel);
      final resp = await client.getQuote(
        GetQuoteRequest()
          ..symbol = '600519'
          ..marketType = MarketType.MARKET_TYPE_A_SHARE,
        options: authOpts,
      );
      expect(resp.currentPrice, greaterThan(Int64.ZERO));
    });

    test('7.2 BatchGetQuotes', () async {
      final client = MarketDataServiceClient(channel);
      final resp = await client.batchGetQuotes(
        BatchGetQuotesRequest()..requests.addAll([
          GetQuoteRequest()
            ..symbol = '600519'
            ..marketType = MarketType.MARKET_TYPE_A_SHARE,
          GetQuoteRequest()
            ..symbol = 'BTC'
            ..marketType = MarketType.MARKET_TYPE_CRYPTO,
        ]),
        options: authOpts,
      );
      expect(resp.quotes.length, greaterThanOrEqualTo(2));
    });

    test('7.3 SearchSymbol', () async {
      final client = MarketDataServiceClient(channel);
      final resp = await client.searchSymbol(
        SearchSymbolRequest()..query = '茅台',
        options: authOpts,
      );
      expect(resp.symbols.length, greaterThanOrEqualTo(1));
    });

    test('7.4 GetPriceHistory', () async {
      final client = MarketDataServiceClient(channel);
      final resp = await client.getPriceHistory(
        GetPriceHistoryRequest()
          ..symbol = '600519'
          ..marketType = MarketType.MARKET_TYPE_A_SHARE,
        options: authOpts,
      );
      // Response received (may have empty prices if mock)
      expect(resp, isNotNull);
    });

    // ════════════════════════════════════════════════════
    //  Asset CRUD (continued)
    // ════════════════════════════════════════════════════
    test('8.1 GetAsset', () async {
      final client = AssetServiceClient(channel);
      final resp = await client.getAsset(
        GetAssetRequest()..assetId = assetId,
        options: authOpts,
      );
      expect(resp.name, equals('E2E测试房产'));
    });

    test('8.2 ListAssets', () async {
      final client = AssetServiceClient(channel);
      final resp = await client.listAssets(
        ListAssetsRequest(),
        options: authOpts,
      );
      expect(resp.assets.length, greaterThanOrEqualTo(1));
    });

    test('8.3 UpdateAsset', () async {
      final client = AssetServiceClient(channel);
      final resp = await client.updateAsset(
        UpdateAssetRequest()
          ..assetId = assetId
          ..name = 'E2E房产-已改名',
        options: authOpts,
      );
      expect(resp.name, equals('E2E房产-已改名'));
    });

    test('8.4 UpdateValuation', () async {
      final client = AssetServiceClient(channel);
      final resp = await client.updateValuation(
        UpdateValuationRequest()
          ..assetId = assetId
          ..value = Int64(550000000)
          ..source = 'manual',
        options: authOpts,
      );
      expect(resp.value, equals(Int64(550000000)));
    });

    test('8.5 ListValuations', () async {
      final client = AssetServiceClient(channel);
      final resp = await client.listValuations(
        ListValuationsRequest()..assetId = assetId,
        options: authOpts,
      );
      expect(resp.valuations.length, greaterThanOrEqualTo(1));
    });

    late String asset2Id;

    test('8.6 CreateAsset #2 (车辆) + SetDepreciationRule', () async {
      final client = AssetServiceClient(channel);
      final resp = await client.createAsset(
        CreateAssetRequest()
          ..name = 'E2E测试车辆'
          ..assetType = AssetType.ASSET_TYPE_VEHICLE
          ..purchasePrice = Int64(30000000)
          ..purchaseDate = ts.Timestamp.fromDateTime(DateTime(2023, 1, 1)),
        options: authOpts,
      );
      asset2Id = resp.id;
      // Set depreciation rule
      final rule = await client.setDepreciationRule(
        SetDepreciationRuleRequest()
          ..assetId = asset2Id
          ..method = DepreciationMethod.DEPRECIATION_METHOD_STRAIGHT_LINE
          ..usefulLifeYears = 5
          ..salvageRate = 0.05,
        options: authOpts,
      );
      expect(rule.method, equals(DepreciationMethod.DEPRECIATION_METHOD_STRAIGHT_LINE));
    });

    // ════════════════════════════════════════════════════
    //  Dashboard (continued)
    // ════════════════════════════════════════════════════
    test('9.1 GetIncomeExpenseTrend', () async {
      final client = DashboardServiceClient(channel);
      final resp = await client.getIncomeExpenseTrend(
        TrendRequest()..count = 6,
        options: authOpts,
      );
      expect(resp.points.length, greaterThanOrEqualTo(1));
    });

    test('9.2 GetCategoryBreakdown', () async {
      final client = DashboardServiceClient(channel);
      final now = DateTime.now();
      final resp = await client.getCategoryBreakdown(
        CategoryBreakdownRequest()
          ..year = now.year
          ..month = now.month
          ..type = 'expense',
        options: authOpts,
      );
      expect(resp.total, greaterThan(Int64.ZERO));
    });

    test('9.3 GetBudgetSummary', () async {
      final client = DashboardServiceClient(channel);
      final now = DateTime.now();
      final resp = await client.getBudgetSummary(
        BudgetSummaryRequest()
          ..year = now.year
          ..month = now.month,
        options: authOpts,
      );
      expect(resp, isNotNull);
    });

    test('9.4 GetNetWorthTrend', () async {
      final client = DashboardServiceClient(channel);
      final resp = await client.getNetWorthTrend(
        TrendRequest()..count = 6,
        options: authOpts,
      );
      expect(resp.points.length, greaterThanOrEqualTo(1));
    });

    // ════════════════════════════════════════════════════
    //  Export
    // ════════════════════════════════════════════════════
    test('10.1 ExportTransactions (CSV)', () async {
      final client = ExportServiceClient(channel);
      final resp = await client.exportTransactions(
        ExportRequest()..format = 'csv',
        options: authOpts,
      );
      expect(resp.filename, isNotEmpty);
      expect(resp.contentType, contains('csv'));
    });

    // ════════════════════════════════════════════════════
    //  Import
    // ════════════════════════════════════════════════════
    test('11.1 ParseCSV + ConfirmImport', () async {
      final importClient = ImportServiceClient(channel);
      // Use ASCII-safe CSV to avoid UTF-8 encoding issues with codeUnits
      final csvData = 'date,amount,type,category,note\n2026-04-01,50.00,expense,food,lunch\n2026-04-02,100.00,expense,transport,metro';
      final parseResp = await importClient.parseCSV(
        ParseCSVRequest()..csvData = csvData.codeUnits,
        options: authOpts,
      );
      expect(parseResp.sessionId, isNotEmpty);
      expect(parseResp.totalRows, equals(2));

      // Confirm import
      final confirmResp = await importClient.confirmImport(
        ConfirmImportRequest()
          ..sessionId = parseResp.sessionId
          ..defaultAccountId = accountId
          ..userId = userId
          ..mappings.addAll([
            FieldMapping()..csvColumn = 'date'..targetField = 'date',
            FieldMapping()..csvColumn = 'amount'..targetField = 'amount',
            FieldMapping()..csvColumn = 'type'..targetField = 'type',
            FieldMapping()..csvColumn = 'category'..targetField = 'category',
            FieldMapping()..csvColumn = 'note'..targetField = 'note',
          ]),
        options: authOpts,
      );
      expect(confirmResp.importedCount, greaterThan(0));
    });

    // ════════════════════════════════════════════════════
    //  Family
    // ════════════════════════════════════════════════════
    late String familyId;

    test('12.1 CreateFamily', () async {
      final client = FamilyServiceClient(channel);
      final resp = await client.createFamily(
        CreateFamilyRequest()..name = 'E2E测试家庭',
        options: authOpts,
      );
      expect(resp.family.id, isNotEmpty);
      familyId = resp.family.id;
    });

    test('12.2 GetFamily', () async {
      final client = FamilyServiceClient(channel);
      final resp = await client.getFamily(
        GetFamilyRequest()..familyId = familyId,
        options: authOpts,
      );
      expect(resp.family.name, equals('E2E测试家庭'));
    });

    test('12.3 GenerateInviteCode', () async {
      final client = FamilyServiceClient(channel);
      final resp = await client.generateInviteCode(
        GenerateInviteCodeRequest()..familyId = familyId,
        options: authOpts,
      );
      expect(resp.inviteCode, isNotEmpty);
    });

    test('12.4 ListFamilyMembers', () async {
      final client = FamilyServiceClient(channel);
      final resp = await client.listFamilyMembers(
        ListFamilyMembersRequest()..familyId = familyId,
        options: authOpts,
      );
      expect(resp.members.length, greaterThanOrEqualTo(1));
    });

    test('12.5 SetMemberRole', () async {
      final client = FamilyServiceClient(channel);
      // The creator is owner; set role to ADMIN (the server may reject
      // changing the owner's role, so we tolerate FAILED_PRECONDITION)
      try {
        await client.setMemberRole(
          SetMemberRoleRequest()
            ..familyId = familyId
            ..userId = userId
            ..role = FamilyRole.FAMILY_ROLE_ADMIN,
          options: authOpts,
        );
      } on GrpcError catch (e) {
        // Owner cannot demote self is valid business logic
        expect(e.code, anyOf(StatusCode.failedPrecondition, StatusCode.permissionDenied));
      }
    });

    test('12.6 LeaveFamily (expect error: owner cannot leave)', () async {
      // Owner cannot leave — this is correct business logic
      final client = FamilyServiceClient(channel);
      try {
        await client.leaveFamily(
          LeaveFamilyRequest()..familyId = familyId,
          options: authOpts,
        );
        fail('Should have thrown FAILED_PRECONDITION');
      } on GrpcError catch (e) {
        expect(e.code, equals(StatusCode.failedPrecondition));
      }
    });

    // ════════════════════════════════════════════════════
    //  Notify
    // ════════════════════════════════════════════════════
    late String deviceId;

    test('13.1 RegisterDevice', () async {
      final client = NotifyServiceClient(channel);
      final resp = await client.registerDevice(
        RegisterDeviceRequest()
          ..deviceToken = 'e2e-test-token-$suffix'
          ..platform = 'ios'
          ..deviceName = 'E2E Test Device',
        options: authOpts,
      );
      expect(resp.deviceId, isNotEmpty);
      deviceId = resp.deviceId;
    });

    test('13.2 GetNotificationSettings', () async {
      final client = NotifyServiceClient(channel);
      final resp = await client.getNotificationSettings(
        GetNotificationSettingsRequest(),
        options: authOpts,
      );
      expect(resp.settings, isNotNull);
    });

    test('13.3 UpdateNotificationSettings', () async {
      final client = NotifyServiceClient(channel);
      await client.updateNotificationSettings(
        UpdateNotificationSettingsRequest()
          ..settings = (NotificationSettings()
            ..budgetAlert = true
            ..loanReminder = true
            ..dailySummary = false),
        options: authOpts,
      );
    });

    test('13.4 ListNotifications', () async {
      final client = NotifyServiceClient(channel);
      final resp = await client.listNotifications(
        ListNotificationsRequest()..pageSize = 10,
        options: authOpts,
      );
      expect(resp, isNotNull);
    });

    test('13.5 MarkAsRead', () async {
      final client = NotifyServiceClient(channel);
      // With no real notifications, just ensure the call doesn't throw
      await client.markAsRead(
        MarkAsReadRequest()..notificationIds.add('nonexistent-id'),
        options: authOpts,
      );
    });

    test('13.6 UnregisterDevice', () async {
      final client = NotifyServiceClient(channel);
      await client.unregisterDevice(
        UnregisterDeviceRequest()..deviceId = deviceId,
        options: authOpts,
      );
    });

    // ════════════════════════════════════════════════════
    //  Cleanup
    // ════════════════════════════════════════════════════
    test('99.1 DeleteLoan', () async {
      final client = LoanServiceClient(channel);
      await client.deleteLoan(
        DeleteLoanRequest()..loanId = loanId,
        options: authOpts,
      );
    });

    test('99.2 DeleteInvestment', () async {
      final client = InvestmentServiceClient(channel);
      await client.deleteInvestment(
        DeleteInvestmentRequest()..investmentId = investmentId,
        options: authOpts,
      );
    });

    test('99.3 DeleteAsset #1', () async {
      final client = AssetServiceClient(channel);
      await client.deleteAsset(
        DeleteAssetRequest()..assetId = assetId,
        options: authOpts,
      );
    });

    test('99.4 DeleteAsset #2', () async {
      final client = AssetServiceClient(channel);
      await client.deleteAsset(
        DeleteAssetRequest()..assetId = asset2Id,
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
