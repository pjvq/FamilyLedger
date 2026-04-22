//
//  Generated code. Do not modify.
//  source: investment.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use marketTypeDescriptor instead')
const MarketType$json = {
  '1': 'MarketType',
  '2': [
    {'1': 'MARKET_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'MARKET_TYPE_A_SHARE', '2': 1},
    {'1': 'MARKET_TYPE_HK_STOCK', '2': 2},
    {'1': 'MARKET_TYPE_US_STOCK', '2': 3},
    {'1': 'MARKET_TYPE_CRYPTO', '2': 4},
    {'1': 'MARKET_TYPE_FUND', '2': 5},
  ],
};

/// Descriptor for `MarketType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List marketTypeDescriptor = $convert.base64Decode(
    'CgpNYXJrZXRUeXBlEhsKF01BUktFVF9UWVBFX1VOU1BFQ0lGSUVEEAASFwoTTUFSS0VUX1RZUE'
    'VfQV9TSEFSRRABEhgKFE1BUktFVF9UWVBFX0hLX1NUT0NLEAISGAoUTUFSS0VUX1RZUEVfVVNf'
    'U1RPQ0sQAxIWChJNQVJLRVRfVFlQRV9DUllQVE8QBBIUChBNQVJLRVRfVFlQRV9GVU5EEAU=');

@$core.Deprecated('Use tradeTypeDescriptor instead')
const TradeType$json = {
  '1': 'TradeType',
  '2': [
    {'1': 'TRADE_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'TRADE_TYPE_BUY', '2': 1},
    {'1': 'TRADE_TYPE_SELL', '2': 2},
  ],
};

/// Descriptor for `TradeType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List tradeTypeDescriptor = $convert.base64Decode(
    'CglUcmFkZVR5cGUSGgoWVFJBREVfVFlQRV9VTlNQRUNJRklFRBAAEhIKDlRSQURFX1RZUEVfQl'
    'VZEAESEwoPVFJBREVfVFlQRV9TRUxMEAI=');

@$core.Deprecated('Use investmentDescriptor instead')
const Investment$json = {
  '1': 'Investment',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'symbol', '3': 3, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'market_type', '3': 5, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
    {'1': 'quantity', '3': 6, '4': 1, '5': 1, '10': 'quantity'},
    {'1': 'cost_basis', '3': 7, '4': 1, '5': 3, '10': 'costBasis'},
    {'1': 'current_value', '3': 8, '4': 1, '5': 3, '10': 'currentValue'},
    {'1': 'total_return', '3': 9, '4': 1, '5': 1, '10': 'totalReturn'},
    {'1': 'annualized_return', '3': 10, '4': 1, '5': 1, '10': 'annualizedReturn'},
    {'1': 'created_at', '3': 11, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
    {'1': 'updated_at', '3': 12, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedAt'},
  ],
};

/// Descriptor for `Investment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List investmentDescriptor = $convert.base64Decode(
    'CgpJbnZlc3RtZW50Eg4KAmlkGAEgASgJUgJpZBIXCgd1c2VyX2lkGAIgASgJUgZ1c2VySWQSFg'
    'oGc3ltYm9sGAMgASgJUgZzeW1ib2wSEgoEbmFtZRgEIAEoCVIEbmFtZRJHCgttYXJrZXRfdHlw'
    'ZRgFIAEoDjImLmZhbWlseWxlZGdlci5pbnZlc3RtZW50LnYxLk1hcmtldFR5cGVSCm1hcmtldF'
    'R5cGUSGgoIcXVhbnRpdHkYBiABKAFSCHF1YW50aXR5Eh0KCmNvc3RfYmFzaXMYByABKANSCWNv'
    'c3RCYXNpcxIjCg1jdXJyZW50X3ZhbHVlGAggASgDUgxjdXJyZW50VmFsdWUSIQoMdG90YWxfcm'
    'V0dXJuGAkgASgBUgt0b3RhbFJldHVybhIrChFhbm51YWxpemVkX3JldHVybhgKIAEoAVIQYW5u'
    'dWFsaXplZFJldHVybhI5CgpjcmVhdGVkX2F0GAsgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbW'
    'VzdGFtcFIJY3JlYXRlZEF0EjkKCnVwZGF0ZWRfYXQYDCABKAsyGi5nb29nbGUucHJvdG9idWYu'
    'VGltZXN0YW1wUgl1cGRhdGVkQXQ=');

@$core.Deprecated('Use investmentTradeDescriptor instead')
const InvestmentTrade$json = {
  '1': 'InvestmentTrade',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'investment_id', '3': 2, '4': 1, '5': 9, '10': 'investmentId'},
    {'1': 'trade_type', '3': 3, '4': 1, '5': 14, '6': '.familyledger.investment.v1.TradeType', '10': 'tradeType'},
    {'1': 'quantity', '3': 4, '4': 1, '5': 1, '10': 'quantity'},
    {'1': 'price', '3': 5, '4': 1, '5': 3, '10': 'price'},
    {'1': 'total_amount', '3': 6, '4': 1, '5': 3, '10': 'totalAmount'},
    {'1': 'fee', '3': 7, '4': 1, '5': 3, '10': 'fee'},
    {'1': 'trade_date', '3': 8, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'tradeDate'},
  ],
};

/// Descriptor for `InvestmentTrade`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List investmentTradeDescriptor = $convert.base64Decode(
    'Cg9JbnZlc3RtZW50VHJhZGUSDgoCaWQYASABKAlSAmlkEiMKDWludmVzdG1lbnRfaWQYAiABKA'
    'lSDGludmVzdG1lbnRJZBJECgp0cmFkZV90eXBlGAMgASgOMiUuZmFtaWx5bGVkZ2VyLmludmVz'
    'dG1lbnQudjEuVHJhZGVUeXBlUgl0cmFkZVR5cGUSGgoIcXVhbnRpdHkYBCABKAFSCHF1YW50aX'
    'R5EhQKBXByaWNlGAUgASgDUgVwcmljZRIhCgx0b3RhbF9hbW91bnQYBiABKANSC3RvdGFsQW1v'
    'dW50EhAKA2ZlZRgHIAEoA1IDZmVlEjkKCnRyYWRlX2RhdGUYCCABKAsyGi5nb29nbGUucHJvdG'
    '9idWYuVGltZXN0YW1wUgl0cmFkZURhdGU=');

@$core.Deprecated('Use marketQuoteDescriptor instead')
const MarketQuote$json = {
  '1': 'MarketQuote',
  '2': [
    {'1': 'symbol', '3': 1, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'market_type', '3': 3, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
    {'1': 'current_price', '3': 4, '4': 1, '5': 3, '10': 'currentPrice'},
    {'1': 'change', '3': 5, '4': 1, '5': 3, '10': 'change'},
    {'1': 'change_percent', '3': 6, '4': 1, '5': 1, '10': 'changePercent'},
    {'1': 'open', '3': 7, '4': 1, '5': 3, '10': 'open'},
    {'1': 'high', '3': 8, '4': 1, '5': 3, '10': 'high'},
    {'1': 'low', '3': 9, '4': 1, '5': 3, '10': 'low'},
    {'1': 'prev_close', '3': 10, '4': 1, '5': 3, '10': 'prevClose'},
    {'1': 'updated_at', '3': 11, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedAt'},
  ],
};

/// Descriptor for `MarketQuote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List marketQuoteDescriptor = $convert.base64Decode(
    'CgtNYXJrZXRRdW90ZRIWCgZzeW1ib2wYASABKAlSBnN5bWJvbBISCgRuYW1lGAIgASgJUgRuYW'
    '1lEkcKC21hcmtldF90eXBlGAMgASgOMiYuZmFtaWx5bGVkZ2VyLmludmVzdG1lbnQudjEuTWFy'
    'a2V0VHlwZVIKbWFya2V0VHlwZRIjCg1jdXJyZW50X3ByaWNlGAQgASgDUgxjdXJyZW50UHJpY2'
    'USFgoGY2hhbmdlGAUgASgDUgZjaGFuZ2USJQoOY2hhbmdlX3BlcmNlbnQYBiABKAFSDWNoYW5n'
    'ZVBlcmNlbnQSEgoEb3BlbhgHIAEoA1IEb3BlbhISCgRoaWdoGAggASgDUgRoaWdoEhAKA2xvdx'
    'gJIAEoA1IDbG93Eh0KCnByZXZfY2xvc2UYCiABKANSCXByZXZDbG9zZRI5Cgp1cGRhdGVkX2F0'
    'GAsgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJdXBkYXRlZEF0');

@$core.Deprecated('Use portfolioSummaryDescriptor instead')
const PortfolioSummary$json = {
  '1': 'PortfolioSummary',
  '2': [
    {'1': 'total_value', '3': 1, '4': 1, '5': 3, '10': 'totalValue'},
    {'1': 'total_cost', '3': 2, '4': 1, '5': 3, '10': 'totalCost'},
    {'1': 'total_profit', '3': 3, '4': 1, '5': 3, '10': 'totalProfit'},
    {'1': 'total_return', '3': 4, '4': 1, '5': 1, '10': 'totalReturn'},
    {'1': 'holdings', '3': 5, '4': 3, '5': 11, '6': '.familyledger.investment.v1.HoldingItem', '10': 'holdings'},
  ],
};

/// Descriptor for `PortfolioSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List portfolioSummaryDescriptor = $convert.base64Decode(
    'ChBQb3J0Zm9saW9TdW1tYXJ5Eh8KC3RvdGFsX3ZhbHVlGAEgASgDUgp0b3RhbFZhbHVlEh0KCn'
    'RvdGFsX2Nvc3QYAiABKANSCXRvdGFsQ29zdBIhCgx0b3RhbF9wcm9maXQYAyABKANSC3RvdGFs'
    'UHJvZml0EiEKDHRvdGFsX3JldHVybhgEIAEoAVILdG90YWxSZXR1cm4SQwoIaG9sZGluZ3MYBS'
    'ADKAsyJy5mYW1pbHlsZWRnZXIuaW52ZXN0bWVudC52MS5Ib2xkaW5nSXRlbVIIaG9sZGluZ3M=');

@$core.Deprecated('Use holdingItemDescriptor instead')
const HoldingItem$json = {
  '1': 'HoldingItem',
  '2': [
    {'1': 'investment_id', '3': 1, '4': 1, '5': 9, '10': 'investmentId'},
    {'1': 'symbol', '3': 2, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'quantity', '3': 4, '4': 1, '5': 1, '10': 'quantity'},
    {'1': 'current_value', '3': 5, '4': 1, '5': 3, '10': 'currentValue'},
    {'1': 'weight', '3': 6, '4': 1, '5': 1, '10': 'weight'},
    {'1': 'return_rate', '3': 7, '4': 1, '5': 1, '10': 'returnRate'},
  ],
};

/// Descriptor for `HoldingItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List holdingItemDescriptor = $convert.base64Decode(
    'CgtIb2xkaW5nSXRlbRIjCg1pbnZlc3RtZW50X2lkGAEgASgJUgxpbnZlc3RtZW50SWQSFgoGc3'
    'ltYm9sGAIgASgJUgZzeW1ib2wSEgoEbmFtZRgDIAEoCVIEbmFtZRIaCghxdWFudGl0eRgEIAEo'
    'AVIIcXVhbnRpdHkSIwoNY3VycmVudF92YWx1ZRgFIAEoA1IMY3VycmVudFZhbHVlEhYKBndlaW'
    'dodBgGIAEoAVIGd2VpZ2h0Eh8KC3JldHVybl9yYXRlGAcgASgBUgpyZXR1cm5SYXRl');

@$core.Deprecated('Use pricePointDescriptor instead')
const PricePoint$json = {
  '1': 'PricePoint',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'timestamp'},
    {'1': 'price', '3': 2, '4': 1, '5': 3, '10': 'price'},
  ],
};

/// Descriptor for `PricePoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pricePointDescriptor = $convert.base64Decode(
    'CgpQcmljZVBvaW50EjgKCXRpbWVzdGFtcBgBIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3'
    'RhbXBSCXRpbWVzdGFtcBIUCgVwcmljZRgCIAEoA1IFcHJpY2U=');

@$core.Deprecated('Use symbolInfoDescriptor instead')
const SymbolInfo$json = {
  '1': 'SymbolInfo',
  '2': [
    {'1': 'symbol', '3': 1, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'market_type', '3': 3, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
  ],
};

/// Descriptor for `SymbolInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List symbolInfoDescriptor = $convert.base64Decode(
    'CgpTeW1ib2xJbmZvEhYKBnN5bWJvbBgBIAEoCVIGc3ltYm9sEhIKBG5hbWUYAiABKAlSBG5hbW'
    'USRwoLbWFya2V0X3R5cGUYAyABKA4yJi5mYW1pbHlsZWRnZXIuaW52ZXN0bWVudC52MS5NYXJr'
    'ZXRUeXBlUgptYXJrZXRUeXBl');

@$core.Deprecated('Use createInvestmentRequestDescriptor instead')
const CreateInvestmentRequest$json = {
  '1': 'CreateInvestmentRequest',
  '2': [
    {'1': 'symbol', '3': 1, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'market_type', '3': 3, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
  ],
};

/// Descriptor for `CreateInvestmentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createInvestmentRequestDescriptor = $convert.base64Decode(
    'ChdDcmVhdGVJbnZlc3RtZW50UmVxdWVzdBIWCgZzeW1ib2wYASABKAlSBnN5bWJvbBISCgRuYW'
    '1lGAIgASgJUgRuYW1lEkcKC21hcmtldF90eXBlGAMgASgOMiYuZmFtaWx5bGVkZ2VyLmludmVz'
    'dG1lbnQudjEuTWFya2V0VHlwZVIKbWFya2V0VHlwZQ==');

@$core.Deprecated('Use getInvestmentRequestDescriptor instead')
const GetInvestmentRequest$json = {
  '1': 'GetInvestmentRequest',
  '2': [
    {'1': 'investment_id', '3': 1, '4': 1, '5': 9, '10': 'investmentId'},
  ],
};

/// Descriptor for `GetInvestmentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getInvestmentRequestDescriptor = $convert.base64Decode(
    'ChRHZXRJbnZlc3RtZW50UmVxdWVzdBIjCg1pbnZlc3RtZW50X2lkGAEgASgJUgxpbnZlc3RtZW'
    '50SWQ=');

@$core.Deprecated('Use listInvestmentsRequestDescriptor instead')
const ListInvestmentsRequest$json = {
  '1': 'ListInvestmentsRequest',
  '2': [
    {'1': 'market_type', '3': 1, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
  ],
};

/// Descriptor for `ListInvestmentsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listInvestmentsRequestDescriptor = $convert.base64Decode(
    'ChZMaXN0SW52ZXN0bWVudHNSZXF1ZXN0EkcKC21hcmtldF90eXBlGAEgASgOMiYuZmFtaWx5bG'
    'VkZ2VyLmludmVzdG1lbnQudjEuTWFya2V0VHlwZVIKbWFya2V0VHlwZQ==');

@$core.Deprecated('Use listInvestmentsResponseDescriptor instead')
const ListInvestmentsResponse$json = {
  '1': 'ListInvestmentsResponse',
  '2': [
    {'1': 'investments', '3': 1, '4': 3, '5': 11, '6': '.familyledger.investment.v1.Investment', '10': 'investments'},
  ],
};

/// Descriptor for `ListInvestmentsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listInvestmentsResponseDescriptor = $convert.base64Decode(
    'ChdMaXN0SW52ZXN0bWVudHNSZXNwb25zZRJICgtpbnZlc3RtZW50cxgBIAMoCzImLmZhbWlseW'
    'xlZGdlci5pbnZlc3RtZW50LnYxLkludmVzdG1lbnRSC2ludmVzdG1lbnRz');

@$core.Deprecated('Use updateInvestmentRequestDescriptor instead')
const UpdateInvestmentRequest$json = {
  '1': 'UpdateInvestmentRequest',
  '2': [
    {'1': 'investment_id', '3': 1, '4': 1, '5': 9, '10': 'investmentId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `UpdateInvestmentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateInvestmentRequestDescriptor = $convert.base64Decode(
    'ChdVcGRhdGVJbnZlc3RtZW50UmVxdWVzdBIjCg1pbnZlc3RtZW50X2lkGAEgASgJUgxpbnZlc3'
    'RtZW50SWQSEgoEbmFtZRgCIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use deleteInvestmentRequestDescriptor instead')
const DeleteInvestmentRequest$json = {
  '1': 'DeleteInvestmentRequest',
  '2': [
    {'1': 'investment_id', '3': 1, '4': 1, '5': 9, '10': 'investmentId'},
  ],
};

/// Descriptor for `DeleteInvestmentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteInvestmentRequestDescriptor = $convert.base64Decode(
    'ChdEZWxldGVJbnZlc3RtZW50UmVxdWVzdBIjCg1pbnZlc3RtZW50X2lkGAEgASgJUgxpbnZlc3'
    'RtZW50SWQ=');

@$core.Deprecated('Use recordTradeRequestDescriptor instead')
const RecordTradeRequest$json = {
  '1': 'RecordTradeRequest',
  '2': [
    {'1': 'investment_id', '3': 1, '4': 1, '5': 9, '10': 'investmentId'},
    {'1': 'trade_type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.investment.v1.TradeType', '10': 'tradeType'},
    {'1': 'quantity', '3': 3, '4': 1, '5': 1, '10': 'quantity'},
    {'1': 'price', '3': 4, '4': 1, '5': 3, '10': 'price'},
    {'1': 'fee', '3': 5, '4': 1, '5': 3, '10': 'fee'},
    {'1': 'trade_date', '3': 6, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'tradeDate'},
  ],
};

/// Descriptor for `RecordTradeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordTradeRequestDescriptor = $convert.base64Decode(
    'ChJSZWNvcmRUcmFkZVJlcXVlc3QSIwoNaW52ZXN0bWVudF9pZBgBIAEoCVIMaW52ZXN0bWVudE'
    'lkEkQKCnRyYWRlX3R5cGUYAiABKA4yJS5mYW1pbHlsZWRnZXIuaW52ZXN0bWVudC52MS5UcmFk'
    'ZVR5cGVSCXRyYWRlVHlwZRIaCghxdWFudGl0eRgDIAEoAVIIcXVhbnRpdHkSFAoFcHJpY2UYBC'
    'ABKANSBXByaWNlEhAKA2ZlZRgFIAEoA1IDZmVlEjkKCnRyYWRlX2RhdGUYBiABKAsyGi5nb29n'
    'bGUucHJvdG9idWYuVGltZXN0YW1wUgl0cmFkZURhdGU=');

@$core.Deprecated('Use listTradesRequestDescriptor instead')
const ListTradesRequest$json = {
  '1': 'ListTradesRequest',
  '2': [
    {'1': 'investment_id', '3': 1, '4': 1, '5': 9, '10': 'investmentId'},
  ],
};

/// Descriptor for `ListTradesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTradesRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0VHJhZGVzUmVxdWVzdBIjCg1pbnZlc3RtZW50X2lkGAEgASgJUgxpbnZlc3RtZW50SW'
    'Q=');

@$core.Deprecated('Use listTradesResponseDescriptor instead')
const ListTradesResponse$json = {
  '1': 'ListTradesResponse',
  '2': [
    {'1': 'trades', '3': 1, '4': 3, '5': 11, '6': '.familyledger.investment.v1.InvestmentTrade', '10': 'trades'},
  ],
};

/// Descriptor for `ListTradesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTradesResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0VHJhZGVzUmVzcG9uc2USQwoGdHJhZGVzGAEgAygLMisuZmFtaWx5bGVkZ2VyLmludm'
    'VzdG1lbnQudjEuSW52ZXN0bWVudFRyYWRlUgZ0cmFkZXM=');

@$core.Deprecated('Use getPortfolioSummaryRequestDescriptor instead')
const GetPortfolioSummaryRequest$json = {
  '1': 'GetPortfolioSummaryRequest',
};

/// Descriptor for `GetPortfolioSummaryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPortfolioSummaryRequestDescriptor = $convert.base64Decode(
    'ChpHZXRQb3J0Zm9saW9TdW1tYXJ5UmVxdWVzdA==');

@$core.Deprecated('Use getQuoteRequestDescriptor instead')
const GetQuoteRequest$json = {
  '1': 'GetQuoteRequest',
  '2': [
    {'1': 'symbol', '3': 1, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'market_type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
  ],
};

/// Descriptor for `GetQuoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getQuoteRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRRdW90ZVJlcXVlc3QSFgoGc3ltYm9sGAEgASgJUgZzeW1ib2wSRwoLbWFya2V0X3R5cG'
    'UYAiABKA4yJi5mYW1pbHlsZWRnZXIuaW52ZXN0bWVudC52MS5NYXJrZXRUeXBlUgptYXJrZXRU'
    'eXBl');

@$core.Deprecated('Use batchGetQuotesRequestDescriptor instead')
const BatchGetQuotesRequest$json = {
  '1': 'BatchGetQuotesRequest',
  '2': [
    {'1': 'requests', '3': 1, '4': 3, '5': 11, '6': '.familyledger.investment.v1.GetQuoteRequest', '10': 'requests'},
  ],
};

/// Descriptor for `BatchGetQuotesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchGetQuotesRequestDescriptor = $convert.base64Decode(
    'ChVCYXRjaEdldFF1b3Rlc1JlcXVlc3QSRwoIcmVxdWVzdHMYASADKAsyKy5mYW1pbHlsZWRnZX'
    'IuaW52ZXN0bWVudC52MS5HZXRRdW90ZVJlcXVlc3RSCHJlcXVlc3Rz');

@$core.Deprecated('Use batchGetQuotesResponseDescriptor instead')
const BatchGetQuotesResponse$json = {
  '1': 'BatchGetQuotesResponse',
  '2': [
    {'1': 'quotes', '3': 1, '4': 3, '5': 11, '6': '.familyledger.investment.v1.MarketQuote', '10': 'quotes'},
  ],
};

/// Descriptor for `BatchGetQuotesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchGetQuotesResponseDescriptor = $convert.base64Decode(
    'ChZCYXRjaEdldFF1b3Rlc1Jlc3BvbnNlEj8KBnF1b3RlcxgBIAMoCzInLmZhbWlseWxlZGdlci'
    '5pbnZlc3RtZW50LnYxLk1hcmtldFF1b3RlUgZxdW90ZXM=');

@$core.Deprecated('Use searchSymbolRequestDescriptor instead')
const SearchSymbolRequest$json = {
  '1': 'SearchSymbolRequest',
  '2': [
    {'1': 'query', '3': 1, '4': 1, '5': 9, '10': 'query'},
    {'1': 'market_type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
  ],
};

/// Descriptor for `SearchSymbolRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchSymbolRequestDescriptor = $convert.base64Decode(
    'ChNTZWFyY2hTeW1ib2xSZXF1ZXN0EhQKBXF1ZXJ5GAEgASgJUgVxdWVyeRJHCgttYXJrZXRfdH'
    'lwZRgCIAEoDjImLmZhbWlseWxlZGdlci5pbnZlc3RtZW50LnYxLk1hcmtldFR5cGVSCm1hcmtl'
    'dFR5cGU=');

@$core.Deprecated('Use searchSymbolResponseDescriptor instead')
const SearchSymbolResponse$json = {
  '1': 'SearchSymbolResponse',
  '2': [
    {'1': 'symbols', '3': 1, '4': 3, '5': 11, '6': '.familyledger.investment.v1.SymbolInfo', '10': 'symbols'},
  ],
};

/// Descriptor for `SearchSymbolResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchSymbolResponseDescriptor = $convert.base64Decode(
    'ChRTZWFyY2hTeW1ib2xSZXNwb25zZRJACgdzeW1ib2xzGAEgAygLMiYuZmFtaWx5bGVkZ2VyLm'
    'ludmVzdG1lbnQudjEuU3ltYm9sSW5mb1IHc3ltYm9scw==');

@$core.Deprecated('Use getPriceHistoryRequestDescriptor instead')
const GetPriceHistoryRequest$json = {
  '1': 'GetPriceHistoryRequest',
  '2': [
    {'1': 'symbol', '3': 1, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'market_type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
    {'1': 'start_date', '3': 3, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'startDate'},
    {'1': 'end_date', '3': 4, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'endDate'},
  ],
};

/// Descriptor for `GetPriceHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPriceHistoryRequestDescriptor = $convert.base64Decode(
    'ChZHZXRQcmljZUhpc3RvcnlSZXF1ZXN0EhYKBnN5bWJvbBgBIAEoCVIGc3ltYm9sEkcKC21hcm'
    'tldF90eXBlGAIgASgOMiYuZmFtaWx5bGVkZ2VyLmludmVzdG1lbnQudjEuTWFya2V0VHlwZVIK'
    'bWFya2V0VHlwZRI5CgpzdGFydF9kYXRlGAMgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdG'
    'FtcFIJc3RhcnREYXRlEjUKCGVuZF9kYXRlGAQgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVz'
    'dGFtcFIHZW5kRGF0ZQ==');

@$core.Deprecated('Use priceHistoryResponseDescriptor instead')
const PriceHistoryResponse$json = {
  '1': 'PriceHistoryResponse',
  '2': [
    {'1': 'symbol', '3': 1, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'market_type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.investment.v1.MarketType', '10': 'marketType'},
    {'1': 'points', '3': 3, '4': 3, '5': 11, '6': '.familyledger.investment.v1.PricePoint', '10': 'points'},
  ],
};

/// Descriptor for `PriceHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List priceHistoryResponseDescriptor = $convert.base64Decode(
    'ChRQcmljZUhpc3RvcnlSZXNwb25zZRIWCgZzeW1ib2wYASABKAlSBnN5bWJvbBJHCgttYXJrZX'
    'RfdHlwZRgCIAEoDjImLmZhbWlseWxlZGdlci5pbnZlc3RtZW50LnYxLk1hcmtldFR5cGVSCm1h'
    'cmtldFR5cGUSPgoGcG9pbnRzGAMgAygLMiYuZmFtaWx5bGVkZ2VyLmludmVzdG1lbnQudjEuUH'
    'JpY2VQb2ludFIGcG9pbnRz');

