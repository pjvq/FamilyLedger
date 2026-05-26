/// Route path constants and builders for the app.
///
/// The actual routing is handled by go_router in `router.dart`.
/// Static constants are for parameterless routes.
/// Static methods are for routes requiring path parameters (go_router style).
class AppRouter {
  AppRouter._();

  // ── Auth ──
  static const login = '/login';
  static const register = '/register';

  // ── Tabs ──
  static const home = '/overview';
  static const transactionHistory = '/transactions';
  static const assets = '/assets';

  // ── Transaction ──
  static const addTransaction = '/add-transaction';
  static const transfer = '/transfer';
  static const transactionDetail = '/transactions/detail';

  // ── Assets / Accounts ──
  static const addAccount = '/assets/accounts/add';
  static String accountDetail(String accountId) => '/assets/accounts/$accountId';

  // ── Loans ──
  static const loans = '/assets/loans';
  static const addLoan = '/assets/loans/add';
  static String loanDetail(String loanId) => '/assets/loans/$loanId';
  static String loanGroupDetail(String groupId) =>
      '/assets/loans/group/$groupId';
  static String prepayment(String loanId) => '/assets/loans/$loanId/prepayment';

  // ── Investments ──
  static const investments = '/assets/investments';
  static const addInvestment = '/assets/investments/add';
  static String investmentDetail(String investmentId) =>
      '/assets/investments/$investmentId';
  static String investmentTrade(String investmentId) =>
      '/assets/investments/$investmentId/trade';

  // ── Fixed Assets ──
  static const addAsset = '/assets/fixed/add';
  static String assetDetail(String assetId) => '/assets/fixed/$assetId';

  // ── Mine ──
  static const settings = '/mine/settings';
  static const familyMembers = '/mine/settings/members';
  static const categoryManage = '/mine/settings/categories';
  static const notifications = '/mine/notifications';
  static const notificationSettings = '/mine/notifications/settings';
  static const budget = '/mine/budget';
  static const report = '/mine/report';
  static const export = '/mine/export';
  static const csvImport = '/mine/import';
}
