import 'dart:convert';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:http/http.dart' as http;

import 'market_models.dart';

/// Direct client-side market-data fetcher.
///
/// Ported from `server/internal/market/fetcher.go`. Hits the same free,
/// auth-free public HTTP sources the server used, so quotes / K-line / search
/// work without a backend ("去服务化" Phase 1, issue #142):
///
///   - A股 / 港股 / 基金 → 东方财富 (EastMoney) + 天天基金
///   - 美股             → Yahoo Finance
///   - 加密货币          → CoinGecko
///   - 贵金属            → Sina finance (hq.sinajs.cn)
///
/// Pure I/O service — no Riverpod / Drift knowledge. The [http.Client] is
/// injected so parsing can be unit-tested against captured payloads without
/// touching the network. On any upstream error the methods throw; the calling
/// provider is responsible for cache fallback.
class MarketFetcher {
  final http.Client _client;

  /// Per-request timeout, mirrors the server's 10s `http.Client{Timeout}`.
  static const _timeout = Duration(seconds: 10);

  MarketFetcher(this._client);

  // ── Quote ──────────────────────────────────────────────────────────────

  /// Fetch a single quote for [symbol] of [marketType].
  Future<MarketQuoteData> fetchQuote(String symbol, String marketType) async {
    switch (marketType) {
      case 'a_share':
        return _fetchEastMoneyAShare(symbol);
      case 'hk_stock':
        return _fetchEastMoneyHKStock(symbol);
      case 'fund':
        return _fetchEastMoneyFund(symbol);
      case 'us_stock':
        return _fetchYahooQuote(symbol);
      case 'crypto':
        return _fetchCoinGeckoQuote(symbol);
      case 'precious_metal':
        return _fetchPreciousMetal(symbol);
      default:
        throw MarketFetchException('unsupported market type: $marketType');
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────

  /// Search symbols matching [query], optionally scoped to [marketType].
  Future<List<SymbolInfoData>> searchSymbol(
    String query,
    String marketType,
  ) async {
    switch (marketType) {
      case 'a_share':
      case 'hk_stock':
      case 'fund':
        return _searchEastMoney(query, marketType);
      case 'us_stock':
        return _searchYahoo(query);
      case 'crypto':
        return _searchCoinGecko(query);
      case 'precious_metal':
        return _searchPreciousMetal(query);
      default:
        throw MarketFetchException(
          'unsupported market type for search: $marketType',
        );
    }
  }

  // ── Price history (K-line) ───────────────────────────────────────────────

  /// Fetch daily close-price history for [symbol] between [start] and [end].
  ///
  /// There is no server-side equivalent (the backend served history from a
  /// scheduler-populated DB table), so this fetches daily K-line straight from
  /// the same public sources. Funds and precious metals have no usable public
  /// K-line endpoint reachable from the client, so they return an empty series.
  Future<List<PricePointData>> fetchPriceHistory(
    String symbol,
    String marketType,
    DateTime start,
    DateTime end,
  ) async {
    switch (marketType) {
      case 'a_share':
        return _fetchEastMoneyKline(_aShareSecID(symbol), start, end);
      case 'hk_stock':
        return _fetchEastMoneyKline(_hkSecID(symbol), start, end);
      case 'us_stock':
        return _fetchYahooKline(symbol, start, end);
      case 'crypto':
        return _fetchCoinGeckoKline(symbol, start, end);
      case 'fund':
      case 'precious_metal':
        return const [];
      default:
        return const [];
    }
  }

  // ── 东方财富 A股 / 港股 ───────────────────────────────────────────────────

  /// Returns the EastMoney secid prefix for an A-share symbol.
  ///
  /// SH (prefix "1."): codes starting with 6, 9, 5. SZ (prefix "0."): others.
  ///
  /// A-share codes are strictly 6-digit numeric; non-numeric inputs (e.g. a
  /// precious-metal symbol mistakenly stored with market_type=a_share) would
  /// otherwise produce a bogus secid like "0.Au99.99" and hammer the upstream
  /// API — so reject them up front, exactly as the server does.
  static String _aShareSecID(String symbol) {
    if (!_isNumericSymbol(symbol)) {
      throw MarketFetchException(
        'invalid A-share symbol "$symbol" (expected 6-digit numeric)',
      );
    }
    switch (symbol[0]) {
      case '6':
      case '9':
      case '5':
        return '1.$symbol';
      default:
        return '0.$symbol';
    }
  }

  static String _hkSecID(String symbol) {
    if (!_isNumericSymbol(symbol)) {
      throw MarketFetchException(
        'invalid HK stock symbol "$symbol" (expected numeric code)',
      );
    }
    return '116.$symbol';
  }

  /// Reports whether [symbol] is a non-empty all-digit string.
  static bool _isNumericSymbol(String symbol) {
    if (symbol.isEmpty) return false;
    for (final unit in symbol.codeUnits) {
      if (unit < 0x30 || unit > 0x39) return false;
    }
    return true;
  }

  Future<MarketQuoteData> _fetchEastMoneyAShare(String symbol) =>
      _fetchEastMoneyStock(_aShareSecID(symbol), symbol, 'a_share');

  Future<MarketQuoteData> _fetchEastMoneyHKStock(String symbol) =>
      _fetchEastMoneyStock(_hkSecID(symbol), symbol, 'hk_stock');

  Future<MarketQuoteData> _fetchEastMoneyStock(
    String secid,
    String symbol,
    String marketType,
  ) async {
    final uri = Uri.parse(
      'https://push2.eastmoney.com/api/qt/stock/get'
      '?secid=$secid&fields=f43,f44,f45,f46,f57,f58,f60,f169,f170&fltt=2',
    );
    final body = await _get(uri, headers: const {
      'Referer': 'https://www.eastmoney.com/',
    });

    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw MarketFetchException('eastmoney: no data for $symbol');
    }

    // f43..f170 are 元; convert to 分.
    var currentPrice = _yuanToCents(data['f43']);
    final highPrice = _yuanToCents(data['f44']);
    final lowPrice = _yuanToCents(data['f45']);
    final openPrice = _yuanToCents(data['f46']);
    final prevClose = _yuanToCents(data['f60']);
    final changeAmount = _yuanToCents(data['f169']);
    final changePercent = _toDouble(data['f170']);

    // When the market is closed, current price may be 0 — fall back to prev close.
    if (currentPrice == 0 && prevClose > 0) {
      currentPrice = prevClose;
    }

    final rawName = data['f58'];
    final name = (rawName is String && rawName.isNotEmpty) ? rawName : symbol;

    return MarketQuoteData(
      symbol: symbol,
      name: name,
      marketType: marketType,
      currentPrice: currentPrice,
      changeAmount: changeAmount,
      changePercent: _round2(changePercent),
      open: openPrice,
      high: highPrice,
      low: lowPrice,
      prevClose: prevClose,
    );
  }

  // ── 天天基金 (基金净值) ─────────────────────────────────────────────────────

  Future<MarketQuoteData> _fetchEastMoneyFund(String symbol) async {
    final uri = Uri.parse('https://fundgz.1234567.com.cn/js/$symbol.js');
    final body = await _get(uri, headers: const {
      'Referer': 'https://www.eastmoney.com/',
    });

    // Response is JSONP: jsonpgz({...});
    final start = body.indexOf('(');
    final end = body.lastIndexOf(')');
    if (start < 0 || end < 0 || end <= start) {
      throw MarketFetchException('invalid JSONP response: $body');
    }
    final fund = jsonDecode(body.substring(start + 1, end)) as Map<String, dynamic>;

    final gsz = double.tryParse('${fund['gsz'] ?? ''}') ?? 0; // 估算净值 (元)
    final dwjz = double.tryParse('${fund['dwjz'] ?? ''}') ?? 0; // 上一日净值 (元)

    final currentPrice = (gsz * 100).round();
    final prevClose = (dwjz * 100).round();
    final changeAmount = currentPrice - prevClose;
    final changePercent =
        prevClose > 0 ? changeAmount / prevClose * 100.0 : 0.0;

    final rawName = fund['name'];
    final name = (rawName is String && rawName.isNotEmpty) ? rawName : symbol;

    return MarketQuoteData(
      symbol: symbol,
      name: name,
      marketType: 'fund',
      currentPrice: currentPrice,
      changeAmount: changeAmount,
      changePercent: _round2(changePercent),
      open: prevClose, // 基金无盘中数据, 用昨日净值
      high: currentPrice,
      low: currentPrice,
      prevClose: prevClose,
    );
  }

  // ── Yahoo Finance 美股 ─────────────────────────────────────────────────────

  Future<MarketQuoteData> _fetchYahooQuote(String symbol) async {
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
      '?interval=1d&range=1d',
    );
    final body = await _get(uri, headers: const {
      'User-Agent': 'Mozilla/5.0 (compatible; FamilyLedger/1.0)',
    });

    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = _path(json, ['chart', 'result']);
    if (results is! List || results.isEmpty) {
      throw MarketFetchException('yahoo returned empty result for $symbol');
    }
    final result = results.first as Map<String, dynamic>;
    final meta = result['meta'] as Map<String, dynamic>? ?? const {};

    final currentPrice = (_toDouble(meta['regularMarketPrice']) * 100).round();
    final prevClose = (_toDouble(meta['previousClose']) * 100).round();

    var openPrice = 0, highPrice = 0, lowPrice = 0;
    final quotes = _path(result, ['indicators', 'quote']);
    if (quotes is List && quotes.isNotEmpty) {
      final q = quotes.first as Map<String, dynamic>;
      openPrice = _firstCents(q['open']);
      highPrice = _firstCents(q['high']);
      lowPrice = _firstCents(q['low']);
    }

    final changeAmount = currentPrice - prevClose;
    final changePercent =
        prevClose > 0 ? changeAmount / prevClose * 100.0 : 0.0;

    final rawName = meta['shortName'];
    final name = (rawName is String && rawName.isNotEmpty) ? rawName : symbol;

    return MarketQuoteData(
      symbol: symbol,
      name: name,
      marketType: 'us_stock',
      currentPrice: currentPrice,
      changeAmount: changeAmount,
      changePercent: _round2(changePercent),
      open: openPrice,
      high: highPrice,
      low: lowPrice,
      prevClose: prevClose,
    );
  }

  // ── CoinGecko 加密货币 ──────────────────────────────────────────────────────

  Future<MarketQuoteData> _fetchCoinGeckoQuote(String symbol) async {
    final uri = Uri.parse(
      'https://api.coingecko.com/api/v3/simple/price'
      '?ids=$symbol&vs_currencies=usd&include_24hr_change=true',
    );
    final body = await _get(uri);

    // {"bitcoin": {"usd": 12345.67, "usd_24h_change": -2.5}}
    final json = jsonDecode(body) as Map<String, dynamic>;
    final coin = json[symbol];
    if (coin is! Map<String, dynamic>) {
      throw MarketFetchException('coingecko: no data for "$symbol"');
    }

    final usd = _toDouble(coin['usd']);
    final usd24hChange = _toDouble(coin['usd_24h_change']);

    final currentPrice = (usd * 100).round();
    final changePercent = _round2(usd24hChange);

    // Estimate prevClose from current price and 24h change.
    final prevClose = changePercent != 0
        ? (usd / (1 + usd24hChange / 100) * 100).round()
        : currentPrice;
    final changeAmount = currentPrice - prevClose;

    return MarketQuoteData(
      symbol: symbol,
      name: '$symbol/USD',
      marketType: 'crypto',
      currentPrice: currentPrice,
      changeAmount: changeAmount,
      changePercent: changePercent,
      open: prevClose, // CoinGecko simple API has no OHLC
      high: currentPrice,
      low: currentPrice,
      prevClose: prevClose,
    );
  }

  // ── 贵金属 (Sina) ───────────────────────────────────────────────────────────

  /// Static catalog of supported precious metals (matches the server).
  static const List<SymbolInfoData> preciousMetalList = [
    SymbolInfoData(symbol: 'Au99.99', name: '黄金9999', marketType: 'precious_metal'),
    SymbolInfoData(symbol: 'Au99.95', name: '黄金9995', marketType: 'precious_metal'),
    SymbolInfoData(symbol: 'Au100g', name: '黄金100克', marketType: 'precious_metal'),
    SymbolInfoData(symbol: 'Au(T+D)', name: '黄金T+D', marketType: 'precious_metal'),
    SymbolInfoData(symbol: 'mAu(T+D)', name: '迷你黄金T+D', marketType: 'precious_metal'),
    SymbolInfoData(symbol: 'Ag(T+D)', name: '白银T+D', marketType: 'precious_metal'),
    SymbolInfoData(symbol: 'Pt99.95', name: '铂金9995', marketType: 'precious_metal'),
  ];

  /// Maps our display symbol to the Sina SGE list code (gds_<CODE>).
  static const Map<String, String> _preciousMetalSinaCode = {
    'Au99.99': 'AU9999',
    'Au99.95': 'AU9995',
    'Au100g': 'AU100G',
    'Au(T+D)': 'AUTD',
    'mAu(T+D)': 'MAUTD',
    'Ag(T+D)': 'AGTD',
    'Pt99.95': 'PT9995',
  };

  Future<MarketQuoteData> _fetchPreciousMetal(String symbol) async {
    final code = _preciousMetalSinaCode[symbol];
    if (code == null) {
      throw MarketFetchException('unsupported precious metal symbol: $symbol');
    }

    final uri = Uri.parse('https://hq.sinajs.cn/list=gds_$code');
    // Sina rejects requests without a finance.sina.com.cn Referer; body is GBK.
    final raw = await _getBytes(uri, headers: const {
      'Referer': 'https://finance.sina.com.cn/',
      'User-Agent': 'Mozilla/5.0 (compatible)',
    });
    final body = gbk.decode(raw);
    return parseSinaPreciousMetal(symbol, code, body);
  }

  /// Intentionally synchronous: precious-metal symbols are a fixed local
  /// catalog ([preciousMetalList]), so search is a pure in-memory filter with
  /// no network call. It still satisfies the `Future`-returning [searchSymbol]
  /// switch arm because Dart implicitly wraps the returned list in a Future.
  List<SymbolInfoData> _searchPreciousMetal(String query) {
    final q = query.toLowerCase();
    return preciousMetalList
        .where((pm) =>
            pm.symbol.toLowerCase().contains(q) ||
            pm.name.toLowerCase().contains(q) ||
            pm.name.contains(query))
        .toList();
  }

  // ── Search implementations ──────────────────────────────────────────────

  Future<List<SymbolInfoData>> _searchEastMoney(
    String query,
    String marketType,
  ) async {
    final uri = Uri.parse(
      'https://searchapi.eastmoney.com/api/suggest/get'
      '?input=${Uri.encodeQueryComponent(query)}&type=14&count=10',
    );
    final body = await _get(uri, headers: const {
      'Referer': 'https://www.eastmoney.com/',
    });

    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = _path(json, ['QuotationCodeTable', 'Data']);
    final results = <SymbolInfoData>[];
    if (data is List) {
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final itemMarket = _mktNumToMarketType('${item['MktNum'] ?? ''}');
        if (marketType.isNotEmpty && itemMarket != marketType) continue;
        results.add(SymbolInfoData(
          symbol: '${item['Code'] ?? ''}',
          name: '${item['Name'] ?? ''}',
          marketType: itemMarket,
        ));
      }
    }
    return results;
  }

  static String _mktNumToMarketType(String mktNum) {
    switch (mktNum) {
      case '0':
      case '1':
        return 'a_share';
      case '116':
        return 'hk_stock';
      default:
        return 'a_share';
    }
  }

  Future<List<SymbolInfoData>> _searchYahoo(String query) async {
    final uri = Uri.parse(
      'https://query2.finance.yahoo.com/v1/finance/search'
      '?q=${Uri.encodeQueryComponent(query)}&quotesCount=10&newsCount=0',
    );
    final body = await _get(uri, headers: const {
      'User-Agent': 'Mozilla/5.0 (compatible; FamilyLedger/1.0)',
    });

    final json = jsonDecode(body) as Map<String, dynamic>;
    final quotes = json['quotes'];
    final results = <SymbolInfoData>[];
    if (quotes is List) {
      for (final q in quotes) {
        if (q is! Map<String, dynamic>) continue;
        results.add(SymbolInfoData(
          symbol: '${q['symbol'] ?? ''}',
          name: '${q['shortname'] ?? ''}',
          marketType: 'us_stock',
        ));
      }
    }
    return results;
  }

  Future<List<SymbolInfoData>> _searchCoinGecko(String query) async {
    final uri = Uri.parse(
      'https://api.coingecko.com/api/v3/search'
      '?query=${Uri.encodeQueryComponent(query)}',
    );
    final body = await _get(uri);

    final json = jsonDecode(body) as Map<String, dynamic>;
    final coins = json['coins'];
    final results = <SymbolInfoData>[];
    if (coins is List) {
      for (final c in coins) {
        if (c is! Map<String, dynamic>) continue;
        final coinSymbol = '${c['symbol'] ?? ''}'.toUpperCase();
        results.add(SymbolInfoData(
          symbol: '${c['id'] ?? ''}',
          name: '${c['name'] ?? ''} ($coinSymbol)',
          marketType: 'crypto',
        ));
      }
    }
    return results;
  }

  // ── K-line implementations ────────────────────────────────────────────────

  /// EastMoney daily K-line for a stock/HK secid.
  ///
  /// `fields2=f51,f53` = date,close. `klt=101` daily, `fqt=1` forward-adjusted.
  Future<List<PricePointData>> _fetchEastMoneyKline(
    String secid,
    DateTime start,
    DateTime end,
  ) async {
    final uri = Uri.parse(
      'https://push2his.eastmoney.com/api/qt/stock/kline/get'
      '?secid=$secid&klt=101&fqt=1'
      '&beg=${_ymd(start)}&end=${_ymd(end)}'
      '&fields1=f1&fields2=f51,f53',
    );
    final body = await _get(uri, headers: const {
      'Referer': 'https://www.eastmoney.com/',
    });

    final json = jsonDecode(body) as Map<String, dynamic>;
    final klines = _path(json, ['data', 'klines']);
    final points = <PricePointData>[];
    if (klines is List) {
      for (final line in klines) {
        if (line is! String) continue;
        final parts = line.split(',');
        if (parts.length < 2) continue;
        final ts = DateTime.tryParse(parts[0]);
        final close = double.tryParse(parts[1]);
        if (ts == null || close == null) continue;
        points.add(PricePointData(timestamp: ts, price: (close * 100).round()));
      }
    }
    return points;
  }

  /// Yahoo daily K-line via the chart endpoint, clamped to [start, end].
  Future<List<PricePointData>> _fetchYahooKline(
    String symbol,
    DateTime start,
    DateTime end,
  ) async {
    final period1 = start.toUtc().millisecondsSinceEpoch ~/ 1000;
    final period2 = end.toUtc().millisecondsSinceEpoch ~/ 1000;
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
      '?interval=1d&period1=$period1&period2=$period2',
    );
    final body = await _get(uri, headers: const {
      'User-Agent': 'Mozilla/5.0 (compatible; FamilyLedger/1.0)',
    });

    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = _path(json, ['chart', 'result']);
    if (results is! List || results.isEmpty) return const [];
    final result = results.first as Map<String, dynamic>;

    final timestamps = result['timestamp'];
    final quotes = _path(result, ['indicators', 'quote']);
    if (timestamps is! List || quotes is! List || quotes.isEmpty) {
      return const [];
    }
    final closes = (quotes.first as Map<String, dynamic>)['close'];
    if (closes is! List) return const [];

    final points = <PricePointData>[];
    for (var i = 0; i < timestamps.length && i < closes.length; i++) {
      final tsSec = timestamps[i];
      final close = closes[i];
      if (tsSec is! num || close is! num) continue; // null gaps in series
      points.add(PricePointData(
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(tsSec.toInt() * 1000, isUtc: true),
        price: (close.toDouble() * 100).round(),
      ));
    }
    return points;
  }

  /// CoinGecko market-chart daily prices for the [start, end] window.
  Future<List<PricePointData>> _fetchCoinGeckoKline(
    String symbol,
    DateTime start,
    DateTime end,
  ) async {
    final days = end.difference(start).inDays.clamp(1, 3650);
    final uri = Uri.parse(
      'https://api.coingecko.com/api/v3/coins/$symbol/market_chart'
      '?vs_currency=usd&days=$days&interval=daily',
    );
    final body = await _get(uri);

    final json = jsonDecode(body) as Map<String, dynamic>;
    final prices = json['prices'];
    final points = <PricePointData>[];
    if (prices is List) {
      for (final p in prices) {
        if (p is! List || p.length < 2) continue;
        final ms = p[0];
        final price = p[1];
        if (ms is! num || price is! num) continue;
        points.add(PricePointData(
          timestamp:
              DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
          price: (price.toDouble() * 100).round(),
        ));
      }
    }
    return points;
  }

  // ── HTTP helpers ──────────────────────────────────────────────────────────

  /// Fetches [uri] and decodes the body as **strict** UTF-8.
  ///
  /// Strict (no `allowMalformed`) is deliberate: every JSON source routed
  /// through here (EastMoney / Yahoo / CoinGecko) serves UTF-8, so malformed
  /// bytes mean the response is corrupt or not what we expect. We want that to
  /// surface as a [MarketFetchException] rather than be silently rewritten to
  /// U+FFFD and then fail later with a confusing parse error. The GBK-encoded
  /// Sina precious-metal source does NOT go through here — it calls [_getBytes]
  /// directly and decodes with `gbk.decode`.
  Future<String> _get(Uri uri, {Map<String, String>? headers}) async {
    final bytes = await _getBytes(uri, headers: headers);
    try {
      return utf8.decode(bytes); // strict: throws on malformed bytes
    } on FormatException catch (e) {
      throw MarketFetchException('GET ${uri.host} returned non-UTF-8 body: $e');
    }
  }

  Future<List<int>> _getBytes(Uri uri, {Map<String, String>? headers}) async {
    final resp = await _client.get(uri, headers: headers).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw _statusException(uri, resp.statusCode);
    }
    return resp.bodyBytes;
  }

  /// Builds a [MarketFetchException] for a non-200 status, attaching extra
  /// context for the two statuses our upstreams use to signal a specific
  /// problem so callers / logs can distinguish them from a generic failure:
  ///
  ///   - **429** — rate limited. CoinGecko's free tier allows only ~10–30
  ///     req/min (see the CoinGecko fetch/search/kline methods); a burst of
  ///     quote refreshes can trip it. Surface it clearly instead of crashing.
  ///   - **403** — forbidden. Yahoo's v8/v1 endpoints increasingly require a
  ///     consent cookie / crumb; a bare 403 from a `*.finance.yahoo.com` host
  ///     almost always means that, not a bad symbol.
  static MarketFetchException _statusException(Uri uri, int status) {
    final host = uri.host;
    switch (status) {
      case 429:
        return MarketFetchException(
          'GET $host rate-limited (HTTP 429) — upstream request quota '
          'exceeded (CoinGecko free tier is ~10-30 req/min); retry later',
        );
      case 403:
        if (host.endsWith('finance.yahoo.com')) {
          return MarketFetchException(
            'GET $host forbidden (HTTP 403) — Yahoo now requires a consent '
            'cookie / crumb; this symbol cannot be fetched anonymously',
          );
        }
        return MarketFetchException('GET $host forbidden (HTTP 403)');
      default:
        return MarketFetchException('GET $host returned status $status');
    }
  }

  // ── Parsing helpers ─────────────────────────────────────────────────────────

  /// Walks nested maps following [keys], returning the value or null.
  static dynamic _path(dynamic node, List<String> keys) {
    for (final k in keys) {
      if (node is Map<String, dynamic>) {
        node = node[k];
      } else {
        return null;
      }
    }
    return node;
  }

  /// Parses a JSON number (num or numeric String) to double, defaulting to 0.
  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  /// Converts a 元 value (num or numeric String) to int 分.
  static int _yuanToCents(dynamic v) => (_toDouble(v) * 100).round();

  /// First element of a numeric list, in 分; 0 if absent/null.
  static int _firstCents(dynamic list) {
    if (list is List && list.isNotEmpty && list.first is num) {
      return ((list.first as num).toDouble() * 100).round();
    }
    return 0;
  }

  /// Rounds a percentage to 2 decimals, matching the server's `Round(x*100)/100`.
  static double _round2(double v) => (v * 100).round() / 100;

  /// Formats a date as YYYYMMDD for EastMoney K-line `beg`/`end` params.
  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
}

// ── Sina precious-metal parsing (split out for testability) ─────────────────

/// Sina gds_ payload field indices (comma-separated), verified against
/// EastMoney kline history (see server fetcher.go).
const int _sinaIdxPrice = 0; // current price (元/克)
const int _sinaIdxHigh = 4; // intraday high
const int _sinaIdxLow = 5; // intraday low
const int _sinaIdxPrevClose = 7; // previous close (drives change)
const int _sinaIdxOpen = 8; // open
const int _sinaIdxName = 13; // product name
const int _sinaFieldCount = 14; // minimum field count required

/// Parses a UTF-8 (already GBK-decoded) Sina `gds_` line into a quote.
///
/// Response shape: `var hq_str_gds_AU9999="937.52,0,938.50,...,沪金99";`
MarketQuoteData parseSinaPreciousMetal(String symbol, String code, String body) {
  final start = body.indexOf('"');
  final end = body.lastIndexOf('"');
  if (start < 0 || end <= start) {
    throw MarketFetchException('$symbol: unexpected sina response: $body');
  }
  final payload = body.substring(start + 1, end);
  if (payload.isEmpty) {
    throw MarketFetchException(
      '$symbol: sina returned empty quote (delisted or wrong code "$code")',
    );
  }

  final fields = payload.split(',');
  if (fields.length < _sinaFieldCount) {
    throw MarketFetchException(
      '$symbol: sina payload has ${fields.length} fields '
      '(expected >=$_sinaFieldCount): $payload',
    );
  }

  final price = double.tryParse(fields[_sinaIdxPrice].trim());
  if (price == null) {
    throw MarketFetchException(
      '$symbol: parse current price "${fields[_sinaIdxPrice]}"',
    );
  }
  if (price <= 0) {
    throw MarketFetchException('$symbol: sina returned non-positive price $price');
  }

  // prevClose drives change; a parse failure is a hard error (a silent 0 would
  // render as a bogus "zero change" instead of surfacing malformed data).
  final prevClose = double.tryParse(fields[_sinaIdxPrevClose].trim());
  if (prevClose == null) {
    throw MarketFetchException(
      '$symbol: parse prev close "${fields[_sinaIdxPrevClose]}"',
    );
  }

  var changeAmount = 0.0;
  var changePercent = 0.0;
  if (prevClose > 0) {
    changeAmount = price - prevClose;
    changePercent = changeAmount / prevClose * 100;
  }

  var name = fields[_sinaIdxName].trim();
  if (name.isEmpty) {
    for (final pm in MarketFetcher.preciousMetalList) {
      if (pm.symbol == symbol) {
        name = pm.name;
        break;
      }
    }
  }

  // open/high/low are informational; tolerate parse failures (default 0).
  final open = double.tryParse(fields[_sinaIdxOpen].trim()) ?? 0;
  final high = double.tryParse(fields[_sinaIdxHigh].trim()) ?? 0;
  final low = double.tryParse(fields[_sinaIdxLow].trim()) ?? 0;

  return MarketQuoteData(
    symbol: symbol,
    name: name,
    marketType: 'precious_metal',
    currentPrice: (price * 100).round(),
    changeAmount: (changeAmount * 100).round(),
    changePercent: changePercent,
    open: (open * 100).round(),
    high: (high * 100).round(),
    low: (low * 100).round(),
    prevClose: (prevClose * 100).round(),
  );
}

/// Thrown by [MarketFetcher] on any upstream/parse failure.
class MarketFetchException implements Exception {
  final String message;
  const MarketFetchException(this.message);
  @override
  String toString() => 'MarketFetchException: $message';
}
