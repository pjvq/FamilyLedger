//
//  Generated code. Do not modify.
//  source: export.proto
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

import 'export.pb.dart' as $1;

export 'export.pb.dart';

@$pb.GrpcServiceName('familyledger.export.v1.ExportService')
class ExportServiceClient extends $grpc.Client {
  static final _$exportTransactions = $grpc.ClientMethod<$1.ExportRequest, $1.ExportResponse>(
      '/familyledger.export.v1.ExportService/ExportTransactions',
      ($1.ExportRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.ExportResponse.fromBuffer(value));

  ExportServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$1.ExportResponse> exportTransactions($1.ExportRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$exportTransactions, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.export.v1.ExportService')
abstract class ExportServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.export.v1.ExportService';

  ExportServiceBase() {
    $addMethod($grpc.ServiceMethod<$1.ExportRequest, $1.ExportResponse>(
        'ExportTransactions',
        exportTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.ExportRequest.fromBuffer(value),
        ($1.ExportResponse value) => value.writeToBuffer()));
  }

  $async.Future<$1.ExportResponse> exportTransactions_Pre($grpc.ServiceCall call, $async.Future<$1.ExportRequest> request) async {
    return exportTransactions(call, await request);
  }

  $async.Future<$1.ExportResponse> exportTransactions($grpc.ServiceCall call, $1.ExportRequest request);
}
