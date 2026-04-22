//
//  Generated code. Do not modify.
//  source: investment.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'google/protobuf/timestamp.pb.dart' as $2;
import 'investment.pbenum.dart';

export 'investment.pbenum.dart';

class Investment extends $pb.GeneratedMessage {
  factory Investment({
    $core.String? id,
    $core.String? userId,
    $core.String? symbol,
    $core.String? name,
    MarketType? marketType,
    $core.double? quantity,
    $fixnum.Int64? costBasis,
    $fixnum.Int64? currentValue,
    $core.double? totalReturn,
    $core.double? annualizedReturn,
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (symbol != null) {
      $result.symbol = symbol;
    }
    if (name != null) {
      $result.name = name;
    }
    if (marketType != null) {
      $result.marketType = marketType;
    }
    if (quantity != null) {
      $result.quantity = quantity;
    }
    if (costBasis != null) {
      $result.costBasis = costBasis;
    }
    if (currentValue != null) {
      $result.currentValue = currentValue;
    }
    if (totalReturn != null) {
      $result.totalReturn = totalReturn;
    }
    if (annualizedReturn != null) {
      $result.annualizedReturn = annualizedReturn;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    if (updatedAt != null) {
      $result.updatedAt = updatedAt;
    }
    return $result;
  }
  Investment._() : super();
  factory Investment.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Investment.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Investment', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'symbol')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..e<MarketType>(5, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..a<$core.double>(6, _omitFieldNames ? '' : 'quantity', $pb.PbFieldType.OD)
    ..aInt64(7, _omitFieldNames ? '' : 'costBasis')
    ..aInt64(8, _omitFieldNames ? '' : 'currentValue')
    ..a<$core.double>(9, _omitFieldNames ? '' : 'totalReturn', $pb.PbFieldType.OD)
    ..a<$core.double>(10, _omitFieldNames ? '' : 'annualizedReturn', $pb.PbFieldType.OD)
    ..aOM<$2.Timestamp>(11, _omitFieldNames ? '' : 'createdAt', subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(12, _omitFieldNames ? '' : 'updatedAt', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Investment clone() => Investment()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Investment copyWith(void Function(Investment) updates) => super.copyWith((message) => updates(message as Investment)) as Investment;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Investment create() => Investment._();
  Investment createEmptyInstance() => create();
  static $pb.PbList<Investment> createRepeated() => $pb.PbList<Investment>();
  @$core.pragma('dart2js:noInline')
  static Investment getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Investment>(create);
  static Investment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get symbol => $_getSZ(2);
  @$pb.TagNumber(3)
  set symbol($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSymbol() => $_has(2);
  @$pb.TagNumber(3)
  void clearSymbol() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => clearField(4);

  @$pb.TagNumber(5)
  MarketType get marketType => $_getN(4);
  @$pb.TagNumber(5)
  set marketType(MarketType v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasMarketType() => $_has(4);
  @$pb.TagNumber(5)
  void clearMarketType() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get quantity => $_getN(5);
  @$pb.TagNumber(6)
  set quantity($core.double v) { $_setDouble(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasQuantity() => $_has(5);
  @$pb.TagNumber(6)
  void clearQuantity() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get costBasis => $_getI64(6);
  @$pb.TagNumber(7)
  set costBasis($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasCostBasis() => $_has(6);
  @$pb.TagNumber(7)
  void clearCostBasis() => clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get currentValue => $_getI64(7);
  @$pb.TagNumber(8)
  set currentValue($fixnum.Int64 v) { $_setInt64(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasCurrentValue() => $_has(7);
  @$pb.TagNumber(8)
  void clearCurrentValue() => clearField(8);

  @$pb.TagNumber(9)
  $core.double get totalReturn => $_getN(8);
  @$pb.TagNumber(9)
  set totalReturn($core.double v) { $_setDouble(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasTotalReturn() => $_has(8);
  @$pb.TagNumber(9)
  void clearTotalReturn() => clearField(9);

  @$pb.TagNumber(10)
  $core.double get annualizedReturn => $_getN(9);
  @$pb.TagNumber(10)
  set annualizedReturn($core.double v) { $_setDouble(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasAnnualizedReturn() => $_has(9);
  @$pb.TagNumber(10)
  void clearAnnualizedReturn() => clearField(10);

  @$pb.TagNumber(11)
  $2.Timestamp get createdAt => $_getN(10);
  @$pb.TagNumber(11)
  set createdAt($2.Timestamp v) { setField(11, v); }
  @$pb.TagNumber(11)
  $core.bool hasCreatedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearCreatedAt() => clearField(11);
  @$pb.TagNumber(11)
  $2.Timestamp ensureCreatedAt() => $_ensure(10);

  @$pb.TagNumber(12)
  $2.Timestamp get updatedAt => $_getN(11);
  @$pb.TagNumber(12)
  set updatedAt($2.Timestamp v) { setField(12, v); }
  @$pb.TagNumber(12)
  $core.bool hasUpdatedAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearUpdatedAt() => clearField(12);
  @$pb.TagNumber(12)
  $2.Timestamp ensureUpdatedAt() => $_ensure(11);
}

class InvestmentTrade extends $pb.GeneratedMessage {
  factory InvestmentTrade({
    $core.String? id,
    $core.String? investmentId,
    TradeType? tradeType,
    $core.double? quantity,
    $fixnum.Int64? price,
    $fixnum.Int64? totalAmount,
    $fixnum.Int64? fee,
    $2.Timestamp? tradeDate,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (investmentId != null) {
      $result.investmentId = investmentId;
    }
    if (tradeType != null) {
      $result.tradeType = tradeType;
    }
    if (quantity != null) {
      $result.quantity = quantity;
    }
    if (price != null) {
      $result.price = price;
    }
    if (totalAmount != null) {
      $result.totalAmount = totalAmount;
    }
    if (fee != null) {
      $result.fee = fee;
    }
    if (tradeDate != null) {
      $result.tradeDate = tradeDate;
    }
    return $result;
  }
  InvestmentTrade._() : super();
  factory InvestmentTrade.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory InvestmentTrade.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'InvestmentTrade', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'investmentId')
    ..e<TradeType>(3, _omitFieldNames ? '' : 'tradeType', $pb.PbFieldType.OE, defaultOrMaker: TradeType.TRADE_TYPE_UNSPECIFIED, valueOf: TradeType.valueOf, enumValues: TradeType.values)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'quantity', $pb.PbFieldType.OD)
    ..aInt64(5, _omitFieldNames ? '' : 'price')
    ..aInt64(6, _omitFieldNames ? '' : 'totalAmount')
    ..aInt64(7, _omitFieldNames ? '' : 'fee')
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'tradeDate', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  InvestmentTrade clone() => InvestmentTrade()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  InvestmentTrade copyWith(void Function(InvestmentTrade) updates) => super.copyWith((message) => updates(message as InvestmentTrade)) as InvestmentTrade;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InvestmentTrade create() => InvestmentTrade._();
  InvestmentTrade createEmptyInstance() => create();
  static $pb.PbList<InvestmentTrade> createRepeated() => $pb.PbList<InvestmentTrade>();
  @$core.pragma('dart2js:noInline')
  static InvestmentTrade getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<InvestmentTrade>(create);
  static InvestmentTrade? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get investmentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set investmentId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasInvestmentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearInvestmentId() => clearField(2);

  @$pb.TagNumber(3)
  TradeType get tradeType => $_getN(2);
  @$pb.TagNumber(3)
  set tradeType(TradeType v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasTradeType() => $_has(2);
  @$pb.TagNumber(3)
  void clearTradeType() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get quantity => $_getN(3);
  @$pb.TagNumber(4)
  set quantity($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasQuantity() => $_has(3);
  @$pb.TagNumber(4)
  void clearQuantity() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get price => $_getI64(4);
  @$pb.TagNumber(5)
  set price($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPrice() => $_has(4);
  @$pb.TagNumber(5)
  void clearPrice() => clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get totalAmount => $_getI64(5);
  @$pb.TagNumber(6)
  set totalAmount($fixnum.Int64 v) { $_setInt64(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTotalAmount() => $_has(5);
  @$pb.TagNumber(6)
  void clearTotalAmount() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get fee => $_getI64(6);
  @$pb.TagNumber(7)
  set fee($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasFee() => $_has(6);
  @$pb.TagNumber(7)
  void clearFee() => clearField(7);

  @$pb.TagNumber(8)
  $2.Timestamp get tradeDate => $_getN(7);
  @$pb.TagNumber(8)
  set tradeDate($2.Timestamp v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasTradeDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearTradeDate() => clearField(8);
  @$pb.TagNumber(8)
  $2.Timestamp ensureTradeDate() => $_ensure(7);
}

class MarketQuote extends $pb.GeneratedMessage {
  factory MarketQuote({
    $core.String? symbol,
    $core.String? name,
    MarketType? marketType,
    $fixnum.Int64? currentPrice,
    $fixnum.Int64? change,
    $core.double? changePercent,
    $fixnum.Int64? open,
    $fixnum.Int64? high,
    $fixnum.Int64? low,
    $fixnum.Int64? prevClose,
    $2.Timestamp? updatedAt,
  }) {
    final $result = create();
    if (symbol != null) {
      $result.symbol = symbol;
    }
    if (name != null) {
      $result.name = name;
    }
    if (marketType != null) {
      $result.marketType = marketType;
    }
    if (currentPrice != null) {
      $result.currentPrice = currentPrice;
    }
    if (change != null) {
      $result.change = change;
    }
    if (changePercent != null) {
      $result.changePercent = changePercent;
    }
    if (open != null) {
      $result.open = open;
    }
    if (high != null) {
      $result.high = high;
    }
    if (low != null) {
      $result.low = low;
    }
    if (prevClose != null) {
      $result.prevClose = prevClose;
    }
    if (updatedAt != null) {
      $result.updatedAt = updatedAt;
    }
    return $result;
  }
  MarketQuote._() : super();
  factory MarketQuote.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MarketQuote.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MarketQuote', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'symbol')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..e<MarketType>(3, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..aInt64(4, _omitFieldNames ? '' : 'currentPrice')
    ..aInt64(5, _omitFieldNames ? '' : 'change')
    ..a<$core.double>(6, _omitFieldNames ? '' : 'changePercent', $pb.PbFieldType.OD)
    ..aInt64(7, _omitFieldNames ? '' : 'open')
    ..aInt64(8, _omitFieldNames ? '' : 'high')
    ..aInt64(9, _omitFieldNames ? '' : 'low')
    ..aInt64(10, _omitFieldNames ? '' : 'prevClose')
    ..aOM<$2.Timestamp>(11, _omitFieldNames ? '' : 'updatedAt', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MarketQuote clone() => MarketQuote()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MarketQuote copyWith(void Function(MarketQuote) updates) => super.copyWith((message) => updates(message as MarketQuote)) as MarketQuote;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarketQuote create() => MarketQuote._();
  MarketQuote createEmptyInstance() => create();
  static $pb.PbList<MarketQuote> createRepeated() => $pb.PbList<MarketQuote>();
  @$core.pragma('dart2js:noInline')
  static MarketQuote getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MarketQuote>(create);
  static MarketQuote? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get symbol => $_getSZ(0);
  @$pb.TagNumber(1)
  set symbol($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSymbol() => $_has(0);
  @$pb.TagNumber(1)
  void clearSymbol() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  MarketType get marketType => $_getN(2);
  @$pb.TagNumber(3)
  set marketType(MarketType v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasMarketType() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarketType() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get currentPrice => $_getI64(3);
  @$pb.TagNumber(4)
  set currentPrice($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCurrentPrice() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrentPrice() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get change => $_getI64(4);
  @$pb.TagNumber(5)
  set change($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasChange() => $_has(4);
  @$pb.TagNumber(5)
  void clearChange() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get changePercent => $_getN(5);
  @$pb.TagNumber(6)
  set changePercent($core.double v) { $_setDouble(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasChangePercent() => $_has(5);
  @$pb.TagNumber(6)
  void clearChangePercent() => clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get open => $_getI64(6);
  @$pb.TagNumber(7)
  set open($fixnum.Int64 v) { $_setInt64(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasOpen() => $_has(6);
  @$pb.TagNumber(7)
  void clearOpen() => clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get high => $_getI64(7);
  @$pb.TagNumber(8)
  set high($fixnum.Int64 v) { $_setInt64(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasHigh() => $_has(7);
  @$pb.TagNumber(8)
  void clearHigh() => clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get low => $_getI64(8);
  @$pb.TagNumber(9)
  set low($fixnum.Int64 v) { $_setInt64(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasLow() => $_has(8);
  @$pb.TagNumber(9)
  void clearLow() => clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get prevClose => $_getI64(9);
  @$pb.TagNumber(10)
  set prevClose($fixnum.Int64 v) { $_setInt64(9, v); }
  @$pb.TagNumber(10)
  $core.bool hasPrevClose() => $_has(9);
  @$pb.TagNumber(10)
  void clearPrevClose() => clearField(10);

  @$pb.TagNumber(11)
  $2.Timestamp get updatedAt => $_getN(10);
  @$pb.TagNumber(11)
  set updatedAt($2.Timestamp v) { setField(11, v); }
  @$pb.TagNumber(11)
  $core.bool hasUpdatedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearUpdatedAt() => clearField(11);
  @$pb.TagNumber(11)
  $2.Timestamp ensureUpdatedAt() => $_ensure(10);
}

class PortfolioSummary extends $pb.GeneratedMessage {
  factory PortfolioSummary({
    $fixnum.Int64? totalValue,
    $fixnum.Int64? totalCost,
    $fixnum.Int64? totalProfit,
    $core.double? totalReturn,
    $core.Iterable<HoldingItem>? holdings,
  }) {
    final $result = create();
    if (totalValue != null) {
      $result.totalValue = totalValue;
    }
    if (totalCost != null) {
      $result.totalCost = totalCost;
    }
    if (totalProfit != null) {
      $result.totalProfit = totalProfit;
    }
    if (totalReturn != null) {
      $result.totalReturn = totalReturn;
    }
    if (holdings != null) {
      $result.holdings.addAll(holdings);
    }
    return $result;
  }
  PortfolioSummary._() : super();
  factory PortfolioSummary.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PortfolioSummary.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PortfolioSummary', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'totalValue')
    ..aInt64(2, _omitFieldNames ? '' : 'totalCost')
    ..aInt64(3, _omitFieldNames ? '' : 'totalProfit')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'totalReturn', $pb.PbFieldType.OD)
    ..pc<HoldingItem>(5, _omitFieldNames ? '' : 'holdings', $pb.PbFieldType.PM, subBuilder: HoldingItem.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PortfolioSummary clone() => PortfolioSummary()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PortfolioSummary copyWith(void Function(PortfolioSummary) updates) => super.copyWith((message) => updates(message as PortfolioSummary)) as PortfolioSummary;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PortfolioSummary create() => PortfolioSummary._();
  PortfolioSummary createEmptyInstance() => create();
  static $pb.PbList<PortfolioSummary> createRepeated() => $pb.PbList<PortfolioSummary>();
  @$core.pragma('dart2js:noInline')
  static PortfolioSummary getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PortfolioSummary>(create);
  static PortfolioSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get totalValue => $_getI64(0);
  @$pb.TagNumber(1)
  set totalValue($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasTotalValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalValue() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalCost => $_getI64(1);
  @$pb.TagNumber(2)
  set totalCost($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTotalCost() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalCost() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalProfit => $_getI64(2);
  @$pb.TagNumber(3)
  set totalProfit($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasTotalProfit() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalProfit() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get totalReturn => $_getN(3);
  @$pb.TagNumber(4)
  set totalReturn($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTotalReturn() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalReturn() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<HoldingItem> get holdings => $_getList(4);
}

class HoldingItem extends $pb.GeneratedMessage {
  factory HoldingItem({
    $core.String? investmentId,
    $core.String? symbol,
    $core.String? name,
    $core.double? quantity,
    $fixnum.Int64? currentValue,
    $core.double? weight,
    $core.double? returnRate,
  }) {
    final $result = create();
    if (investmentId != null) {
      $result.investmentId = investmentId;
    }
    if (symbol != null) {
      $result.symbol = symbol;
    }
    if (name != null) {
      $result.name = name;
    }
    if (quantity != null) {
      $result.quantity = quantity;
    }
    if (currentValue != null) {
      $result.currentValue = currentValue;
    }
    if (weight != null) {
      $result.weight = weight;
    }
    if (returnRate != null) {
      $result.returnRate = returnRate;
    }
    return $result;
  }
  HoldingItem._() : super();
  factory HoldingItem.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory HoldingItem.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'HoldingItem', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'investmentId')
    ..aOS(2, _omitFieldNames ? '' : 'symbol')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..a<$core.double>(4, _omitFieldNames ? '' : 'quantity', $pb.PbFieldType.OD)
    ..aInt64(5, _omitFieldNames ? '' : 'currentValue')
    ..a<$core.double>(6, _omitFieldNames ? '' : 'weight', $pb.PbFieldType.OD)
    ..a<$core.double>(7, _omitFieldNames ? '' : 'returnRate', $pb.PbFieldType.OD)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  HoldingItem clone() => HoldingItem()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  HoldingItem copyWith(void Function(HoldingItem) updates) => super.copyWith((message) => updates(message as HoldingItem)) as HoldingItem;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HoldingItem create() => HoldingItem._();
  HoldingItem createEmptyInstance() => create();
  static $pb.PbList<HoldingItem> createRepeated() => $pb.PbList<HoldingItem>();
  @$core.pragma('dart2js:noInline')
  static HoldingItem getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HoldingItem>(create);
  static HoldingItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get investmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set investmentId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInvestmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvestmentId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get symbol => $_getSZ(1);
  @$pb.TagNumber(2)
  set symbol($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSymbol() => $_has(1);
  @$pb.TagNumber(2)
  void clearSymbol() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get quantity => $_getN(3);
  @$pb.TagNumber(4)
  set quantity($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasQuantity() => $_has(3);
  @$pb.TagNumber(4)
  void clearQuantity() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get currentValue => $_getI64(4);
  @$pb.TagNumber(5)
  set currentValue($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasCurrentValue() => $_has(4);
  @$pb.TagNumber(5)
  void clearCurrentValue() => clearField(5);

  @$pb.TagNumber(6)
  $core.double get weight => $_getN(5);
  @$pb.TagNumber(6)
  set weight($core.double v) { $_setDouble(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasWeight() => $_has(5);
  @$pb.TagNumber(6)
  void clearWeight() => clearField(6);

  @$pb.TagNumber(7)
  $core.double get returnRate => $_getN(6);
  @$pb.TagNumber(7)
  set returnRate($core.double v) { $_setDouble(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasReturnRate() => $_has(6);
  @$pb.TagNumber(7)
  void clearReturnRate() => clearField(7);
}

class PricePoint extends $pb.GeneratedMessage {
  factory PricePoint({
    $2.Timestamp? timestamp,
    $fixnum.Int64? price,
  }) {
    final $result = create();
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    if (price != null) {
      $result.price = price;
    }
    return $result;
  }
  PricePoint._() : super();
  factory PricePoint.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PricePoint.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PricePoint', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOM<$2.Timestamp>(1, _omitFieldNames ? '' : 'timestamp', subBuilder: $2.Timestamp.create)
    ..aInt64(2, _omitFieldNames ? '' : 'price')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PricePoint clone() => PricePoint()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PricePoint copyWith(void Function(PricePoint) updates) => super.copyWith((message) => updates(message as PricePoint)) as PricePoint;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PricePoint create() => PricePoint._();
  PricePoint createEmptyInstance() => create();
  static $pb.PbList<PricePoint> createRepeated() => $pb.PbList<PricePoint>();
  @$core.pragma('dart2js:noInline')
  static PricePoint getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PricePoint>(create);
  static PricePoint? _defaultInstance;

  @$pb.TagNumber(1)
  $2.Timestamp get timestamp => $_getN(0);
  @$pb.TagNumber(1)
  set timestamp($2.Timestamp v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => clearField(1);
  @$pb.TagNumber(1)
  $2.Timestamp ensureTimestamp() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get price => $_getI64(1);
  @$pb.TagNumber(2)
  set price($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPrice() => $_has(1);
  @$pb.TagNumber(2)
  void clearPrice() => clearField(2);
}

class SymbolInfo extends $pb.GeneratedMessage {
  factory SymbolInfo({
    $core.String? symbol,
    $core.String? name,
    MarketType? marketType,
  }) {
    final $result = create();
    if (symbol != null) {
      $result.symbol = symbol;
    }
    if (name != null) {
      $result.name = name;
    }
    if (marketType != null) {
      $result.marketType = marketType;
    }
    return $result;
  }
  SymbolInfo._() : super();
  factory SymbolInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SymbolInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SymbolInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'symbol')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..e<MarketType>(3, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SymbolInfo clone() => SymbolInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SymbolInfo copyWith(void Function(SymbolInfo) updates) => super.copyWith((message) => updates(message as SymbolInfo)) as SymbolInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SymbolInfo create() => SymbolInfo._();
  SymbolInfo createEmptyInstance() => create();
  static $pb.PbList<SymbolInfo> createRepeated() => $pb.PbList<SymbolInfo>();
  @$core.pragma('dart2js:noInline')
  static SymbolInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SymbolInfo>(create);
  static SymbolInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get symbol => $_getSZ(0);
  @$pb.TagNumber(1)
  set symbol($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSymbol() => $_has(0);
  @$pb.TagNumber(1)
  void clearSymbol() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  MarketType get marketType => $_getN(2);
  @$pb.TagNumber(3)
  set marketType(MarketType v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasMarketType() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarketType() => clearField(3);
}

/// InvestmentService
class CreateInvestmentRequest extends $pb.GeneratedMessage {
  factory CreateInvestmentRequest({
    $core.String? symbol,
    $core.String? name,
    MarketType? marketType,
  }) {
    final $result = create();
    if (symbol != null) {
      $result.symbol = symbol;
    }
    if (name != null) {
      $result.name = name;
    }
    if (marketType != null) {
      $result.marketType = marketType;
    }
    return $result;
  }
  CreateInvestmentRequest._() : super();
  factory CreateInvestmentRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateInvestmentRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateInvestmentRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'symbol')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..e<MarketType>(3, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateInvestmentRequest clone() => CreateInvestmentRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateInvestmentRequest copyWith(void Function(CreateInvestmentRequest) updates) => super.copyWith((message) => updates(message as CreateInvestmentRequest)) as CreateInvestmentRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateInvestmentRequest create() => CreateInvestmentRequest._();
  CreateInvestmentRequest createEmptyInstance() => create();
  static $pb.PbList<CreateInvestmentRequest> createRepeated() => $pb.PbList<CreateInvestmentRequest>();
  @$core.pragma('dart2js:noInline')
  static CreateInvestmentRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateInvestmentRequest>(create);
  static CreateInvestmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get symbol => $_getSZ(0);
  @$pb.TagNumber(1)
  set symbol($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSymbol() => $_has(0);
  @$pb.TagNumber(1)
  void clearSymbol() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  MarketType get marketType => $_getN(2);
  @$pb.TagNumber(3)
  set marketType(MarketType v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasMarketType() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarketType() => clearField(3);
}

class GetInvestmentRequest extends $pb.GeneratedMessage {
  factory GetInvestmentRequest({
    $core.String? investmentId,
  }) {
    final $result = create();
    if (investmentId != null) {
      $result.investmentId = investmentId;
    }
    return $result;
  }
  GetInvestmentRequest._() : super();
  factory GetInvestmentRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetInvestmentRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetInvestmentRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'investmentId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetInvestmentRequest clone() => GetInvestmentRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetInvestmentRequest copyWith(void Function(GetInvestmentRequest) updates) => super.copyWith((message) => updates(message as GetInvestmentRequest)) as GetInvestmentRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetInvestmentRequest create() => GetInvestmentRequest._();
  GetInvestmentRequest createEmptyInstance() => create();
  static $pb.PbList<GetInvestmentRequest> createRepeated() => $pb.PbList<GetInvestmentRequest>();
  @$core.pragma('dart2js:noInline')
  static GetInvestmentRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetInvestmentRequest>(create);
  static GetInvestmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get investmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set investmentId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInvestmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvestmentId() => clearField(1);
}

class ListInvestmentsRequest extends $pb.GeneratedMessage {
  factory ListInvestmentsRequest({
    MarketType? marketType,
  }) {
    final $result = create();
    if (marketType != null) {
      $result.marketType = marketType;
    }
    return $result;
  }
  ListInvestmentsRequest._() : super();
  factory ListInvestmentsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListInvestmentsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListInvestmentsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..e<MarketType>(1, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListInvestmentsRequest clone() => ListInvestmentsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListInvestmentsRequest copyWith(void Function(ListInvestmentsRequest) updates) => super.copyWith((message) => updates(message as ListInvestmentsRequest)) as ListInvestmentsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListInvestmentsRequest create() => ListInvestmentsRequest._();
  ListInvestmentsRequest createEmptyInstance() => create();
  static $pb.PbList<ListInvestmentsRequest> createRepeated() => $pb.PbList<ListInvestmentsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListInvestmentsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListInvestmentsRequest>(create);
  static ListInvestmentsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  MarketType get marketType => $_getN(0);
  @$pb.TagNumber(1)
  set marketType(MarketType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasMarketType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMarketType() => clearField(1);
}

class ListInvestmentsResponse extends $pb.GeneratedMessage {
  factory ListInvestmentsResponse({
    $core.Iterable<Investment>? investments,
  }) {
    final $result = create();
    if (investments != null) {
      $result.investments.addAll(investments);
    }
    return $result;
  }
  ListInvestmentsResponse._() : super();
  factory ListInvestmentsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListInvestmentsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListInvestmentsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..pc<Investment>(1, _omitFieldNames ? '' : 'investments', $pb.PbFieldType.PM, subBuilder: Investment.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListInvestmentsResponse clone() => ListInvestmentsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListInvestmentsResponse copyWith(void Function(ListInvestmentsResponse) updates) => super.copyWith((message) => updates(message as ListInvestmentsResponse)) as ListInvestmentsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListInvestmentsResponse create() => ListInvestmentsResponse._();
  ListInvestmentsResponse createEmptyInstance() => create();
  static $pb.PbList<ListInvestmentsResponse> createRepeated() => $pb.PbList<ListInvestmentsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListInvestmentsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListInvestmentsResponse>(create);
  static ListInvestmentsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Investment> get investments => $_getList(0);
}

class UpdateInvestmentRequest extends $pb.GeneratedMessage {
  factory UpdateInvestmentRequest({
    $core.String? investmentId,
    $core.String? name,
  }) {
    final $result = create();
    if (investmentId != null) {
      $result.investmentId = investmentId;
    }
    if (name != null) {
      $result.name = name;
    }
    return $result;
  }
  UpdateInvestmentRequest._() : super();
  factory UpdateInvestmentRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateInvestmentRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateInvestmentRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'investmentId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateInvestmentRequest clone() => UpdateInvestmentRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateInvestmentRequest copyWith(void Function(UpdateInvestmentRequest) updates) => super.copyWith((message) => updates(message as UpdateInvestmentRequest)) as UpdateInvestmentRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateInvestmentRequest create() => UpdateInvestmentRequest._();
  UpdateInvestmentRequest createEmptyInstance() => create();
  static $pb.PbList<UpdateInvestmentRequest> createRepeated() => $pb.PbList<UpdateInvestmentRequest>();
  @$core.pragma('dart2js:noInline')
  static UpdateInvestmentRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateInvestmentRequest>(create);
  static UpdateInvestmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get investmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set investmentId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInvestmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvestmentId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);
}

class DeleteInvestmentRequest extends $pb.GeneratedMessage {
  factory DeleteInvestmentRequest({
    $core.String? investmentId,
  }) {
    final $result = create();
    if (investmentId != null) {
      $result.investmentId = investmentId;
    }
    return $result;
  }
  DeleteInvestmentRequest._() : super();
  factory DeleteInvestmentRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteInvestmentRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteInvestmentRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'investmentId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteInvestmentRequest clone() => DeleteInvestmentRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteInvestmentRequest copyWith(void Function(DeleteInvestmentRequest) updates) => super.copyWith((message) => updates(message as DeleteInvestmentRequest)) as DeleteInvestmentRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteInvestmentRequest create() => DeleteInvestmentRequest._();
  DeleteInvestmentRequest createEmptyInstance() => create();
  static $pb.PbList<DeleteInvestmentRequest> createRepeated() => $pb.PbList<DeleteInvestmentRequest>();
  @$core.pragma('dart2js:noInline')
  static DeleteInvestmentRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteInvestmentRequest>(create);
  static DeleteInvestmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get investmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set investmentId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInvestmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvestmentId() => clearField(1);
}

class RecordTradeRequest extends $pb.GeneratedMessage {
  factory RecordTradeRequest({
    $core.String? investmentId,
    TradeType? tradeType,
    $core.double? quantity,
    $fixnum.Int64? price,
    $fixnum.Int64? fee,
    $2.Timestamp? tradeDate,
  }) {
    final $result = create();
    if (investmentId != null) {
      $result.investmentId = investmentId;
    }
    if (tradeType != null) {
      $result.tradeType = tradeType;
    }
    if (quantity != null) {
      $result.quantity = quantity;
    }
    if (price != null) {
      $result.price = price;
    }
    if (fee != null) {
      $result.fee = fee;
    }
    if (tradeDate != null) {
      $result.tradeDate = tradeDate;
    }
    return $result;
  }
  RecordTradeRequest._() : super();
  factory RecordTradeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RecordTradeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RecordTradeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'investmentId')
    ..e<TradeType>(2, _omitFieldNames ? '' : 'tradeType', $pb.PbFieldType.OE, defaultOrMaker: TradeType.TRADE_TYPE_UNSPECIFIED, valueOf: TradeType.valueOf, enumValues: TradeType.values)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'quantity', $pb.PbFieldType.OD)
    ..aInt64(4, _omitFieldNames ? '' : 'price')
    ..aInt64(5, _omitFieldNames ? '' : 'fee')
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'tradeDate', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RecordTradeRequest clone() => RecordTradeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RecordTradeRequest copyWith(void Function(RecordTradeRequest) updates) => super.copyWith((message) => updates(message as RecordTradeRequest)) as RecordTradeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordTradeRequest create() => RecordTradeRequest._();
  RecordTradeRequest createEmptyInstance() => create();
  static $pb.PbList<RecordTradeRequest> createRepeated() => $pb.PbList<RecordTradeRequest>();
  @$core.pragma('dart2js:noInline')
  static RecordTradeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RecordTradeRequest>(create);
  static RecordTradeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get investmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set investmentId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInvestmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvestmentId() => clearField(1);

  @$pb.TagNumber(2)
  TradeType get tradeType => $_getN(1);
  @$pb.TagNumber(2)
  set tradeType(TradeType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasTradeType() => $_has(1);
  @$pb.TagNumber(2)
  void clearTradeType() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get quantity => $_getN(2);
  @$pb.TagNumber(3)
  set quantity($core.double v) { $_setDouble(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasQuantity() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuantity() => clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get price => $_getI64(3);
  @$pb.TagNumber(4)
  set price($fixnum.Int64 v) { $_setInt64(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPrice() => $_has(3);
  @$pb.TagNumber(4)
  void clearPrice() => clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get fee => $_getI64(4);
  @$pb.TagNumber(5)
  set fee($fixnum.Int64 v) { $_setInt64(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasFee() => $_has(4);
  @$pb.TagNumber(5)
  void clearFee() => clearField(5);

  @$pb.TagNumber(6)
  $2.Timestamp get tradeDate => $_getN(5);
  @$pb.TagNumber(6)
  set tradeDate($2.Timestamp v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasTradeDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearTradeDate() => clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureTradeDate() => $_ensure(5);
}

class ListTradesRequest extends $pb.GeneratedMessage {
  factory ListTradesRequest({
    $core.String? investmentId,
  }) {
    final $result = create();
    if (investmentId != null) {
      $result.investmentId = investmentId;
    }
    return $result;
  }
  ListTradesRequest._() : super();
  factory ListTradesRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListTradesRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListTradesRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'investmentId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListTradesRequest clone() => ListTradesRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListTradesRequest copyWith(void Function(ListTradesRequest) updates) => super.copyWith((message) => updates(message as ListTradesRequest)) as ListTradesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTradesRequest create() => ListTradesRequest._();
  ListTradesRequest createEmptyInstance() => create();
  static $pb.PbList<ListTradesRequest> createRepeated() => $pb.PbList<ListTradesRequest>();
  @$core.pragma('dart2js:noInline')
  static ListTradesRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListTradesRequest>(create);
  static ListTradesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get investmentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set investmentId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInvestmentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearInvestmentId() => clearField(1);
}

class ListTradesResponse extends $pb.GeneratedMessage {
  factory ListTradesResponse({
    $core.Iterable<InvestmentTrade>? trades,
  }) {
    final $result = create();
    if (trades != null) {
      $result.trades.addAll(trades);
    }
    return $result;
  }
  ListTradesResponse._() : super();
  factory ListTradesResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListTradesResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListTradesResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..pc<InvestmentTrade>(1, _omitFieldNames ? '' : 'trades', $pb.PbFieldType.PM, subBuilder: InvestmentTrade.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListTradesResponse clone() => ListTradesResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListTradesResponse copyWith(void Function(ListTradesResponse) updates) => super.copyWith((message) => updates(message as ListTradesResponse)) as ListTradesResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTradesResponse create() => ListTradesResponse._();
  ListTradesResponse createEmptyInstance() => create();
  static $pb.PbList<ListTradesResponse> createRepeated() => $pb.PbList<ListTradesResponse>();
  @$core.pragma('dart2js:noInline')
  static ListTradesResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListTradesResponse>(create);
  static ListTradesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<InvestmentTrade> get trades => $_getList(0);
}

class GetPortfolioSummaryRequest extends $pb.GeneratedMessage {
  factory GetPortfolioSummaryRequest() => create();
  GetPortfolioSummaryRequest._() : super();
  factory GetPortfolioSummaryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetPortfolioSummaryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetPortfolioSummaryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetPortfolioSummaryRequest clone() => GetPortfolioSummaryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetPortfolioSummaryRequest copyWith(void Function(GetPortfolioSummaryRequest) updates) => super.copyWith((message) => updates(message as GetPortfolioSummaryRequest)) as GetPortfolioSummaryRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPortfolioSummaryRequest create() => GetPortfolioSummaryRequest._();
  GetPortfolioSummaryRequest createEmptyInstance() => create();
  static $pb.PbList<GetPortfolioSummaryRequest> createRepeated() => $pb.PbList<GetPortfolioSummaryRequest>();
  @$core.pragma('dart2js:noInline')
  static GetPortfolioSummaryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetPortfolioSummaryRequest>(create);
  static GetPortfolioSummaryRequest? _defaultInstance;
}

/// MarketDataService
class GetQuoteRequest extends $pb.GeneratedMessage {
  factory GetQuoteRequest({
    $core.String? symbol,
    MarketType? marketType,
  }) {
    final $result = create();
    if (symbol != null) {
      $result.symbol = symbol;
    }
    if (marketType != null) {
      $result.marketType = marketType;
    }
    return $result;
  }
  GetQuoteRequest._() : super();
  factory GetQuoteRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetQuoteRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetQuoteRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'symbol')
    ..e<MarketType>(2, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetQuoteRequest clone() => GetQuoteRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetQuoteRequest copyWith(void Function(GetQuoteRequest) updates) => super.copyWith((message) => updates(message as GetQuoteRequest)) as GetQuoteRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetQuoteRequest create() => GetQuoteRequest._();
  GetQuoteRequest createEmptyInstance() => create();
  static $pb.PbList<GetQuoteRequest> createRepeated() => $pb.PbList<GetQuoteRequest>();
  @$core.pragma('dart2js:noInline')
  static GetQuoteRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetQuoteRequest>(create);
  static GetQuoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get symbol => $_getSZ(0);
  @$pb.TagNumber(1)
  set symbol($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSymbol() => $_has(0);
  @$pb.TagNumber(1)
  void clearSymbol() => clearField(1);

  @$pb.TagNumber(2)
  MarketType get marketType => $_getN(1);
  @$pb.TagNumber(2)
  set marketType(MarketType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasMarketType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarketType() => clearField(2);
}

class BatchGetQuotesRequest extends $pb.GeneratedMessage {
  factory BatchGetQuotesRequest({
    $core.Iterable<GetQuoteRequest>? requests,
  }) {
    final $result = create();
    if (requests != null) {
      $result.requests.addAll(requests);
    }
    return $result;
  }
  BatchGetQuotesRequest._() : super();
  factory BatchGetQuotesRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BatchGetQuotesRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BatchGetQuotesRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..pc<GetQuoteRequest>(1, _omitFieldNames ? '' : 'requests', $pb.PbFieldType.PM, subBuilder: GetQuoteRequest.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BatchGetQuotesRequest clone() => BatchGetQuotesRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BatchGetQuotesRequest copyWith(void Function(BatchGetQuotesRequest) updates) => super.copyWith((message) => updates(message as BatchGetQuotesRequest)) as BatchGetQuotesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchGetQuotesRequest create() => BatchGetQuotesRequest._();
  BatchGetQuotesRequest createEmptyInstance() => create();
  static $pb.PbList<BatchGetQuotesRequest> createRepeated() => $pb.PbList<BatchGetQuotesRequest>();
  @$core.pragma('dart2js:noInline')
  static BatchGetQuotesRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BatchGetQuotesRequest>(create);
  static BatchGetQuotesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<GetQuoteRequest> get requests => $_getList(0);
}

class BatchGetQuotesResponse extends $pb.GeneratedMessage {
  factory BatchGetQuotesResponse({
    $core.Iterable<MarketQuote>? quotes,
  }) {
    final $result = create();
    if (quotes != null) {
      $result.quotes.addAll(quotes);
    }
    return $result;
  }
  BatchGetQuotesResponse._() : super();
  factory BatchGetQuotesResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BatchGetQuotesResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BatchGetQuotesResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..pc<MarketQuote>(1, _omitFieldNames ? '' : 'quotes', $pb.PbFieldType.PM, subBuilder: MarketQuote.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BatchGetQuotesResponse clone() => BatchGetQuotesResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BatchGetQuotesResponse copyWith(void Function(BatchGetQuotesResponse) updates) => super.copyWith((message) => updates(message as BatchGetQuotesResponse)) as BatchGetQuotesResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BatchGetQuotesResponse create() => BatchGetQuotesResponse._();
  BatchGetQuotesResponse createEmptyInstance() => create();
  static $pb.PbList<BatchGetQuotesResponse> createRepeated() => $pb.PbList<BatchGetQuotesResponse>();
  @$core.pragma('dart2js:noInline')
  static BatchGetQuotesResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BatchGetQuotesResponse>(create);
  static BatchGetQuotesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<MarketQuote> get quotes => $_getList(0);
}

class SearchSymbolRequest extends $pb.GeneratedMessage {
  factory SearchSymbolRequest({
    $core.String? query,
    MarketType? marketType,
  }) {
    final $result = create();
    if (query != null) {
      $result.query = query;
    }
    if (marketType != null) {
      $result.marketType = marketType;
    }
    return $result;
  }
  SearchSymbolRequest._() : super();
  factory SearchSymbolRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SearchSymbolRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SearchSymbolRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'query')
    ..e<MarketType>(2, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SearchSymbolRequest clone() => SearchSymbolRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SearchSymbolRequest copyWith(void Function(SearchSymbolRequest) updates) => super.copyWith((message) => updates(message as SearchSymbolRequest)) as SearchSymbolRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchSymbolRequest create() => SearchSymbolRequest._();
  SearchSymbolRequest createEmptyInstance() => create();
  static $pb.PbList<SearchSymbolRequest> createRepeated() => $pb.PbList<SearchSymbolRequest>();
  @$core.pragma('dart2js:noInline')
  static SearchSymbolRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SearchSymbolRequest>(create);
  static SearchSymbolRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get query => $_getSZ(0);
  @$pb.TagNumber(1)
  set query($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasQuery() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuery() => clearField(1);

  @$pb.TagNumber(2)
  MarketType get marketType => $_getN(1);
  @$pb.TagNumber(2)
  set marketType(MarketType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasMarketType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarketType() => clearField(2);
}

class SearchSymbolResponse extends $pb.GeneratedMessage {
  factory SearchSymbolResponse({
    $core.Iterable<SymbolInfo>? symbols,
  }) {
    final $result = create();
    if (symbols != null) {
      $result.symbols.addAll(symbols);
    }
    return $result;
  }
  SearchSymbolResponse._() : super();
  factory SearchSymbolResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SearchSymbolResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SearchSymbolResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..pc<SymbolInfo>(1, _omitFieldNames ? '' : 'symbols', $pb.PbFieldType.PM, subBuilder: SymbolInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SearchSymbolResponse clone() => SearchSymbolResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SearchSymbolResponse copyWith(void Function(SearchSymbolResponse) updates) => super.copyWith((message) => updates(message as SearchSymbolResponse)) as SearchSymbolResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchSymbolResponse create() => SearchSymbolResponse._();
  SearchSymbolResponse createEmptyInstance() => create();
  static $pb.PbList<SearchSymbolResponse> createRepeated() => $pb.PbList<SearchSymbolResponse>();
  @$core.pragma('dart2js:noInline')
  static SearchSymbolResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SearchSymbolResponse>(create);
  static SearchSymbolResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<SymbolInfo> get symbols => $_getList(0);
}

class GetPriceHistoryRequest extends $pb.GeneratedMessage {
  factory GetPriceHistoryRequest({
    $core.String? symbol,
    MarketType? marketType,
    $2.Timestamp? startDate,
    $2.Timestamp? endDate,
  }) {
    final $result = create();
    if (symbol != null) {
      $result.symbol = symbol;
    }
    if (marketType != null) {
      $result.marketType = marketType;
    }
    if (startDate != null) {
      $result.startDate = startDate;
    }
    if (endDate != null) {
      $result.endDate = endDate;
    }
    return $result;
  }
  GetPriceHistoryRequest._() : super();
  factory GetPriceHistoryRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetPriceHistoryRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetPriceHistoryRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'symbol')
    ..e<MarketType>(2, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..aOM<$2.Timestamp>(3, _omitFieldNames ? '' : 'startDate', subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(4, _omitFieldNames ? '' : 'endDate', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetPriceHistoryRequest clone() => GetPriceHistoryRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetPriceHistoryRequest copyWith(void Function(GetPriceHistoryRequest) updates) => super.copyWith((message) => updates(message as GetPriceHistoryRequest)) as GetPriceHistoryRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPriceHistoryRequest create() => GetPriceHistoryRequest._();
  GetPriceHistoryRequest createEmptyInstance() => create();
  static $pb.PbList<GetPriceHistoryRequest> createRepeated() => $pb.PbList<GetPriceHistoryRequest>();
  @$core.pragma('dart2js:noInline')
  static GetPriceHistoryRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetPriceHistoryRequest>(create);
  static GetPriceHistoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get symbol => $_getSZ(0);
  @$pb.TagNumber(1)
  set symbol($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSymbol() => $_has(0);
  @$pb.TagNumber(1)
  void clearSymbol() => clearField(1);

  @$pb.TagNumber(2)
  MarketType get marketType => $_getN(1);
  @$pb.TagNumber(2)
  set marketType(MarketType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasMarketType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarketType() => clearField(2);

  @$pb.TagNumber(3)
  $2.Timestamp get startDate => $_getN(2);
  @$pb.TagNumber(3)
  set startDate($2.Timestamp v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasStartDate() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartDate() => clearField(3);
  @$pb.TagNumber(3)
  $2.Timestamp ensureStartDate() => $_ensure(2);

  @$pb.TagNumber(4)
  $2.Timestamp get endDate => $_getN(3);
  @$pb.TagNumber(4)
  set endDate($2.Timestamp v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasEndDate() => $_has(3);
  @$pb.TagNumber(4)
  void clearEndDate() => clearField(4);
  @$pb.TagNumber(4)
  $2.Timestamp ensureEndDate() => $_ensure(3);
}

class PriceHistoryResponse extends $pb.GeneratedMessage {
  factory PriceHistoryResponse({
    $core.String? symbol,
    MarketType? marketType,
    $core.Iterable<PricePoint>? points,
  }) {
    final $result = create();
    if (symbol != null) {
      $result.symbol = symbol;
    }
    if (marketType != null) {
      $result.marketType = marketType;
    }
    if (points != null) {
      $result.points.addAll(points);
    }
    return $result;
  }
  PriceHistoryResponse._() : super();
  factory PriceHistoryResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PriceHistoryResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PriceHistoryResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.investment.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'symbol')
    ..e<MarketType>(2, _omitFieldNames ? '' : 'marketType', $pb.PbFieldType.OE, defaultOrMaker: MarketType.MARKET_TYPE_UNSPECIFIED, valueOf: MarketType.valueOf, enumValues: MarketType.values)
    ..pc<PricePoint>(3, _omitFieldNames ? '' : 'points', $pb.PbFieldType.PM, subBuilder: PricePoint.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PriceHistoryResponse clone() => PriceHistoryResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PriceHistoryResponse copyWith(void Function(PriceHistoryResponse) updates) => super.copyWith((message) => updates(message as PriceHistoryResponse)) as PriceHistoryResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PriceHistoryResponse create() => PriceHistoryResponse._();
  PriceHistoryResponse createEmptyInstance() => create();
  static $pb.PbList<PriceHistoryResponse> createRepeated() => $pb.PbList<PriceHistoryResponse>();
  @$core.pragma('dart2js:noInline')
  static PriceHistoryResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PriceHistoryResponse>(create);
  static PriceHistoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get symbol => $_getSZ(0);
  @$pb.TagNumber(1)
  set symbol($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSymbol() => $_has(0);
  @$pb.TagNumber(1)
  void clearSymbol() => clearField(1);

  @$pb.TagNumber(2)
  MarketType get marketType => $_getN(1);
  @$pb.TagNumber(2)
  set marketType(MarketType v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasMarketType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarketType() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<PricePoint> get points => $_getList(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
