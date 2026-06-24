import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io' show SocketException;
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:drift/drift.dart' show Value;
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/investment.pb.dart' as pb;
import '../../generated/proto/investment.pbgrpc.dart';
import '../../generated/proto/investment.pbenum.dart' as pb_enum;
import '../../generated/proto/google/protobuf/timestamp.pb.dart' as ts_pb;
import '../../sync/sync_engine.dart';
import '../services/offline_sync_queue.dart';
import 'transaction_provider.dart' show offlineSyncQueueProvider;
import 'app_providers.dart';

// ── Portfolio display models ──

class PortfolioSummary {
  final int totalValue; // 分
  final int totalCost; // 分
  final int totalProfit; // 分
  final double totalReturn;
  final List<HoldingDisplayItem> holdings;

  const PortfolioSummary({
    this.totalValue = 0,
    this.totalCost = 0,
    this.totalProfit = 0,
    this.totalReturn = 0.0,
    this.holdings = const [],
  });
}

class HoldingDisplayItem {
  final String investmentId;
  final String symbol;
  final String name;
  final double quantity;
  final int currentValue; // 分
  final double weight; // 0–1
  final double returnRate;

  const HoldingDisplayItem({
    required this.investmentId,
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.currentValue,
    required this.weight,
    required this.returnRate,
  });
}

// ── State ──

class InvestmentState {
  final List<db.Investment> investments;
  final PortfolioSummary portfolio;
  final List<db.InvestmentTrade> currentTrades;
  final bool isLoading;
  final String? error;

  const InvestmentState({
    this.investments = const [],
    this.portfolio = const PortfolioSummary(),
    this.currentTrades = const [],
    this.isLoading = false,
    this.error,
  });

  InvestmentState copyWith({
    List<db.Investment>? investments,
    PortfolioSummary? portfolio,
    List<db.InvestmentTrade>? currentTrades,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => InvestmentState(
    investments: investments ?? this.investments,
    portfolio: portfolio ?? this.portfolio,
    currentTrades: currentTrades ?? this.currentTrades,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

// ── Proto helpers ──

String _marketTypeToString(pb_enum.MarketType type) {
  switch (type) {
    case pb_enum.MarketType.MARKET_TYPE_A_SHARE:
      return 'a_share';
    case pb_enum.MarketType.MARKET_TYPE_HK_STOCK:
      return 'hk_stock';
    case pb_enum.MarketType.MARKET_TYPE_US_STOCK:
      return 'us_stock';
    case pb_enum.MarketType.MARKET_TYPE_CRYPTO:
      return 'crypto';
    case pb_enum.MarketType.MARKET_TYPE_FUND:
      return 'fund';
    case pb_enum.MarketType.MARKET_TYPE_PRECIOUS_METAL:
      return 'precious_metal';
    default:
      return 'a_share';
  }
}

pb_enum.MarketType _stringToMarketType(String type) {
  switch (type) {
    case 'a_share':
      return pb_enum.MarketType.MARKET_TYPE_A_SHARE;
    case 'hk_stock':
      return pb_enum.MarketType.MARKET_TYPE_HK_STOCK;
    case 'us_stock':
      return pb_enum.MarketType.MARKET_TYPE_US_STOCK;
    case 'crypto':
      return pb_enum.MarketType.MARKET_TYPE_CRYPTO;
    case 'fund':
      return pb_enum.MarketType.MARKET_TYPE_FUND;
    case 'precious_metal':
      return pb_enum.MarketType.MARKET_TYPE_PRECIOUS_METAL;
    default:
      return pb_enum.MarketType.MARKET_TYPE_A_SHARE;
  }
}

pb_enum.TradeType _stringToTradeType(String type) {
  switch (type) {
    case 'sell':
      return pb_enum.TradeType.TRADE_TYPE_SELL;
    default:
      return pb_enum.TradeType.TRADE_TYPE_BUY;
  }
}

ts_pb.Timestamp _toTimestamp(DateTime dt) {
  final seconds = dt.millisecondsSinceEpoch ~/ 1000;
  return ts_pb.Timestamp(seconds: Int64(seconds));
}

DateTime _fromTimestamp(ts_pb.Timestamp ts) =>
    DateTime.fromMillisecondsSinceEpoch(
      ts.seconds.toInt() * 1000 + (ts.nanos ~/ 1000000),
      isUtc: true,
    ).toLocal();

/// Whether a failed RPC should be treated as "offline" and queued for later
/// push. Fail-closed: only errors we can positively identify as transient
/// connectivity failures qualify. Everything else (business rejections like
/// already-exists / invalid-argument / permission-denied / unauthenticated,
/// AND unexpected non-gRPC errors such as serialization/assertion/local-DB
/// failures) must NOT be queued — queuing them produces orphan sync ops that
/// resurrect as "ghost" rows on every fresh device pull (the server applies
/// the create via ON CONFLICT, so the op sticks even though the original RPC
/// was a hard rejection or never a real network failure).
bool _isOfflineError(Object e) {
  if (e is GrpcError) {
    switch (e.code) {
      case StatusCode.unavailable:
      case StatusCode.deadlineExceeded:
      case StatusCode.resourceExhausted:
      case StatusCode.aborted:
      // cancelled: RPC torn down by app backgrounding / connection drop —
      // a transient condition that should be retried, not surfaced as a
      // hard error to the user.
      case StatusCode.cancelled:
        return true;
      default:
        return false;
    }
  }
  // Raw socket / TLS / timeout exceptions surface as non-gRPC errors on some
  // platforms; these ARE connectivity failures and should be queued.
  if (e is SocketException || e is TimeoutException) {
    return true;
  }
  // Unknown error type → fail-closed: do not queue, surface to UI.
  return false;
}

String _tradeTypeToString(pb_enum.TradeType type) {
  switch (type) {
    case pb_enum.TradeType.TRADE_TYPE_SELL:
      return 'sell';
    default:
      return 'buy';
  }
}

// ── Market type display labels ──

const marketTypeLabels = {
  'a_share': 'A股',
  'hk_stock': '港股',
  'us_stock': '美股',
  'crypto': '加密货币',
  'fund': '基金',
  'precious_metal': '贵金属',
};

String marketTypeLabel(String type) => marketTypeLabels[type] ?? type;

// ── Notifier ──

class InvestmentNotifier extends StateNotifier<InvestmentState> {
  final db.AppDatabase _db;
  final InvestmentServiceClient _investmentClient;
  final OfflineSyncQueue _syncQueue;
  final String? _userId;
  final String? _familyId;

  InvestmentNotifier(
    this._db,
    this._investmentClient,
    this._syncQueue,
    this._userId,
    this._familyId,
  ) : super(const InvestmentState()) {
    if (_userId != null) {
      listInvestments();
    }
  }

  /// List all investments (gRPC first, local fallback)
  Future<void> listInvestments() async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final invReq = pb.ListInvestmentsRequest();
      if (_familyId != null && _familyId.isNotEmpty) {
        invReq.familyId = _familyId;
      }
      final resp = await _investmentClient.listInvestments(invReq);
      for (final inv in resp.investments) {
        await _db.upsertInvestment(
          db.InvestmentsCompanion.insert(
            id: inv.id,
            userId: inv.userId,
            familyId: Value(inv.familyId),
            symbol: inv.symbol,
            name: inv.name,
            marketType: _marketTypeToString(inv.marketType),
            quantity: Value(inv.quantity),
            costBasis: Value(inv.costBasis.toInt()),
          ),
        );
      }
    } catch (_) {
      // Offline fallback
    }

    try {
      final investments = await _db.getInvestments(
        _userId,
        familyId: _familyId,
      );
      final portfolio = await _computePortfolio(investments);
      state = state.copyWith(
        investments: investments,
        portfolio: portfolio,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new investment holding
  Future<void> createInvestment({
    required String symbol,
    required String name,
    required String marketType,
    String? familyId,
  }) async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);

    String invId = const Uuid().v4();

    try {
      final resp = await _investmentClient.createInvestment(
        pb.CreateInvestmentRequest()
          ..symbol = symbol
          ..name = name
          ..marketType = _stringToMarketType(marketType)
          ..familyId = familyId ?? '',
      );
      invId = resp.id;

      await _db.upsertInvestment(
        db.InvestmentsCompanion.insert(
          id: resp.id,
          userId: resp.userId,
          familyId: Value(familyId ?? ''),
          symbol: resp.symbol,
          name: resp.name,
          marketType: _marketTypeToString(resp.marketType),
          quantity: Value(resp.quantity),
          costBasis: Value(resp.costBasis.toInt()),
        ),
      );
    } catch (e) {
      // Business rejection (already-exists / invalid / permission / auth)
      // must NOT be queued — doing so creates an orphan create op that
      // resurrects as a ghost row on the next device pull. Surface it to UI.
      if (!_isOfflineError(e)) {
        dev.log(
          'createInvestment: rejected by server, not queuing: $e',
          name: 'investment',
        );
        state = state.copyWith(isLoading: false, error: e.toString());
        rethrow;
      }
      // Offline: save locally + enqueue create for later push.
      // Without enqueue, the holding would only live in Drift and be lost on
      // logout (clearAllData) since it was never uploaded to the server.
      final fid = familyId ?? '';
      await _db.upsertInvestment(
        db.InvestmentsCompanion.insert(
          id: invId,
          userId: _userId,
          familyId: Value(fid),
          symbol: symbol,
          name: name,
          marketType: marketType,
        ),
      );

      // Payload MUST match server investmentPayload (entity_ops.go): only
      // symbol/name/market_type/quantity/cost_basis are decoded; id & family_id
      // are NOT fields on the struct and would be silently dropped.
      //
      // We deliberately omit quantity/cost_basis here: the server create path
      // does NOT overwrite them on ON CONFLICT (it only re-establishes the
      // holding container), and a brand-new holding starts at 0 via the INSERT
      // default. Position size is established by the subsequent trade/update
      // op, never by a placeholder in the create payload.
      dev.log(
        'createInvestment: offline, queueing create: $e',
        name: 'investment',
      );
      await _syncQueue.enqueueCreate(
        entityType: 'investment',
        entityId: invId,
        payload: {'symbol': symbol, 'name': name, 'market_type': marketType},
      );
    }

    await listInvestments();
  }

  /// Record a buy/sell trade
  Future<void> recordTrade({
    required String investmentId,
    required String tradeType, // 'buy' / 'sell'
    required double quantity,
    required int price, // 分/股
    required int fee,
    required DateTime tradeDate,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final totalAmount =
        (quantity * price).round() + (tradeType == 'buy' ? fee : -fee);
    String tradeId = const Uuid().v4();
    bool syncedToServer = false;

    try {
      final resp = await _investmentClient.recordTrade(
        pb.RecordTradeRequest()
          ..investmentId = investmentId
          ..tradeType = _stringToTradeType(tradeType)
          ..quantity = quantity
          ..price = Int64(price)
          ..fee = Int64(fee)
          ..tradeDate = _toTimestamp(tradeDate),
      );
      tradeId = resp.id;
      syncedToServer = true;
    } catch (e) {
      // Business rejection must surface to UI and must NOT be queued.
      if (!_isOfflineError(e)) {
        dev.log(
          'recordTrade: rejected by server, not queuing: $e',
          name: 'investment',
        );
        state = state.copyWith(isLoading: false, error: e.toString());
        rethrow;
      }
      // Offline — recorded locally below, queued after local state is updated.
      dev.log(
        'recordTrade: gRPC failed, will queue investment update: $e',
        name: 'investment',
      );
    }

    await _db.insertInvestmentTrade(
      db.InvestmentTradesCompanion.insert(
        id: tradeId,
        investmentId: investmentId,
        tradeType: tradeType,
        quantity: quantity,
        price: price,
        totalAmount: totalAmount,
        tradeDate: tradeDate,
        fee: Value(fee),
      ),
    );

    // Update local investment quantity/costBasis
    final investment = await _db.getInvestmentById(investmentId);
    if (investment != null) {
      double newQty = investment.quantity;
      int newCost = investment.costBasis;
      if (tradeType == 'buy') {
        newQty += quantity;
        newCost += totalAmount;
      } else {
        newQty -= quantity;
        // Proportional cost reduction
        if (investment.quantity > 0) {
          final costPerUnit = investment.costBasis / investment.quantity;
          newCost -= (costPerUnit * quantity).round();
        }
      }
      if (newQty < 0) newQty = 0;
      if (newCost < 0) newCost = 0;

      await _db.updateInvestmentFields(
        investmentId,
        db.InvestmentsCompanion(
          quantity: Value(newQty),
          costBasis: Value(newCost),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Trade sync strategy: the server sync engine has NO 'trade' entity —
      // trades only reach the server via the live recordTrade RPC. When that
      // RPC fails (offline), we converge by enqueuing an investment UPDATE
      // carrying the recomputed quantity + cost_basis so the holding state
      // still propagates once connectivity returns.
      //
      // Payload only carries fields on server investmentPayload (entity_ops.go):
      // name/quantity/cost_basis. (symbol/market_type are immutable identity and
      // not updatable; id/family_id are not struct fields.) Full liquidation
      // (newQty == 0) now persists correctly: the server uses pointer fields to
      // distinguish absent from explicit-zero, so 0 is written rather than
      // dropped by the old `!= 0` guard.
      if (!syncedToServer) {
        await _syncQueue.enqueueUpdate(
          entityType: 'investment',
          entityId: investmentId,
          payload: {
            'name': investment.name,
            'quantity': newQty,
            'cost_basis': newCost,
          },
        );
      }
    }

    await listInvestments();
  }

  /// Load trades for a specific investment
  Future<void> loadTrades(String investmentId) async {
    // Trades are NOT part of the offline sync op-log (the server sync engine has
    // no 'trade' entity), so after logout/clearAllData the local Drift copy is
    // gone. The ListTrades RPC is the only way to recover them — so we must
    // persist the server response back into Drift, not discard it.
    try {
      final resp = await _investmentClient.listTrades(
        pb.ListTradesRequest()..investmentId = investmentId,
      );
      for (final t in resp.trades) {
        await _db.upsertInvestmentTrade(
          db.InvestmentTradesCompanion.insert(
            id: t.id,
            investmentId: t.investmentId,
            tradeType: _tradeTypeToString(t.tradeType),
            quantity: t.quantity,
            price: t.price.toInt(),
            totalAmount: t.totalAmount.toInt(),
            tradeDate: _fromTimestamp(t.tradeDate),
            fee: Value(t.fee.toInt()),
          ),
        );
      }
    } catch (e) {
      // Offline or RPC failure: fall back to whatever is in local Drift.
      dev.log(
        'loadTrades: ListTrades RPC failed, using local trades: $e',
        name: 'investment',
      );
    }

    final trades = await _db.getInvestmentTrades(investmentId);
    state = state.copyWith(currentTrades: trades);
  }

  /// Delete an investment
  Future<void> deleteInvestment(String investmentId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _investmentClient.deleteInvestment(
        pb.DeleteInvestmentRequest()..investmentId = investmentId,
      );
    } catch (e) {
      // Business rejection (e.g. permission denied) must NOT be queued and must
      // not soft-delete locally — surface to UI instead.
      if (!_isOfflineError(e)) {
        dev.log(
          'deleteInvestment: rejected by server, not queuing: $e',
          name: 'investment',
        );
        state = state.copyWith(isLoading: false, error: e.toString());
        rethrow;
      }
      // Offline: soft-delete locally below + enqueue delete for later push.
      dev.log(
        'deleteInvestment: gRPC failed, queueing delete: $e',
        name: 'investment',
      );
      await _syncQueue.enqueueDelete(
        entityType: 'investment',
        entityId: investmentId,
      );
    }

    await _db.softDeleteInvestment(investmentId);
    await listInvestments();
  }

  /// Compute portfolio summary from local data
  Future<PortfolioSummary> _computePortfolio(
    List<db.Investment> investments,
  ) async {
    if (investments.isEmpty) return const PortfolioSummary();

    int totalValue = 0;
    int totalCost = 0;
    final holdings = <HoldingDisplayItem>[];

    for (final inv in investments) {
      // Try to get cached quote
      final quote = await _db.getMarketQuote(inv.symbol, inv.marketType);
      final price = quote?.currentPrice ?? 0;
      // Fallback: if no market price, use cost basis as estimated value
      final value = price > 0 ? (inv.quantity * price).round() : inv.costBasis;

      totalValue += value;
      totalCost += inv.costBasis;

      holdings.add(
        HoldingDisplayItem(
          investmentId: inv.id,
          symbol: inv.symbol,
          name: inv.name,
          quantity: inv.quantity,
          currentValue: value,
          weight: 0, // computed below
          returnRate: inv.costBasis > 0
              ? (value - inv.costBasis) / inv.costBasis
              : 0.0,
        ),
      );
    }

    // Compute weights
    final withWeights = holdings.map((h) {
      return HoldingDisplayItem(
        investmentId: h.investmentId,
        symbol: h.symbol,
        name: h.name,
        quantity: h.quantity,
        currentValue: h.currentValue,
        weight: totalValue > 0 ? h.currentValue / totalValue : 0.0,
        returnRate: h.returnRate,
      );
    }).toList();

    final totalProfit = totalValue - totalCost;
    final totalReturn = totalCost > 0 ? totalProfit / totalCost : 0.0;

    return PortfolioSummary(
      totalValue: totalValue,
      totalCost: totalCost,
      totalProfit: totalProfit,
      totalReturn: totalReturn,
      holdings: withWeights,
    );
  }

  /// Compute annualized return
  static double annualizedReturn({
    required int costBasis,
    required int currentValue,
    required DateTime firstTradeDate,
  }) {
    if (costBasis <= 0) return 0.0;
    final years = DateTime.now().difference(firstTradeDate).inDays / 365.25;
    if (years <= 0) return 0.0;
    final totalReturn = (currentValue - costBasis) / costBasis;
    // (1 + R)^(1/years) - 1
    return math.pow(1 + totalReturn, 1 / years) - 1;
  }
}

// ── Provider ──

final investmentProvider =
    StateNotifierProvider<InvestmentNotifier, InvestmentState>((ref) {
      final database = ref.watch(databaseProvider);
      final client = ref.watch(investmentClientProvider);
      final syncQueue = ref.watch(offlineSyncQueueProvider);
      final userId = ref.watch(currentUserIdProvider);
      final familyId = ref.watch(currentFamilyIdProvider);
      final notifier = InvestmentNotifier(
        database,
        client,
        syncQueue,
        userId,
        familyId,
      );

      // Forward sync queue notifications to SyncEngine so a freshly enqueued
      // investment op triggers an immediate push attempt (same pattern as
      // transactionProvider).
      StreamSubscription<void>? syncSub;
      syncSub = syncQueue.onEnqueued.listen((_) {
        try {
          final engine = ref.read(syncEngineProvider);
          unawaited(
            engine.syncNow().catchError(
              (Object e, StackTrace st) => dev.log(
                'SyncEngine.syncNow() failed: $e',
                name: 'investment',
              ),
            ),
          );
        } on StateError catch (_) {}
      });
      ref.onDispose(() => syncSub?.cancel());

      return notifier;
    });
