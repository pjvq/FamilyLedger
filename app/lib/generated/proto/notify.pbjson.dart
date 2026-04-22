//
//  Generated code. Do not modify.
//  source: notify.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use notificationSettingsDescriptor instead')
const NotificationSettings$json = {
  '1': 'NotificationSettings',
  '2': [
    {'1': 'budget_alert', '3': 1, '4': 1, '5': 8, '10': 'budgetAlert'},
    {'1': 'budget_warning', '3': 2, '4': 1, '5': 8, '10': 'budgetWarning'},
    {'1': 'daily_summary', '3': 3, '4': 1, '5': 8, '10': 'dailySummary'},
    {'1': 'loan_reminder', '3': 4, '4': 1, '5': 8, '10': 'loanReminder'},
    {'1': 'reminder_days_before', '3': 5, '4': 1, '5': 5, '10': 'reminderDaysBefore'},
  ],
};

/// Descriptor for `NotificationSettings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List notificationSettingsDescriptor = $convert.base64Decode(
    'ChROb3RpZmljYXRpb25TZXR0aW5ncxIhCgxidWRnZXRfYWxlcnQYASABKAhSC2J1ZGdldEFsZX'
    'J0EiUKDmJ1ZGdldF93YXJuaW5nGAIgASgIUg1idWRnZXRXYXJuaW5nEiMKDWRhaWx5X3N1bW1h'
    'cnkYAyABKAhSDGRhaWx5U3VtbWFyeRIjCg1sb2FuX3JlbWluZGVyGAQgASgIUgxsb2FuUmVtaW'
    '5kZXISMAoUcmVtaW5kZXJfZGF5c19iZWZvcmUYBSABKAVSEnJlbWluZGVyRGF5c0JlZm9yZQ==');

@$core.Deprecated('Use notificationDescriptor instead')
const Notification$json = {
  '1': 'Notification',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'type', '3': 3, '4': 1, '5': 9, '10': 'type'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'body', '3': 5, '4': 1, '5': 9, '10': 'body'},
    {'1': 'data_json', '3': 6, '4': 1, '5': 9, '10': 'dataJson'},
    {'1': 'is_read', '3': 7, '4': 1, '5': 8, '10': 'isRead'},
    {'1': 'created_at', '3': 8, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
  ],
};

/// Descriptor for `Notification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List notificationDescriptor = $convert.base64Decode(
    'CgxOb3RpZmljYXRpb24SDgoCaWQYASABKAlSAmlkEhcKB3VzZXJfaWQYAiABKAlSBnVzZXJJZB'
    'ISCgR0eXBlGAMgASgJUgR0eXBlEhQKBXRpdGxlGAQgASgJUgV0aXRsZRISCgRib2R5GAUgASgJ'
    'UgRib2R5EhsKCWRhdGFfanNvbhgGIAEoCVIIZGF0YUpzb24SFwoHaXNfcmVhZBgHIAEoCFIGaX'
    'NSZWFkEjkKCmNyZWF0ZWRfYXQYCCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUglj'
    'cmVhdGVkQXQ=');

@$core.Deprecated('Use registerDeviceRequestDescriptor instead')
const RegisterDeviceRequest$json = {
  '1': 'RegisterDeviceRequest',
  '2': [
    {'1': 'device_token', '3': 1, '4': 1, '5': 9, '10': 'deviceToken'},
    {'1': 'platform', '3': 2, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'device_name', '3': 3, '4': 1, '5': 9, '10': 'deviceName'},
  ],
};

/// Descriptor for `RegisterDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceRequestDescriptor = $convert.base64Decode(
    'ChVSZWdpc3RlckRldmljZVJlcXVlc3QSIQoMZGV2aWNlX3Rva2VuGAEgASgJUgtkZXZpY2VUb2'
    'tlbhIaCghwbGF0Zm9ybRgCIAEoCVIIcGxhdGZvcm0SHwoLZGV2aWNlX25hbWUYAyABKAlSCmRl'
    'dmljZU5hbWU=');

@$core.Deprecated('Use registerDeviceResponseDescriptor instead')
const RegisterDeviceResponse$json = {
  '1': 'RegisterDeviceResponse',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
  ],
};

/// Descriptor for `RegisterDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceResponseDescriptor = $convert.base64Decode(
    'ChZSZWdpc3RlckRldmljZVJlc3BvbnNlEhsKCWRldmljZV9pZBgBIAEoCVIIZGV2aWNlSWQ=');

@$core.Deprecated('Use unregisterDeviceRequestDescriptor instead')
const UnregisterDeviceRequest$json = {
  '1': 'UnregisterDeviceRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
  ],
};

/// Descriptor for `UnregisterDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unregisterDeviceRequestDescriptor = $convert.base64Decode(
    'ChdVbnJlZ2lzdGVyRGV2aWNlUmVxdWVzdBIbCglkZXZpY2VfaWQYASABKAlSCGRldmljZUlk');

@$core.Deprecated('Use unregisterDeviceResponseDescriptor instead')
const UnregisterDeviceResponse$json = {
  '1': 'UnregisterDeviceResponse',
};

/// Descriptor for `UnregisterDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unregisterDeviceResponseDescriptor = $convert.base64Decode(
    'ChhVbnJlZ2lzdGVyRGV2aWNlUmVzcG9uc2U=');

@$core.Deprecated('Use getNotificationSettingsRequestDescriptor instead')
const GetNotificationSettingsRequest$json = {
  '1': 'GetNotificationSettingsRequest',
};

/// Descriptor for `GetNotificationSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNotificationSettingsRequestDescriptor = $convert.base64Decode(
    'Ch5HZXROb3RpZmljYXRpb25TZXR0aW5nc1JlcXVlc3Q=');

@$core.Deprecated('Use getNotificationSettingsResponseDescriptor instead')
const GetNotificationSettingsResponse$json = {
  '1': 'GetNotificationSettingsResponse',
  '2': [
    {'1': 'settings', '3': 1, '4': 1, '5': 11, '6': '.familyledger.notify.v1.NotificationSettings', '10': 'settings'},
  ],
};

/// Descriptor for `GetNotificationSettingsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNotificationSettingsResponseDescriptor = $convert.base64Decode(
    'Ch9HZXROb3RpZmljYXRpb25TZXR0aW5nc1Jlc3BvbnNlEkgKCHNldHRpbmdzGAEgASgLMiwuZm'
    'FtaWx5bGVkZ2VyLm5vdGlmeS52MS5Ob3RpZmljYXRpb25TZXR0aW5nc1IIc2V0dGluZ3M=');

@$core.Deprecated('Use updateNotificationSettingsRequestDescriptor instead')
const UpdateNotificationSettingsRequest$json = {
  '1': 'UpdateNotificationSettingsRequest',
  '2': [
    {'1': 'settings', '3': 1, '4': 1, '5': 11, '6': '.familyledger.notify.v1.NotificationSettings', '10': 'settings'},
  ],
};

/// Descriptor for `UpdateNotificationSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateNotificationSettingsRequestDescriptor = $convert.base64Decode(
    'CiFVcGRhdGVOb3RpZmljYXRpb25TZXR0aW5nc1JlcXVlc3QSSAoIc2V0dGluZ3MYASABKAsyLC'
    '5mYW1pbHlsZWRnZXIubm90aWZ5LnYxLk5vdGlmaWNhdGlvblNldHRpbmdzUghzZXR0aW5ncw==');

@$core.Deprecated('Use updateNotificationSettingsResponseDescriptor instead')
const UpdateNotificationSettingsResponse$json = {
  '1': 'UpdateNotificationSettingsResponse',
};

/// Descriptor for `UpdateNotificationSettingsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateNotificationSettingsResponseDescriptor = $convert.base64Decode(
    'CiJVcGRhdGVOb3RpZmljYXRpb25TZXR0aW5nc1Jlc3BvbnNl');

@$core.Deprecated('Use listNotificationsRequestDescriptor instead')
const ListNotificationsRequest$json = {
  '1': 'ListNotificationsRequest',
  '2': [
    {'1': 'page', '3': 1, '4': 1, '5': 5, '10': 'page'},
    {'1': 'page_size', '3': 2, '4': 1, '5': 5, '10': 'pageSize'},
  ],
};

/// Descriptor for `ListNotificationsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listNotificationsRequestDescriptor = $convert.base64Decode(
    'ChhMaXN0Tm90aWZpY2F0aW9uc1JlcXVlc3QSEgoEcGFnZRgBIAEoBVIEcGFnZRIbCglwYWdlX3'
    'NpemUYAiABKAVSCHBhZ2VTaXpl');

@$core.Deprecated('Use listNotificationsResponseDescriptor instead')
const ListNotificationsResponse$json = {
  '1': 'ListNotificationsResponse',
  '2': [
    {'1': 'notifications', '3': 1, '4': 3, '5': 11, '6': '.familyledger.notify.v1.Notification', '10': 'notifications'},
    {'1': 'total_count', '3': 2, '4': 1, '5': 5, '10': 'totalCount'},
  ],
};

/// Descriptor for `ListNotificationsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listNotificationsResponseDescriptor = $convert.base64Decode(
    'ChlMaXN0Tm90aWZpY2F0aW9uc1Jlc3BvbnNlEkoKDW5vdGlmaWNhdGlvbnMYASADKAsyJC5mYW'
    '1pbHlsZWRnZXIubm90aWZ5LnYxLk5vdGlmaWNhdGlvblINbm90aWZpY2F0aW9ucxIfCgt0b3Rh'
    'bF9jb3VudBgCIAEoBVIKdG90YWxDb3VudA==');

@$core.Deprecated('Use markAsReadRequestDescriptor instead')
const MarkAsReadRequest$json = {
  '1': 'MarkAsReadRequest',
  '2': [
    {'1': 'notification_ids', '3': 1, '4': 3, '5': 9, '10': 'notificationIds'},
  ],
};

/// Descriptor for `MarkAsReadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markAsReadRequestDescriptor = $convert.base64Decode(
    'ChFNYXJrQXNSZWFkUmVxdWVzdBIpChBub3RpZmljYXRpb25faWRzGAEgAygJUg9ub3RpZmljYX'
    'Rpb25JZHM=');

@$core.Deprecated('Use markAsReadResponseDescriptor instead')
const MarkAsReadResponse$json = {
  '1': 'MarkAsReadResponse',
};

/// Descriptor for `MarkAsReadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markAsReadResponseDescriptor = $convert.base64Decode(
    'ChJNYXJrQXNSZWFkUmVzcG9uc2U=');

