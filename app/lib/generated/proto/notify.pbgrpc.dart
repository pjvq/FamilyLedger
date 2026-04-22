//
//  Generated code. Do not modify.
//  source: notify.proto
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

import 'notify.pb.dart' as $1;

export 'notify.pb.dart';

@$pb.GrpcServiceName('familyledger.notify.v1.NotifyService')
class NotifyServiceClient extends $grpc.Client {
  static final _$registerDevice = $grpc.ClientMethod<$1.RegisterDeviceRequest, $1.RegisterDeviceResponse>(
      '/familyledger.notify.v1.NotifyService/RegisterDevice',
      ($1.RegisterDeviceRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.RegisterDeviceResponse.fromBuffer(value));
  static final _$unregisterDevice = $grpc.ClientMethod<$1.UnregisterDeviceRequest, $1.UnregisterDeviceResponse>(
      '/familyledger.notify.v1.NotifyService/UnregisterDevice',
      ($1.UnregisterDeviceRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.UnregisterDeviceResponse.fromBuffer(value));
  static final _$getNotificationSettings = $grpc.ClientMethod<$1.GetNotificationSettingsRequest, $1.GetNotificationSettingsResponse>(
      '/familyledger.notify.v1.NotifyService/GetNotificationSettings',
      ($1.GetNotificationSettingsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.GetNotificationSettingsResponse.fromBuffer(value));
  static final _$updateNotificationSettings = $grpc.ClientMethod<$1.UpdateNotificationSettingsRequest, $1.UpdateNotificationSettingsResponse>(
      '/familyledger.notify.v1.NotifyService/UpdateNotificationSettings',
      ($1.UpdateNotificationSettingsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.UpdateNotificationSettingsResponse.fromBuffer(value));
  static final _$listNotifications = $grpc.ClientMethod<$1.ListNotificationsRequest, $1.ListNotificationsResponse>(
      '/familyledger.notify.v1.NotifyService/ListNotifications',
      ($1.ListNotificationsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.ListNotificationsResponse.fromBuffer(value));
  static final _$markAsRead = $grpc.ClientMethod<$1.MarkAsReadRequest, $1.MarkAsReadResponse>(
      '/familyledger.notify.v1.NotifyService/MarkAsRead',
      ($1.MarkAsReadRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.MarkAsReadResponse.fromBuffer(value));

  NotifyServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$1.RegisterDeviceResponse> registerDevice($1.RegisterDeviceRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$registerDevice, request, options: options);
  }

  $grpc.ResponseFuture<$1.UnregisterDeviceResponse> unregisterDevice($1.UnregisterDeviceRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$unregisterDevice, request, options: options);
  }

  $grpc.ResponseFuture<$1.GetNotificationSettingsResponse> getNotificationSettings($1.GetNotificationSettingsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getNotificationSettings, request, options: options);
  }

  $grpc.ResponseFuture<$1.UpdateNotificationSettingsResponse> updateNotificationSettings($1.UpdateNotificationSettingsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateNotificationSettings, request, options: options);
  }

  $grpc.ResponseFuture<$1.ListNotificationsResponse> listNotifications($1.ListNotificationsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listNotifications, request, options: options);
  }

  $grpc.ResponseFuture<$1.MarkAsReadResponse> markAsRead($1.MarkAsReadRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$markAsRead, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.notify.v1.NotifyService')
abstract class NotifyServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.notify.v1.NotifyService';

  NotifyServiceBase() {
    $addMethod($grpc.ServiceMethod<$1.RegisterDeviceRequest, $1.RegisterDeviceResponse>(
        'RegisterDevice',
        registerDevice_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.RegisterDeviceRequest.fromBuffer(value),
        ($1.RegisterDeviceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.UnregisterDeviceRequest, $1.UnregisterDeviceResponse>(
        'UnregisterDevice',
        unregisterDevice_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.UnregisterDeviceRequest.fromBuffer(value),
        ($1.UnregisterDeviceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.GetNotificationSettingsRequest, $1.GetNotificationSettingsResponse>(
        'GetNotificationSettings',
        getNotificationSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.GetNotificationSettingsRequest.fromBuffer(value),
        ($1.GetNotificationSettingsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.UpdateNotificationSettingsRequest, $1.UpdateNotificationSettingsResponse>(
        'UpdateNotificationSettings',
        updateNotificationSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.UpdateNotificationSettingsRequest.fromBuffer(value),
        ($1.UpdateNotificationSettingsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.ListNotificationsRequest, $1.ListNotificationsResponse>(
        'ListNotifications',
        listNotifications_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.ListNotificationsRequest.fromBuffer(value),
        ($1.ListNotificationsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.MarkAsReadRequest, $1.MarkAsReadResponse>(
        'MarkAsRead',
        markAsRead_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.MarkAsReadRequest.fromBuffer(value),
        ($1.MarkAsReadResponse value) => value.writeToBuffer()));
  }

  $async.Future<$1.RegisterDeviceResponse> registerDevice_Pre($grpc.ServiceCall call, $async.Future<$1.RegisterDeviceRequest> request) async {
    return registerDevice(call, await request);
  }

  $async.Future<$1.UnregisterDeviceResponse> unregisterDevice_Pre($grpc.ServiceCall call, $async.Future<$1.UnregisterDeviceRequest> request) async {
    return unregisterDevice(call, await request);
  }

  $async.Future<$1.GetNotificationSettingsResponse> getNotificationSettings_Pre($grpc.ServiceCall call, $async.Future<$1.GetNotificationSettingsRequest> request) async {
    return getNotificationSettings(call, await request);
  }

  $async.Future<$1.UpdateNotificationSettingsResponse> updateNotificationSettings_Pre($grpc.ServiceCall call, $async.Future<$1.UpdateNotificationSettingsRequest> request) async {
    return updateNotificationSettings(call, await request);
  }

  $async.Future<$1.ListNotificationsResponse> listNotifications_Pre($grpc.ServiceCall call, $async.Future<$1.ListNotificationsRequest> request) async {
    return listNotifications(call, await request);
  }

  $async.Future<$1.MarkAsReadResponse> markAsRead_Pre($grpc.ServiceCall call, $async.Future<$1.MarkAsReadRequest> request) async {
    return markAsRead(call, await request);
  }

  $async.Future<$1.RegisterDeviceResponse> registerDevice($grpc.ServiceCall call, $1.RegisterDeviceRequest request);
  $async.Future<$1.UnregisterDeviceResponse> unregisterDevice($grpc.ServiceCall call, $1.UnregisterDeviceRequest request);
  $async.Future<$1.GetNotificationSettingsResponse> getNotificationSettings($grpc.ServiceCall call, $1.GetNotificationSettingsRequest request);
  $async.Future<$1.UpdateNotificationSettingsResponse> updateNotificationSettings($grpc.ServiceCall call, $1.UpdateNotificationSettingsRequest request);
  $async.Future<$1.ListNotificationsResponse> listNotifications($grpc.ServiceCall call, $1.ListNotificationsRequest request);
  $async.Future<$1.MarkAsReadResponse> markAsRead($grpc.ServiceCall call, $1.MarkAsReadRequest request);
}
