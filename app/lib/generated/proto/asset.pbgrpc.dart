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

import 'asset.pb.dart' as $3;
import 'google/protobuf/empty.pb.dart' as $1;

export 'asset.pb.dart';

@$pb.GrpcServiceName('familyledger.asset.v1.AssetService')
class AssetServiceClient extends $grpc.Client {
  static final _$createAsset = $grpc.ClientMethod<$3.CreateAssetRequest, $3.Asset>(
      '/familyledger.asset.v1.AssetService/CreateAsset',
      ($3.CreateAssetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $3.Asset.fromBuffer(value));
  static final _$getAsset = $grpc.ClientMethod<$3.GetAssetRequest, $3.Asset>(
      '/familyledger.asset.v1.AssetService/GetAsset',
      ($3.GetAssetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $3.Asset.fromBuffer(value));
  static final _$listAssets = $grpc.ClientMethod<$3.ListAssetsRequest, $3.ListAssetsResponse>(
      '/familyledger.asset.v1.AssetService/ListAssets',
      ($3.ListAssetsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $3.ListAssetsResponse.fromBuffer(value));
  static final _$updateAsset = $grpc.ClientMethod<$3.UpdateAssetRequest, $3.Asset>(
      '/familyledger.asset.v1.AssetService/UpdateAsset',
      ($3.UpdateAssetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $3.Asset.fromBuffer(value));
  static final _$deleteAsset = $grpc.ClientMethod<$3.DeleteAssetRequest, $1.Empty>(
      '/familyledger.asset.v1.AssetService/DeleteAsset',
      ($3.DeleteAssetRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.Empty.fromBuffer(value));
  static final _$updateValuation = $grpc.ClientMethod<$3.UpdateValuationRequest, $3.AssetValuation>(
      '/familyledger.asset.v1.AssetService/UpdateValuation',
      ($3.UpdateValuationRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $3.AssetValuation.fromBuffer(value));
  static final _$listValuations = $grpc.ClientMethod<$3.ListValuationsRequest, $3.ListValuationsResponse>(
      '/familyledger.asset.v1.AssetService/ListValuations',
      ($3.ListValuationsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $3.ListValuationsResponse.fromBuffer(value));
  static final _$setDepreciationRule = $grpc.ClientMethod<$3.SetDepreciationRuleRequest, $3.DepreciationRule>(
      '/familyledger.asset.v1.AssetService/SetDepreciationRule',
      ($3.SetDepreciationRuleRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $3.DepreciationRule.fromBuffer(value));
  static final _$runDepreciation = $grpc.ClientMethod<$3.RunDepreciationRequest, $3.Asset>(
      '/familyledger.asset.v1.AssetService/RunDepreciation',
      ($3.RunDepreciationRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $3.Asset.fromBuffer(value));

  AssetServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$3.Asset> createAsset($3.CreateAssetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createAsset, request, options: options);
  }

  $grpc.ResponseFuture<$3.Asset> getAsset($3.GetAssetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getAsset, request, options: options);
  }

  $grpc.ResponseFuture<$3.ListAssetsResponse> listAssets($3.ListAssetsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listAssets, request, options: options);
  }

  $grpc.ResponseFuture<$3.Asset> updateAsset($3.UpdateAssetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateAsset, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteAsset($3.DeleteAssetRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteAsset, request, options: options);
  }

  $grpc.ResponseFuture<$3.AssetValuation> updateValuation($3.UpdateValuationRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateValuation, request, options: options);
  }

  $grpc.ResponseFuture<$3.ListValuationsResponse> listValuations($3.ListValuationsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listValuations, request, options: options);
  }

  $grpc.ResponseFuture<$3.DepreciationRule> setDepreciationRule($3.SetDepreciationRuleRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$setDepreciationRule, request, options: options);
  }

  $grpc.ResponseFuture<$3.Asset> runDepreciation($3.RunDepreciationRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$runDepreciation, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.asset.v1.AssetService')
abstract class AssetServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.asset.v1.AssetService';

  AssetServiceBase() {
    $addMethod($grpc.ServiceMethod<$3.CreateAssetRequest, $3.Asset>(
        'CreateAsset',
        createAsset_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.CreateAssetRequest.fromBuffer(value),
        ($3.Asset value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.GetAssetRequest, $3.Asset>(
        'GetAsset',
        getAsset_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.GetAssetRequest.fromBuffer(value),
        ($3.Asset value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.ListAssetsRequest, $3.ListAssetsResponse>(
        'ListAssets',
        listAssets_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.ListAssetsRequest.fromBuffer(value),
        ($3.ListAssetsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.UpdateAssetRequest, $3.Asset>(
        'UpdateAsset',
        updateAsset_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.UpdateAssetRequest.fromBuffer(value),
        ($3.Asset value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.DeleteAssetRequest, $1.Empty>(
        'DeleteAsset',
        deleteAsset_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.DeleteAssetRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.UpdateValuationRequest, $3.AssetValuation>(
        'UpdateValuation',
        updateValuation_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.UpdateValuationRequest.fromBuffer(value),
        ($3.AssetValuation value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.ListValuationsRequest, $3.ListValuationsResponse>(
        'ListValuations',
        listValuations_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.ListValuationsRequest.fromBuffer(value),
        ($3.ListValuationsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.SetDepreciationRuleRequest, $3.DepreciationRule>(
        'SetDepreciationRule',
        setDepreciationRule_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.SetDepreciationRuleRequest.fromBuffer(value),
        ($3.DepreciationRule value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$3.RunDepreciationRequest, $3.Asset>(
        'RunDepreciation',
        runDepreciation_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $3.RunDepreciationRequest.fromBuffer(value),
        ($3.Asset value) => value.writeToBuffer()));
  }

  $async.Future<$3.Asset> createAsset_Pre($grpc.ServiceCall call, $async.Future<$3.CreateAssetRequest> request) async {
    return createAsset(call, await request);
  }

  $async.Future<$3.Asset> getAsset_Pre($grpc.ServiceCall call, $async.Future<$3.GetAssetRequest> request) async {
    return getAsset(call, await request);
  }

  $async.Future<$3.ListAssetsResponse> listAssets_Pre($grpc.ServiceCall call, $async.Future<$3.ListAssetsRequest> request) async {
    return listAssets(call, await request);
  }

  $async.Future<$3.Asset> updateAsset_Pre($grpc.ServiceCall call, $async.Future<$3.UpdateAssetRequest> request) async {
    return updateAsset(call, await request);
  }

  $async.Future<$1.Empty> deleteAsset_Pre($grpc.ServiceCall call, $async.Future<$3.DeleteAssetRequest> request) async {
    return deleteAsset(call, await request);
  }

  $async.Future<$3.AssetValuation> updateValuation_Pre($grpc.ServiceCall call, $async.Future<$3.UpdateValuationRequest> request) async {
    return updateValuation(call, await request);
  }

  $async.Future<$3.ListValuationsResponse> listValuations_Pre($grpc.ServiceCall call, $async.Future<$3.ListValuationsRequest> request) async {
    return listValuations(call, await request);
  }

  $async.Future<$3.DepreciationRule> setDepreciationRule_Pre($grpc.ServiceCall call, $async.Future<$3.SetDepreciationRuleRequest> request) async {
    return setDepreciationRule(call, await request);
  }

  $async.Future<$3.Asset> runDepreciation_Pre($grpc.ServiceCall call, $async.Future<$3.RunDepreciationRequest> request) async {
    return runDepreciation(call, await request);
  }

  $async.Future<$3.Asset> createAsset($grpc.ServiceCall call, $3.CreateAssetRequest request);
  $async.Future<$3.Asset> getAsset($grpc.ServiceCall call, $3.GetAssetRequest request);
  $async.Future<$3.ListAssetsResponse> listAssets($grpc.ServiceCall call, $3.ListAssetsRequest request);
  $async.Future<$3.Asset> updateAsset($grpc.ServiceCall call, $3.UpdateAssetRequest request);
  $async.Future<$1.Empty> deleteAsset($grpc.ServiceCall call, $3.DeleteAssetRequest request);
  $async.Future<$3.AssetValuation> updateValuation($grpc.ServiceCall call, $3.UpdateValuationRequest request);
  $async.Future<$3.ListValuationsResponse> listValuations($grpc.ServiceCall call, $3.ListValuationsRequest request);
  $async.Future<$3.DepreciationRule> setDepreciationRule($grpc.ServiceCall call, $3.SetDepreciationRuleRequest request);
  $async.Future<$3.Asset> runDepreciation($grpc.ServiceCall call, $3.RunDepreciationRequest request);
}
