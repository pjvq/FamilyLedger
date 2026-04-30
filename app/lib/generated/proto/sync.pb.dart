//
//  Generated code. Do not modify.
//  source: sync.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'google/protobuf/timestamp.pb.dart' as $3;
import 'sync.pbenum.dart';

export 'sync.pbenum.dart';

class SyncOperation extends $pb.GeneratedMessage {
  factory SyncOperation({
    $core.String? id,
    $core.String? entityType,
    $core.String? entityId,
    OperationType? opType,
    $core.String? payload,
    $core.String? clientId,
    $3.Timestamp? timestamp,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (entityType != null) {
      $result.entityType = entityType;
    }
    if (entityId != null) {
      $result.entityId = entityId;
    }
    if (opType != null) {
      $result.opType = opType;
    }
    if (payload != null) {
      $result.payload = payload;
    }
    if (clientId != null) {
      $result.clientId = clientId;
    }
    if (timestamp != null) {
      $result.timestamp = timestamp;
    }
    return $result;
  }
  SyncOperation._() : super();
  factory SyncOperation.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SyncOperation.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SyncOperation', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.sync.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'entityType')
    ..aOS(3, _omitFieldNames ? '' : 'entityId')
    ..e<OperationType>(4, _omitFieldNames ? '' : 'opType', $pb.PbFieldType.OE, defaultOrMaker: OperationType.OPERATION_TYPE_UNSPECIFIED, valueOf: OperationType.valueOf, enumValues: OperationType.values)
    ..aOS(5, _omitFieldNames ? '' : 'payload')
    ..aOS(6, _omitFieldNames ? '' : 'clientId')
    ..aOM<$3.Timestamp>(7, _omitFieldNames ? '' : 'timestamp', subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SyncOperation clone() => SyncOperation()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SyncOperation copyWith(void Function(SyncOperation) updates) => super.copyWith((message) => updates(message as SyncOperation)) as SyncOperation;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncOperation create() => SyncOperation._();
  SyncOperation createEmptyInstance() => create();
  static $pb.PbList<SyncOperation> createRepeated() => $pb.PbList<SyncOperation>();
  @$core.pragma('dart2js:noInline')
  static SyncOperation getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncOperation>(create);
  static SyncOperation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get entityType => $_getSZ(1);
  @$pb.TagNumber(2)
  set entityType($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEntityType() => $_has(1);
  @$pb.TagNumber(2)
  void clearEntityType() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get entityId => $_getSZ(2);
  @$pb.TagNumber(3)
  set entityId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasEntityId() => $_has(2);
  @$pb.TagNumber(3)
  void clearEntityId() => clearField(3);

  @$pb.TagNumber(4)
  OperationType get opType => $_getN(3);
  @$pb.TagNumber(4)
  set opType(OperationType v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasOpType() => $_has(3);
  @$pb.TagNumber(4)
  void clearOpType() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get payload => $_getSZ(4);
  @$pb.TagNumber(5)
  set payload($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasPayload() => $_has(4);
  @$pb.TagNumber(5)
  void clearPayload() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get clientId => $_getSZ(5);
  @$pb.TagNumber(6)
  set clientId($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasClientId() => $_has(5);
  @$pb.TagNumber(6)
  void clearClientId() => clearField(6);

  @$pb.TagNumber(7)
  $3.Timestamp get timestamp => $_getN(6);
  @$pb.TagNumber(7)
  set timestamp($3.Timestamp v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasTimestamp() => $_has(6);
  @$pb.TagNumber(7)
  void clearTimestamp() => clearField(7);
  @$pb.TagNumber(7)
  $3.Timestamp ensureTimestamp() => $_ensure(6);
}

class PushOperationsRequest extends $pb.GeneratedMessage {
  factory PushOperationsRequest({
    $core.Iterable<SyncOperation>? operations,
  }) {
    final $result = create();
    if (operations != null) {
      $result.operations.addAll(operations);
    }
    return $result;
  }
  PushOperationsRequest._() : super();
  factory PushOperationsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PushOperationsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PushOperationsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.sync.v1'), createEmptyInstance: create)
    ..pc<SyncOperation>(1, _omitFieldNames ? '' : 'operations', $pb.PbFieldType.PM, subBuilder: SyncOperation.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PushOperationsRequest clone() => PushOperationsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PushOperationsRequest copyWith(void Function(PushOperationsRequest) updates) => super.copyWith((message) => updates(message as PushOperationsRequest)) as PushOperationsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PushOperationsRequest create() => PushOperationsRequest._();
  PushOperationsRequest createEmptyInstance() => create();
  static $pb.PbList<PushOperationsRequest> createRepeated() => $pb.PbList<PushOperationsRequest>();
  @$core.pragma('dart2js:noInline')
  static PushOperationsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PushOperationsRequest>(create);
  static PushOperationsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<SyncOperation> get operations => $_getList(0);
}

class PushOperationsResponse extends $pb.GeneratedMessage {
  factory PushOperationsResponse({
    $core.int? acceptedCount,
    $core.Iterable<$core.String>? failedIds,
  }) {
    final $result = create();
    if (acceptedCount != null) {
      $result.acceptedCount = acceptedCount;
    }
    if (failedIds != null) {
      $result.failedIds.addAll(failedIds);
    }
    return $result;
  }
  PushOperationsResponse._() : super();
  factory PushOperationsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PushOperationsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PushOperationsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.sync.v1'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'acceptedCount', $pb.PbFieldType.O3)
    ..pPS(2, _omitFieldNames ? '' : 'failedIds')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PushOperationsResponse clone() => PushOperationsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PushOperationsResponse copyWith(void Function(PushOperationsResponse) updates) => super.copyWith((message) => updates(message as PushOperationsResponse)) as PushOperationsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PushOperationsResponse create() => PushOperationsResponse._();
  PushOperationsResponse createEmptyInstance() => create();
  static $pb.PbList<PushOperationsResponse> createRepeated() => $pb.PbList<PushOperationsResponse>();
  @$core.pragma('dart2js:noInline')
  static PushOperationsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PushOperationsResponse>(create);
  static PushOperationsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get acceptedCount => $_getIZ(0);
  @$pb.TagNumber(1)
  set acceptedCount($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAcceptedCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearAcceptedCount() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.String> get failedIds => $_getList(1);
}

class PullChangesRequest extends $pb.GeneratedMessage {
  factory PullChangesRequest({
    $3.Timestamp? since,
    $core.String? clientId,
  }) {
    final $result = create();
    if (since != null) {
      $result.since = since;
    }
    if (clientId != null) {
      $result.clientId = clientId;
    }
    return $result;
  }
  PullChangesRequest._() : super();
  factory PullChangesRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PullChangesRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PullChangesRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.sync.v1'), createEmptyInstance: create)
    ..aOM<$3.Timestamp>(1, _omitFieldNames ? '' : 'since', subBuilder: $3.Timestamp.create)
    ..aOS(2, _omitFieldNames ? '' : 'clientId')
    ..aOS(3, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PullChangesRequest clone() => PullChangesRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PullChangesRequest copyWith(void Function(PullChangesRequest) updates) => super.copyWith((message) => updates(message as PullChangesRequest)) as PullChangesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullChangesRequest create() => PullChangesRequest._();
  PullChangesRequest createEmptyInstance() => create();
  static $pb.PbList<PullChangesRequest> createRepeated() => $pb.PbList<PullChangesRequest>();
  @$core.pragma('dart2js:noInline')
  static PullChangesRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PullChangesRequest>(create);
  static PullChangesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $3.Timestamp get since => $_getN(0);
  @$pb.TagNumber(1)
  set since($3.Timestamp v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasSince() => $_has(0);
  @$pb.TagNumber(1)
  void clearSince() => clearField(1);
  @$pb.TagNumber(1)
  $3.Timestamp ensureSince() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get clientId => $_getSZ(1);
  @$pb.TagNumber(2)
  set clientId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasClientId() => $_has(1);
  @$pb.TagNumber(2)
  void clearClientId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get familyId => $_getSZ(2);
  @$pb.TagNumber(3)
  set familyId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasFamilyId() => $_has(2);
  @$pb.TagNumber(3)
  void clearFamilyId() => clearField(3);
}

class PullChangesResponse extends $pb.GeneratedMessage {
  factory PullChangesResponse({
    $core.Iterable<SyncOperation>? operations,
    $3.Timestamp? serverTime,
  }) {
    final $result = create();
    if (operations != null) {
      $result.operations.addAll(operations);
    }
    if (serverTime != null) {
      $result.serverTime = serverTime;
    }
    return $result;
  }
  PullChangesResponse._() : super();
  factory PullChangesResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PullChangesResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PullChangesResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.sync.v1'), createEmptyInstance: create)
    ..pc<SyncOperation>(1, _omitFieldNames ? '' : 'operations', $pb.PbFieldType.PM, subBuilder: SyncOperation.create)
    ..aOM<$3.Timestamp>(2, _omitFieldNames ? '' : 'serverTime', subBuilder: $3.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PullChangesResponse clone() => PullChangesResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PullChangesResponse copyWith(void Function(PullChangesResponse) updates) => super.copyWith((message) => updates(message as PullChangesResponse)) as PullChangesResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullChangesResponse create() => PullChangesResponse._();
  PullChangesResponse createEmptyInstance() => create();
  static $pb.PbList<PullChangesResponse> createRepeated() => $pb.PbList<PullChangesResponse>();
  @$core.pragma('dart2js:noInline')
  static PullChangesResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PullChangesResponse>(create);
  static PullChangesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<SyncOperation> get operations => $_getList(0);

  @$pb.TagNumber(2)
  $3.Timestamp get serverTime => $_getN(1);
  @$pb.TagNumber(2)
  set serverTime($3.Timestamp v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasServerTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearServerTime() => clearField(2);
  @$pb.TagNumber(2)
  $3.Timestamp ensureServerTime() => $_ensure(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
