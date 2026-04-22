//
//  Generated code. Do not modify.
//  source: dashboard.proto
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

import 'dashboard.pb.dart' as $0;

export 'dashboard.pb.dart';

@$pb.GrpcServiceName('familyledger.dashboard.v1.DashboardService')
class DashboardServiceClient extends $grpc.Client {
  static final _$getNetWorth = $grpc.ClientMethod<$0.GetNetWorthRequest, $0.NetWorth>(
      '/familyledger.dashboard.v1.DashboardService/GetNetWorth',
      ($0.GetNetWorthRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.NetWorth.fromBuffer(value));
  static final _$getIncomeExpenseTrend = $grpc.ClientMethod<$0.TrendRequest, $0.TrendResponse>(
      '/familyledger.dashboard.v1.DashboardService/GetIncomeExpenseTrend',
      ($0.TrendRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TrendResponse.fromBuffer(value));
  static final _$getCategoryBreakdown = $grpc.ClientMethod<$0.CategoryBreakdownRequest, $0.CategoryBreakdownResponse>(
      '/familyledger.dashboard.v1.DashboardService/GetCategoryBreakdown',
      ($0.CategoryBreakdownRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.CategoryBreakdownResponse.fromBuffer(value));
  static final _$getBudgetSummary = $grpc.ClientMethod<$0.BudgetSummaryRequest, $0.BudgetSummaryResponse>(
      '/familyledger.dashboard.v1.DashboardService/GetBudgetSummary',
      ($0.BudgetSummaryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.BudgetSummaryResponse.fromBuffer(value));
  static final _$getNetWorthTrend = $grpc.ClientMethod<$0.TrendRequest, $0.TrendResponse>(
      '/familyledger.dashboard.v1.DashboardService/GetNetWorthTrend',
      ($0.TrendRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.TrendResponse.fromBuffer(value));

  DashboardServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.NetWorth> getNetWorth($0.GetNetWorthRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getNetWorth, request, options: options);
  }

  $grpc.ResponseFuture<$0.TrendResponse> getIncomeExpenseTrend($0.TrendRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getIncomeExpenseTrend, request, options: options);
  }

  $grpc.ResponseFuture<$0.CategoryBreakdownResponse> getCategoryBreakdown($0.CategoryBreakdownRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getCategoryBreakdown, request, options: options);
  }

  $grpc.ResponseFuture<$0.BudgetSummaryResponse> getBudgetSummary($0.BudgetSummaryRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getBudgetSummary, request, options: options);
  }

  $grpc.ResponseFuture<$0.TrendResponse> getNetWorthTrend($0.TrendRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getNetWorthTrend, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.dashboard.v1.DashboardService')
abstract class DashboardServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.dashboard.v1.DashboardService';

  DashboardServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetNetWorthRequest, $0.NetWorth>(
        'GetNetWorth',
        getNetWorth_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetNetWorthRequest.fromBuffer(value),
        ($0.NetWorth value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TrendRequest, $0.TrendResponse>(
        'GetIncomeExpenseTrend',
        getIncomeExpenseTrend_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TrendRequest.fromBuffer(value),
        ($0.TrendResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CategoryBreakdownRequest, $0.CategoryBreakdownResponse>(
        'GetCategoryBreakdown',
        getCategoryBreakdown_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CategoryBreakdownRequest.fromBuffer(value),
        ($0.CategoryBreakdownResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BudgetSummaryRequest, $0.BudgetSummaryResponse>(
        'GetBudgetSummary',
        getBudgetSummary_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BudgetSummaryRequest.fromBuffer(value),
        ($0.BudgetSummaryResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TrendRequest, $0.TrendResponse>(
        'GetNetWorthTrend',
        getNetWorthTrend_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TrendRequest.fromBuffer(value),
        ($0.TrendResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.NetWorth> getNetWorth_Pre($grpc.ServiceCall call, $async.Future<$0.GetNetWorthRequest> request) async {
    return getNetWorth(call, await request);
  }

  $async.Future<$0.TrendResponse> getIncomeExpenseTrend_Pre($grpc.ServiceCall call, $async.Future<$0.TrendRequest> request) async {
    return getIncomeExpenseTrend(call, await request);
  }

  $async.Future<$0.CategoryBreakdownResponse> getCategoryBreakdown_Pre($grpc.ServiceCall call, $async.Future<$0.CategoryBreakdownRequest> request) async {
    return getCategoryBreakdown(call, await request);
  }

  $async.Future<$0.BudgetSummaryResponse> getBudgetSummary_Pre($grpc.ServiceCall call, $async.Future<$0.BudgetSummaryRequest> request) async {
    return getBudgetSummary(call, await request);
  }

  $async.Future<$0.TrendResponse> getNetWorthTrend_Pre($grpc.ServiceCall call, $async.Future<$0.TrendRequest> request) async {
    return getNetWorthTrend(call, await request);
  }

  $async.Future<$0.NetWorth> getNetWorth($grpc.ServiceCall call, $0.GetNetWorthRequest request);
  $async.Future<$0.TrendResponse> getIncomeExpenseTrend($grpc.ServiceCall call, $0.TrendRequest request);
  $async.Future<$0.CategoryBreakdownResponse> getCategoryBreakdown($grpc.ServiceCall call, $0.CategoryBreakdownRequest request);
  $async.Future<$0.BudgetSummaryResponse> getBudgetSummary($grpc.ServiceCall call, $0.BudgetSummaryRequest request);
  $async.Future<$0.TrendResponse> getNetWorthTrend($grpc.ServiceCall call, $0.TrendRequest request);
}
