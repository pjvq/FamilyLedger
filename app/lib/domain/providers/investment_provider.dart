import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import 'package:drift/drift.dart' show Value;
import '../../data/local/database.dart' as db;
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/investment.pb.dart' as pb;
import '../../generated/proto/investment.pbgrpc.dart';
import '../../generated/proto/investment.pbenum.dart' as pb_enum;
import '../../generated/proto/google/protobuf/timestamp.pb.dart' as ts_pb;
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
  }) =>
      InvestmentState(
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
  final String? _userId;
  final String? _familyId;

  InvestmentNotifier(this._db, this._investmentClient, this._userId, this._familyId)
      : super(const InvestmentState()) {
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
      final resp =
          await _investmentClient.listInvestments(invReq);
      for (final inv in resp.investments) {
        await _db.upsertInvestment(db.InvestmentsCompanion.insert(
          id: inv.id,
          userId: inv.userId,
          familyId: Value(inv.familyId),
          symbol: inv.symbol,
          name: inv.name,
          marketType: _marketTypeToString(inv.marketType),
          quantity: Value(inv.quantity),
          costBasis: Value(inv.costBasis.toInt()),
        ));
      }
    } catch (_) {
      // Offline fallback
    }

    try {
      final investments = await _db.getInvestments(_userId, familyId: _familyId);
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
      final resp =
          await _investmentClient.createInvestment(pb.CreateInvestmentRequest()
            ..symbol = symbol
            ..name = name
            ..marketType = _stringToMarketType(marketType)
            ..familyId = familyId ?? '');
      invId = resp.id;

      await _db.upsertInvestment(db.InvestmentsCompanion.insert(
        id: resp.id,
        userId: resp.userId,
        familyId: Value(familyId ?? ''),
        symbol: resp.symbol,
        name: resp.name,
        marketType: _marketTypeToString(resp.marketType),
        quantity: Value(resp.quantity),
        costBasis: Value(resp.costBasis.toInt()),
      ));
    } catch (_) {
      // Offline: save locally
      await _db.upsertInvestment(db.InvestmentsCompanion.insert(
        id: invId,
        userId: _userId,
        familyId: Value(familyId ?? ''),
        symbol: symbol,
        name: name,
        marketType: marketType,
      ));
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

    final totalAmount = (quantity * price).round() + (tradeType == 'buy' ? fee : -fee);
    String tradeId = const Uuid().v4();

    try {
      final resp =
          await _investmentClient.recordTrade(pb.RecordTradeRequest()
            ..investmentId = investmentId
            ..tradeType = _stringToTradeType(tradeType)
            ..quantity = quantity
            ..price = Int64(price)
            ..fee = Int64(fee)
            ..tradeDate = _toTimestamp(tradeDate));
      tradeId = resp.id;
    } catch (_) {
      // Offline
    }

    await _db.insertInvestmentTrade(db.InvestmentTradesCompanion.insert(
      id: tradeId,
      investmentId: investmentId,
      tradeType: tradeType,
      quantity: quantity,
      price: price,
      totalAmount: totalAmount,
      tradeDate: tradeDate,
      fee: Value(fee),
    ));

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
    }

    await listInvestments();
  }

  /// Load trades for a specific investment
  Future<void> loadTrades(String investmentId) async {
    try {
      await _investmentClient
          .listTrades(pb.ListTradesRequest()..investmentId = investmentId);
      // We don't persist trades from server in batch for simplicity;
      // just use the local trades
    } catch (_) {}

    final trades = await _db.getInvestmentTrades(investmentId);
    state = state.copyWith(currentTrades: trades);
  }

  /// Delete an investment
  Future<void> deleteInvestment(String investmentId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _investmentClient.deleteInvestment(
          pb.DeleteInvestmentRequest()..investmentId = investmentId);
    } catch (_) {}

    await _db.softDeleteInvestment(investmentId);
    await listInvestments();
  }

  /// Compute portfolio summary from local data
  Future<PortfolioSummary> _computePortfolio(
      List<db.Investment> investments) async {
    if (investments.isEmpty) return const PortfolioSummary();

    int totalValue = 0;
    int totalCost = 0;
    final holdings = <HoldingDisplayItem>[];

    for (final inv in investments) {
      // Try to get cached quote
      final quote = await _db.getMarketQuote(inv.symbol, inv.marketType);
      final price = quote?.currentPrice ?? 0;
      final value = (inv.quantity * price).round();

      totalValue += value;
      totalCost += inv.costBasis;

      holdings.add(HoldingDisplayItem(
        investmentId: inv.id,
        symbol: inv.symbol,
        name: inv.name,
        quantity: inv.quantity,
        currentValue: value,
        weight: 0, // computed below
        returnRate: inv.costBasis > 0
            ? (value - inv.costBasis) / inv.costBasis
            : 0.0,
      ));
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
  static double annualizedReturn(
      {required int costBasis,
      required int currentValue,
      required DateTime firstTradeDate}) {
    if (costBasis <= 0) return 0.0;
    final years =
        DateTime.now().difference(firstTradeDate).inDays / 365.25;
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
  final userId = ref.watch(currentUserIdProvider);
  final familyId = ref.watch(currentFamilyIdProvider);
  return InvestmentNotifier(database, client, userId, familyId);
});
