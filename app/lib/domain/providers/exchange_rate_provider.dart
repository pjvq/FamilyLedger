import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database.dart';
import 'app_providers.dart';

/// Default exchange rates (fallback)
const _defaultRates = <String, double>{
  'USD/CNY': 7.25,
  'EUR/CNY': 7.90,
  'GBP/CNY': 9.15,
  'JPY/CNY': 0.048,
  'HKD/CNY': 0.93,
  'BTC/CNY': 480000.0,
};

/// Supported currencies
const supportedCurrencies = ['CNY', 'USD', 'EUR', 'GBP', 'JPY', 'HKD', 'BTC'];

const currencySymbols = <String, String>{
  'CNY': '¥',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'HKD': 'HK\$',
  'BTC': '₿',
};

/// Exchange rate provider
final exchangeRateProvider =
    StateNotifierProvider<ExchangeRateNotifier, Map<String, double>>((ref) {
  final db = ref.watch(databaseProvider);
  return ExchangeRateNotifier(db);
});

class ExchangeRateNotifier extends StateNotifier<Map<String, double>> {
  final AppDatabase _db;

  ExchangeRateNotifier(this._db) : super({..._defaultRates}) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final rows = await _db.select(_db.exchangeRates).get();
      if (rows.isNotEmpty) {
        final dbRates = <String, double>{};
        for (final row in rows) {
          dbRates[row.currencyPair] = row.rate;
        }
        // Merge: DB values override defaults
        state = {..._defaultRates, ...dbRates};
      }
    } catch (_) {
      // DB might not have table yet (pre-migration), keep defaults
    }
  }

  /// Get exchange rate from [from] to [to]
  double getRate(String from, String to) {
    if (from == to) return 1.0;
    if (to == 'CNY') {
      return state['$from/CNY'] ?? 1.0;
    }
    if (from == 'CNY') {
      final toCny = state['$to/CNY'];
      if (toCny != null && toCny > 0) return 1.0 / toCny;
    }
    // Cross-rate via CNY
    final fromCny = state['$from/CNY'] ?? 1.0;
    final toCny = state['$to/CNY'] ?? 1.0;
    if (toCny > 0) return fromCny / toCny;
    return 1.0;
  }

  /// Convert amount in [from] currency to CNY (in fen)
  int toCny(int amountFen, String from) {
    if (from == 'CNY') return amountFen;
    final rate = getRate(from, 'CNY');
    return (amountFen * rate).round();
  }

  /// Refresh rates from network (TODO: call backend API)
  Future<void> refreshRates() async {
    // For now, just reload from DB
    await _loadFromDb();
  }

  /// Save rates to local DB
  Future<void> saveRates(Map<String, double> rates) async {
    for (final entry in rates.entries) {
      await _db.into(_db.exchangeRates).insertOnConflictUpdate(
            ExchangeRatesCompanion.insert(
              currencyPair: entry.key,
              rate: entry.value,
            ),
          );
    }
    state = {...state, ...rates};
  }
}
