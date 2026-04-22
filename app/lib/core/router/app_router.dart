import 'package:flutter/material.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/home/home_page.dart';
import '../../features/transaction/add_transaction_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/family_members_page.dart';
import '../../features/account/accounts_page.dart';
import '../../features/account/add_account_page.dart';
import '../../features/account/transfer_page.dart';
import '../../features/budget/budget_page.dart';
import '../../features/notification/notifications_page.dart';
import '../../features/notification/notification_settings_page.dart';

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

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return _slide(const LoginPage());
      case register:
        return _slide(const RegisterPage());
      case home:
        return _fade(const HomePage());
      case addTransaction:
        return _slideUp(const AddTransactionPage());
      case AppRouter.settings:
        return _slide(const SettingsPage());
      case familyMembers:
        return _slide(const FamilyMembersPage());
      case accounts:
        return _slide(const AccountsPage());
      case addAccount:
        return _slideUp(const AddAccountPage());
      case transfer:
        return _slideUp(const TransferPage());
      case budget:
        return _slide(const BudgetPage());
      case notifications:
        return _slide(const NotificationsPage());
      case notificationSettings:
        return _slide(const NotificationSettingsPage());
      default:
        return _fade(const HomePage());
    }
  }

  static PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, a, secondaryAnimation, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      );

  static PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, a, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      );

  static PageRouteBuilder _slideUp(Widget page) => PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, a, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      );
}
