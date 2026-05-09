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

import 'package:protobuf/protobuf.dart' as $pb;

class MarketType extends $pb.ProtobufEnum {
  static const MarketType MARKET_TYPE_UNSPECIFIED = MarketType._(0, _omitEnumNames ? '' : 'MARKET_TYPE_UNSPECIFIED');
  static const MarketType MARKET_TYPE_A_SHARE = MarketType._(1, _omitEnumNames ? '' : 'MARKET_TYPE_A_SHARE');
  static const MarketType MARKET_TYPE_HK_STOCK = MarketType._(2, _omitEnumNames ? '' : 'MARKET_TYPE_HK_STOCK');
  static const MarketType MARKET_TYPE_US_STOCK = MarketType._(3, _omitEnumNames ? '' : 'MARKET_TYPE_US_STOCK');
  static const MarketType MARKET_TYPE_CRYPTO = MarketType._(4, _omitEnumNames ? '' : 'MARKET_TYPE_CRYPTO');
  static const MarketType MARKET_TYPE_FUND = MarketType._(5, _omitEnumNames ? '' : 'MARKET_TYPE_FUND');
  static const MarketType MARKET_TYPE_PRECIOUS_METAL = MarketType._(6, _omitEnumNames ? '' : 'MARKET_TYPE_PRECIOUS_METAL');

  static const $core.List<MarketType> values = <MarketType> [
    MARKET_TYPE_UNSPECIFIED,
    MARKET_TYPE_A_SHARE,
    MARKET_TYPE_HK_STOCK,
    MARKET_TYPE_US_STOCK,
    MARKET_TYPE_CRYPTO,
    MARKET_TYPE_FUND,
    MARKET_TYPE_PRECIOUS_METAL,
  ];

  static final $core.Map<$core.int, MarketType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static MarketType? valueOf($core.int value) => _byValue[value];

  const MarketType._($core.int v, $core.String n) : super(v, n);
}

class TradeType extends $pb.ProtobufEnum {
  static const TradeType TRADE_TYPE_UNSPECIFIED = TradeType._(0, _omitEnumNames ? '' : 'TRADE_TYPE_UNSPECIFIED');
  static const TradeType TRADE_TYPE_BUY = TradeType._(1, _omitEnumNames ? '' : 'TRADE_TYPE_BUY');
  static const TradeType TRADE_TYPE_SELL = TradeType._(2, _omitEnumNames ? '' : 'TRADE_TYPE_SELL');

  static const $core.List<TradeType> values = <TradeType> [
    TRADE_TYPE_UNSPECIFIED,
    TRADE_TYPE_BUY,
    TRADE_TYPE_SELL,
  ];

  static final $core.Map<$core.int, TradeType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static TradeType? valueOf($core.int value) => _byValue[value];

  const TradeType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
