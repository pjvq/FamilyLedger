import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/database.dart';
import '../../core/constants/app_constants.dart';
import '../interfaces/interfaces.dart';
import '../repositories/account_repository.dart';
import '../repositories/category_repository.dart';

/// 数据库单例
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// 当前用户 ID
final currentUserIdProvider = StateProvider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(AppConstants.userIdKey);
});

/// 是否已登录
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserIdProvider) != null;
});

/// 当前家庭 ID（null = 个人模式）
/// 启动时通过 initFamilyIdFromPrefs() 从 SharedPreferences 恢复
final currentFamilyIdProvider = StateProvider<String?>((ref) {
  return null; // 启动后由 initFamilyIdFromPrefs 设置
});

// ─── Repository Providers (DIP) ─────────────────────────────────────────────
// These expose concrete repositories typed as interfaces.
// Override in tests with mock implementations via ProviderScope.

/// Account repository — override with mock in tests.
final accountRepositoryProvider = Provider<IAccountRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountRepository(db);
});

/// Category repository — override with mock in tests.
final categoryRepositoryProvider = Provider<ICategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});
