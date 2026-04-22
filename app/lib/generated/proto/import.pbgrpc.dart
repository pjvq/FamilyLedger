//
//  Generated code. Do not modify.
//  source: import.proto
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

import 'import.pb.dart' as $2;

export 'import.pb.dart';

@$pb.GrpcServiceName('familyledger.import.v1.ImportService')
class ImportServiceClient extends $grpc.Client {
  static final _$parseCSV = $grpc.ClientMethod<$2.ParseCSVRequest, $2.ParseCSVResponse>(
      '/familyledger.import.v1.ImportService/ParseCSV',
      ($2.ParseCSVRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.ParseCSVResponse.fromBuffer(value));
  static final _$confirmImport = $grpc.ClientMethod<$2.ConfirmImportRequest, $2.ConfirmImportResponse>(
      '/familyledger.import.v1.ImportService/ConfirmImport',
      ($2.ConfirmImportRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $2.ConfirmImportResponse.fromBuffer(value));

  ImportServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$2.ParseCSVResponse> parseCSV($2.ParseCSVRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$parseCSV, request, options: options);
  }

  $grpc.ResponseFuture<$2.ConfirmImportResponse> confirmImport($2.ConfirmImportRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$confirmImport, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.import.v1.ImportService')
abstract class ImportServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.import.v1.ImportService';

  ImportServiceBase() {
    $addMethod($grpc.ServiceMethod<$2.ParseCSVRequest, $2.ParseCSVResponse>(
        'ParseCSV',
        parseCSV_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.ParseCSVRequest.fromBuffer(value),
        ($2.ParseCSVResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$2.ConfirmImportRequest, $2.ConfirmImportResponse>(
        'ConfirmImport',
        confirmImport_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $2.ConfirmImportRequest.fromBuffer(value),
        ($2.ConfirmImportResponse value) => value.writeToBuffer()));
  }

  $async.Future<$2.ParseCSVResponse> parseCSV_Pre($grpc.ServiceCall call, $async.Future<$2.ParseCSVRequest> request) async {
    return parseCSV(call, await request);
  }

  $async.Future<$2.ConfirmImportResponse> confirmImport_Pre($grpc.ServiceCall call, $async.Future<$2.ConfirmImportRequest> request) async {
    return confirmImport(call, await request);
  }

  $async.Future<$2.ParseCSVResponse> parseCSV($grpc.ServiceCall call, $2.ParseCSVRequest request);
  $async.Future<$2.ConfirmImportResponse> confirmImport($grpc.ServiceCall call, $2.ConfirmImportRequest request);
}
