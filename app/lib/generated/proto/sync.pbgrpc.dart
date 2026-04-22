//
//  Generated code. Do not modify.
//  source: sync.proto
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

import 'sync.pb.dart' as $2;

export 'sync.pb.dart';

@$pb.GrpcServiceName('familyledger.sync.v1.SyncService')
class SyncServiceClient extends $grpc.Client {
  static final _$pushOperations = $grpc.ClientMethod<$2.PushOperationsRequest, $2.PushOperationsResponse>(
      '/familyledger.sync.v1.SyncService/PushOperations',
      ($2.PushOperationsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.PushOperationsResponse.fromBuffer(value));
  static final _$pullChanges = $grpc.ClientMethod<$2.PullChangesRequest, $2.PullChangesResponse>(
      '/familyledger.sync.v1.SyncService/PullChanges',
      ($2.PullChangesRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.PullChangesResponse.fromBuffer(value));

  SyncServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$2.PushOperationsResponse> pushOperations($2.PushOperationsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$pushOperations, request, options: options);
  }

  $grpc.ResponseFuture<$2.PullChangesResponse> pullChanges($2.PullChangesRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$pullChanges, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.sync.v1.SyncService')
abstract class SyncServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.sync.v1.SyncService';

  SyncServiceBase() {
    $addMethod($grpc.ServiceMethod<$2.PushOperationsRequest, $2.PushOperationsResponse>(
        'PushOperations',
        pushOperations_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.PushOperationsRequest.fromBuffer(value),
        ($2.PushOperationsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.PullChangesRequest, $2.PullChangesResponse>(
        'PullChanges',
        pullChanges_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.PullChangesRequest.fromBuffer(value),
        ($2.PullChangesResponse value) => value.writeToBuffer()));
  }

  $async.Future<$2.PushOperationsResponse> pushOperations_Pre($grpc.ServiceCall call, $async.Future<$2.PushOperationsRequest> request) async {
    return pushOperations(call, await request);
  }

  $async.Future<$2.PullChangesResponse> pullChanges_Pre($grpc.ServiceCall call, $async.Future<$2.PullChangesRequest> request) async {
    return pullChanges(call, await request);
  }

  $async.Future<$2.PushOperationsResponse> pushOperations($grpc.ServiceCall call, $2.PushOperationsRequest request);
  $async.Future<$2.PullChangesResponse> pullChanges($grpc.ServiceCall call, $2.PullChangesRequest request);
}
