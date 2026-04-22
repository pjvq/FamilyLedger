//
//  Generated code. Do not modify.
//  source: notify.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'google/protobuf/timestamp.pb.dart' as $2;

class NotificationSettings extends $pb.GeneratedMessage {
  factory NotificationSettings({
    $core.bool? budgetAlert,
    $core.bool? budgetWarning,
    $core.bool? dailySummary,
    $core.bool? loanReminder,
    $core.int? reminderDaysBefore,
  }) {
    final $result = create();
    if (budgetAlert != null) {
      $result.budgetAlert = budgetAlert;
    }
    if (budgetWarning != null) {
      $result.budgetWarning = budgetWarning;
    }
    if (dailySummary != null) {
      $result.dailySummary = dailySummary;
    }
    if (loanReminder != null) {
      $result.loanReminder = loanReminder;
    }
    if (reminderDaysBefore != null) {
      $result.reminderDaysBefore = reminderDaysBefore;
    }
    return $result;
  }
  NotificationSettings._() : super();
  factory NotificationSettings.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory NotificationSettings.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'NotificationSettings', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'budgetAlert')
    ..aOB(2, _omitFieldNames ? '' : 'budgetWarning')
    ..aOB(3, _omitFieldNames ? '' : 'dailySummary')
    ..aOB(4, _omitFieldNames ? '' : 'loanReminder')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'reminderDaysBefore', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  NotificationSettings clone() => NotificationSettings()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  NotificationSettings copyWith(void Function(NotificationSettings) updates) => super.copyWith((message) => updates(message as NotificationSettings)) as NotificationSettings;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NotificationSettings create() => NotificationSettings._();
  NotificationSettings createEmptyInstance() => create();
  static $pb.PbList<NotificationSettings> createRepeated() => $pb.PbList<NotificationSettings>();
  @$core.pragma('dart2js:noInline')
  static NotificationSettings getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<NotificationSettings>(create);
  static NotificationSettings? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get budgetAlert => $_getBF(0);
  @$pb.TagNumber(1)
  set budgetAlert($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBudgetAlert() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudgetAlert() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get budgetWarning => $_getBF(1);
  @$pb.TagNumber(2)
  set budgetWarning($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasBudgetWarning() => $_has(1);
  @$pb.TagNumber(2)
  void clearBudgetWarning() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get dailySummary => $_getBF(2);
  @$pb.TagNumber(3)
  set dailySummary($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDailySummary() => $_has(2);
  @$pb.TagNumber(3)
  void clearDailySummary() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get loanReminder => $_getBF(3);
  @$pb.TagNumber(4)
  set loanReminder($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasLoanReminder() => $_has(3);
  @$pb.TagNumber(4)
  void clearLoanReminder() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get reminderDaysBefore => $_getIZ(4);
  @$pb.TagNumber(5)
  set reminderDaysBefore($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasReminderDaysBefore() => $_has(4);
  @$pb.TagNumber(5)
  void clearReminderDaysBefore() => clearField(5);
}

class Notification extends $pb.GeneratedMessage {
  factory Notification({
    $core.String? id,
    $core.String? userId,
    $core.String? type,
    $core.String? title,
    $core.String? body,
    $core.String? dataJson,
    $core.bool? isRead,
    $2.Timestamp? createdAt,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (type != null) {
      $result.type = type;
    }
    if (title != null) {
      $result.title = title;
    }
    if (body != null) {
      $result.body = body;
    }
    if (dataJson != null) {
      $result.dataJson = dataJson;
    }
    if (isRead != null) {
      $result.isRead = isRead;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    return $result;
  }
  Notification._() : super();
  factory Notification.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Notification.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Notification', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'body')
    ..aOS(6, _omitFieldNames ? '' : 'dataJson')
    ..aOB(7, _omitFieldNames ? '' : 'isRead')
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'createdAt', subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Notification clone() => Notification()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Notification copyWith(void Function(Notification) updates) => super.copyWith((message) => updates(message as Notification)) as Notification;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Notification create() => Notification._();
  Notification createEmptyInstance() => create();
  static $pb.PbList<Notification> createRepeated() => $pb.PbList<Notification>();
  @$core.pragma('dart2js:noInline')
  static Notification getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Notification>(create);
  static Notification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get body => $_getSZ(4);
  @$pb.TagNumber(5)
  set body($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasBody() => $_has(4);
  @$pb.TagNumber(5)
  void clearBody() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get dataJson => $_getSZ(5);
  @$pb.TagNumber(6)
  set dataJson($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasDataJson() => $_has(5);
  @$pb.TagNumber(6)
  void clearDataJson() => clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isRead => $_getBF(6);
  @$pb.TagNumber(7)
  set isRead($core.bool v) { $_setBool(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasIsRead() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsRead() => clearField(7);

  @$pb.TagNumber(8)
  $2.Timestamp get createdAt => $_getN(7);
  @$pb.TagNumber(8)
  set createdAt($2.Timestamp v) { setField(8, v); }
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => clearField(8);
  @$pb.TagNumber(8)
  $2.Timestamp ensureCreatedAt() => $_ensure(7);
}

class RegisterDeviceRequest extends $pb.GeneratedMessage {
  factory RegisterDeviceRequest({
    $core.String? deviceToken,
    $core.String? platform,
    $core.String? deviceName,
  }) {
    final $result = create();
    if (deviceToken != null) {
      $result.deviceToken = deviceToken;
    }
    if (platform != null) {
      $result.platform = platform;
    }
    if (deviceName != null) {
      $result.deviceName = deviceName;
    }
    return $result;
  }
  RegisterDeviceRequest._() : super();
  factory RegisterDeviceRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RegisterDeviceRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RegisterDeviceRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceToken')
    ..aOS(2, _omitFieldNames ? '' : 'platform')
    ..aOS(3, _omitFieldNames ? '' : 'deviceName')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RegisterDeviceRequest clone() => RegisterDeviceRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RegisterDeviceRequest copyWith(void Function(RegisterDeviceRequest) updates) => super.copyWith((message) => updates(message as RegisterDeviceRequest)) as RegisterDeviceRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceRequest create() => RegisterDeviceRequest._();
  RegisterDeviceRequest createEmptyInstance() => create();
  static $pb.PbList<RegisterDeviceRequest> createRepeated() => $pb.PbList<RegisterDeviceRequest>();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RegisterDeviceRequest>(create);
  static RegisterDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceToken($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDeviceToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceToken() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get platform => $_getSZ(1);
  @$pb.TagNumber(2)
  set platform($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPlatform() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlatform() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get deviceName => $_getSZ(2);
  @$pb.TagNumber(3)
  set deviceName($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDeviceName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceName() => clearField(3);
}

class RegisterDeviceResponse extends $pb.GeneratedMessage {
  factory RegisterDeviceResponse({
    $core.String? deviceId,
  }) {
    final $result = create();
    if (deviceId != null) {
      $result.deviceId = deviceId;
    }
    return $result;
  }
  RegisterDeviceResponse._() : super();
  factory RegisterDeviceResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RegisterDeviceResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RegisterDeviceResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RegisterDeviceResponse clone() => RegisterDeviceResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RegisterDeviceResponse copyWith(void Function(RegisterDeviceResponse) updates) => super.copyWith((message) => updates(message as RegisterDeviceResponse)) as RegisterDeviceResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceResponse create() => RegisterDeviceResponse._();
  RegisterDeviceResponse createEmptyInstance() => create();
  static $pb.PbList<RegisterDeviceResponse> createRepeated() => $pb.PbList<RegisterDeviceResponse>();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RegisterDeviceResponse>(create);
  static RegisterDeviceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => clearField(1);
}

class UnregisterDeviceRequest extends $pb.GeneratedMessage {
  factory UnregisterDeviceRequest({
    $core.String? deviceId,
  }) {
    final $result = create();
    if (deviceId != null) {
      $result.deviceId = deviceId;
    }
    return $result;
  }
  UnregisterDeviceRequest._() : super();
  factory UnregisterDeviceRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UnregisterDeviceRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UnregisterDeviceRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UnregisterDeviceRequest clone() => UnregisterDeviceRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UnregisterDeviceRequest copyWith(void Function(UnregisterDeviceRequest) updates) => super.copyWith((message) => updates(message as UnregisterDeviceRequest)) as UnregisterDeviceRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnregisterDeviceRequest create() => UnregisterDeviceRequest._();
  UnregisterDeviceRequest createEmptyInstance() => create();
  static $pb.PbList<UnregisterDeviceRequest> createRepeated() => $pb.PbList<UnregisterDeviceRequest>();
  @$core.pragma('dart2js:noInline')
  static UnregisterDeviceRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnregisterDeviceRequest>(create);
  static UnregisterDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => clearField(1);
}

class UnregisterDeviceResponse extends $pb.GeneratedMessage {
  factory UnregisterDeviceResponse() => create();
  UnregisterDeviceResponse._() : super();
  factory UnregisterDeviceResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UnregisterDeviceResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UnregisterDeviceResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UnregisterDeviceResponse clone() => UnregisterDeviceResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UnregisterDeviceResponse copyWith(void Function(UnregisterDeviceResponse) updates) => super.copyWith((message) => updates(message as UnregisterDeviceResponse)) as UnregisterDeviceResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnregisterDeviceResponse create() => UnregisterDeviceResponse._();
  UnregisterDeviceResponse createEmptyInstance() => create();
  static $pb.PbList<UnregisterDeviceResponse> createRepeated() => $pb.PbList<UnregisterDeviceResponse>();
  @$core.pragma('dart2js:noInline')
  static UnregisterDeviceResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnregisterDeviceResponse>(create);
  static UnregisterDeviceResponse? _defaultInstance;
}

class GetNotificationSettingsRequest extends $pb.GeneratedMessage {
  factory GetNotificationSettingsRequest() => create();
  GetNotificationSettingsRequest._() : super();
  factory GetNotificationSettingsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetNotificationSettingsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetNotificationSettingsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetNotificationSettingsRequest clone() => GetNotificationSettingsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetNotificationSettingsRequest copyWith(void Function(GetNotificationSettingsRequest) updates) => super.copyWith((message) => updates(message as GetNotificationSettingsRequest)) as GetNotificationSettingsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetNotificationSettingsRequest create() => GetNotificationSettingsRequest._();
  GetNotificationSettingsRequest createEmptyInstance() => create();
  static $pb.PbList<GetNotificationSettingsRequest> createRepeated() => $pb.PbList<GetNotificationSettingsRequest>();
  @$core.pragma('dart2js:noInline')
  static GetNotificationSettingsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetNotificationSettingsRequest>(create);
  static GetNotificationSettingsRequest? _defaultInstance;
}

class GetNotificationSettingsResponse extends $pb.GeneratedMessage {
  factory GetNotificationSettingsResponse({
    NotificationSettings? settings,
  }) {
    final $result = create();
    if (settings != null) {
      $result.settings = settings;
    }
    return $result;
  }
  GetNotificationSettingsResponse._() : super();
  factory GetNotificationSettingsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetNotificationSettingsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetNotificationSettingsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..aOM<NotificationSettings>(1, _omitFieldNames ? '' : 'settings', subBuilder: NotificationSettings.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetNotificationSettingsResponse clone() => GetNotificationSettingsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetNotificationSettingsResponse copyWith(void Function(GetNotificationSettingsResponse) updates) => super.copyWith((message) => updates(message as GetNotificationSettingsResponse)) as GetNotificationSettingsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetNotificationSettingsResponse create() => GetNotificationSettingsResponse._();
  GetNotificationSettingsResponse createEmptyInstance() => create();
  static $pb.PbList<GetNotificationSettingsResponse> createRepeated() => $pb.PbList<GetNotificationSettingsResponse>();
  @$core.pragma('dart2js:noInline')
  static GetNotificationSettingsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetNotificationSettingsResponse>(create);
  static GetNotificationSettingsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  NotificationSettings get settings => $_getN(0);
  @$pb.TagNumber(1)
  set settings(NotificationSettings v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasSettings() => $_has(0);
  @$pb.TagNumber(1)
  void clearSettings() => clearField(1);
  @$pb.TagNumber(1)
  NotificationSettings ensureSettings() => $_ensure(0);
}

class UpdateNotificationSettingsRequest extends $pb.GeneratedMessage {
  factory UpdateNotificationSettingsRequest({
    NotificationSettings? settings,
  }) {
    final $result = create();
    if (settings != null) {
      $result.settings = settings;
    }
    return $result;
  }
  UpdateNotificationSettingsRequest._() : super();
  factory UpdateNotificationSettingsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateNotificationSettingsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateNotificationSettingsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..aOM<NotificationSettings>(1, _omitFieldNames ? '' : 'settings', subBuilder: NotificationSettings.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateNotificationSettingsRequest clone() => UpdateNotificationSettingsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateNotificationSettingsRequest copyWith(void Function(UpdateNotificationSettingsRequest) updates) => super.copyWith((message) => updates(message as UpdateNotificationSettingsRequest)) as UpdateNotificationSettingsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateNotificationSettingsRequest create() => UpdateNotificationSettingsRequest._();
  UpdateNotificationSettingsRequest createEmptyInstance() => create();
  static $pb.PbList<UpdateNotificationSettingsRequest> createRepeated() => $pb.PbList<UpdateNotificationSettingsRequest>();
  @$core.pragma('dart2js:noInline')
  static UpdateNotificationSettingsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateNotificationSettingsRequest>(create);
  static UpdateNotificationSettingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  NotificationSettings get settings => $_getN(0);
  @$pb.TagNumber(1)
  set settings(NotificationSettings v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasSettings() => $_has(0);
  @$pb.TagNumber(1)
  void clearSettings() => clearField(1);
  @$pb.TagNumber(1)
  NotificationSettings ensureSettings() => $_ensure(0);
}

class UpdateNotificationSettingsResponse extends $pb.GeneratedMessage {
  factory UpdateNotificationSettingsResponse() => create();
  UpdateNotificationSettingsResponse._() : super();
  factory UpdateNotificationSettingsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UpdateNotificationSettingsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UpdateNotificationSettingsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UpdateNotificationSettingsResponse clone() => UpdateNotificationSettingsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UpdateNotificationSettingsResponse copyWith(void Function(UpdateNotificationSettingsResponse) updates) => super.copyWith((message) => updates(message as UpdateNotificationSettingsResponse)) as UpdateNotificationSettingsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateNotificationSettingsResponse create() => UpdateNotificationSettingsResponse._();
  UpdateNotificationSettingsResponse createEmptyInstance() => create();
  static $pb.PbList<UpdateNotificationSettingsResponse> createRepeated() => $pb.PbList<UpdateNotificationSettingsResponse>();
  @$core.pragma('dart2js:noInline')
  static UpdateNotificationSettingsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UpdateNotificationSettingsResponse>(create);
  static UpdateNotificationSettingsResponse? _defaultInstance;
}

class ListNotificationsRequest extends $pb.GeneratedMessage {
  factory ListNotificationsRequest({
    $core.int? page,
    $core.int? pageSize,
  }) {
    final $result = create();
    if (page != null) {
      $result.page = page;
    }
    if (pageSize != null) {
      $result.pageSize = pageSize;
    }
    return $result;
  }
  ListNotificationsRequest._() : super();
  factory ListNotificationsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListNotificationsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListNotificationsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'page', $pb.PbFieldType.O3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'pageSize', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListNotificationsRequest clone() => ListNotificationsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListNotificationsRequest copyWith(void Function(ListNotificationsRequest) updates) => super.copyWith((message) => updates(message as ListNotificationsRequest)) as ListNotificationsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListNotificationsRequest create() => ListNotificationsRequest._();
  ListNotificationsRequest createEmptyInstance() => create();
  static $pb.PbList<ListNotificationsRequest> createRepeated() => $pb.PbList<ListNotificationsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListNotificationsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListNotificationsRequest>(create);
  static ListNotificationsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get page => $_getIZ(0);
  @$pb.TagNumber(1)
  set page($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get pageSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set pageSize($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPageSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageSize() => clearField(2);
}

class ListNotificationsResponse extends $pb.GeneratedMessage {
  factory ListNotificationsResponse({
    $core.Iterable<Notification>? notifications,
    $core.int? totalCount,
  }) {
    final $result = create();
    if (notifications != null) {
      $result.notifications.addAll(notifications);
    }
    if (totalCount != null) {
      $result.totalCount = totalCount;
    }
    return $result;
  }
  ListNotificationsResponse._() : super();
  factory ListNotificationsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListNotificationsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListNotificationsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..pc<Notification>(1, _omitFieldNames ? '' : 'notifications', $pb.PbFieldType.PM, subBuilder: Notification.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'totalCount', $pb.PbFieldType.O3)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListNotificationsResponse clone() => ListNotificationsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListNotificationsResponse copyWith(void Function(ListNotificationsResponse) updates) => super.copyWith((message) => updates(message as ListNotificationsResponse)) as ListNotificationsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListNotificationsResponse create() => ListNotificationsResponse._();
  ListNotificationsResponse createEmptyInstance() => create();
  static $pb.PbList<ListNotificationsResponse> createRepeated() => $pb.PbList<ListNotificationsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListNotificationsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListNotificationsResponse>(create);
  static ListNotificationsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Notification> get notifications => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get totalCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalCount($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTotalCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalCount() => clearField(2);
}

class MarkAsReadRequest extends $pb.GeneratedMessage {
  factory MarkAsReadRequest({
    $core.Iterable<$core.String>? notificationIds,
  }) {
    final $result = create();
    if (notificationIds != null) {
      $result.notificationIds.addAll(notificationIds);
    }
    return $result;
  }
  MarkAsReadRequest._() : super();
  factory MarkAsReadRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MarkAsReadRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MarkAsReadRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'notificationIds')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MarkAsReadRequest clone() => MarkAsReadRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MarkAsReadRequest copyWith(void Function(MarkAsReadRequest) updates) => super.copyWith((message) => updates(message as MarkAsReadRequest)) as MarkAsReadRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkAsReadRequest create() => MarkAsReadRequest._();
  MarkAsReadRequest createEmptyInstance() => create();
  static $pb.PbList<MarkAsReadRequest> createRepeated() => $pb.PbList<MarkAsReadRequest>();
  @$core.pragma('dart2js:noInline')
  static MarkAsReadRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MarkAsReadRequest>(create);
  static MarkAsReadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.String> get notificationIds => $_getList(0);
}

class MarkAsReadResponse extends $pb.GeneratedMessage {
  factory MarkAsReadResponse() => create();
  MarkAsReadResponse._() : super();
  factory MarkAsReadResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MarkAsReadResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MarkAsReadResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.notify.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MarkAsReadResponse clone() => MarkAsReadResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MarkAsReadResponse copyWith(void Function(MarkAsReadResponse) updates) => super.copyWith((message) => updates(message as MarkAsReadResponse)) as MarkAsReadResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarkAsReadResponse create() => MarkAsReadResponse._();
  MarkAsReadResponse createEmptyInstance() => create();
  static $pb.PbList<MarkAsReadResponse> createRepeated() => $pb.PbList<MarkAsReadResponse>();
  @$core.pragma('dart2js:noInline')
  static MarkAsReadResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MarkAsReadResponse>(create);
  static MarkAsReadResponse? _defaultInstance;
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
