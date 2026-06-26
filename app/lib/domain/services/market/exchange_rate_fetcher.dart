import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when fetching exchange rates from the upstream API fails.
class ExchangeRateFetchException implements Exception {
  ExchangeRateFetchException(this.message);

  final String message;

  @override
  String toString() => 'ExchangeRateFetchException: $message';
}

/// Direct client-side FX-rate fetcher.
///
/// Ported from `server/internal/market/exchange_service.go` — hits the same
/// free, auth-free endpoint (open.er-api.com, base = CNY) so currency
/// conversion works without a backend ("去服务化" Phase 1, issue #143).
///
/// Pure I/O service — no Riverpod / Drift knowledge. The [http.Client] is
/// injected so parsing can be unit-tested against captured payloads without
/// touching the network. On any upstream error it throws; the calling provider
/// keeps its cached/default rates.
class ExchangeRateFetcher {
  ExchangeRateFetcher(this._client);

  final http.Client _client;

  static const _timeout = Duration(seconds: 10);
  static const _endpoint = 'https://open.er-api.com/v6/latest/CNY';

  /// Closes the underlying HTTP client (releases its connection pool). Call
  /// only when this fetcher owns the client — i.e. it wasn't constructed with
  /// an injected/shared client.
  void close() => _client.close();

  /// Fetches `X/CNY` rates (how many CNY per 1 unit of X) for each of
  /// [currencies] except CNY.
  ///
  /// open.er-api.com returns base=CNY rates — `rates[X]` = units of X per 1
  /// CNY — so `X/CNY = 1 / rates[X]` (matching the local store's convention,
  /// e.g. `USD/CNY = 7.25`). Only pairs the API actually returns are included
  /// (e.g. BTC is fiat-only-absent and is left to other sources/defaults).
  Future<Map<String, double>> fetchCnyRates(List<String> currencies) async {
    final http.Response resp;
    try {
      resp = await _client.get(Uri.parse(_endpoint)).timeout(_timeout);
    } catch (e) {
      throw ExchangeRateFetchException('http get failed: $e');
    }

    if (resp.statusCode != 200) {
      throw ExchangeRateFetchException('API returned status ${resp.statusCode}');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw ExchangeRateFetchException('decode json failed: $e');
    }

    if (json['result'] != 'success') {
      throw ExchangeRateFetchException('API result=${json['result']}');
    }
    final rates = json['rates'];
    if (rates is! Map || rates.isEmpty) {
      throw ExchangeRateFetchException('missing rates');
    }

    final out = <String, double>{};
    for (final c in currencies) {
      if (c == 'CNY') continue;
      final r = rates[c];
      if (r is num && r > 0) {
        // X/CNY = CNY per 1 X = 1 / (units of X per 1 CNY). Round to 8 dp to
        // match the server's precision.
        out['$c/CNY'] = double.parse((1.0 / r).toStringAsFixed(8));
      }
    }
    return out;
  }
}
