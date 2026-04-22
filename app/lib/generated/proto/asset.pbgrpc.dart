//
//  Generated code. Do not modify.
//  source: asset.proto
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

import 'asset.pb.dart' as $0;
import 'google/protobuf/empty.pb.dart' as $1;

export 'asset.pb.dart';

@$pb.GrpcServiceName('familyledger.asset.v1.AssetService')
class AssetServiceClient extends $grpc.Client {
  static final _$createAsset = $grpc.ClientMethod<$0.CreateAssetRequest, $0.Asset>(
      '/familyledger.asset.v1.AssetService/CreateAsset',
      ($0.CreateAssetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Asset.fromBuffer(value));
  static final _$getAsset = $grpc.ClientMethod<$0.GetAssetRequest, $0.Asset>(
      '/familyledger.asset.v1.AssetService/GetAsset',
      ($0.GetAssetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Asset.fromBuffer(value));
  static final _$listAssets = $grpc.ClientMethod<$0.ListAssetsRequest, $0.ListAssetsResponse>(
      '/familyledger.asset.v1.AssetService/ListAssets',
      ($0.ListAssetsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListAssetsResponse.fromBuffer(value));
  static final _$updateAsset = $grpc.ClientMethod<$0.UpdateAssetRequest, $0.Asset>(
      '/familyledger.asset.v1.AssetService/UpdateAsset',
      ($0.UpdateAssetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Asset.fromBuffer(value));
  static final _$deleteAsset = $grpc.ClientMethod<$0.DeleteAssetRequest, $1.Empty>(
      '/familyledger.asset.v1.AssetService/DeleteAsset',
      ($0.DeleteAssetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.Empty.fromBuffer(value));
  static final _$updateValuation = $grpc.ClientMethod<$0.UpdateValuationRequest, $0.AssetValuation>(
      '/familyledger.asset.v1.AssetService/UpdateValuation',
      ($0.UpdateValuationRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.AssetValuation.fromBuffer(value));
  static final _$listValuations = $grpc.ClientMethod<$0.ListValuationsRequest, $0.ListValuationsResponse>(
      '/familyledger.asset.v1.AssetService/ListValuations',
      ($0.ListValuationsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListValuationsResponse.fromBuffer(value));
  static final _$setDepreciationRule = $grpc.ClientMethod<$0.SetDepreciationRuleRequest, $0.DepreciationRule>(
      '/familyledger.asset.v1.AssetService/SetDepreciationRule',
      ($0.SetDepreciationRuleRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.DepreciationRule.fromBuffer(value));
  static final _$runDepreciation = $grpc.ClientMethod<$0.RunDepreciationRequest, $0.Asset>(
      '/familyledger.asset.v1.AssetService/RunDepreciation',
      ($0.RunDepreciationRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Asset.fromBuffer(value));

  AssetServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.Asset> createAsset($0.CreateAssetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createAsset, request, options: options);
  }

  $grpc.ResponseFuture<$0.Asset> getAsset($0.GetAssetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getAsset, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListAssetsResponse> listAssets($0.ListAssetsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listAssets, request, options: options);
  }

  $grpc.ResponseFuture<$0.Asset> updateAsset($0.UpdateAssetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateAsset, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteAsset($0.DeleteAssetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteAsset, request, options: options);
  }

  $grpc.ResponseFuture<$0.AssetValuation> updateValuation($0.UpdateValuationRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateValuation, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListValuationsResponse> listValuations($0.ListValuationsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listValuations, request, options: options);
  }

  $grpc.ResponseFuture<$0.DepreciationRule> setDepreciationRule($0.SetDepreciationRuleRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$setDepreciationRule, request, options: options);
  }

  $grpc.ResponseFuture<$0.Asset> runDepreciation($0.RunDepreciationRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$runDepreciation, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.asset.v1.AssetService')
abstract class AssetServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.asset.v1.AssetService';

  AssetServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateAssetRequest, $0.Asset>(
        'CreateAsset',
        createAsset_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateAssetRequest.fromBuffer(value),
        ($0.Asset value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetAssetRequest, $0.Asset>(
        'GetAsset',
        getAsset_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetAssetRequest.fromBuffer(value),
        ($0.Asset value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListAssetsRequest, $0.ListAssetsResponse>(
        'ListAssets',
        listAssets_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListAssetsRequest.fromBuffer(value),
        ($0.ListAssetsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateAssetRequest, $0.Asset>(
        'UpdateAsset',
        updateAsset_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateAssetRequest.fromBuffer(value),
        ($0.Asset value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteAssetRequest, $1.Empty>(
        'DeleteAsset',
        deleteAsset_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteAssetRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateValuationRequest, $0.AssetValuation>(
        'UpdateValuation',
        updateValuation_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateValuationRequest.fromBuffer(value),
        ($0.AssetValuation value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListValuationsRequest, $0.ListValuationsResponse>(
        'ListValuations',
        listValuations_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListValuationsRequest.fromBuffer(value),
        ($0.ListValuationsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetDepreciationRuleRequest, $0.DepreciationRule>(
        'SetDepreciationRule',
        setDepreciationRule_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SetDepreciationRuleRequest.fromBuffer(value),
        ($0.DepreciationRule value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RunDepreciationRequest, $0.Asset>(
        'RunDepreciation',
        runDepreciation_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RunDepreciationRequest.fromBuffer(value),
        ($0.Asset value) => value.writeToBuffer()));
  }

  $async.Future<$0.Asset> createAsset_Pre($grpc.ServiceCall call, $async.Future<$0.CreateAssetRequest> request) async {
    return createAsset(call, await request);
  }

  $async.Future<$0.Asset> getAsset_Pre($grpc.ServiceCall call, $async.Future<$0.GetAssetRequest> request) async {
    return getAsset(call, await request);
  }

  $async.Future<$0.ListAssetsResponse> listAssets_Pre($grpc.ServiceCall call, $async.Future<$0.ListAssetsRequest> request) async {
    return listAssets(call, await request);
  }

  $async.Future<$0.Asset> updateAsset_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateAssetRequest> request) async {
    return updateAsset(call, await request);
  }

  $async.Future<$1.Empty> deleteAsset_Pre($grpc.ServiceCall call, $async.Future<$0.DeleteAssetRequest> request) async {
    return deleteAsset(call, await request);
  }

  $async.Future<$0.AssetValuation> updateValuation_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateValuationRequest> request) async {
    return updateValuation(call, await request);
  }

  $async.Future<$0.ListValuationsResponse> listValuations_Pre($grpc.ServiceCall call, $async.Future<$0.ListValuationsRequest> request) async {
    return listValuations(call, await request);
  }

  $async.Future<$0.DepreciationRule> setDepreciationRule_Pre($grpc.ServiceCall call, $async.Future<$0.SetDepreciationRuleRequest> request) async {
    return setDepreciationRule(call, await request);
  }

  $async.Future<$0.Asset> runDepreciation_Pre($grpc.ServiceCall call, $async.Future<$0.RunDepreciationRequest> request) async {
    return runDepreciation(call, await request);
  }

  $async.Future<$0.Asset> createAsset($grpc.ServiceCall call, $0.CreateAssetRequest request);
  $async.Future<$0.Asset> getAsset($grpc.ServiceCall call, $0.GetAssetRequest request);
  $async.Future<$0.ListAssetsResponse> listAssets($grpc.ServiceCall call, $0.ListAssetsRequest request);
  $async.Future<$0.Asset> updateAsset($grpc.ServiceCall call, $0.UpdateAssetRequest request);
  $async.Future<$1.Empty> deleteAsset($grpc.ServiceCall call, $0.DeleteAssetRequest request);
  $async.Future<$0.AssetValuation> updateValuation($grpc.ServiceCall call, $0.UpdateValuationRequest request);
  $async.Future<$0.ListValuationsResponse> listValuations($grpc.ServiceCall call, $0.ListValuationsRequest request);
  $async.Future<$0.DepreciationRule> setDepreciationRule($grpc.ServiceCall call, $0.SetDepreciationRuleRequest request);
  $async.Future<$0.Asset> runDepreciation($grpc.ServiceCall call, $0.RunDepreciationRequest request);
}
