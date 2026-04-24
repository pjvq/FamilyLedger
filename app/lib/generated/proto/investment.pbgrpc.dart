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
import 'investment.pb.dart' as $2;

export 'investment.pb.dart';

@$pb.GrpcServiceName('familyledger.investment.v1.InvestmentService')
class InvestmentServiceClient extends $grpc.Client {
  static final _$createInvestment = $grpc.ClientMethod<$2.CreateInvestmentRequest, $2.Investment>(
      '/familyledger.investment.v1.InvestmentService/CreateInvestment',
      ($2.CreateInvestmentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.Investment.fromBuffer(value));
  static final _$getInvestment = $grpc.ClientMethod<$2.GetInvestmentRequest, $2.Investment>(
      '/familyledger.investment.v1.InvestmentService/GetInvestment',
      ($2.GetInvestmentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.Investment.fromBuffer(value));
  static final _$listInvestments = $grpc.ClientMethod<$2.ListInvestmentsRequest, $2.ListInvestmentsResponse>(
      '/familyledger.investment.v1.InvestmentService/ListInvestments',
      ($2.ListInvestmentsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.ListInvestmentsResponse.fromBuffer(value));
  static final _$updateInvestment = $grpc.ClientMethod<$2.UpdateInvestmentRequest, $2.Investment>(
      '/familyledger.investment.v1.InvestmentService/UpdateInvestment',
      ($2.UpdateInvestmentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.Investment.fromBuffer(value));
  static final _$deleteInvestment = $grpc.ClientMethod<$2.DeleteInvestmentRequest, $1.Empty>(
      '/familyledger.investment.v1.InvestmentService/DeleteInvestment',
      ($2.DeleteInvestmentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.Empty.fromBuffer(value));
  static final _$recordTrade = $grpc.ClientMethod<$2.RecordTradeRequest, $2.InvestmentTrade>(
      '/familyledger.investment.v1.InvestmentService/RecordTrade',
      ($2.RecordTradeRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.InvestmentTrade.fromBuffer(value));
  static final _$listTrades = $grpc.ClientMethod<$2.ListTradesRequest, $2.ListTradesResponse>(
      '/familyledger.investment.v1.InvestmentService/ListTrades',
      ($2.ListTradesRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.ListTradesResponse.fromBuffer(value));
  static final _$getPortfolioSummary = $grpc.ClientMethod<$2.GetPortfolioSummaryRequest, $2.PortfolioSummary>(
      '/familyledger.investment.v1.InvestmentService/GetPortfolioSummary',
      ($2.GetPortfolioSummaryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.PortfolioSummary.fromBuffer(value));

  InvestmentServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$2.Investment> createInvestment($2.CreateInvestmentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createInvestment, request, options: options);
  }

  $grpc.ResponseFuture<$2.Investment> getInvestment($2.GetInvestmentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getInvestment, request, options: options);
  }

  $grpc.ResponseFuture<$2.ListInvestmentsResponse> listInvestments($2.ListInvestmentsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listInvestments, request, options: options);
  }

  $grpc.ResponseFuture<$2.Investment> updateInvestment($2.UpdateInvestmentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateInvestment, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteInvestment($2.DeleteInvestmentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteInvestment, request, options: options);
  }

  $grpc.ResponseFuture<$2.InvestmentTrade> recordTrade($2.RecordTradeRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$recordTrade, request, options: options);
  }

  $grpc.ResponseFuture<$2.ListTradesResponse> listTrades($2.ListTradesRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listTrades, request, options: options);
  }

  $grpc.ResponseFuture<$2.PortfolioSummary> getPortfolioSummary($2.GetPortfolioSummaryRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getPortfolioSummary, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.investment.v1.InvestmentService')
abstract class InvestmentServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.investment.v1.InvestmentService';

  InvestmentServiceBase() {
    $addMethod($grpc.ServiceMethod<$2.CreateInvestmentRequest, $2.Investment>(
        'CreateInvestment',
        createInvestment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.CreateInvestmentRequest.fromBuffer(value),
        ($2.Investment value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.GetInvestmentRequest, $2.Investment>(
        'GetInvestment',
        getInvestment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.GetInvestmentRequest.fromBuffer(value),
        ($2.Investment value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.ListInvestmentsRequest, $2.ListInvestmentsResponse>(
        'ListInvestments',
        listInvestments_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.ListInvestmentsRequest.fromBuffer(value),
        ($2.ListInvestmentsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.UpdateInvestmentRequest, $2.Investment>(
        'UpdateInvestment',
        updateInvestment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.UpdateInvestmentRequest.fromBuffer(value),
        ($2.Investment value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.DeleteInvestmentRequest, $1.Empty>(
        'DeleteInvestment',
        deleteInvestment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.DeleteInvestmentRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.RecordTradeRequest, $2.InvestmentTrade>(
        'RecordTrade',
        recordTrade_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.RecordTradeRequest.fromBuffer(value),
        ($2.InvestmentTrade value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.ListTradesRequest, $2.ListTradesResponse>(
        'ListTrades',
        listTrades_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.ListTradesRequest.fromBuffer(value),
        ($2.ListTradesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.GetPortfolioSummaryRequest, $2.PortfolioSummary>(
        'GetPortfolioSummary',
        getPortfolioSummary_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.GetPortfolioSummaryRequest.fromBuffer(value),
        ($2.PortfolioSummary value) => value.writeToBuffer()));
  }

  $async.Future<$2.Investment> createInvestment_Pre($grpc.ServiceCall call, $async.Future<$2.CreateInvestmentRequest> request) async {
    return createInvestment(call, await request);
  }

  $async.Future<$2.Investment> getInvestment_Pre($grpc.ServiceCall call, $async.Future<$2.GetInvestmentRequest> request) async {
    return getInvestment(call, await request);
  }

  $async.Future<$2.ListInvestmentsResponse> listInvestments_Pre($grpc.ServiceCall call, $async.Future<$2.ListInvestmentsRequest> request) async {
    return listInvestments(call, await request);
  }

  $async.Future<$2.Investment> updateInvestment_Pre($grpc.ServiceCall call, $async.Future<$2.UpdateInvestmentRequest> request) async {
    return updateInvestment(call, await request);
  }

  $async.Future<$1.Empty> deleteInvestment_Pre($grpc.ServiceCall call, $async.Future<$2.DeleteInvestmentRequest> request) async {
    return deleteInvestment(call, await request);
  }

  $async.Future<$2.InvestmentTrade> recordTrade_Pre($grpc.ServiceCall call, $async.Future<$2.RecordTradeRequest> request) async {
    return recordTrade(call, await request);
  }

  $async.Future<$2.ListTradesResponse> listTrades_Pre($grpc.ServiceCall call, $async.Future<$2.ListTradesRequest> request) async {
    return listTrades(call, await request);
  }

  $async.Future<$2.PortfolioSummary> getPortfolioSummary_Pre($grpc.ServiceCall call, $async.Future<$2.GetPortfolioSummaryRequest> request) async {
    return getPortfolioSummary(call, await request);
  }

  $async.Future<$2.Investment> createInvestment($grpc.ServiceCall call, $2.CreateInvestmentRequest request);
  $async.Future<$2.Investment> getInvestment($grpc.ServiceCall call, $2.GetInvestmentRequest request);
  $async.Future<$2.ListInvestmentsResponse> listInvestments($grpc.ServiceCall call, $2.ListInvestmentsRequest request);
  $async.Future<$2.Investment> updateInvestment($grpc.ServiceCall call, $2.UpdateInvestmentRequest request);
  $async.Future<$1.Empty> deleteInvestment($grpc.ServiceCall call, $2.DeleteInvestmentRequest request);
  $async.Future<$2.InvestmentTrade> recordTrade($grpc.ServiceCall call, $2.RecordTradeRequest request);
  $async.Future<$2.ListTradesResponse> listTrades($grpc.ServiceCall call, $2.ListTradesRequest request);
  $async.Future<$2.PortfolioSummary> getPortfolioSummary($grpc.ServiceCall call, $2.GetPortfolioSummaryRequest request);
}
@$pb.GrpcServiceName('familyledger.investment.v1.MarketDataService')
class MarketDataServiceClient extends $grpc.Client {
  static final _$getQuote = $grpc.ClientMethod<$2.GetQuoteRequest, $2.MarketQuote>(
      '/familyledger.investment.v1.MarketDataService/GetQuote',
      ($2.GetQuoteRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.MarketQuote.fromBuffer(value));
  static final _$batchGetQuotes = $grpc.ClientMethod<$2.BatchGetQuotesRequest, $2.BatchGetQuotesResponse>(
      '/familyledger.investment.v1.MarketDataService/BatchGetQuotes',
      ($2.BatchGetQuotesRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.BatchGetQuotesResponse.fromBuffer(value));
  static final _$searchSymbol = $grpc.ClientMethod<$2.SearchSymbolRequest, $2.SearchSymbolResponse>(
      '/familyledger.investment.v1.MarketDataService/SearchSymbol',
      ($2.SearchSymbolRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.SearchSymbolResponse.fromBuffer(value));
  static final _$getPriceHistory = $grpc.ClientMethod<$2.GetPriceHistoryRequest, $2.PriceHistoryResponse>(
      '/familyledger.investment.v1.MarketDataService/GetPriceHistory',
      ($2.GetPriceHistoryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.PriceHistoryResponse.fromBuffer(value));

  MarketDataServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$2.MarketQuote> getQuote($2.GetQuoteRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getQuote, request, options: options);
  }

  $grpc.ResponseFuture<$2.BatchGetQuotesResponse> batchGetQuotes($2.BatchGetQuotesRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$batchGetQuotes, request, options: options);
  }

  $grpc.ResponseFuture<$2.SearchSymbolResponse> searchSymbol($2.SearchSymbolRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$searchSymbol, request, options: options);
  }

  $grpc.ResponseFuture<$2.PriceHistoryResponse> getPriceHistory($2.GetPriceHistoryRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getPriceHistory, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.investment.v1.MarketDataService')
abstract class MarketDataServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.investment.v1.MarketDataService';

  MarketDataServiceBase() {
    $addMethod($grpc.ServiceMethod<$2.GetQuoteRequest, $2.MarketQuote>(
        'GetQuote',
        getQuote_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.GetQuoteRequest.fromBuffer(value),
        ($2.MarketQuote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.BatchGetQuotesRequest, $2.BatchGetQuotesResponse>(
        'BatchGetQuotes',
        batchGetQuotes_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.BatchGetQuotesRequest.fromBuffer(value),
        ($2.BatchGetQuotesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.SearchSymbolRequest, $2.SearchSymbolResponse>(
        'SearchSymbol',
        searchSymbol_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.SearchSymbolRequest.fromBuffer(value),
        ($2.SearchSymbolResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.GetPriceHistoryRequest, $2.PriceHistoryResponse>(
        'GetPriceHistory',
        getPriceHistory_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.GetPriceHistoryRequest.fromBuffer(value),
        ($2.PriceHistoryResponse value) => value.writeToBuffer()));
  }

  $async.Future<$2.MarketQuote> getQuote_Pre($grpc.ServiceCall call, $async.Future<$2.GetQuoteRequest> request) async {
    return getQuote(call, await request);
  }

  $async.Future<$2.BatchGetQuotesResponse> batchGetQuotes_Pre($grpc.ServiceCall call, $async.Future<$2.BatchGetQuotesRequest> request) async {
    return batchGetQuotes(call, await request);
  }

  $async.Future<$2.SearchSymbolResponse> searchSymbol_Pre($grpc.ServiceCall call, $async.Future<$2.SearchSymbolRequest> request) async {
    return searchSymbol(call, await request);
  }

  $async.Future<$2.PriceHistoryResponse> getPriceHistory_Pre($grpc.ServiceCall call, $async.Future<$2.GetPriceHistoryRequest> request) async {
    return getPriceHistory(call, await request);
  }

  $async.Future<$2.MarketQuote> getQuote($grpc.ServiceCall call, $2.GetQuoteRequest request);
  $async.Future<$2.BatchGetQuotesResponse> batchGetQuotes($grpc.ServiceCall call, $2.BatchGetQuotesRequest request);
  $async.Future<$2.SearchSymbolResponse> searchSymbol($grpc.ServiceCall call, $2.SearchSymbolRequest request);
  $async.Future<$2.PriceHistoryResponse> getPriceHistory($grpc.ServiceCall call, $2.GetPriceHistoryRequest request);
}
