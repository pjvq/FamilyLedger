import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Notifier, FamilyNotifier;
import 'package:flutter_test/flutter_test.dart';

import 'package:familyledger/data/local/database.dart' as db;
import 'package:familyledger/domain/providers/loan_provider.dart';
import 'package:familyledger/features/loan/rate_change_dialog.dart';
import 'package:familyledger/features/loan/loans_page.dart';
import 'package:familyledger/features/loan/prepayment_page.dart';
import 'package:familyledger/features/loan/add_loan_page.dart';
import 'package:familyledger/features/loan/loan_detail_page.dart';
import 'package:familyledger/core/widgets/skeleton_loading.dart';
import 'package:familyledger/features/loan/loan_group_detail_page.dart';

import 'test_helpers.dart';

// ─── Enhanced FakeLoanNotifier ─────────────────────────────────
// The shared FakeLoanNotifier.noSuchMethod returns Future<void> for all
// method calls, but getMonthlyPayment() returns int and
// getNextPaymentDate() returns DateTime? — both synchronous.
// We override them here so _LoanCard / _LoanGroupCard / _SummaryCard render.

class _TestLoanNotifier extends FakeLoanNotifier {
  _TestLoanNotifier([super.s]);

  @override
  int getMonthlyPayment(db.Loan loan) => 469000;

  @override
  DateTime? getNextPaymentDate(db.Loan loan) =>
      DateTime(2025, 5, 15);

  @override
  Future<List<LoanScheduleDisplayItem>> getScheduleForLoan(
      String loanId) async {
    return [];
  }
}

// ─── Test Data ─────────────────────────────────────────────────

final _now = DateTime(2025, 4, 1);

db.Loan _makeLoan({
  String id = 'loan-1',
  String name = '测试房贷',
  String loanType = 'mortgage',
  int principal = 100000000, // 100万 (分)
  int remainingPrincipal = 80000000, // 80万
  double annualRate = 3.85,
  int totalMonths = 360,
  int paidMonths = 24,
  String repaymentMethod = 'equal_installment',
  int paymentDay = 15,
  String groupId = '',
  String subType = '',
  String rateType = 'fixed',
}) {
  return db.Loan(
    id: id,
    userId: 'user-1',
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
    startDate: _now,
    accountId: '',
    groupId: groupId,
    subType: subType,
    rateType: rateType,
    lprBase: 0.0,
    lprSpread: 0.0,
    rateAdjustMonth: 1,
    repaymentCategoryId: '',
    createdAt: _now,
    updatedAt: _now,
  );
}

db.LoanGroup _makeLoanGroup({
  String id = 'group-1',
  String name = '测试组合贷',
  String groupType = 'combined',
  int totalPrincipal = 200000000,
  String loanType = 'mortgage',
}) {
  return db.LoanGroup(
    id: id,
    userId: 'user-1',
    familyId: '',
    name: name,
    groupType: groupType,
    totalPrincipal: totalPrincipal,
    paymentDay: 15,
    startDate: _now,
    accountId: '',
    loanType: loanType,
    createdAt: _now,
    updatedAt: _now,
  );
}

LoanGroupDisplayItem _makeGroupDisplay({
  String id = 'group-1',
  String name = '测试组合贷',
}) {
  final comLoan = _makeLoan(
    id: 'com-1',
    name: '$name-商贷',
    groupId: id,
    subType: 'commercial',
    principal: 70000000,
    remainingPrincipal: 60000000,
  );
  final pvdLoan = _makeLoan(
    id: 'pvd-1',
    name: '$name-公积金',
    groupId: id,
    subType: 'provident',
    principal: 30000000,
    remainingPrincipal: 25000000,
    annualRate: 2.85,
  );
  return LoanGroupDisplayItem(
    group: _makeLoanGroup(id: id, name: name),
    subLoans: [comLoan, pvdLoan],
    totalMonthlyPayment: 500000,
    totalRemainingPrincipal: 85000000,
    overallProgress: 0.07,
  );
}

List<LoanScheduleDisplayItem> _makeSchedule({int count = 3}) {
  return List.generate(count, (i) {
    return LoanScheduleDisplayItem(
      monthNumber: i + 1,
      payment: 469000,
      principalPart: 148000,
      interestPart: 321000,
      remainingPrincipal: 100000000 - (i + 1) * 148000,
      dueDate: DateTime(2025, 5 + i, 15),
      isPaid: i == 0,
    );
  });
}

// ─── Helper: wrapWithProviders using _TestLoanNotifier ─────────

/// Like the shared wrapWithProviders but injects [_TestLoanNotifier]
/// so that synchronous methods (getMonthlyPayment, getNextPaymentDate)
/// return proper types instead of Future<void>.
Widget _wrap(
  Widget child, {
  LoanState? loan,
  Map<String, WidgetBuilder>? routes,
}) {
  return wrapWithProviders(
    child,
    loan: loan,
    routes: routes,
    extra: [
      // Override loanProvider with our enhanced fake
      loanProvider
          .overrideWith((_) => _TestLoanNotifier(loan)),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════
void main() {
  // ─── 1. RateChangeDialog ───────────────────────────────────

  group('RateChangeDialog', () {
    testWidgets('renders form elements', (tester) async {
      final loan = _makeLoan();
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const RateChangeDialog(loanId: 'loan-1'),
            ),
            child: const Text('open'),
          );
        }),
        loan: LoanState(currentLoan: loan),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('利率变动'), findsOneWidget);
      expect(find.text('新年利率（%）'), findsOneWidget);
      expect(find.text('生效日期'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('pre-fills current rate', (tester) async {
      final loan = _makeLoan(annualRate: 4.20);
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const RateChangeDialog(loanId: 'loan-1'),
            ),
            child: const Text('open'),
          );
        }),
        loan: LoanState(currentLoan: loan),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '4.20');
    });

    testWidgets('cancel dismisses dialog', (tester) async {
      final loan = _makeLoan();
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const RateChangeDialog(loanId: 'loan-1'),
            ),
            child: const Text('open'),
          );
        }),
        loan: LoanState(currentLoan: loan),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('利率变动'), findsNothing);
    });
  });

  // ─── 2. LoansPage ──────────────────────────────────────────

  group('LoansPage', () {
    testWidgets('shows empty state when no loans', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoansPage(),
        loan: const LoanState(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('贷款管理'), findsOneWidget);
      expect(find.text('暂无贷款记录'), findsOneWidget);
      expect(find.text('支持商业贷款、公积金贷款、组合贷款'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
    });

    testWidgets('shows loading indicator', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoansPage(),
        loan: const LoanState(isLoading: true),
      ));
      await tester.pump();

      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('shows FAB for adding loan', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoansPage(),
        loan: const LoanState(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('添加贷款'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('renders standalone loan cards', (tester) async {
      final loan = _makeLoan();
      await tester.pumpWidget(_wrap(
        const LoansPage(),
        loan: LoanState(loans: [loan]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('测试房贷'), findsOneWidget);
      expect(find.text('剩余本金'), findsOneWidget);
    });

    testWidgets('renders loan group cards', (tester) async {
      final group = _makeGroupDisplay();
      await tester.pumpWidget(_wrap(
        const LoansPage(),
        loan: LoanState(loanGroups: [group]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('测试组合贷'), findsOneWidget);
    });
  });

  group('getLoanTypeInfo', () {
    test('mortgage returns 房贷', () {
      final info = getLoanTypeInfo('mortgage');
      expect(info.label, '房贷');
      expect(info.emoji, '🏠');
    });

    test('car_loan returns 车贷', () {
      final info = getLoanTypeInfo('car_loan');
      expect(info.label, '车贷');
      expect(info.emoji, '🚗');
    });

    test('credit_card returns 信用卡', () {
      final info = getLoanTypeInfo('credit_card');
      expect(info.label, '信用卡');
      expect(info.emoji, '💳');
    });

    test('consumer returns 消费贷', () {
      final info = getLoanTypeInfo('consumer');
      expect(info.label, '消费贷');
      expect(info.emoji, '💰');
    });

    test('business returns 经营贷', () {
      final info = getLoanTypeInfo('business');
      expect(info.label, '经营贷');
      expect(info.emoji, '🏢');
    });

    test('unknown returns 其他', () {
      final info = getLoanTypeInfo('xyz');
      expect(info.label, '其他');
      expect(info.emoji, '📋');
    });
  });

  // ─── 3. PrepaymentPage ─────────────────────────────────────

  group('PrepaymentPage', () {
    testWidgets('renders with mock loan', (tester) async {
      final loan = _makeLoan();
      await tester.pumpWidget(_wrap(
        const PrepaymentPage(loanId: 'loan-1'),
        loan: LoanState(currentLoan: loan),
      ));
      await tester.pumpAndSettle();

      expect(find.text('提前还款模拟'), findsOneWidget);
      expect(find.text('提前还款金额（元）'), findsOneWidget);
      expect(find.text('还款策略'), findsOneWidget);
      expect(find.text('缩短期限'), findsOneWidget);
      expect(find.text('减少月供'), findsOneWidget);
      expect(find.text('开始模拟'), findsOneWidget);
    });

    testWidgets('shows remaining principal hint', (tester) async {
      final loan = _makeLoan(remainingPrincipal: 80000000);
      await tester.pumpWidget(_wrap(
        const PrepaymentPage(loanId: 'loan-1'),
        loan: LoanState(currentLoan: loan),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('剩余本金'), findsOneWidget);
    });

    testWidgets('simulate button disabled when no amount', (tester) async {
      final loan = _makeLoan();
      await tester.pumpWidget(_wrap(
        const PrepaymentPage(loanId: 'loan-1'),
        loan: LoanState(currentLoan: loan),
      ));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '开始模拟'),
      );
      expect(button.onPressed, isNull);
    });
  });

  // ─── 4. AddLoanPage ────────────────────────────────────────

  group('AddLoanPage', () {
    testWidgets('renders basic form elements', (tester) async {
      await tester.pumpWidget(_wrap(
        const AddLoanPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('添加贷款'), findsOneWidget);
      expect(find.text('贷款类别'), findsOneWidget);
      expect(find.text('贷款名称'), findsOneWidget);
      expect(find.text('贷款类型'), findsOneWidget);
    });

    testWidgets('shows three category chips', (tester) async {
      await tester.pumpWidget(_wrap(
        const AddLoanPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('商业贷款'), findsOneWidget);
      expect(find.textContaining('公积金贷款'), findsOneWidget);
      expect(find.textContaining('组合贷款'), findsOneWidget);
    });

    testWidgets('shows loan type selector emojis', (tester) async {
      await tester.pumpWidget(_wrap(
        const AddLoanPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('🏠'), findsAtLeast(1));
      expect(find.text('🚗'), findsOneWidget);
      expect(find.text('📋'), findsOneWidget);
    });

    testWidgets('shows commercial form by default', (tester) async {
      await tester.pumpWidget(_wrap(
        const AddLoanPage(),
      ));
      await tester.pumpAndSettle();

      // Scroll down to reveal the form section below the fold
      await tester.scrollUntilVisible(
        find.text('💰 商业贷款信息'), 200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('💰 商业贷款信息'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('利率类型'), 200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('利率类型'), findsOneWidget);
      expect(find.text('贷款期数'), findsOneWidget);
      expect(find.text('还款方式'), findsOneWidget);
    });

    testWidgets('switching to provident shows provident form', (tester) async {
      await tester.pumpWidget(_wrap(
        const AddLoanPage(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('公积金贷款'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('🏠 公积金贷款信息'), 200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('🏠 公积金贷款信息'), findsOneWidget);
    });

    testWidgets('switching to combined shows stepper', (tester) async {
      await tester.pumpWidget(_wrap(
        const AddLoanPage(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('组合贷款'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byType(Stepper), 200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(Stepper), findsOneWidget);
      expect(find.text('总贷款信息'), findsOneWidget);
      expect(find.text('公积金部分'), findsOneWidget);
      expect(find.text('商贷部分'), findsOneWidget);
    });

    testWidgets('create button shows correct text for combined',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AddLoanPage(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('组合贷款'));
      await tester.pumpAndSettle();

      // Drag the outer (vertical) ListView up to reveal the create button
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('创建组合贷款'), findsOneWidget);
    });
  });

  // ─── 5. LoanDetailPage ────────────────────────────────────

  group('LoanDetailPage', () {
    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoanDetailPage(loanId: 'loan-1'),
        loan: const LoanState(isLoading: true),
      ));
      await tester.pump();

      expect(find.text('贷款详情'), findsOneWidget);
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('shows error when loan is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoanDetailPage(loanId: 'loan-1'),
        loan: const LoanState(error: '贷款不存在'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('贷款不存在'), findsOneWidget);
    });

    testWidgets('renders loan data when loaded', (tester) async {
      final loan = _makeLoan();
      final schedule = _makeSchedule();
      await tester.pumpWidget(_wrap(
        const LoanDetailPage(loanId: 'loan-1'),
        loan: LoanState(currentLoan: loan, schedule: schedule),
      ));
      await tester.pumpAndSettle();

      expect(find.text('测试房贷'), findsOneWidget);
      expect(find.text('剩余本金'), findsOneWidget);
      expect(find.text('月供'), findsOneWidget);
      expect(find.text('提前还款'), findsOneWidget);
      expect(find.text('利率变动'), findsOneWidget);
      expect(find.text('记录还款'), findsOneWidget);
      expect(find.text('还款计划'), findsOneWidget);
    });

    testWidgets('displays rate info', (tester) async {
      final loan = _makeLoan(annualRate: 3.85);
      final schedule = _makeSchedule();
      await tester.pumpWidget(_wrap(
        const LoanDetailPage(loanId: 'loan-1'),
        loan: LoanState(currentLoan: loan, schedule: schedule),
      ));
      await tester.pumpAndSettle();

      expect(find.text('3.85%'), findsOneWidget);
      expect(find.text(' 年利率'), findsOneWidget);
    });

    testWidgets('displays repayment method equal_principal', (tester) async {
      final loan = _makeLoan(repaymentMethod: 'equal_principal');
      final schedule = _makeSchedule();
      await tester.pumpWidget(_wrap(
        const LoanDetailPage(loanId: 'loan-1'),
        loan: LoanState(currentLoan: loan, schedule: schedule),
      ));
      await tester.pumpAndSettle();

      expect(find.text('等额本金'), findsOneWidget);
    });
  });

  // ─── 6. LoanGroupDetailPage ───────────────────────────────

  group('LoanGroupDetailPage', () {
    // _loadSchedules uses Future.delayed(200ms), so we must pump past it
    // to avoid "A Timer is still pending" assertion.

    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoanGroupDetailPage(groupId: 'group-1'),
        loan: const LoanState(isLoading: true),
      ));
      await tester.pump(); // first frame
      await tester.pump(const Duration(milliseconds: 300)); // past _loadSchedules delay

      expect(find.text('贷款详情'), findsOneWidget);
      expect(find.byType(SkeletonList), findsOneWidget);
    });

    testWidgets('shows error when group is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoanGroupDetailPage(groupId: 'group-1'),
        loan: const LoanState(error: '贷款组不存在'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('贷款组不存在'), findsOneWidget);
    });

    testWidgets('renders group data with tabs', (tester) async {
      final group = _makeGroupDisplay();
      await tester.pumpWidget(_wrap(
        const LoanGroupDetailPage(groupId: 'group-1'),
        loan: LoanState(currentGroup: group),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('测试组合贷'), findsOneWidget);
      expect(find.text('🏘️ 组合贷'), findsOneWidget);
      expect(find.text('总月供'), findsOneWidget);
      expect(find.text('剩余本金'), findsOneWidget);
      // Tab bar
      expect(find.text('总览'), findsOneWidget);
      expect(find.text('商贷'), findsAtLeast(1));
      expect(find.text('公积金'), findsAtLeast(1));
    });

    testWidgets('shows action buttons', (tester) async {
      final group = _makeGroupDisplay();
      await tester.pumpWidget(_wrap(
        const LoanGroupDetailPage(groupId: 'group-1'),
        loan: LoanState(currentGroup: group),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('提前还款'), findsOneWidget);
      expect(find.text('商贷详情'), findsOneWidget);
    });
  });

  // ─── Model / Helper tests ─────────────────────────────────

  group('LoanState', () {
    test('default state has empty fields', () {
      const state = LoanState();
      expect(state.loans, isEmpty);
      expect(state.loanGroups, isEmpty);
      expect(state.currentLoan, isNull);
      expect(state.currentGroup, isNull);
      expect(state.schedule, isEmpty);
      expect(state.simulation, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final loan = _makeLoan();
      final state = LoanState(currentLoan: loan, isLoading: true);
      final next = state.copyWith(isLoading: false);
      expect(next.currentLoan, loan);
      expect(next.isLoading, false);
    });

    test('copyWith clearCurrentLoan', () {
      final loan = _makeLoan();
      final state = LoanState(currentLoan: loan);
      final next = state.copyWith(clearCurrentLoan: true);
      expect(next.currentLoan, isNull);
    });
  });

  group('LoanGroupDisplayItem', () {
    test('commercialLoan returns correct sub-loan', () {
      final group = _makeGroupDisplay();
      expect(group.commercialLoan, isNotNull);
      expect(group.commercialLoan!.subType, 'commercial');
    });

    test('providentLoan returns correct sub-loan', () {
      final group = _makeGroupDisplay();
      expect(group.providentLoan, isNotNull);
      expect(group.providentLoan!.subType, 'provident');
    });

    test('returns null when sub-loan type is missing', () {
      final group = LoanGroupDisplayItem(
        group: _makeLoanGroup(),
        subLoans: [_makeLoan(subType: 'commercial')],
        totalMonthlyPayment: 500000,
        totalRemainingPrincipal: 60000000,
        overallProgress: 0.1,
      );
      expect(group.commercialLoan, isNotNull);
      expect(group.providentLoan, isNull);
    });
  });

  group('LoanScheduleDisplayItem', () {
    test('constructs with required fields', () {
      final item = LoanScheduleDisplayItem(
        monthNumber: 1,
        payment: 469000,
        principalPart: 148000,
        interestPart: 321000,
        remainingPrincipal: 99852000,
        dueDate: DateTime(2025, 5, 15),
        isPaid: true,
      );
      expect(item.monthNumber, 1);
      expect(item.isPaid, true);
      expect(item.paidDate, isNull);
    });
  });

  group('PrepaymentSimulationResult', () {
    test('constructs with all fields', () {
      final result = PrepaymentSimulationResult(
        prepaymentAmount: 10000000,
        totalInterestBefore: 50000000,
        totalInterestAfter: 40000000,
        interestSaved: 10000000,
        monthsReduced: 36,
        newMonthlyPayment: 400000,
        newSchedule: [],
      );
      expect(result.interestSaved, 10000000);
      expect(result.monthsReduced, 36);
      expect(result.newSchedule, isEmpty);
    });
  });
}
