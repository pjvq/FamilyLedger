import 'dart:convert';

import 'package:familyledger/domain/services/market/market_fetcher.dart';
import 'package:familyledger/domain/services/market/market_models.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// A fake [http.Client] that returns a canned response per host (or path),
/// so parsing is tested against captured payloads without touching the network.
class _FakeClient extends http.BaseClient {
  /// matcher → (statusCode, body bytes)
  final List<({bool Function(Uri) match, int status, List<int> body})> _routes;
  Uri? lastUri;
  Map<String, String>? lastHeaders;

  _FakeClient(this._routes);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    lastHeaders = request.headers;
    for (final r in _routes) {
      if (r.match(request.url)) {
        return http.StreamedResponse(
          Stream.value(r.body),
          r.status,
          request: request,
        );
      }
    }
    return http.StreamedResponse(const Stream.empty(), 404, request: request);
  }
}

_FakeClient _clientReturning(String body, {int status = 200, List<int>? bytes}) {
  return _FakeClient([
    (match: (_) => true, status: status, body: bytes ?? utf8.encode(body)),
  ]);
}

void main() {
  group('A-share / HK secid validation', () {
    test('rejects non-numeric A-share symbol', () async {
      final f = MarketFetcher(_clientReturning('{}'));
      expect(
        () => f.fetchQuote('Au99.99', 'a_share'),
        throwsA(isA<MarketFetchException>()),
      );
    });

    test('rejects non-numeric HK symbol', () async {
      final f = MarketFetcher(_clientReturning('{}'));
      expect(
        () => f.fetchQuote('ABC', 'hk_stock'),
        throwsA(isA<MarketFetchException>()),
      );
    });

    test('SH prefix (6/9/5) and SZ prefix routing via request URL', () async {
      final client = _clientReturning(jsonEncode({
        'data': {
          'f43': 1000.0, 'f44': 1010.0, 'f45': 990.0, 'f46': 995.0,
          'f57': '600519', 'f58': '贵州茅台', 'f60': 980.0,
          'f169': 20.0, 'f170': 2.04,
        },
      }));
      final f = MarketFetcher(client);
      await f.fetchQuote('600519', 'a_share');
      expect(client.lastUri.toString(), contains('secid=1.600519'));

      final client2 = _clientReturning(jsonEncode({
        'data': {'f43': 10.0, 'f58': '平安银行', 'f60': 10.0, 'f170': 0.0},
      }));
      final f2 = MarketFetcher(client2);
      await f2.fetchQuote('000001', 'a_share');
      expect(client2.lastUri.toString(), contains('secid=0.000001'));
    });
  });

  group('EastMoney stock quote parsing', () {
    test('parses fields and converts 元→分', () async {
      final client = _clientReturning(jsonEncode({
        'data': {
          'f43': 1700.50, // current
          'f44': 1720.0, // high
          'f45': 1680.0, // low
          'f46': 1690.0, // open
          'f57': '600519',
          'f58': '贵州茅台',
          'f60': 1685.0, // prev close
          'f169': 15.50, // change amount
          'f170': 0.918, // change percent
        },
      }));
      final q = await MarketFetcher(client).fetchQuote('600519', 'a_share');
      expect(q.currentPrice, 170050);
      expect(q.high, 172000);
      expect(q.low, 168000);
      expect(q.open, 169000);
      expect(q.prevClose, 168500);
      expect(q.changeAmount, 1550);
      expect(q.changePercent, 0.92); // rounded to 2dp
      expect(q.name, '贵州茅台');
      expect(q.marketType, 'a_share');
    });

    test('falls back to prevClose when current price is 0', () async {
      final client = _clientReturning(jsonEncode({
        'data': {'f43': 0, 'f58': 'X', 'f60': 500.0, 'f170': 0.0},
      }));
      final q = await MarketFetcher(client).fetchQuote('600000', 'a_share');
      expect(q.currentPrice, 50000);
    });

    test('handles string-encoded numbers', () async {
      final client = _clientReturning(jsonEncode({
        'data': {'f43': '12.34', 'f58': 'Y', 'f60': '12.00', 'f170': '2.83'},
      }));
      final q = await MarketFetcher(client).fetchQuote('000002', 'a_share');
      expect(q.currentPrice, 1234);
      expect(q.prevClose, 1200);
    });
  });

  group('Fund (JSONP) parsing', () {
    test('extracts NAV and computes change', () async {
      const body =
          'jsonpgz({"fundcode":"161725","name":"招商中证白酒","dwjz":"1.0000",'
          '"gsz":"1.0200","gszzl":"2.00"});';
      final q = await MarketFetcher(_clientReturning(body))
          .fetchQuote('161725', 'fund');
      expect(q.currentPrice, 102);
      expect(q.prevClose, 100);
      expect(q.changeAmount, 2);
      expect(q.changePercent, 2.0);
      expect(q.name, '招商中证白酒');
      expect(q.marketType, 'fund');
    });

    test('throws on non-JSONP body', () async {
      expect(
        () => MarketFetcher(_clientReturning('not jsonp')).fetchQuote('1', 'fund'),
        throwsA(isA<MarketFetchException>()),
      );
    });
  });

  group('Yahoo quote parsing', () {
    test('parses meta + indicators', () async {
      final body = jsonEncode({
        'chart': {
          'result': [
            {
              'meta': {
                'symbol': 'AAPL',
                'regularMarketPrice': 195.12,
                'previousClose': 190.00,
                'shortName': 'Apple Inc.',
              },
              'indicators': {
                'quote': [
                  {
                    'open': [191.0],
                    'high': [196.5],
                    'low': [190.2],
                    'close': [195.12],
                  }
                ],
              },
            }
          ],
        },
      });
      final q = await MarketFetcher(_clientReturning(body))
          .fetchQuote('AAPL', 'us_stock');
      expect(q.currentPrice, 19512);
      expect(q.prevClose, 19000);
      expect(q.open, 19100);
      expect(q.high, 19650);
      expect(q.low, 19020);
      expect(q.changeAmount, 512);
      expect(q.changePercent, 2.69);
      expect(q.name, 'Apple Inc.');
    });

    test('throws on empty result', () async {
      final body = jsonEncode({'chart': {'result': []}});
      expect(
        () => MarketFetcher(_clientReturning(body)).fetchQuote('X', 'us_stock'),
        throwsA(isA<MarketFetchException>()),
      );
    });
  });

  group('CoinGecko quote parsing', () {
    test('parses price + estimates prevClose from 24h change', () async {
      final body = jsonEncode({
        'bitcoin': {'usd': 60000.0, 'usd_24h_change': 5.0},
      });
      final q = await MarketFetcher(_clientReturning(body))
          .fetchQuote('bitcoin', 'crypto');
      expect(q.currentPrice, 6000000);
      expect(q.changePercent, 5.0);
      // prevClose = 60000 / 1.05 ≈ 57142.857 → 5714286 分
      expect(q.prevClose, 5714286);
      expect(q.changeAmount, 6000000 - 5714286);
      expect(q.name, 'bitcoin/USD');
    });

    test('throws when symbol missing', () async {
      final body = jsonEncode({'ethereum': {'usd': 1.0}});
      expect(
        () => MarketFetcher(_clientReturning(body)).fetchQuote('bitcoin', 'crypto'),
        throwsA(isA<MarketFetchException>()),
      );
    });
  });

  group('Sina precious metal parsing', () {
    test('parses gds_ line fields', () {
      // [0]price [4]high [5]low [7]prevClose [8]open [13]name
      const payload = '937.52,0,938.50,939.89,943.00,909.00,15:30:01,'
          '907.47,912.60,0,0,0,0,沪金99';
      const body = 'var hq_str_gds_AU9999="$payload";';
      final q = parseSinaPreciousMetal('Au99.99', 'AU9999', body);
      expect(q.currentPrice, 93752);
      expect(q.high, 94300);
      expect(q.low, 90900);
      expect(q.prevClose, 90747);
      expect(q.open, 91260);
      expect(q.name, '沪金99');
      expect(q.changeAmount, q.currentPrice - q.prevClose);
      expect(q.marketType, 'precious_metal');
    });

    test('throws on empty payload', () {
      const body = 'var hq_str_gds_AU9999="";';
      expect(
        () => parseSinaPreciousMetal('Au99.99', 'AU9999', body),
        throwsA(isA<MarketFetchException>()),
      );
    });

    test('throws on too few fields', () {
      const body = 'var hq_str_gds_AU9999="1,2,3";';
      expect(
        () => parseSinaPreciousMetal('Au99.99', 'AU9999', body),
        throwsA(isA<MarketFetchException>()),
      );
    });

    test('fetchQuote decodes GBK body', () async {
      const payload = '937.52,0,938.50,939.89,943.00,909.00,15:30:01,'
          '907.47,912.60,0,0,0,0,沪金99';
      final gbkBytes = gbk.encode('var hq_str_gds_AU9999="$payload";');
      final client = _clientReturning('', bytes: gbkBytes);
      final q = await MarketFetcher(client).fetchQuote('Au99.99', 'precious_metal');
      expect(q.name, '沪金99');
      expect(q.currentPrice, 93752);
      expect(client.lastHeaders?['Referer'], 'https://finance.sina.com.cn/');
    });

    test('unsupported metal symbol throws', () async {
      expect(
        () => MarketFetcher(_clientReturning(''))
            .fetchQuote('Ag99.99', 'precious_metal'),
        throwsA(isA<MarketFetchException>()),
      );
    });
  });

  group('Search', () {
    test('EastMoney suggest filters by market type (MktNum)', () async {
      final body = jsonEncode({
        'QuotationCodeTable': {
          'Data': [
            {'Code': '600519', 'Name': '贵州茅台', 'MktNum': '1'}, // SH → a_share
            {'Code': '00700', 'Name': '腾讯控股', 'MktNum': '116'}, // HK
          ],
        },
      });
      final results = await MarketFetcher(_clientReturning(body))
          .searchSymbol('茅台', 'a_share');
      expect(results.length, 1);
      expect(results.first.symbol, '600519');
      expect(results.first.marketType, 'a_share');
    });

    test('Yahoo search maps to us_stock', () async {
      final body = jsonEncode({
        'quotes': [
          {'symbol': 'AAPL', 'shortname': 'Apple Inc.', 'exchange': 'NMS'},
        ],
      });
      final results = await MarketFetcher(_clientReturning(body))
          .searchSymbol('apple', 'us_stock');
      expect(results.single.symbol, 'AAPL');
      expect(results.single.marketType, 'us_stock');
    });

    test('CoinGecko search formats name with uppercase symbol', () async {
      final body = jsonEncode({
        'coins': [
          {'id': 'bitcoin', 'name': 'Bitcoin', 'symbol': 'btc'},
        ],
      });
      final results = await MarketFetcher(_clientReturning(body))
          .searchSymbol('bit', 'crypto');
      expect(results.single.symbol, 'bitcoin');
      expect(results.single.name, 'Bitcoin (BTC)');
    });

    test('precious metal search is local catalog match', () async {
      final results = await MarketFetcher(_clientReturning(''))
          .searchSymbol('黄金', 'precious_metal');
      expect(results, isNotEmpty);
      expect(results.every((r) => r.marketType == 'precious_metal'), isTrue);
    });
  });

  group('Price history (K-line)', () {
    test('EastMoney klines parse date + close', () async {
      final body = jsonEncode({
        'data': {
          'klines': [
            '2024-01-02,12.34',
            '2024-01-03,12.56',
          ],
        },
      });
      final client = _clientReturning(body);
      final points = await MarketFetcher(client)
          .fetchPriceHistory('600519', 'a_share', DateTime(2024, 1, 1),
              DateTime(2024, 1, 5));
      expect(points.length, 2);
      expect(points.first.price, 1234);
      expect(points.last.price, 1256);
      expect(client.lastUri.toString(), contains('secid=1.600519'));
      expect(client.lastUri.toString(), contains('klt=101'));
    });

    test('Yahoo kline skips null gaps', () async {
      final body = jsonEncode({
        'chart': {
          'result': [
            {
              'timestamp': [1704153600, 1704240000, 1704326400],
              'indicators': {
                'quote': [
                  {'close': [195.0, null, 196.5]},
                ],
              },
            }
          ],
        },
      });
      final points = await MarketFetcher(_clientReturning(body))
          .fetchPriceHistory('AAPL', 'us_stock', DateTime(2024, 1, 1),
              DateTime(2024, 1, 5));
      expect(points.length, 2); // null skipped
      expect(points.first.price, 19500);
      expect(points.last.price, 19650);
    });

    test('CoinGecko market_chart parses [ms, price] pairs', () async {
      final body = jsonEncode({
        'prices': [
          [1704153600000, 42000.0],
          [1704240000000, 43000.5],
        ],
      });
      final points = await MarketFetcher(_clientReturning(body))
          .fetchPriceHistory('bitcoin', 'crypto', DateTime(2024, 1, 1),
              DateTime(2024, 1, 5));
      expect(points.length, 2);
      expect(points.first.price, 4200000);
      expect(points.last.price, 4300050);
    });

    test('fund and precious_metal return empty series', () async {
      final f = MarketFetcher(_clientReturning('{}'));
      expect(
        await f.fetchPriceHistory('1', 'fund', DateTime(2024), DateTime(2024, 2)),
        isEmpty,
      );
      expect(
        await f.fetchPriceHistory('Au99.99', 'precious_metal', DateTime(2024),
            DateTime(2024, 2)),
        isEmpty,
      );
    });
  });

  group('HTTP errors', () {
    test('non-200 status throws', () async {
      final f = MarketFetcher(_clientReturning('err', status: 500));
      expect(
        () => f.fetchQuote('600519', 'a_share'),
        throwsA(isA<MarketFetchException>()),
      );
    });

    test('unsupported market type throws', () async {
      final f = MarketFetcher(_clientReturning('{}'));
      expect(
        () => f.fetchQuote('X', 'bogus'),
        throwsA(isA<MarketFetchException>()),
      );
    });
  });

  test('value object types are exported', () {
    const q = MarketQuoteData(
      symbol: 's',
      name: 'n',
      marketType: 'a_share',
      currentPrice: 1,
      changeAmount: 0,
      changePercent: 0,
    );
    expect(q.symbol, 's');
    final p = PricePointData(timestamp: DateTime(2024), price: 0);
    expect(p.price, 0);
  });
}
