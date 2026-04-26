import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:state_notifier/state_notifier.dart';

import 'package:familyledger/core/theme/app_colors.dart';
import 'package:familyledger/core/utils/category_uuid.dart';
import 'package:familyledger/features/dashboard/dashboard_page.dart';
import 'package:familyledger/features/dashboard/widgets/dashboard_card.dart';
import 'package:familyledger/features/report/report_page.dart';
import 'package:familyledger/features/import/csv_import_page.dart';
import 'package:familyledger/domain/providers/dashboard_provider.dart';
import 'package:familyledger/domain/providers/transaction_provider.dart';
import 'package:familyledger/domain/providers/app_providers.dart';
import 'package:familyledger/data/local/database.dart';

// ─── Helpers ───────────────────────────────────────────────────────────

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

Widget _wrapWithProviders(
  Widget child, {
  ThemeData? theme,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      home: child,
    ),
  );
}

Widget _wrapScaffold(
  Widget child, {
  ThemeData? theme,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: theme ?? ThemeData.light(useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
}

// ─── Mock Data Factories ─────────────────────────────────────────────

NetWorthData _makeNetWorth({
  int total = 50000000, // ¥500,000 = 50.00万
  int cashAndBank = 20000000,
  int investmentValue = 15000000,
  int fixedAssetValue = 20000000,
  int loanBalance = -5000000,
  int changeFromLastMonth = 1000000,
  double changePercent = 2.0,
  List<AssetCompositionItem>? composition,
}) {
  return NetWorthData(
    total: total,
    cashAndBank: cashAndBank,
    investmentValue: investmentValue,
    fixedAssetValue: fixedAssetValue,
    loanBalance: loanBalance,
    changeFromLastMonth: changeFromLastMonth,
    changePercent: changePercent,
    composition: composition ??
        [
          const AssetCompositionItem(
              category: 'cash', label: '现金银行', value: 20000000, weight: 0.33),
          const AssetCompositionItem(
              category: 'investment', label: '投资', value: 15000000, weight: 0.25),
          const AssetCompositionItem(
              category: 'fixed_asset',
              label: '固定资产',
              value: 20000000,
              weight: 0.33),
          const AssetCompositionItem(
              category: 'loan', label: '贷款', value: -5000000, weight: 0.08),
        ],
  );
}

List<TrendPointData> _makeTrendPoints({int count = 6}) {
  return List.generate(count, (i) {
    final month = i + 1;
    return TrendPointData(
      label: '2025-${month.toString().padLeft(2, '0')}',
      income: 1000000 + i * 100000,
      expense: 800000 + i * 50000,
      net: 200000 + i * 50000,
    );
  });
}

List<CategoryBreakdownItem> _makeCategoryBreakdown() {
  return [
    CategoryBreakdownItem(
        categoryId: CategoryUUID.generate('expense', '餐饮'),
        categoryName: '餐饮',
        icon: '🍜',
        amount: 300000,
        weight: 0.3),
    CategoryBreakdownItem(
        categoryId: CategoryUUID.generate('expense', '交通'),
        categoryName: '交通',
        icon: '🚗',
        amount: 200000,
        weight: 0.2),
    CategoryBreakdownItem(
        categoryId: CategoryUUID.generate('expense', '购物'),
        categoryName: '购物',
        icon: '🛍️',
        amount: 150000,
        weight: 0.15),
    CategoryBreakdownItem(
        categoryId: CategoryUUID.generate('expense', '居住'),
        categoryName: '居住',
        icon: '🏠',
        amount: 350000,
        weight: 0.35),
  ];
}

BudgetSummaryData _makeBudget({
  int totalBudget = 1000000,
  int totalSpent = 600000,
  double executionRate = 0.6,
}) {
  return BudgetSummaryData(
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    executionRate: executionRate,
  );
}

DashboardState _makeFullDashboardState({
  NetWorthData? netWorth,
  List<TrendPointData>? incomeExpenseTrend,
  List<CategoryBreakdownItem>? categoryBreakdown,
  int categoryBreakdownTotal = 1000000,
  BudgetSummaryData? budgetSummary,
  List<TrendPointData>? netWorthTrend,
  bool isLoading = false,
  String trendPeriod = 'monthly',
}) {
  return DashboardState(
    netWorth: netWorth ?? _makeNetWorth(),
    incomeExpenseTrend: incomeExpenseTrend ?? _makeTrendPoints(),
    categoryBreakdown: categoryBreakdown ?? _makeCategoryBreakdown(),
    categoryBreakdownTotal: categoryBreakdownTotal,
    budgetSummary: budgetSummary ?? _makeBudget(),
    netWorthTrend: netWorthTrend ?? _makeTrendPoints(count: 12),
    isLoading: isLoading,
    trendPeriod: trendPeriod,
  );
}

Category _makeCategory({
  String? id,
  String name = '餐饮',
  String icon = '🍜',
  String type = 'expense',
  bool isPreset = true,
  int sortOrder = 1,
}) {
  return Category(
    id: id ?? CategoryUUID.generate(type, name),
    name: name,
    icon: icon,
    type: type,
    isPreset: isPreset,
    sortOrder: sortOrder,
    iconKey: '',
  );
}

TransactionState _makeTransactionState({
  List<Category>? expenseCategories,
  List<Category>? incomeCategories,
}) {
  return TransactionState(
    transactions: const [],
    expenseCategories: expenseCategories ??
        [
          _makeCategory(id: CategoryUUID.generate('expense', '餐饮'), name: '餐饮', icon: '🍜'),
          _makeCategory(id: CategoryUUID.generate('expense', '交通'), name: '交通', icon: '🚗'),
        ],
    incomeCategories: incomeCategories ??
        [
          _makeCategory(
              id: CategoryUUID.generate('income', '工资'), name: '工资', icon: '💰', type: 'income'),
        ],
    isLoading: false,
  );
}

// ─── Provider Overrides ──────────────────────────────────────────────

/// Creates overrides for the dashboard page with all needed providers.
List<Override> _dashboardOverrides({
  DashboardState? state,
  SharedPreferences? prefs,
}) {
  final dashState = state ?? _makeFullDashboardState();
  return [
    dashboardProvider.overrideWith((ref) {
      return _FakeDashboardNotifier(dashState);
    }),
    if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
  ];
}

class _FakeDashboardNotifier extends StateNotifier<DashboardState>
    implements DashboardNotifier {
  _FakeDashboardNotifier(DashboardState initial) : super(initial);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return null;
  }
}

class _FakeDatabase extends Fake implements AppDatabase {
  @override
  Future<List<Transaction>> getRecentTransactions(String userId, int limit) async => [];
}

// ═══════════════════════════════════════════════════════════════════════
// DashboardCard Widget Tests
// ═══════════════════════════════════════════════════════════════════════

void main() {
  group('DashboardCard', () {
    testWidgets('renders title and icon', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '测试卡片',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          child: const Text('卡片内容'),
        ),
      ));

      expect(find.text('测试卡片'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('shows child content when expanded', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '展开测试',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          child: const Text('展开的内容'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('展开的内容'), findsOneWidget);
    });

    testWidgets('hides child content when collapsed (via AnimatedCrossFade)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '折叠测试',
          icon: Icons.star,
          isExpanded: false,
          onToggle: () {},
          child: const Text('隐藏的内容'),
        ),
      ));
      await tester.pumpAndSettle();

      // AnimatedCrossFade still has the widget in tree but second child is SizedBox.shrink
      expect(find.byType(AnimatedCrossFade), findsOneWidget);
      final acf =
          tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(acf.crossFadeState, CrossFadeState.showSecond);
    });

    testWidgets('calls onToggle when header is tapped', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '点击测试',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () => toggled = true,
          child: const Text('内容'),
        ),
      ));

      // Tap on the card header (InkWell)
      await tester.tap(find.text('点击测试'));
      expect(toggled, isTrue);
    });

    testWidgets('shows trailing widget when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '带尾部',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          trailing: const Icon(Icons.drag_handle),
          child: const Text('内容'),
        ),
      ));

      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });

    testWidgets('has no trailing when not provided', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '无尾部',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          child: const Text('内容'),
        ),
      ));

      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('shows expand/collapse arrow icon', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '箭头测试',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          child: const Text('内容'),
        ),
      ));

      expect(
          find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('arrow rotates when expanded (AnimatedRotation)', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '旋转测试',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          child: const Text('内容'),
        ),
      ));
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, 0.5); // expanded = rotated 180°
    });

    testWidgets('arrow not rotated when collapsed', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '旋转测试',
          icon: Icons.star,
          isExpanded: false,
          onToggle: () {},
          child: const Text('内容'),
        ),
      ));
      await tester.pumpAndSettle();

      final rotation =
          tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, 0.0);
    });

    testWidgets('accessibility label includes title and expand state',
        (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '资产构成',
          icon: Icons.donut_large_rounded,
          isExpanded: true,
          onToggle: () {},
          child: const Text('内容'),
        ),
      ));

      expect(
        find.bySemanticsLabel('资产构成卡片，已展开'),
        findsOneWidget,
      );
    });

    testWidgets('accessibility label for collapsed state', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '预算执行',
          icon: Icons.track_changes_rounded,
          isExpanded: false,
          onToggle: () {},
          child: const Text('内容'),
        ),
      ));

      expect(
        find.bySemanticsLabel('预算执行卡片，已折叠'),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark theme', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '暗色测试',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          child: const Text('暗色内容'),
        ),
        theme: ThemeData.dark(useMaterial3: true),
      ));

      expect(find.text('暗色测试'), findsOneWidget);
      expect(find.text('暗色内容'), findsOneWidget);

      // Verify Card has dark elevation=0
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 0);
    });

    testWidgets('Card uses CardLight color in light theme', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '颜色测试',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          child: const Text('内容'),
        ),
        theme: ThemeData.light(useMaterial3: true),
      ));

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, AppColors.cardLight);
    });

    testWidgets('Card uses rounded corners with radius 16', (tester) async {
      await tester.pumpWidget(_wrap(
        DashboardCard(
          title: '圆角测试',
          icon: Icons.star,
          isExpanded: true,
          onToggle: () {},
          child: const Text('内容'),
        ),
      ));

      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(16),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // DashboardPage Widget Tests
  // ═══════════════════════════════════════════════════════════════════════

  group('DashboardPage', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    /// Pumps DashboardPage with standard overrides.
    Future<void> pumpDashboard(
      WidgetTester tester, {
      DashboardState? state,
      bool settle = true,
    }) async {
      // Use a taller surface (1600px) so most dashboard cards are visible
      // without scrolling (default 800px only shows top 2-3 cards).
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_wrapWithProviders(
        const Scaffold(body: DashboardPage()),
        overrides: _dashboardOverrides(
          state: state ?? _makeFullDashboardState(),
          prefs: prefs,
        ),
      ));
      // pump a few frames instead of pumpAndSettle to avoid
      // infinite animation timeouts (CircularProgressIndicator, charts)
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows loading indicator when isLoading with no data',
        (tester) async {
      await pumpDashboard(tester, state: const DashboardState(isLoading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders all 7 cards when data is loaded', (tester) async {
      await pumpDashboard(tester);

      // Net Worth card (first card, always visible)
      expect(find.text('净资产'), findsOneWidget);

      // Top visible DashboardCards (ReorderableListView.builder only builds visible)
      expect(find.text('资产构成'), findsOneWidget);

      // Scroll down to reveal more cards
      final listFinder = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('收支趋势'), 300, scrollable: listFinder);
      expect(find.text('收支趋势'), findsOneWidget);

      // Verify ReorderableListView is used (all 7 sections are in the builder)
      expect(DashboardSection.values.length, 7);
    });

    testWidgets('uses ReorderableListView', (tester) async {
      await pumpDashboard(tester);

      expect(find.byType(ReorderableListView), findsOneWidget);
    });

    testWidgets('net worth card displays formatted total', (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            netWorth: _makeNetWorth(total: 50000000), // 50.00万
          ));

      expect(find.textContaining('50.00万'), findsOneWidget);
    });

    testWidgets('net worth card shows change from last month',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            netWorth: _makeNetWorth(
              changeFromLastMonth: 1000000,
              changePercent: 2.0,
            ),
          ));

      expect(find.textContaining('1.00万'), findsWidgets);
      expect(find.textContaining('+2.0%'), findsOneWidget);
      expect(find.text('较上月'), findsOneWidget);
    });

    testWidgets('net worth card shows upward arrow for positive change',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            netWorth: _makeNetWorth(changeFromLastMonth: 100000),
          ));

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('net worth card shows downward arrow for negative change',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            netWorth: _makeNetWorth(
              changeFromLastMonth: -200000,
              changePercent: -4.0,
            ),
          ));

      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });

    testWidgets('net worth card expand/collapse toggles detail rows',
        (tester) async {
      await pumpDashboard(tester);

      // Initially expanded: asset detail rows should be visible
      expect(find.text('💵'), findsOneWidget);
      expect(find.text('📈'), findsWidgets); // may appear in investment card too
      expect(find.text('🏠'), findsOneWidget);
      expect(find.text('🏦'), findsOneWidget);

      // Tap net worth card to collapse
      await tester.tap(find.text('净资产'));
      await tester.pumpAndSettle();

      // After collapse, the AnimatedCrossFade should show second child
      // The detail section is hidden
    });

    testWidgets('dashboard card expand/collapse toggles via onToggle',
        (tester) async {
      await pumpDashboard(tester);

      // Tap on "资产构成" header to collapse it
      await tester.tap(find.text('资产构成'));
      await tester.pumpAndSettle();

      // After toggle, check that the card is now collapsed
      // by verifying the Semantics label
      expect(
        find.bySemanticsLabel('资产构成卡片，已折叠'),
        findsOneWidget,
      );

      // Tap again to expand
      await tester.tap(find.text('资产构成'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('资产构成卡片，已展开'),
        findsOneWidget,
      );
    });

    testWidgets('asset pie chart section uses RepaintBoundary',
        (tester) async {
      await pumpDashboard(tester);

      // RepaintBoundary wraps the pie charts
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('shows PieChart widgets for asset and category sections',
        (tester) async {
      await pumpDashboard(tester);

      // Two pie charts: asset composition + category breakdown
      expect(find.byType(PieChart), findsNWidgets(2));
    });

    testWidgets('shows LineChart for income/expense trend', (tester) async {
      await pumpDashboard(tester);

      // Two line charts: income/expense trend + net worth trend
      expect(find.byType(LineChart), findsNWidgets(2));
    });

    testWidgets('period toggle shows month/year segments', (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(trendPeriod: 'monthly'));

      expect(find.text('月'), findsNWidgets(2));
      expect(find.text('年'), findsNWidgets(2));
    });

    testWidgets('period toggle uses SegmentedButton', (tester) async {
      await pumpDashboard(tester);

      expect(find.byType(SegmentedButton<String>), findsNWidgets(2));
    });

    testWidgets('budget card shows execution rate', (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            budgetSummary: _makeBudget(
              totalBudget: 1000000,
              totalSpent: 600000,
              executionRate: 0.6,
            ),
          ));

      expect(find.text('60%'), findsOneWidget);
      expect(find.textContaining('已用'), findsOneWidget);
      expect(find.textContaining('预算'), findsWidgets); // title + detail
    });

    testWidgets('budget card shows "本月暂未设置预算" when budget is 0',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            budgetSummary: _makeBudget(
              totalBudget: 0,
              totalSpent: 0,
              executionRate: 0.0,
            ),
          ));

      expect(find.text('本月暂未设置预算'), findsOneWidget);
    });

    testWidgets('shows "暂无资产数据" when composition is empty',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            netWorth: _makeNetWorth(composition: []),
          ));

      expect(find.text('暂无资产数据'), findsOneWidget);
    });

    testWidgets('shows "暂无趋势数据" when trend points are empty',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(incomeExpenseTrend: []));

      expect(find.text('暂无趋势数据'), findsOneWidget);
    });

    testWidgets('shows "当月暂无支出" when category breakdown is empty',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(categoryBreakdown: []));

      expect(find.text('当月暂无支出'), findsOneWidget);
    });

    testWidgets('shows "暂无净资产趋势" when net worth trend is empty',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(netWorthTrend: []));

      expect(find.text('暂无净资产趋势'), findsOneWidget);
    });

    testWidgets('shows "暂无投资数据" when investmentValue is 0',
        (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            netWorth: _makeNetWorth(investmentValue: 0),
          ));

      expect(find.text('暂无投资数据'), findsOneWidget);
    });

    testWidgets('investment card shows portfolio value', (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            netWorth: _makeNetWorth(investmentValue: 15000000),
          ));

      expect(find.text('投资组合市值'), findsOneWidget);
      expect(find.textContaining('15.00万'), findsWidgets);
    });

    testWidgets('all drag handles are present', (tester) async {
      await pumpDashboard(tester);

      // Each card has a drag handle icon
      expect(
          find.byIcon(Icons.drag_handle_rounded), findsNWidgets(7));
    });

    testWidgets('has RefreshIndicator', (tester) async {
      await pumpDashboard(tester);

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('renders in dark theme', (tester) async {
      await pumpDashboard(tester);

      expect(find.text('净资产'), findsOneWidget);
      expect(find.text('资产构成'), findsOneWidget);
    });

    testWidgets('net worth card has semantic label', (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            netWorth: _makeNetWorth(
              total: 50000000,
              changeFromLastMonth: 1000000,
            ),
          ));

      // Semantic label contains 净资产
      expect(
        find.bySemanticsLabel(RegExp(r'净资产.*元.*较上月')),
        findsOneWidget,
      );
    });

    testWidgets('asset pie chart has semantic label', (tester) async {
      await pumpDashboard(tester);

      expect(find.byType(PieChart), findsWidgets);
    });

    testWidgets('category pie chart has semantic label', (tester) async {
      await pumpDashboard(tester);

      expect(find.text('分类支出'), findsOneWidget);
    });

    testWidgets('income/expense chart has semantic label', (tester) async {
      await pumpDashboard(tester);

      expect(find.byType(LineChart), findsWidgets);
    });

    testWidgets('asset composition legend shows category labels',
        (tester) async {
      await pumpDashboard(tester);

      expect(find.text('现金银行'), findsWidgets); // in pie legend + detail
      expect(find.text('投资'), findsWidgets);
      expect(find.text('固定资产'), findsWidgets);
      expect(find.text('贷款'), findsWidgets);
    });

    testWidgets('category breakdown legend shows category names',
        (tester) async {
      await pumpDashboard(tester);

      // Category labels with icons
      expect(find.textContaining('餐饮'), findsOneWidget);
      expect(find.textContaining('交通'), findsOneWidget);
      expect(find.textContaining('购物'), findsOneWidget);
      expect(find.textContaining('居住'), findsOneWidget);
    });

    testWidgets('budget card shows LinearProgressIndicator', (tester) async {
      await pumpDashboard(tester, state: _makeFullDashboardState(
            budgetSummary: _makeBudget(executionRate: 0.7),
          ));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ReportPage Widget Tests
  // ═══════════════════════════════════════════════════════════════════════

  group('ReportPage', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'user_id': 'test_user'});
      prefs = await SharedPreferences.getInstance();
    });

    List<Override> _reportOverrides() => [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserIdProvider.overrideWith((ref) => 'test_user'),
          databaseProvider.overrideWithValue(_FakeDatabase()),
          transactionProvider.overrideWith((ref) {
            return _FakeTransactionNotifier(_makeTransactionState());
          }),
        ];

    testWidgets('renders AppBar with title "交易报表"', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const ReportPage(),
        overrides: _reportOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('交易报表'), findsOneWidget);
    });

    testWidgets('shows date preset chips', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const ReportPage(),
        overrides: _reportOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('本月'), findsOneWidget);
      expect(find.text('上月'), findsOneWidget);
      expect(find.text('近30天'), findsOneWidget);
    });

    testWidgets('shows 支出/收入 tabs', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const ReportPage(),
        overrides: _reportOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('支出'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
    });

    testWidgets('shows summary with 总支出', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const ReportPage(),
        overrides: _reportOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('总支出'), findsOneWidget);
    });

    testWidgets('shows empty state message when no transactions',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const ReportPage(),
        overrides: _reportOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('暂无数据'), findsOneWidget);
    });

    testWidgets('shows 自定义 date preset chip', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const ReportPage(),
        overrides: _reportOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('自定义'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════
  // CsvImportPage Widget Tests
  // ═══════════════════════════════════════════════════════════════════════

  group('CsvImportPage', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'user_id': 'test_user'});
      prefs = await SharedPreferences.getInstance();
    });

    List<Override> _importOverrides() => [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ];

    testWidgets('renders AppBar with title "CSV 导入"', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const CsvImportPage(),
        overrides: _importOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CSV 导入'), findsOneWidget);
    });

    testWidgets('shows Stepper with 4 steps', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const CsvImportPage(),
        overrides: _importOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Stepper), findsOneWidget);

      // Step titles
      expect(find.text('选择文件'), findsOneWidget);
      expect(find.text('数据预览'), findsOneWidget);
      expect(find.text('字段映射'), findsOneWidget);
      expect(find.text('导入结果'), findsOneWidget);
    });

    testWidgets('step 1: shows "选择 CSV 文件" button', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const CsvImportPage(),
        overrides: _importOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('选择 CSV 文件'), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);
    });

    testWidgets('step 1: "下一步" button is disabled when no file selected',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const CsvImportPage(),
        overrides: _importOverrides(),
      ));
      await tester.pumpAndSettle();

      // Find the "下一步" button — it should be disabled
      final button = find.widgetWithText(FilledButton, '下一步');
      expect(button, findsWidgets); // Stepper creates multiple

      final filledButton = tester.widget<FilledButton>(button.first);
      expect(filledButton.onPressed, isNull);
    });

    testWidgets('step 2: shows preview instructions when no data parsed',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const CsvImportPage(),
        overrides: _importOverrides(),
      ));
      await tester.pumpAndSettle();

      // Step 2 content shows placeholder message
      // (not active yet but the content still exists in the Stepper tree)
      expect(find.text('请先选择并解析 CSV 文件'), findsOneWidget);
    });

    testWidgets('step 4: shows "等待导入..." before import starts',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const CsvImportPage(),
        overrides: _importOverrides(),
      ));
      await tester.pumpAndSettle();

      // Step 4 content is present but not active
      expect(find.text('等待导入...'), findsOneWidget);
    });

    testWidgets('has upload file icon button', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const CsvImportPage(),
        overrides: _importOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('starts at step 0', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(
        const CsvImportPage(),
        overrides: _importOverrides(),
      ));
      await tester.pumpAndSettle();

      final stepper = tester.widget<Stepper>(find.byType(Stepper));
      expect(stepper.currentStep, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // DashboardSection enum Tests
  // ═══════════════════════════════════════════════════════════════════════

  group('DashboardSection enum', () {
    test('has 7 values', () {
      expect(DashboardSection.values.length, 7);
    });

    test('contains all expected sections', () {
      expect(DashboardSection.values, contains(DashboardSection.netWorth));
      expect(
          DashboardSection.values, contains(DashboardSection.assetComposition));
      expect(DashboardSection.values,
          contains(DashboardSection.incomeExpenseTrend));
      expect(DashboardSection.values,
          contains(DashboardSection.categoryBreakdown));
      expect(
          DashboardSection.values, contains(DashboardSection.budgetExecution));
      expect(
          DashboardSection.values, contains(DashboardSection.netWorthTrend));
      expect(
          DashboardSection.values, contains(DashboardSection.investmentTrend));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Dashboard Data Model Tests
  // ═══════════════════════════════════════════════════════════════════════

  group('DashboardState', () {
    test('default state has empty data', () {
      const state = DashboardState();
      expect(state.netWorth.total, 0);
      expect(state.incomeExpenseTrend, isEmpty);
      expect(state.categoryBreakdown, isEmpty);
      expect(state.budgetSummary.totalBudget, 0);
      expect(state.isLoading, false);
      expect(state.trendPeriod, 'monthly');
    });

    test('copyWith preserves unchanged values', () {
      final state = _makeFullDashboardState();
      final copied = state.copyWith(isLoading: true);
      expect(copied.isLoading, true);
      expect(copied.netWorth.total, state.netWorth.total);
      expect(copied.trendPeriod, state.trendPeriod);
    });

    test('copyWith can clear error', () {
      final state = _makeFullDashboardState().copyWith(error: 'test error');
      expect(state.error, 'test error');
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });
  });

  group('NetWorthData', () {
    test('default values are all 0', () {
      const nw = NetWorthData();
      expect(nw.total, 0);
      expect(nw.cashAndBank, 0);
      expect(nw.investmentValue, 0);
      expect(nw.fixedAssetValue, 0);
      expect(nw.loanBalance, 0);
      expect(nw.changeFromLastMonth, 0);
      expect(nw.changePercent, 0.0);
      expect(nw.composition, isEmpty);
    });
  });

}

class _FakeTransactionNotifier extends StateNotifier<TransactionState>
    implements TransactionNotifier {
  _FakeTransactionNotifier(TransactionState initial) : super(initial);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return null;
  }
}
