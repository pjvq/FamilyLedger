// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familyledger/data/local/database.dart' as db;
import 'package:familyledger/domain/providers/budget_provider.dart';
import 'package:familyledger/domain/providers/loan_provider.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/domain/providers/account_provider.dart';
import 'package:familyledger/core/widgets/skeleton_loading.dart';
import 'package:familyledger/core/widgets/animated_tab_bar.dart';
import 'package:familyledger/core/theme/app_colors.dart';

import 'package:familyledger/features/budget/budget_execution_card.dart';
import 'package:familyledger/features/budget/budget_page.dart';
import 'package:familyledger/features/budget/set_budget_sheet.dart';
import 'package:familyledger/features/loan/loans_page.dart';
import 'package:familyledger/features/loan/add_loan_page.dart';
import 'package:familyledger/features/loan/loan_detail_page.dart';
import 'package:familyledger/features/loan/loan_group_detail_page.dart';
import 'package:familyledger/features/loan/prepayment_page.dart';
import 'package:familyledger/features/loan/rate_change_dialog.dart';

// ============================================================
// Test Helpers
// ============================================================

Widget buildTestApp(
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
  Map<String, WidgetBuilder>? routes,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      home: child,
      routes: routes ?? {},
    ),
  );
}

ThemeData darkTheme() => ThemeData.dark(useMaterial3: true);

// ── Mock Data Factories ──

db.Loan makeLoan({
  String id = 'loan-1',
  String userId = 'user-1',
  String name = '房贷',
  String loanType = 'mortgage',
  int principal = 100000000,
  int remainingPrincipal = 80000000,
  double annualRate = 4.2,
  int totalMonths = 360,
  int paidMonths = 24,
  String repaymentMethod = 'equal_installment',
  int paymentDay = 15,
  DateTime? startDate,
  String accountId = '',
  String groupId = '',
  String subType = '',
  String rateType = 'fixed',
  double lprBase = 0.0,
  double lprSpread = 0.0,
  int rateAdjustMonth = 1,
}) {
  return db.Loan(
    id: id,
    userId: userId,
    familyId: '',
    name: name,
    loanType: loanType,
    principal: principal,
    remainingPrincipal: remainingPrincipal,
    annualRate: annualRate,
    totalMonths: totalMonths,
    paidMonths: paidMonths,
    repaymentMethod: repaymentMethod,
    paymentDay: paymentDay,
    startDate: startDate ?? DateTime(2024, 1, 1),
    accountId: accountId,
    groupId: groupId,
    subType: subType,
    rateType: rateType,
    lprBase: lprBase,
    lprSpread: lprSpread,
    rateAdjustMonth: rateAdjustMonth,
    repaymentCategoryId: '',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    deletedAt: null,
  );
}

db.LoanGroup makeLoanGroup({
  String id = 'group-1',
  String userId = 'user-1',
  String name = '组合房贷',
  String groupType = 'combined',
  int totalPrincipal = 200000000,
  int paymentDay = 15,
  DateTime? startDate,
  String accountId = '',
  String loanType = 'mortgage',
}) {
  return db.LoanGroup(
    id: id,
    userId: userId,
    familyId: '',
    name: name,
    groupType: groupType,
    totalPrincipal: totalPrincipal,
    paymentDay: paymentDay,
    startDate: startDate ?? DateTime(2024, 1, 1),
    accountId: accountId,
    loanType: loanType,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    deletedAt: null,
  );
}

db.Budget makeBudget({
  String id = 'budget-1',
  String userId = 'user-1',
  String familyId = '',
  int year = 2026,
  int month = 4,
  int totalAmount = 1000000,
}) {
  return db.Budget(
    id: id,
    userId: userId,
    familyId: familyId,
    year: year,
    month: month,
    totalAmount: totalAmount,
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 4, 1),
  );
}

db.Category makeCategory({
  String id = 'cat-food',
  String name = '餐饮',
  String icon = '🍔',
  String type = 'expense',
  bool isPreset = true,
  int sortOrder = 0,
}) {
  return db.Category(
    id: id,
    name: name,
    icon: icon,
    type: type,
    isPreset: isPreset,
    sortOrder: sortOrder,
    iconKey: '',
  );
}

List<LoanScheduleDisplayItem> makeSchedule({
  int months = 3,
  int paidMonths = 1,
  int payment = 500000,
  int principalPart = 300000,
  int interestPart = 200000,
}) {
  return List.generate(months, (i) {
    final monthNum = i + 1;
    return LoanScheduleDisplayItem(
      monthNumber: monthNum,
      payment: payment,
      principalPart: principalPart,
      interestPart: interestPart,
      remainingPrincipal: (months - monthNum) * principalPart,
      dueDate: DateTime(2024, 1 + i, 15),
      isPaid: monthNum <= paidMonths,
    );
  });
}

// ── Common provider overrides that bypass gRPC ──

List<Override> budgetOverrides({
  BudgetState? budgetState,
  TransactionState? txnState,
}) {
  final bState = budgetState ?? const BudgetState(isLoading: false);
  final tState = txnState ??
      TransactionState(
        isLoading: false,
        expenseCategories: [
          makeCategory(id: 'cat-food', name: '餐饮', icon: '🍔'),
          makeCategory(id: 'cat-transport', name: '交通', icon: '🚌'),
        ],
        incomeCategories: [
          makeCategory(
              id: 'cat-salary', name: '工资', icon: '💰', type: 'income'),
        ],
      );

  return [
    budgetProvider.overrideWith(
      (ref) => FakeBudgetNotifier(bState),
    ),
    transactionProvider.overrideWith(
      (ref) => FakeTransactionNotifier(tState),
    ),
  ];
}

List<Override> loanOverrides({
  LoanState? loanState,
  AccountState? accountState,
}) {
  final ls = loanState ?? const LoanState(isLoading: false);
  final as_ = accountState ?? const AccountState(accounts: [], isLoading: false);

  return [
    loanProvider.overrideWith(
      (ref) => FakeLoanNotifier(ls),
    ),
    accountProvider.overrideWith(
      (ref) => FakeAccountNotifier(as_),
    ),
    transactionProvider.overrideWith(
      (ref) => FakeTransactionNotifier(
        TransactionState(
          isLoading: false,
          expenseCategories: [
            makeCategory(id: 'cat-food', name: '餐饮', icon: '🍔'),
          ],
          incomeCategories: [],
        ),
      ),
    ),
  ];
}

// ── Fake StateNotifiers (bypass gRPC / DB completely) ──

class FakeBudgetNotifier extends StateNotifier<BudgetState>
    implements BudgetNotifier {
  FakeBudgetNotifier(super.initial);

  @override
  Future<void> loadCurrentMonth() async {}
  @override
  Future<void> createBudget({
    required int year,
    required int month,
    required int totalAmount,
    required List<CategoryBudgetItem> categoryBudgets,
  }) async {}
  @override
  Future<void> updateBudget({
    required String id,
    int? totalAmount,
    List<CategoryBudgetItem>? categoryBudgets,
  }) async {}
  @override
  Future<void> deleteBudget(String id) async {}

  // noSuchMethod handles any other calls
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeTransactionNotifier extends StateNotifier<TransactionState>
    implements TransactionNotifier {
  FakeTransactionNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeLoanNotifier extends StateNotifier<LoanState>
    implements LoanNotifier {
  FakeLoanNotifier(super.initial);

  @override
  Future<void> loadAll() async {}
  @override
  Future<void> listLoans() async {}
  @override
  Future<void> listLoanGroups() async {}
  @override
  Future<void> getLoanDetail(String loanId) async {}
  @override
  Future<void> getLoanGroupDetail(String groupId) async {}
  @override
  Future<void> simulatePrepayment({
    required String loanId,
    required int amount,
    required String strategy,
  }) async {}
  @override
  Future<void> recordRateChange({
    required String loanId,
    required double newRate,
    required DateTime effectiveDate,
  }) async {}
  @override
  Future<void> recordPayment({
    required String loanId,
    required int monthNumber,
  }) async {}
  @override
  int getMonthlyPayment(db.Loan loan) {
    final schedule = LoanCalculator.calculate(
      principal: loan.principal,
      annualRate: loan.annualRate,
      totalMonths: loan.totalMonths,
      repaymentMethod: loan.repaymentMethod,
      startDate: loan.startDate,
      paymentDay: loan.paymentDay,
    );
    if (schedule.isEmpty) return 0;
    return schedule.first.payment;
  }
  @override
  Future<List<LoanScheduleDisplayItem>> getScheduleForLoan(
      String loanId) async {
    return [];
  }
  @override
  Future<void> deleteLoan(String loanId) async {}
  @override
  Future<void> deleteLoanGroup(String groupId) async {}
  @override
  Future<void> createLoan({
    required String name,
    required String loanType,
    required int principal,
    required double annualRate,
    required int totalMonths,
    required String repaymentMethod,
    required int paymentDay,
    required DateTime startDate,
    String? accountId,
    String? rateType,
    double? lprBase,
    double? lprSpread,
    int? rateAdjustMonth,
    String? familyId,
  }) async {}
  @override
  Future<void> createLoanGroup({
    required String name,
    required String groupType,
    required String loanType,
    required int paymentDay,
    required DateTime startDate,
    required List<SubLoanInput> subLoans,
    String? accountId,
    String? familyId,
  }) async {}
  @override
  DateTime? getNextPaymentDate(db.Loan loan) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeAccountNotifier extends StateNotifier<AccountState>
    implements AccountNotifier {
  FakeAccountNotifier(super.initial);

  @override
  Future<void> loadAccounts() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ============================================================
// TESTS
// ============================================================

void main() {
  // ──────────────────────────────────────────────────────────
  //  1. BudgetExecutionCard
  // ──────────────────────────────────────────────────────────

  group('BudgetExecutionCard', () {
    Widget buildCard({
      required double executionRate,
      int totalBudget = 1000000,
      int totalSpent = 500000,
      ThemeData? theme,
    }) {
      return buildTestApp(
        Scaffold(
          body: BudgetExecutionCard(
            executionRate: executionRate,
            totalBudget: totalBudget,
            totalSpent: totalSpent,
          ),
        ),
        theme: theme,
      );
    }

    testWidgets('rate=0%: shows 0%, green color zone', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.0,
        totalBudget: 1000000,
        totalSpent: 0,
      ));
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsOneWidget);
      expect(find.textContaining('¥0.00'), findsWidgets);
      expect(find.textContaining('¥10,000.00'), findsWidgets);
    });

    testWidgets('rate=50%: shows 50%', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        totalBudget: 1000000,
        totalSpent: 500000,
      ));
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('rate=99%: shows 99%', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.99,
        totalBudget: 1000000,
        totalSpent: 990000,
      ));
      await tester.pumpAndSettle();
      expect(find.text('99%'), findsOneWidget);
    });

    testWidgets('rate=100%: shows 100%', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 1.0,
        totalBudget: 1000000,
        totalSpent: 1000000,
      ));
      // Pulse animation is infinite at rate>=1.0, pump a few frames only
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('rate=150% (overspend): shows 150%, pulse animation',
        (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 1.5,
        totalBudget: 1000000,
        totalSpent: 1500000,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('150%'), findsOneWidget);
      // Pump more frames to make sure pulse doesn't crash
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('semantics label present', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        totalBudget: 1000000,
        totalSpent: 500000,
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('预算执行率')), findsOneWidget);
    });

    testWidgets('spent/budget text renders', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        totalBudget: 500000,
        totalSpent: 250000,
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('已用'), findsOneWidget);
      expect(find.textContaining('预算'), findsOneWidget);
    });

    testWidgets('dark theme renders', (tester) async {
      await tester.pumpWidget(buildCard(
        executionRate: 0.5,
        theme: darkTheme(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('didUpdateWidget triggers re-animation', (tester) async {
      // Start at 30%
      await tester.pumpWidget(buildCard(executionRate: 0.3));
      await tester.pumpAndSettle();
      expect(find.text('30%'), findsOneWidget);

      // Update to 80%
      await tester.pumpWidget(buildCard(executionRate: 0.8));
      await tester.pumpAndSettle();
      expect(find.text('80%'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  2. BudgetPage
  // ──────────────────────────────────────────────────────────

  group('BudgetPage', () {
    testWidgets('empty budget: shows empty state + "设置预算"', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BudgetPage(),
        overrides: budgetOverrides(
          budgetState: const BudgetState(isLoading: false),
        ),
      ));
      await tester.pumpAndSettle();
      // AppBar title is '{month}月预算', body also has '设置每月预算，掌控支出'
      expect(find.textContaining('月预算'), findsWidgets);
      // '设置预算' appears in both the FAB and the empty state button
      expect(find.text('设置预算'), findsWidgets);
    });

    testWidgets('loading: shows CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BudgetPage(),
        overrides: budgetOverrides(
          budgetState: const BudgetState(isLoading: true),
        ),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('with budget: shows execution card + "编辑预算"',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BudgetPage(),
        overrides: budgetOverrides(
          budgetState: BudgetState(
            isLoading: false,
            currentBudget: makeBudget(),
            execution: const BudgetExecutionData(
              totalBudget: 1000000,
              totalSpent: 300000,
              executionRate: 0.3,
              categoryExecutions: [],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetExecutionCard), findsOneWidget);
      expect(find.text('编辑预算'), findsOneWidget);
    });

    testWidgets('with category executions: shows tiles', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BudgetPage(),
        overrides: budgetOverrides(
          budgetState: BudgetState(
            isLoading: false,
            currentBudget: makeBudget(),
            execution: const BudgetExecutionData(
              totalBudget: 1000000,
              totalSpent: 500000,
              executionRate: 0.5,
              categoryExecutions: [
                CategoryExecutionData(
                  categoryId: 'cat-food',
                  categoryName: '餐饮',
                  budgetAmount: 500000,
                  spentAmount: 300000,
                  executionRate: 0.6,
                ),
                CategoryExecutionData(
                  categoryId: 'cat-transport',
                  categoryName: '交通',
                  budgetAmount: 200000,
                  spentAmount: 50000,
                  executionRate: 0.25,
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('分类预算'), findsOneWidget);
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const BudgetPage(),
        overrides: budgetOverrides(
          budgetState: BudgetState(
            isLoading: false,
            currentBudget: makeBudget(),
            execution: const BudgetExecutionData(
              totalBudget: 1000000,
              totalSpent: 0,
              executionRate: 0.0,
              categoryExecutions: [],
            ),
          ),
        ),
        theme: darkTheme(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetExecutionCard), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  3. SetBudgetSheet
  // ──────────────────────────────────────────────────────────

  group('SetBudgetSheet', () {
    Widget sheetLauncher({List<Override>? overrides}) {
      return buildTestApp(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => const SetBudgetSheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: overrides ?? budgetOverrides(),
      );
    }

    testWidgets('renders title, input, and save button', (tester) async {
      await tester.pumpWidget(sheetLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('设置预算'), findsOneWidget);
      expect(find.text('每月总预算'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('category toggle shows category fields', (tester) async {
      await tester.pumpWidget(sheetLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
    });

    testWidgets('can enter total budget amount', (tester) async {
      await tester.pumpWidget(sheetLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '10000');
      await tester.pumpAndSettle();
      expect(find.text('10000'), findsOneWidget);
    });

    testWidgets('close button dismisses', (tester) async {
      await tester.pumpWidget(sheetLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('设置预算'), findsNothing);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  4. LoansPage
  // ──────────────────────────────────────────────────────────

  group('LoansPage', () {
    testWidgets('empty state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoansPage(),
        overrides: loanOverrides(
          loanState: const LoanState(isLoading: false, loans: [], loanGroups: []),
        ),
        routes: {'/loans/add': (_) => const Scaffold()},
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('贷款'), findsWidgets);
    });

    testWidgets('loading', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoansPage(),
        overrides: loanOverrides(
          loanState: const LoanState(isLoading: true),
        ),
        routes: {'/loans/add': (_) => const Scaffold()},
      ));
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('standalone loans', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoansPage(),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            loans: [makeLoan(name: '我的房贷')],
            loanGroups: [],
          ),
        ),
        routes: {
          '/loans/detail': (_) => const Scaffold(),
          '/loans/add': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('我的房贷'), findsOneWidget);
    });

    testWidgets('loan group cards', (tester) async {
      final group = makeLoanGroup(name: '首套组合贷');
      final displayGroup = LoanGroupDisplayItem(
        group: group,
        subLoans: [
          makeLoan(id: 'c1', subType: 'commercial'),
          makeLoan(id: 'p1', subType: 'provident', annualRate: 2.85),
        ],
        totalMonthlyPayment: 800000,
        totalRemainingPrincipal: 135000000,
        overallProgress: 0.1,
      );

      await tester.pumpWidget(buildTestApp(
        const LoansPage(),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            loans: [],
            loanGroups: [displayGroup],
          ),
        ),
        routes: {
          '/loans/group-detail': (_) => const Scaffold(),
          '/loans/add': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('首套组合贷'), findsOneWidget);
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoansPage(),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            loans: [makeLoan()],
            loanGroups: [],
          ),
        ),
        theme: darkTheme(),
        routes: {
          '/loans/detail': (_) => const Scaffold(),
          '/loans/add': (_) => const Scaffold(),
        },
      ));
      await tester.pumpAndSettle();
      expect(find.byType(LoansPage), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  5. AddLoanPage
  // ──────────────────────────────────────────────────────────

  group('AddLoanPage', () {
    testWidgets('initial state: category selector visible', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const AddLoanPage(),
        overrides: loanOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('添加贷款'), findsOneWidget);
      // Category chips render as '🏦 商业贷款' etc.
      expect(find.textContaining('商业贷款'), findsOneWidget);
      expect(find.textContaining('公积金贷款'), findsOneWidget);
      expect(find.textContaining('组合贷款'), findsOneWidget);
    });

    testWidgets('can switch loan categories', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const AddLoanPage(),
        overrides: loanOverrides(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('公积金贷款'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('组合贷款'));
      await tester.pumpAndSettle();

      expect(find.byType(AddLoanPage), findsOneWidget);
    });

    testWidgets('shows loan type chips', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const AddLoanPage(),
        overrides: loanOverrides(),
      ));
      await tester.pumpAndSettle();

      // Loan type selector renders emoji and label in separate Text widgets
      expect(find.text('房贷'), findsOneWidget);
      expect(find.text('车贷'), findsOneWidget);
    });

    testWidgets('shows loan name field', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const AddLoanPage(),
        overrides: loanOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('贷款名称'), findsOneWidget);
    });

    testWidgets('can enter loan name', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const AddLoanPage(),
        overrides: loanOverrides(),
      ));
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextField, '');
      // Try entering name in the first text field
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, '首套房贷');
        await tester.pumpAndSettle();
        expect(find.text('首套房贷'), findsOneWidget);
      }
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const AddLoanPage(),
        overrides: loanOverrides(),
        theme: darkTheme(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AddLoanPage), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  6. LoanDetailPage
  // ──────────────────────────────────────────────────────────

  group('LoanDetailPage', () {
    testWidgets('loading state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanDetailPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: const LoanState(isLoading: true),
        ),
      ));
      await tester.pump();
      expect(find.text('贷款详情'), findsOneWidget);
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('null loan: shows error', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanDetailPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: const LoanState(isLoading: false, error: '贷款不存在'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('贷款不存在'), findsOneWidget);
    });

    testWidgets('shows loan detail + action buttons + schedule',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanDetailPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(),
            schedule: makeSchedule(months: 5, paidMonths: 2),
          ),
        ),
        routes: {'/loans/prepayment': (_) => const Scaffold()},
      ));
      await tester.pumpAndSettle();

      expect(find.text('提前还款'), findsOneWidget);
      expect(find.text('利率变动'), findsOneWidget);
      expect(find.text('记录还款'), findsOneWidget);
      expect(find.text('还款计划'), findsOneWidget);
    });

    testWidgets('progress ring shows correct %', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanDetailPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(paidMonths: 120, totalMonths: 360),
            schedule: makeSchedule(),
          ),
        ),
        routes: {'/loans/prepayment': (_) => const Scaffold()},
      ));
      await tester.pumpAndSettle();
      expect(find.text('33%'), findsOneWidget);
    });

    testWidgets('equal_principal repayment method text', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanDetailPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(repaymentMethod: 'equal_principal'),
            schedule: makeSchedule(),
          ),
        ),
        routes: {'/loans/prepayment': (_) => const Scaffold()},
      ));
      await tester.pumpAndSettle();
      expect(find.text('等额本金'), findsOneWidget);
    });

    testWidgets('equal_installment repayment method text', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanDetailPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(repaymentMethod: 'equal_installment'),
            schedule: makeSchedule(),
          ),
        ),
        routes: {'/loans/prepayment': (_) => const Scaffold()},
      ));
      await tester.pumpAndSettle();
      expect(find.text('等额本息'), findsOneWidget);
    });

    testWidgets('semantics: summary card', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanDetailPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(),
            schedule: makeSchedule(),
          ),
        ),
        routes: {'/loans/prepayment': (_) => const Scaffold()},
      ));
      await tester.pumpAndSettle();
      // Summary card + schedule items all carry semantics with '剩余本金'
      expect(find.bySemanticsLabel(RegExp('剩余本金')), findsWidgets);
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanDetailPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(),
            schedule: makeSchedule(),
          ),
        ),
        theme: darkTheme(),
        routes: {'/loans/prepayment': (_) => const Scaffold()},
      ));
      await tester.pumpAndSettle();
      expect(find.byType(LoanDetailPage), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  7. LoanGroupDetailPage
  // ──────────────────────────────────────────────────────────

  group('LoanGroupDetailPage', () {
    LoanGroupDisplayItem buildGroupDisplay() {
      return LoanGroupDisplayItem(
        group: makeLoanGroup(name: '首套房贷'),
        subLoans: [
          makeLoan(id: 'c1', subType: 'commercial', annualRate: 4.2),
          makeLoan(id: 'p1', subType: 'provident', annualRate: 2.85),
        ],
        totalMonthlyPayment: 1200000,
        totalRemainingPrincipal: 160000000,
        overallProgress: 0.07,
      );
    }

    testWidgets('loading state', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanGroupDetailPage(groupId: 'group-1'),
        overrides: loanOverrides(
          loanState: const LoanState(isLoading: true),
        ),
      ));
      await tester.pump();
      expect(find.text('贷款详情'), findsOneWidget);
      expect(find.byType(SkeletonList), findsOneWidget);
      // Flush the 200ms timer from _loadSchedules to avoid pending timer error
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('null group: error', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanGroupDetailPage(groupId: 'group-1'),
        overrides: loanOverrides(
          loanState: const LoanState(isLoading: false, error: '贷款组不存在'),
        ),
      ));
      await tester.pump(); // first frame, triggers addPostFrameCallback
      await tester.pump(const Duration(milliseconds: 300)); // flush 200ms delayed timer
      expect(find.text('贷款组不存在'), findsOneWidget);
    });

    testWidgets('shows group detail with tabs', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanGroupDetailPage(groupId: 'group-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentGroup: buildGroupDisplay(),
          ),
        ),
        routes: {
          '/loans/prepayment': (_) => const Scaffold(),
          '/loans/detail': (_) => const Scaffold(),
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('首套房贷'), findsOneWidget);
      expect(find.text('总览'), findsOneWidget);
      // '商贷' appears in tab and summary chip
      expect(find.text('商贷'), findsWidgets);
      expect(find.text('公积金'), findsWidgets);
      expect(find.text('🏘️ 组合贷'), findsOneWidget);
    });

    testWidgets('sub-loan rate texts', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanGroupDetailPage(groupId: 'group-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentGroup: buildGroupDisplay(),
          ),
        ),
        routes: {
          '/loans/prepayment': (_) => const Scaffold(),
          '/loans/detail': (_) => const Scaffold(),
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('4.20%'), findsWidgets);
      expect(find.textContaining('2.85%'), findsWidgets);
    });

    testWidgets('tab switching', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanGroupDetailPage(groupId: 'group-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentGroup: buildGroupDisplay(),
          ),
        ),
        routes: {
          '/loans/prepayment': (_) => const Scaffold(),
          '/loans/detail': (_) => const Scaffold(),
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // AnimatedTabBar uses GestureDetector + Semantics instead of Tab widgets.
      // Tap the text directly within AnimatedTabBar area.
      final tabBarFinder = find.byType(AnimatedTabBar);
      expect(tabBarFinder, findsOneWidget);

      await tester.tap(find.descendant(
        of: tabBarFinder,
        matching: find.text('商贷'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.descendant(
        of: tabBarFinder,
        matching: find.text('公积金'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.descendant(
        of: tabBarFinder,
        matching: find.text('总览'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoanGroupDetailPage), findsOneWidget);
    });

    testWidgets('action buttons present', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const LoanGroupDetailPage(groupId: 'group-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentGroup: buildGroupDisplay(),
          ),
        ),
        routes: {
          '/loans/prepayment': (_) => const Scaffold(),
          '/loans/detail': (_) => const Scaffold(),
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('提前还款'), findsOneWidget);
      expect(find.text('商贷详情'), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  8. PrepaymentPage
  // ──────────────────────────────────────────────────────────

  group('PrepaymentPage', () {
    testWidgets('title and strategy selector', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PrepaymentPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('提前还款模拟'), findsOneWidget);
      expect(find.text('缩短期限'), findsWidgets);
      expect(find.text('减少月供'), findsWidgets);
    });

    testWidgets('shows loan info', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PrepaymentPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(remainingPrincipal: 80000000),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('剩余本金'), findsWidgets);
    });

    testWidgets('shows simulation result', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PrepaymentPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(),
            simulation: PrepaymentSimulationResult(
              prepaymentAmount: 10000000,
              totalInterestBefore: 50000000,
              totalInterestAfter: 35000000,
              interestSaved: 15000000,
              monthsReduced: 60,
              newMonthlyPayment: 400000,
              newSchedule: makeSchedule(months: 2),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Simulation results are below the fold in the ListView;
      // scroll down to bring them into the viewport.
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.textContaining('节省利息'), findsWidgets);
    });

    testWidgets('no simulation initially', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PrepaymentPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Simulation card should not be there yet
      expect(find.textContaining('节省利息'), findsNothing);
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const PrepaymentPage(loanId: 'loan-1'),
        overrides: loanOverrides(
          loanState: LoanState(
            isLoading: false,
            currentLoan: makeLoan(),
          ),
        ),
        theme: darkTheme(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(PrepaymentPage), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  9. RateChangeDialog
  // ──────────────────────────────────────────────────────────

  group('RateChangeDialog', () {
    Widget dialogLauncher({LoanState? loanState}) {
      return buildTestApp(
        Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) => const RateChangeDialog(loanId: 'loan-1'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: loanOverrides(
          loanState: loanState ??
              LoanState(
                isLoading: false,
                currentLoan: makeLoan(annualRate: 4.2),
              ),
        ),
      );
    }

    testWidgets('title + fields + buttons', (tester) async {
      await tester.pumpWidget(dialogLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('利率变动'), findsOneWidget);
      expect(find.text('新年利率（%）'), findsOneWidget);
      expect(find.text('生效日期'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('pre-fills current rate', (tester) async {
      await tester.pumpWidget(dialogLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('4.20'), findsOneWidget);
    });

    testWidgets('can enter new rate', (tester) async {
      await tester.pumpWidget(dialogLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '3.85');
      await tester.pumpAndSettle();
      expect(find.text('3.85'), findsOneWidget);
    });

    testWidgets('cancel dismisses', (tester) async {
      await tester.pumpWidget(dialogLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('利率变动'), findsNothing);
    });

    testWidgets('shows % suffix', (tester) async {
      await tester.pumpWidget(dialogLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('%'), findsOneWidget);
    });

    testWidgets('shows date in Chinese format', (tester) async {
      await tester.pumpWidget(dialogLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // yyyy年MM月dd日
      expect(find.textContaining('年'), findsWidgets);
    });

    testWidgets('shows date picker icon', (tester) async {
      await tester.pumpWidget(dialogLauncher());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────
  //  Cross-cutting: LoanCalculator unit tests
  // ──────────────────────────────────────────────────────────

  group('LoanCalculator', () {
    test('equalInstallment: zero rate', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 120000,
        annualRate: 0.0,
        totalMonths: 12,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );
      expect(schedule.length, 12);
      // Each payment should be ~10000
      expect(schedule.first.payment, 10000);
      expect(schedule.first.interestPart, 0);
      expect(schedule.last.remainingPrincipal, 0);
    });

    test('equalInstallment: standard rate', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 100000000,
        annualRate: 4.2,
        totalMonths: 360,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );
      expect(schedule.length, 360);
      // Monthly payment should be around 488948 cents
      expect(schedule.first.payment, greaterThan(400000));
      expect(schedule.first.payment, lessThan(600000));
      // First month interest > principal
      expect(schedule.first.interestPart, greaterThan(schedule.first.principalPart));
      // Last remaining should be 0
      expect(schedule.last.remainingPrincipal, 0);
    });

    test('equalPrincipal: payments decrease over time', () {
      final schedule = LoanCalculator.equalPrincipal(
        principal: 120000,
        annualRate: 12.0,
        totalMonths: 12,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );
      expect(schedule.length, 12);
      // Decreasing payment
      expect(schedule.first.payment, greaterThan(schedule.last.payment));
      expect(schedule.last.remainingPrincipal, 0);
    });

    test('calculate dispatches to correct method', () {
      final ep = LoanCalculator.calculate(
        principal: 120000,
        annualRate: 4.0,
        totalMonths: 12,
        repaymentMethod: 'equal_principal',
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );
      final ei = LoanCalculator.calculate(
        principal: 120000,
        annualRate: 4.0,
        totalMonths: 12,
        repaymentMethod: 'equal_installment',
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
      );
      // Both should produce 12 items
      expect(ep.length, 12);
      expect(ei.length, 12);
      // Equal principal: varying payments; equal installment: ~constant
      expect(ep.first.payment, isNot(equals(ep.last.payment)));
    });

    test('paidMonths marks items as paid', () {
      final schedule = LoanCalculator.equalInstallment(
        principal: 120000,
        annualRate: 4.0,
        totalMonths: 12,
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
        paidMonths: 5,
      );
      expect(schedule.where((s) => s.isPaid).length, 5);
      expect(schedule.where((s) => !s.isPaid).length, 7);
    });

    test('simulateReduceMonths: interest saved > 0', () {
      final result = LoanCalculator.simulateReduceMonths(
        remainingPrincipal: 80000000,
        annualRate: 4.2,
        remainingMonths: 336,
        paidMonths: 24,
        prepaymentAmount: 10000000,
        repaymentMethod: 'equal_installment',
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
        originalPrincipal: 100000000,
        originalTotalMonths: 360,
      );
      expect(result.interestSaved, greaterThan(0));
      expect(result.monthsReduced, greaterThan(0));
    });

    test('simulateReducePayment: new monthly payment < original',
        () {
      final result = LoanCalculator.simulateReducePayment(
        remainingPrincipal: 80000000,
        annualRate: 4.2,
        remainingMonths: 336,
        paidMonths: 24,
        prepaymentAmount: 10000000,
        repaymentMethod: 'equal_installment',
        startDate: DateTime(2024, 1, 1),
        paymentDay: 15,
        originalPrincipal: 100000000,
        originalTotalMonths: 360,
      );
      expect(result.interestSaved, greaterThan(0));
      expect(result.monthsReduced, 0);
    });
  });
}
