//
//  Generated code. Do not modify.
//  source: budget.proto
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

import 'budget.pb.dart' as $0;

export 'budget.pb.dart';

@$pb.GrpcServiceName('familyledger.budget.v1.BudgetService')
class BudgetServiceClient extends $grpc.Client {
  static final _$createBudget = $grpc.ClientMethod<$0.CreateBudgetRequest, $0.CreateBudgetResponse>(
      '/familyledger.budget.v1.BudgetService/CreateBudget',
      ($0.CreateBudgetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.CreateBudgetResponse.fromBuffer(value));
  static final _$getBudget = $grpc.ClientMethod<$0.GetBudgetRequest, $0.GetBudgetResponse>(
      '/familyledger.budget.v1.BudgetService/GetBudget',
      ($0.GetBudgetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetBudgetResponse.fromBuffer(value));
  static final _$listBudgets = $grpc.ClientMethod<$0.ListBudgetsRequest, $0.ListBudgetsResponse>(
      '/familyledger.budget.v1.BudgetService/ListBudgets',
      ($0.ListBudgetsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListBudgetsResponse.fromBuffer(value));
  static final _$updateBudget = $grpc.ClientMethod<$0.UpdateBudgetRequest, $0.UpdateBudgetResponse>(
      '/familyledger.budget.v1.BudgetService/UpdateBudget',
      ($0.UpdateBudgetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.UpdateBudgetResponse.fromBuffer(value));
  static final _$deleteBudget = $grpc.ClientMethod<$0.DeleteBudgetRequest, $0.DeleteBudgetResponse>(
      '/familyledger.budget.v1.BudgetService/DeleteBudget',
      ($0.DeleteBudgetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.DeleteBudgetResponse.fromBuffer(value));
  static final _$getBudgetExecution = $grpc.ClientMethod<$0.GetBudgetExecutionRequest, $0.GetBudgetExecutionResponse>(
      '/familyledger.budget.v1.BudgetService/GetBudgetExecution',
      ($0.GetBudgetExecutionRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetBudgetExecutionResponse.fromBuffer(value));

  BudgetServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.CreateBudgetResponse> createBudget($0.CreateBudgetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createBudget, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetBudgetResponse> getBudget($0.GetBudgetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getBudget, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListBudgetsResponse> listBudgets($0.ListBudgetsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listBudgets, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateBudgetResponse> updateBudget($0.UpdateBudgetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateBudget, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteBudgetResponse> deleteBudget($0.DeleteBudgetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteBudget, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetBudgetExecutionResponse> getBudgetExecution($0.GetBudgetExecutionRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getBudgetExecution, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.budget.v1.BudgetService')
abstract class BudgetServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.budget.v1.BudgetService';

  BudgetServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateBudgetRequest, $0.CreateBudgetResponse>(
        'CreateBudget',
        createBudget_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateBudgetRequest.fromBuffer(value),
        ($0.CreateBudgetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetBudgetRequest, $0.GetBudgetResponse>(
        'GetBudget',
        getBudget_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetBudgetRequest.fromBuffer(value),
        ($0.GetBudgetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListBudgetsRequest, $0.ListBudgetsResponse>(
        'ListBudgets',
        listBudgets_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListBudgetsRequest.fromBuffer(value),
        ($0.ListBudgetsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateBudgetRequest, $0.UpdateBudgetResponse>(
        'UpdateBudget',
        updateBudget_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateBudgetRequest.fromBuffer(value),
        ($0.UpdateBudgetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteBudgetRequest, $0.DeleteBudgetResponse>(
        'DeleteBudget',
        deleteBudget_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteBudgetRequest.fromBuffer(value),
        ($0.DeleteBudgetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetBudgetExecutionRequest, $0.GetBudgetExecutionResponse>(
        'GetBudgetExecution',
        getBudgetExecution_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetBudgetExecutionRequest.fromBuffer(value),
        ($0.GetBudgetExecutionResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreateBudgetResponse> createBudget_Pre($grpc.ServiceCall call, $async.Future<$0.CreateBudgetRequest> request) async {
    return createBudget(call, await request);
  }

  $async.Future<$0.GetBudgetResponse> getBudget_Pre($grpc.ServiceCall call, $async.Future<$0.GetBudgetRequest> request) async {
    return getBudget(call, await request);
  }

  $async.Future<$0.ListBudgetsResponse> listBudgets_Pre($grpc.ServiceCall call, $async.Future<$0.ListBudgetsRequest> request) async {
    return listBudgets(call, await request);
  }

  $async.Future<$0.UpdateBudgetResponse> updateBudget_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateBudgetRequest> request) async {
    return updateBudget(call, await request);
  }

  $async.Future<$0.DeleteBudgetResponse> deleteBudget_Pre($grpc.ServiceCall call, $async.Future<$0.DeleteBudgetRequest> request) async {
    return deleteBudget(call, await request);
  }

  $async.Future<$0.GetBudgetExecutionResponse> getBudgetExecution_Pre($grpc.ServiceCall call, $async.Future<$0.GetBudgetExecutionRequest> request) async {
    return getBudgetExecution(call, await request);
  }

  $async.Future<$0.CreateBudgetResponse> createBudget($grpc.ServiceCall call, $0.CreateBudgetRequest request);
  $async.Future<$0.GetBudgetResponse> getBudget($grpc.ServiceCall call, $0.GetBudgetRequest request);
  $async.Future<$0.ListBudgetsResponse> listBudgets($grpc.ServiceCall call, $0.ListBudgetsRequest request);
  $async.Future<$0.UpdateBudgetResponse> updateBudget($grpc.ServiceCall call, $0.UpdateBudgetRequest request);
  $async.Future<$0.DeleteBudgetResponse> deleteBudget($grpc.ServiceCall call, $0.DeleteBudgetRequest request);
  $async.Future<$0.GetBudgetExecutionResponse> getBudgetExecution($grpc.ServiceCall call, $0.GetBudgetExecutionRequest request);
}
