/// Route path constants for the app.
///
/// The actual routing is handled by go_router in `router.dart`.
/// These constants are kept for use in tests and legacy references.
class AppRouter {
  AppRouter._();

  static const login = '/login';
  static const register = '/register';
  static const home = '/overview';
  static const addTransaction = '/add-transaction';
  static const settings = '/mine/settings';
  static const familyMembers = '/mine/settings/members';
  static const accounts = '/assets';
  static const addAccount = '/assets/accounts/add';
  static const transfer = '/transfer';
  static const budget = '/mine/budget';
  static const notifications = '/mine/notifications';
  static const notificationSettings = '/mine/notifications/settings';
  static const loans = '/assets/loans';
  static const addLoan = '/assets/loans/add';
  static const loanDetail = '/assets/loans/detail';
  static const loanGroupDetail = '/assets/loans/group-detail';
  static const prepayment = '/assets/loans/prepayment';
  static const investments = '/assets/investments';
  static const addInvestment = '/assets/investments/add';
  static const investmentDetail = '/assets/investments/detail';
  static const investmentTrade = '/assets/investments/trade';
  static const assets = '/assets';
  static const addAsset = '/assets/fixed/add';
  static const assetDetail = '/assets/fixed/detail';
  static const report = '/mine/report';
  static const export = '/mine/report/export';
  static const csvImport = '/mine/import/csv';
  static const transactionHistory = '/transactions';
  static const transactionDetail = '/transactions/detail';
  static const categoryManage = '/mine/settings/categories';
}
