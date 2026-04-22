//
//  Generated code. Do not modify.
//  source: investment.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'google/protobuf/empty.pb.dart' as $1;
import 'investment.pb.dart' as $0;

export 'investment.pb.dart';

@$pb.GrpcServiceName('familyledger.investment.v1.InvestmentService')
class InvestmentServiceClient extends $grpc.Client {
  static final _$createInvestment = $grpc.ClientMethod<$0.CreateInvestmentRequest, $0.Investment>(
      '/familyledger.investment.v1.InvestmentService/CreateInvestment',
      ($0.CreateInvestmentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Investment.fromBuffer(value));
  static final _$getInvestment = $grpc.ClientMethod<$0.GetInvestmentRequest, $0.Investment>(
      '/familyledger.investment.v1.InvestmentService/GetInvestment',
      ($0.GetInvestmentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Investment.fromBuffer(value));
  static final _$listInvestments = $grpc.ClientMethod<$0.ListInvestmentsRequest, $0.ListInvestmentsResponse>(
      '/familyledger.investment.v1.InvestmentService/ListInvestments',
      ($0.ListInvestmentsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListInvestmentsResponse.fromBuffer(value));
  static final _$updateInvestment = $grpc.ClientMethod<$0.UpdateInvestmentRequest, $0.Investment>(
      '/familyledger.investment.v1.InvestmentService/UpdateInvestment',
      ($0.UpdateInvestmentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Investment.fromBuffer(value));
  static final _$deleteInvestment = $grpc.ClientMethod<$0.DeleteInvestmentRequest, $1.Empty>(
      '/familyledger.investment.v1.InvestmentService/DeleteInvestment',
      ($0.DeleteInvestmentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.Empty.fromBuffer(value));
  static final _$recordTrade = $grpc.ClientMethod<$0.RecordTradeRequest, $0.InvestmentTrade>(
      '/familyledger.investment.v1.InvestmentService/RecordTrade',
      ($0.RecordTradeRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.InvestmentTrade.fromBuffer(value));
  static final _$listTrades = $grpc.ClientMethod<$0.ListTradesRequest, $0.ListTradesResponse>(
      '/familyledger.investment.v1.InvestmentService/ListTrades',
      ($0.ListTradesRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListTradesResponse.fromBuffer(value));
  static final _$getPortfolioSummary = $grpc.ClientMethod<$0.GetPortfolioSummaryRequest, $0.PortfolioSummary>(
      '/familyledger.investment.v1.InvestmentService/GetPortfolioSummary',
      ($0.GetPortfolioSummaryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.PortfolioSummary.fromBuffer(value));

  InvestmentServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.Investment> createInvestment($0.CreateInvestmentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createInvestment, request, options: options);
  }

  $grpc.ResponseFuture<$0.Investment> getInvestment($0.GetInvestmentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getInvestment, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListInvestmentsResponse> listInvestments($0.ListInvestmentsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listInvestments, request, options: options);
  }

  $grpc.ResponseFuture<$0.Investment> updateInvestment($0.UpdateInvestmentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateInvestment, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteInvestment($0.DeleteInvestmentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteInvestment, request, options: options);
  }

  $grpc.ResponseFuture<$0.InvestmentTrade> recordTrade($0.RecordTradeRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$recordTrade, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListTradesResponse> listTrades($0.ListTradesRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listTrades, request, options: options);
  }

  $grpc.ResponseFuture<$0.PortfolioSummary> getPortfolioSummary($0.GetPortfolioSummaryRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getPortfolioSummary, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.investment.v1.InvestmentService')
abstract class InvestmentServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.investment.v1.InvestmentService';

  InvestmentServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateInvestmentRequest, $0.Investment>(
        'CreateInvestment',
        createInvestment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateInvestmentRequest.fromBuffer(value),
        ($0.Investment value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetInvestmentRequest, $0.Investment>(
        'GetInvestment',
        getInvestment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetInvestmentRequest.fromBuffer(value),
        ($0.Investment value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListInvestmentsRequest, $0.ListInvestmentsResponse>(
        'ListInvestments',
        listInvestments_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListInvestmentsRequest.fromBuffer(value),
        ($0.ListInvestmentsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateInvestmentRequest, $0.Investment>(
        'UpdateInvestment',
        updateInvestment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateInvestmentRequest.fromBuffer(value),
        ($0.Investment value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteInvestmentRequest, $1.Empty>(
        'DeleteInvestment',
        deleteInvestment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteInvestmentRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RecordTradeRequest, $0.InvestmentTrade>(
        'RecordTrade',
        recordTrade_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RecordTradeRequest.fromBuffer(value),
        ($0.InvestmentTrade value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListTradesRequest, $0.ListTradesResponse>(
        'ListTrades',
        listTrades_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListTradesRequest.fromBuffer(value),
        ($0.ListTradesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPortfolioSummaryRequest, $0.PortfolioSummary>(
        'GetPortfolioSummary',
        getPortfolioSummary_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetPortfolioSummaryRequest.fromBuffer(value),
        ($0.PortfolioSummary value) => value.writeToBuffer()));
  }

  $async.Future<$0.Investment> createInvestment_Pre($grpc.ServiceCall call, $async.Future<$0.CreateInvestmentRequest> request) async {
    return createInvestment(call, await request);
  }

  $async.Future<$0.Investment> getInvestment_Pre($grpc.ServiceCall call, $async.Future<$0.GetInvestmentRequest> request) async {
    return getInvestment(call, await request);
  }

  $async.Future<$0.ListInvestmentsResponse> listInvestments_Pre($grpc.ServiceCall call, $async.Future<$0.ListInvestmentsRequest> request) async {
    return listInvestments(call, await request);
  }

  $async.Future<$0.Investment> updateInvestment_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateInvestmentRequest> request) async {
    return updateInvestment(call, await request);
  }

  $async.Future<$1.Empty> deleteInvestment_Pre($grpc.ServiceCall call, $async.Future<$0.DeleteInvestmentRequest> request) async {
    return deleteInvestment(call, await request);
  }

  $async.Future<$0.InvestmentTrade> recordTrade_Pre($grpc.ServiceCall call, $async.Future<$0.RecordTradeRequest> request) async {
    return recordTrade(call, await request);
  }

  $async.Future<$0.ListTradesResponse> listTrades_Pre($grpc.ServiceCall call, $async.Future<$0.ListTradesRequest> request) async {
    return listTrades(call, await request);
  }

  $async.Future<$0.PortfolioSummary> getPortfolioSummary_Pre($grpc.ServiceCall call, $async.Future<$0.GetPortfolioSummaryRequest> request) async {
    return getPortfolioSummary(call, await request);
  }

  $async.Future<$0.Investment> createInvestment($grpc.ServiceCall call, $0.CreateInvestmentRequest request);
  $async.Future<$0.Investment> getInvestment($grpc.ServiceCall call, $0.GetInvestmentRequest request);
  $async.Future<$0.ListInvestmentsResponse> listInvestments($grpc.ServiceCall call, $0.ListInvestmentsRequest request);
  $async.Future<$0.Investment> updateInvestment($grpc.ServiceCall call, $0.UpdateInvestmentRequest request);
  $async.Future<$1.Empty> deleteInvestment($grpc.ServiceCall call, $0.DeleteInvestmentRequest request);
  $async.Future<$0.InvestmentTrade> recordTrade($grpc.ServiceCall call, $0.RecordTradeRequest request);
  $async.Future<$0.ListTradesResponse> listTrades($grpc.ServiceCall call, $0.ListTradesRequest request);
  $async.Future<$0.PortfolioSummary> getPortfolioSummary($grpc.ServiceCall call, $0.GetPortfolioSummaryRequest request);
}
@$pb.GrpcServiceName('familyledger.investment.v1.MarketDataService')
class MarketDataServiceClient extends $grpc.Client {
  static final _$getQuote = $grpc.ClientMethod<$0.GetQuoteRequest, $0.MarketQuote>(
      '/familyledger.investment.v1.MarketDataService/GetQuote',
      ($0.GetQuoteRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.MarketQuote.fromBuffer(value));
  static final _$batchGetQuotes = $grpc.ClientMethod<$0.BatchGetQuotesRequest, $0.BatchGetQuotesResponse>(
      '/familyledger.investment.v1.MarketDataService/BatchGetQuotes',
      ($0.BatchGetQuotesRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.BatchGetQuotesResponse.fromBuffer(value));
  static final _$searchSymbol = $grpc.ClientMethod<$0.SearchSymbolRequest, $0.SearchSymbolResponse>(
      '/familyledger.investment.v1.MarketDataService/SearchSymbol',
      ($0.SearchSymbolRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SearchSymbolResponse.fromBuffer(value));
  static final _$getPriceHistory = $grpc.ClientMethod<$0.GetPriceHistoryRequest, $0.PriceHistoryResponse>(
      '/familyledger.investment.v1.MarketDataService/GetPriceHistory',
      ($0.GetPriceHistoryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.PriceHistoryResponse.fromBuffer(value));

  MarketDataServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.MarketQuote> getQuote($0.GetQuoteRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getQuote, request, options: options);
  }

  $grpc.ResponseFuture<$0.BatchGetQuotesResponse> batchGetQuotes($0.BatchGetQuotesRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$batchGetQuotes, request, options: options);
  }

  $grpc.ResponseFuture<$0.SearchSymbolResponse> searchSymbol($0.SearchSymbolRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$searchSymbol, request, options: options);
  }

  $grpc.ResponseFuture<$0.PriceHistoryResponse> getPriceHistory($0.GetPriceHistoryRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getPriceHistory, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.investment.v1.MarketDataService')
abstract class MarketDataServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.investment.v1.MarketDataService';

  MarketDataServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetQuoteRequest, $0.MarketQuote>(
        'GetQuote',
        getQuote_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetQuoteRequest.fromBuffer(value),
        ($0.MarketQuote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BatchGetQuotesRequest, $0.BatchGetQuotesResponse>(
        'BatchGetQuotes',
        batchGetQuotes_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BatchGetQuotesRequest.fromBuffer(value),
        ($0.BatchGetQuotesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SearchSymbolRequest, $0.SearchSymbolResponse>(
        'SearchSymbol',
        searchSymbol_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SearchSymbolRequest.fromBuffer(value),
        ($0.SearchSymbolResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPriceHistoryRequest, $0.PriceHistoryResponse>(
        'GetPriceHistory',
        getPriceHistory_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetPriceHistoryRequest.fromBuffer(value),
        ($0.PriceHistoryResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.MarketQuote> getQuote_Pre($grpc.ServiceCall call, $async.Future<$0.GetQuoteRequest> request) async {
    return getQuote(call, await request);
  }

  $async.Future<$0.BatchGetQuotesResponse> batchGetQuotes_Pre($grpc.ServiceCall call, $async.Future<$0.BatchGetQuotesRequest> request) async {
    return batchGetQuotes(call, await request);
  }

  $async.Future<$0.SearchSymbolResponse> searchSymbol_Pre($grpc.ServiceCall call, $async.Future<$0.SearchSymbolRequest> request) async {
    return searchSymbol(call, await request);
  }

  $async.Future<$0.PriceHistoryResponse> getPriceHistory_Pre($grpc.ServiceCall call, $async.Future<$0.GetPriceHistoryRequest> request) async {
    return getPriceHistory(call, await request);
  }

  $async.Future<$0.MarketQuote> getQuote($grpc.ServiceCall call, $0.GetQuoteRequest request);
  $async.Future<$0.BatchGetQuotesResponse> batchGetQuotes($grpc.ServiceCall call, $0.BatchGetQuotesRequest request);
  $async.Future<$0.SearchSymbolResponse> searchSymbol($grpc.ServiceCall call, $0.SearchSymbolRequest request);
  $async.Future<$0.PriceHistoryResponse> getPriceHistory($grpc.ServiceCall call, $0.GetPriceHistoryRequest request);
}
