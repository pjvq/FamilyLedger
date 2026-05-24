/// Route path constants for the app.
///
/// The actual routing is handled by go_router in `router.dart`.
/// These constants are kept for use in tests and legacy references.
class AppRouter {
  AppRouter._();

  static const login = '/login';
  static const register = '/register';
  static const home = '/';
  static const addTransaction = '/add-transaction';
  static const settings = '/settings';
  static const familyMembers = '/settings/members';
  static const accounts = '/accounts';
  static const addAccount = '/accounts/add';
  static const transfer = '/transfer';
  static const budget = '/budget';
  static const notifications = '/notifications';
  static const notificationSettings = '/notifications/settings';
  static const loans = '/loans';
  static const addLoan = '/loans/add';
  static const loanDetail = '/loans/detail';
  static const loanGroupDetail = '/loans/group-detail';
  static const prepayment = '/loans/prepayment';
  static const investments = '/investments';
  static const addInvestment = '/investments/add';
  static const investmentDetail = '/investments/detail';
  static const investmentTrade = '/investments/trade';
  static const assets = '/assets';
  static const addAsset = '/assets/add';
  static const assetDetail = '/assets/detail';
  static const report = '/report';
  static const export = '/export';
  static const csvImport = '/import/csv';
  static const transactionHistory = '/transactions';
  static const transactionDetail = '/transaction-detail';
  static const categoryManage = '/settings/categories';
}
