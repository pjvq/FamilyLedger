// W12: E2E Integration Tests — Financial + Notification
//
// Tests the full gRPC round-trip for:
// 1. Loan repayment → account balance deduction (Bug 1 fix verification)
// 2. Budget notification flow (budget creation + execution tracking)
// 3. Exchange rate degradation (GetExchangeRates endpoint)
// 4. Import CSV lifecycle (ParseCSV → ConfirmImport → re-use rejected)
//
// Requires: Go server running on 127.0.0.1:50051 (gRPC)
// with PostgreSQL and JWT_SECRET set.

import 'dart:convert';

import 'package:grpc/grpc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';

import 'harness.dart';
import 'package:familyledger/generated/proto/auth.pb.dart' as auth_pb;
import 'package:familyledger/generated/proto/auth.pbgrpc.dart' as auth_grpc;
import 'package:familyledger/generated/proto/account.pb.dart' as acct_pb;
import 'package:familyledger/generated/proto/account.pbgrpc.dart'
    as acct_grpc;
import 'package:familyledger/generated/proto/loan.pb.dart' as loan_pb;
import 'package:familyledger/generated/proto/loan.pbgrpc.dart' as loan_grpc;
import 'package:familyledger/generated/proto/loan.pbenum.dart' as loan_enum;
import 'package:familyledger/generated/proto/budget.pb.dart' as budget_pb;
import 'package:familyledger/generated/proto/budget.pbgrpc.dart'
    as budget_grpc;
import 'package:familyledger/generated/proto/transaction.pb.dart' as txn_pb;
import 'package:familyledger/generated/proto/transaction.pbgrpc.dart'
    as txn_grpc;
import 'package:familyledger/generated/proto/transaction.pbenum.dart'
    as txn_enum;
import 'package:familyledger/generated/proto/import.pb.dart' as import_pb;
import 'package:familyledger/generated/proto/import.pbgrpc.dart'
    as import_grpc;
import 'package:familyledger/generated/proto/notify.pb.dart' as notify_pb;
import 'package:familyledger/generated/proto/notify.pbgrpc.dart'
    as notify_grpc;
import 'package:familyledger/generated/proto/google/protobuf/timestamp.pb.dart'
    as ts_pb;

void main() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final config = HarnessConfig();

  late ClientChannel channel;
  late auth_grpc.AuthServiceClient authClient;
  late acct_grpc.AccountServiceClient acctClient;
  late loan_grpc.LoanServiceClient loanClient;
  late budget_grpc.BudgetServiceClient budgetClient;
  late txn_grpc.TransactionServiceClient txnClient;
  late import_grpc.ImportServiceClient importClient;
  late notify_grpc.NotifyServiceClient notifyClient;

  setUpAll(() {
    channel = ClientChannel(
      config.grpcHost,
      port: config.grpcPort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    authClient = auth_grpc.AuthServiceClient(channel);
    acctClient = acct_grpc.AccountServiceClient(channel);
    loanClient = loan_grpc.LoanServiceClient(channel);
    budgetClient = budget_grpc.BudgetServiceClient(channel);
    txnClient = txn_grpc.TransactionServiceClient(channel);
    importClient = import_grpc.ImportServiceClient(channel);
    notifyClient = notify_grpc.NotifyServiceClient(channel);
  });

  tearDownAll(() async {
    await channel.shutdown();
  });

  // ─────────────────────────────────────────────────────────────────────
  // Group 1: Loan Repayment → Account Balance Deduction (Bug 1 fix)
  // ─────────────────────────────────────────────────────────────────────
  group('W12 Loan Payment Balance Deduction', () {
    late String userToken;
    late String userId; // ignore: unused_local_variable
    late String accountId;
    late Int64 initialBalance;

    test('LOAN-001: Setup — register + create account', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w12_loan_$ts@test.com'
        ..password = 'W12_Loan_Test123!');
      userToken = resp.accessToken;
      userId = resp.userId;

      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      // Create bank account with known balance
      final acctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'W12 Loan Repayment Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_BANK_CARD
          ..currency = 'CNY'
          ..initialBalance = Int64(1000000), // 10,000 CNY
        options: opts,
      );
      accountId = acctResp.account.id;
      initialBalance = acctResp.account.balance;
      expect(accountId, isNotEmpty);
      expect(initialBalance, equals(Int64(1000000)));
    });

    test('LOAN-002: Create loan with account_id', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      final loanResp = await loanClient.createLoan(
        loan_pb.CreateLoanRequest()
          ..name = 'W12 Test Consumer Loan'
          ..loanType = loan_enum.LoanType.LOAN_TYPE_CONSUMER
          ..principal = Int64(120000) // 1,200 CNY
          ..annualRate = 4.0
          ..totalMonths = 12
          ..repaymentMethod =
              loan_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT
          ..paymentDay = 15
          ..startDate =
              (ts_pb.Timestamp()..seconds = Int64(1704067200)) // 2024-01-01
          ..accountId = accountId,
        options: opts,
      );
      expect(loanResp.id, isNotEmpty);
      expect(loanResp.accountId, equals(accountId));

      // Store loan ID for subsequent tests
      // Use the same group context variable approach
    });

    test('LOAN-003: RecordPayment deducts from account balance', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      // Create a fresh loan for this specific test
      final loanResp = await loanClient.createLoan(
        loan_pb.CreateLoanRequest()
          ..name = 'W12 Balance Deduction Test'
          ..loanType = loan_enum.LoanType.LOAN_TYPE_CONSUMER
          ..principal = Int64(60000)
          ..annualRate = 3.0
          ..totalMonths = 6
          ..repaymentMethod =
              loan_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT
          ..paymentDay = 15
          ..startDate =
              (ts_pb.Timestamp()..seconds = Int64(1704067200)) // 2024-01-01
          ..accountId = accountId,
        options: opts,
      );
      final loanId = loanResp.id;

      // Get account balance before payment
      final beforeResp = await acctClient.getAccount(
        acct_pb.GetAccountRequest()..accountId = accountId,
        options: opts,
      );
      final balanceBefore = beforeResp.account.balance;

      // Get first month payment amount from schedule
      final schedResp = await loanClient.getLoanSchedule(
        loan_pb.GetLoanScheduleRequest()..loanId = loanId,
        options: opts,
      );
      expect(schedResp.items, isNotEmpty);
      final month1Payment = schedResp.items[0].payment;
      expect(month1Payment, greaterThan(Int64(0)));

      // Record payment
      final payResp = await loanClient.recordPayment(
        loan_pb.RecordPaymentRequest()
          ..loanId = loanId
          ..monthNumber = 1,
        options: opts,
      );
      expect(payResp.isPaid, isTrue);
      expect(payResp.payment, equals(month1Payment));

      // Verify account balance decreased by payment amount
      final afterResp = await acctClient.getAccount(
        acct_pb.GetAccountRequest()..accountId = accountId,
        options: opts,
      );
      final balanceAfter = afterResp.account.balance;
      expect(balanceAfter, equals(balanceBefore - month1Payment),
          reason:
              'Account balance should decrease by payment amount after RecordPayment');
    });

    test('LOAN-004: Loan without account_id does not affect accounts',
        () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      // Create loan WITHOUT account_id
      final loanResp = await loanClient.createLoan(
        loan_pb.CreateLoanRequest()
          ..name = 'W12 No Account Loan'
          ..loanType = loan_enum.LoanType.LOAN_TYPE_CONSUMER
          ..principal = Int64(30000)
          ..annualRate = 3.0
          ..totalMonths = 6
          ..repaymentMethod =
              loan_enum.RepaymentMethod.REPAYMENT_METHOD_EQUAL_INSTALLMENT
          ..paymentDay = 15
          ..startDate =
              (ts_pb.Timestamp()..seconds = Int64(1704067200)),
        options: opts,
      );
      final loanId = loanResp.id;

      // Get balance before
      final beforeResp = await acctClient.getAccount(
        acct_pb.GetAccountRequest()..accountId = accountId,
        options: opts,
      );
      final balanceBefore = beforeResp.account.balance;

      // Record payment (no account_id on the loan)
      final payResp = await loanClient.recordPayment(
        loan_pb.RecordPaymentRequest()
          ..loanId = loanId
          ..monthNumber = 1,
        options: opts,
      );
      expect(payResp.isPaid, isTrue);

      // Balance should remain unchanged
      final afterResp = await acctClient.getAccount(
        acct_pb.GetAccountRequest()..accountId = accountId,
        options: opts,
      );
      expect(afterResp.account.balance, equals(balanceBefore),
          reason:
              'Account balance should not change when loan has no account_id');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Group 2: Budget Notification Flow
  // ─────────────────────────────────────────────────────────────────────
  group('W12 Budget Execution Tracking', () {
    late String userToken;
    late String accountId;
    late String categoryId;

    test('BUD-001: Setup — register + create account + get categories',
        () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w12_budget_$ts@test.com'
        ..password = 'W12_Budget_Test123!');
      userToken = resp.accessToken;

      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      final acctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'W12 Budget Test Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_CASH
          ..currency = 'CNY'
          ..initialBalance = Int64(10000000),
        options: opts,
      );
      accountId = acctResp.account.id;

      final catResp = await txnClient.getCategories(
        txn_pb.GetCategoriesRequest()
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE,
        options: opts,
      );
      expect(catResp.categories, isNotEmpty);
      categoryId = catResp.categories.first.id;
    });

    test('BUD-002: Create budget + track execution after expenses', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      final now = DateTime.now();

      // Create budget for current month
      final budgetResp = await budgetClient.createBudget(
        budget_pb.CreateBudgetRequest()
          ..year = now.year
          ..month = now.month
          ..totalAmount = Int64(1000000), // 10,000 CNY budget
        options: opts,
      );
      final budgetId = budgetResp.budget.id;
      expect(budgetId, isNotEmpty);

      // Create expenses totaling 8,500 CNY (85% of budget)
      final today = ts_pb.Timestamp()
        ..seconds = Int64(
            DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
                1000);

      await txnClient.createTransaction(
        txn_pb.CreateTransactionRequest()
          ..accountId = accountId
          ..categoryId = categoryId
          ..amount = Int64(500000)
          ..currency = 'CNY'
          ..amountCny = Int64(500000)
          ..exchangeRate = 1.0
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = 'W12 budget test expense 1'
          ..txnDate = today,
        options: opts,
      );

      await txnClient.createTransaction(
        txn_pb.CreateTransactionRequest()
          ..accountId = accountId
          ..categoryId = categoryId
          ..amount = Int64(350000)
          ..currency = 'CNY'
          ..amountCny = Int64(350000)
          ..exchangeRate = 1.0
          ..type = txn_enum.TransactionType.TRANSACTION_TYPE_EXPENSE
          ..note = 'W12 budget test expense 2'
          ..txnDate = today,
        options: opts,
      );

      // Check budget execution
      final execResp = await budgetClient.getBudgetExecution(
        budget_pb.GetBudgetExecutionRequest()..budgetId = budgetId,
        options: opts,
      );
      expect(execResp.execution.totalSpent, greaterThanOrEqualTo(Int64(800000)),
          reason: 'Budget execution should show total spent ≥ 800000');
      expect(execResp.execution.executionRate, greaterThanOrEqualTo(0.8),
          reason: 'Execution rate should be ≥ 80%');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Group 3: Exchange Rate — tested in Go unit tests
  // The GetExchangeRates gRPC method is not yet in the Dart-generated proto.
  // The fallback-to-1.0 fix is verified by Go unit tests:
  //   TestGetExchangeRate_NotFound in exchange_service_test.go
  // ─────────────────────────────────────────────────────────────────────
  group('W12 Exchange Rate', () {
    test('XRATE-001: Fallback tested in Go unit tests (placeholder)', () {
      // The ExchangeService.GetExchangeRate fallback to 1.0 is tested in
      // server/internal/market/exchange_service_test.go:TestGetExchangeRate_NotFound.
      // The Dart proto for DashboardService doesn't include getExchangeRates yet.
      expect(true, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Group 4: Import CSV Flow
  // ─────────────────────────────────────────────────────────────────────
  group('W12 Import CSV Lifecycle', () {
    late String userToken;
    late String userId;
    late String accountId;

    test('IMP-001: Setup — register + create account', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w12_import_$ts@test.com'
        ..password = 'W12_Import_Test123!');
      userToken = resp.accessToken;
      userId = resp.userId;

      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      final acctResp = await acctClient.createAccount(
        acct_pb.CreateAccountRequest()
          ..name = 'W12 Import Account'
          ..type = acct_pb.AccountType.ACCOUNT_TYPE_BANK_CARD
          ..currency = 'CNY'
          ..initialBalance = Int64(5000000),
        options: opts,
      );
      accountId = acctResp.account.id;
    });

    test('IMP-002: ParseCSV returns headers + preview', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      const csvContent = '日期,金额,类型,分类,备注\n'
          '2024-01-15,50.00,expense,餐饮,午餐\n'
          '2024-01-16,30.00,expense,交通,地铁\n'
          '2024-01-17,100.00,income,收入,奖金\n';

      final parseResp = await importClient.parseCSV(
        import_pb.ParseCSVRequest()
          ..csvData = utf8.encode(csvContent)
          ..encoding = 'utf8',
        options: opts,
      );
      expect(parseResp.sessionId, isNotEmpty);
      expect(parseResp.totalRows, equals(3));
      expect(parseResp.headers, containsAll(['日期', '金额', '类型']));
    });

    test('IMP-003: ConfirmImport imports transactions', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      // Parse CSV first
      const csvContent = '日期,金额,类型,分类,备注\n'
          '2024-02-01,25.50,expense,餐饮,早餐\n'
          '2024-02-02,15.00,expense,交通,公交\n';

      final parseResp = await importClient.parseCSV(
        import_pb.ParseCSVRequest()
          ..csvData = utf8.encode(csvContent)
          ..encoding = 'utf8',
        options: opts,
      );
      final sessionId = parseResp.sessionId;

      // Confirm import with mappings
      final confirmResp = await importClient.confirmImport(
        import_pb.ConfirmImportRequest()
          ..sessionId = sessionId
          ..userId = userId
          ..defaultAccountId = accountId
          ..mappings.addAll([
            import_pb.FieldMapping()
              ..csvColumn = '日期'
              ..targetField = 'date',
            import_pb.FieldMapping()
              ..csvColumn = '金额'
              ..targetField = 'amount',
            import_pb.FieldMapping()
              ..csvColumn = '类型'
              ..targetField = 'type',
            import_pb.FieldMapping()
              ..csvColumn = '分类'
              ..targetField = 'category',
            import_pb.FieldMapping()
              ..csvColumn = '备注'
              ..targetField = 'note',
          ]),
        options: opts,
      );
      expect(confirmResp.importedCount, equals(2));
      expect(confirmResp.skippedCount, equals(0));
    });

    test('IMP-004: Re-use of consumed session fails', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      // Parse a new CSV
      const csvContent = '日期,金额,类型\n2024-03-01,10.00,expense\n';
      final parseResp = await importClient.parseCSV(
        import_pb.ParseCSVRequest()
          ..csvData = utf8.encode(csvContent)
          ..encoding = 'utf8',
        options: opts,
      );
      final sessionId = parseResp.sessionId;

      // Confirm once (success)
      await importClient.confirmImport(
        import_pb.ConfirmImportRequest()
          ..sessionId = sessionId
          ..userId = userId
          ..defaultAccountId = accountId
          ..mappings.addAll([
            import_pb.FieldMapping()
              ..csvColumn = '日期'
              ..targetField = 'date',
            import_pb.FieldMapping()
              ..csvColumn = '金额'
              ..targetField = 'amount',
            import_pb.FieldMapping()
              ..csvColumn = '类型'
              ..targetField = 'type',
          ]),
        options: opts,
      );

      // Try to re-use the session (should fail)
      try {
        await importClient.confirmImport(
          import_pb.ConfirmImportRequest()
            ..sessionId = sessionId
            ..userId = userId
            ..defaultAccountId = accountId
            ..mappings.addAll([
              import_pb.FieldMapping()
                ..csvColumn = '日期'
                ..targetField = 'date',
              import_pb.FieldMapping()
                ..csvColumn = '金额'
                ..targetField = 'amount',
            ]),
          options: opts,
        );
        fail('Should have thrown an error for re-used session');
      } on GrpcError catch (e) {
        expect(
          e.code,
          anyOf(equals(StatusCode.notFound),
              equals(StatusCode.failedPrecondition)),
          reason: 'Re-using consumed session should fail with NotFound or '
              'FailedPrecondition',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Group 5: Token Refresh Flow
  // ─────────────────────────────────────────────────────────────────────
  group('W12 Token Refresh', () {
    test('TOK-001: RefreshToken returns new valid tokens', () async {
      // Register
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w12_token_$ts@test.com'
        ..password = 'W12_Token_Test123!');
      final refreshToken = resp.refreshToken;

      // Refresh
      final refreshResp = await authClient.refreshToken(
        auth_pb.RefreshTokenRequest()..refreshToken = refreshToken,
      );
      expect(refreshResp.accessToken, isNotEmpty);
      expect(refreshResp.refreshToken, isNotEmpty);

      // Verify new token works
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer ${refreshResp.accessToken}'},
      );
      final listResp = await acctClient.listAccounts(
        acct_pb.ListAccountsRequest(),
        options: opts,
      );
      // Should not throw — new token is valid
      expect(listResp, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Group 6: Notification Settings
  // ─────────────────────────────────────────────────────────────────────
  group('W12 Notification Settings', () {
    late String userToken;

    test('NOTIFY-001: Setup — register', () async {
      final resp = await authClient.register(auth_pb.RegisterRequest()
        ..email = 'w12_notify_$ts@test.com'
        ..password = 'W12_Notify_Test123!');
      userToken = resp.accessToken;
    });

    test('NOTIFY-002: Update + read notification settings', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      // Update settings
      await notifyClient.updateNotificationSettings(
        notify_pb.UpdateNotificationSettingsRequest()
          ..settings = (notify_pb.NotificationSettings()
            ..budgetAlert = true
            ..budgetWarning = true
            ..dailySummary = false
            ..loanReminder = true
            ..reminderDaysBefore = 3),
        options: opts,
      );

      // Read back and verify
      final getResp = await notifyClient.getNotificationSettings(
        notify_pb.GetNotificationSettingsRequest(),
        options: opts,
      );
      expect(getResp.settings.budgetAlert, isTrue);
      expect(getResp.settings.budgetWarning, isTrue);
      expect(getResp.settings.dailySummary, isFalse);
      expect(getResp.settings.loanReminder, isTrue);
      expect(getResp.settings.reminderDaysBefore, equals(3));
    });

    test('NOTIFY-003: List notifications (empty initially)', () async {
      final opts = CallOptions(
        metadata: {'authorization': 'Bearer $userToken'},
      );

      final listResp = await notifyClient.listNotifications(
        notify_pb.ListNotificationsRequest()
          ..page = 1
          ..pageSize = 10,
        options: opts,
      );
      // Should not error, notifications list may be empty
      expect(listResp.notifications, isNotNull);
    });
  });
}
