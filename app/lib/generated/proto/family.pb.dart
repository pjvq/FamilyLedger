//
//  Generated code. Do not modify.
//  source: family.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'family.pbenum.dart';
import 'google/protobuf/timestamp.pb.dart' as $1;

export 'family.pbenum.dart';

class MemberPermissions extends $pb.GeneratedMessage {
  factory MemberPermissions({
    $core.bool? canView,
    $core.bool? canCreate,
    $core.bool? canEdit,
    $core.bool? canDelete,
    $core.bool? canManageAccounts,
  }) {
    final $result = create();
    if (canView != null) {
      $result.canView = canView;
    }
    if (canCreate != null) {
      $result.canCreate = canCreate;
    }
    if (canEdit != null) {
      $result.canEdit = canEdit;
    }
    if (canDelete != null) {
      $result.canDelete = canDelete;
    }
    if (canManageAccounts != null) {
      $result.canManageAccounts = canManageAccounts;
    }
    return $result;
  }
  MemberPermissions._() : super();
  factory MemberPermissions.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MemberPermissions.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MemberPermissions', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'canView')
    ..aOB(2, _omitFieldNames ? '' : 'canCreate')
    ..aOB(3, _omitFieldNames ? '' : 'canEdit')
    ..aOB(4, _omitFieldNames ? '' : 'canDelete')
    ..aOB(5, _omitFieldNames ? '' : 'canManageAccounts')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MemberPermissions clone() => MemberPermissions()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MemberPermissions copyWith(void Function(MemberPermissions) updates) => super.copyWith((message) => updates(message as MemberPermissions)) as MemberPermissions;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MemberPermissions create() => MemberPermissions._();
  MemberPermissions createEmptyInstance() => create();
  static $pb.PbList<MemberPermissions> createRepeated() => $pb.PbList<MemberPermissions>();
  @$core.pragma('dart2js:noInline')
  static MemberPermissions getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MemberPermissions>(create);
  static MemberPermissions? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get canView => $_getBF(0);
  @$pb.TagNumber(1)
  set canView($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCanView() => $_has(0);
  @$pb.TagNumber(1)
  void clearCanView() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get canCreate => $_getBF(1);
  @$pb.TagNumber(2)
  set canCreate($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCanCreate() => $_has(1);
  @$pb.TagNumber(2)
  void clearCanCreate() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get canEdit => $_getBF(2);
  @$pb.TagNumber(3)
  set canEdit($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCanEdit() => $_has(2);
  @$pb.TagNumber(3)
  void clearCanEdit() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get canDelete => $_getBF(3);
  @$pb.TagNumber(4)
  set canDelete($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasCanDelete() => $_has(3);
  @$pb.TagNumber(4)
  void clearCanDelete() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get canManageAccounts => $_getBF(4);
  @$pb.TagNumber(5)
  set canManageAccounts($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasCanManageAccounts() => $_has(4);
  @$pb.TagNumber(5)
  void clearCanManageAccounts() => clearField(5);
}

class Family extends $pb.GeneratedMessage {
  factory Family({
    $core.String? id,
    $core.String? name,
    $core.String? ownerId,
    $core.String? inviteCode,
    $1.Timestamp? inviteExpiresAt,
    $1.Timestamp? createdAt,
    $1.Timestamp? updatedAt,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (name != null) {
      $result.name = name;
    }
    if (ownerId != null) {
      $result.ownerId = ownerId;
    }
    if (inviteCode != null) {
      $result.inviteCode = inviteCode;
    }
    if (inviteExpiresAt != null) {
      $result.inviteExpiresAt = inviteExpiresAt;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    if (updatedAt != null) {
      $result.updatedAt = updatedAt;
    }
    return $result;
  }
  Family._() : super();
  factory Family.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Family.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Family', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'ownerId')
    ..aOS(4, _omitFieldNames ? '' : 'inviteCode')
    ..aOM<$1.Timestamp>(5, _omitFieldNames ? '' : 'inviteExpiresAt', subBuilder: $1.Timestamp.create)
    ..aOM<$1.Timestamp>(6, _omitFieldNames ? '' : 'createdAt', subBuilder: $1.Timestamp.create)
    ..aOM<$1.Timestamp>(7, _omitFieldNames ? '' : 'updatedAt', subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Family clone() => Family()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Family copyWith(void Function(Family) updates) => super.copyWith((message) => updates(message as Family)) as Family;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Family create() => Family._();
  Family createEmptyInstance() => create();
  static $pb.PbList<Family> createRepeated() => $pb.PbList<Family>();
  @$core.pragma('dart2js:noInline')
  static Family getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Family>(create);
  static Family? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get ownerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set ownerId($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasOwnerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearOwnerId() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get inviteCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set inviteCode($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasInviteCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearInviteCode() => clearField(4);

  @$pb.TagNumber(5)
  $1.Timestamp get inviteExpiresAt => $_getN(4);
  @$pb.TagNumber(5)
  set inviteExpiresAt($1.Timestamp v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasInviteExpiresAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearInviteExpiresAt() => clearField(5);
  @$pb.TagNumber(5)
  $1.Timestamp ensureInviteExpiresAt() => $_ensure(4);

  @$pb.TagNumber(6)
  $1.Timestamp get createdAt => $_getN(5);
  @$pb.TagNumber(6)
  set createdAt($1.Timestamp v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => clearField(6);
  @$pb.TagNumber(6)
  $1.Timestamp ensureCreatedAt() => $_ensure(5);

  @$pb.TagNumber(7)
  $1.Timestamp get updatedAt => $_getN(6);
  @$pb.TagNumber(7)
  set updatedAt($1.Timestamp v) { setField(7, v); }
  @$pb.TagNumber(7)
  $core.bool hasUpdatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearUpdatedAt() => clearField(7);
  @$pb.TagNumber(7)
  $1.Timestamp ensureUpdatedAt() => $_ensure(6);
}

class FamilyMember extends $pb.GeneratedMessage {
  factory FamilyMember({
    $core.String? id,
    $core.String? userId,
    $core.String? email,
    FamilyRole? role,
    MemberPermissions? permissions,
    $1.Timestamp? joinedAt,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (email != null) {
      $result.email = email;
    }
    if (role != null) {
      $result.role = role;
    }
    if (permissions != null) {
      $result.permissions = permissions;
    }
    if (joinedAt != null) {
      $result.joinedAt = joinedAt;
    }
    return $result;
  }
  FamilyMember._() : super();
  factory FamilyMember.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FamilyMember.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FamilyMember', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'email')
    ..e<FamilyRole>(4, _omitFieldNames ? '' : 'role', $pb.PbFieldType.OE, defaultOrMaker: FamilyRole.FAMILY_ROLE_UNSPECIFIED, valueOf: FamilyRole.valueOf, enumValues: FamilyRole.values)
    ..aOM<MemberPermissions>(5, _omitFieldNames ? '' : 'permissions', subBuilder: MemberPermissions.create)
    ..aOM<$1.Timestamp>(6, _omitFieldNames ? '' : 'joinedAt', subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FamilyMember clone() => FamilyMember()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FamilyMember copyWith(void Function(FamilyMember) updates) => super.copyWith((message) => updates(message as FamilyMember)) as FamilyMember;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FamilyMember create() => FamilyMember._();
  FamilyMember createEmptyInstance() => create();
  static $pb.PbList<FamilyMember> createRepeated() => $pb.PbList<FamilyMember>();
  @$core.pragma('dart2js:noInline')
  static FamilyMember getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FamilyMember>(create);
  static FamilyMember? _defaultInstance;

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
  $core.String get email => $_getSZ(2);
  @$pb.TagNumber(3)
  set email($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasEmail() => $_has(2);
  @$pb.TagNumber(3)
  void clearEmail() => clearField(3);

  @$pb.TagNumber(4)
  FamilyRole get role => $_getN(3);
  @$pb.TagNumber(4)
  set role(FamilyRole v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasRole() => $_has(3);
  @$pb.TagNumber(4)
  void clearRole() => clearField(4);

  @$pb.TagNumber(5)
  MemberPermissions get permissions => $_getN(4);
  @$pb.TagNumber(5)
  set permissions(MemberPermissions v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasPermissions() => $_has(4);
  @$pb.TagNumber(5)
  void clearPermissions() => clearField(5);
  @$pb.TagNumber(5)
  MemberPermissions ensurePermissions() => $_ensure(4);

  @$pb.TagNumber(6)
  $1.Timestamp get joinedAt => $_getN(5);
  @$pb.TagNumber(6)
  set joinedAt($1.Timestamp v) { setField(6, v); }
  @$pb.TagNumber(6)
  $core.bool hasJoinedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearJoinedAt() => clearField(6);
  @$pb.TagNumber(6)
  $1.Timestamp ensureJoinedAt() => $_ensure(5);
}

/// CreateFamily
class CreateFamilyRequest extends $pb.GeneratedMessage {
  factory CreateFamilyRequest({
    $core.String? name,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    return $result;
  }
  CreateFamilyRequest._() : super();
  factory CreateFamilyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateFamilyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateFamilyRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateFamilyRequest clone() => CreateFamilyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateFamilyRequest copyWith(void Function(CreateFamilyRequest) updates) => super.copyWith((message) => updates(message as CreateFamilyRequest)) as CreateFamilyRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateFamilyRequest create() => CreateFamilyRequest._();
  CreateFamilyRequest createEmptyInstance() => create();
  static $pb.PbList<CreateFamilyRequest> createRepeated() => $pb.PbList<CreateFamilyRequest>();
  @$core.pragma('dart2js:noInline')
  static CreateFamilyRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateFamilyRequest>(create);
  static CreateFamilyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);
}

class CreateFamilyResponse extends $pb.GeneratedMessage {
  factory CreateFamilyResponse({
    Family? family,
  }) {
    final $result = create();
    if (family != null) {
      $result.family = family;
    }
    return $result;
  }
  CreateFamilyResponse._() : super();
  factory CreateFamilyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateFamilyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateFamilyResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOM<Family>(1, _omitFieldNames ? '' : 'family', subBuilder: Family.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateFamilyResponse clone() => CreateFamilyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateFamilyResponse copyWith(void Function(CreateFamilyResponse) updates) => super.copyWith((message) => updates(message as CreateFamilyResponse)) as CreateFamilyResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateFamilyResponse create() => CreateFamilyResponse._();
  CreateFamilyResponse createEmptyInstance() => create();
  static $pb.PbList<CreateFamilyResponse> createRepeated() => $pb.PbList<CreateFamilyResponse>();
  @$core.pragma('dart2js:noInline')
  static CreateFamilyResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateFamilyResponse>(create);
  static CreateFamilyResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Family get family => $_getN(0);
  @$pb.TagNumber(1)
  set family(Family v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamily() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamily() => clearField(1);
  @$pb.TagNumber(1)
  Family ensureFamily() => $_ensure(0);
}

/// JoinFamily
class JoinFamilyRequest extends $pb.GeneratedMessage {
  factory JoinFamilyRequest({
    $core.String? inviteCode,
  }) {
    final $result = create();
    if (inviteCode != null) {
      $result.inviteCode = inviteCode;
    }
    return $result;
  }
  JoinFamilyRequest._() : super();
  factory JoinFamilyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory JoinFamilyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'JoinFamilyRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'inviteCode')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  JoinFamilyRequest clone() => JoinFamilyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  JoinFamilyRequest copyWith(void Function(JoinFamilyRequest) updates) => super.copyWith((message) => updates(message as JoinFamilyRequest)) as JoinFamilyRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinFamilyRequest create() => JoinFamilyRequest._();
  JoinFamilyRequest createEmptyInstance() => create();
  static $pb.PbList<JoinFamilyRequest> createRepeated() => $pb.PbList<JoinFamilyRequest>();
  @$core.pragma('dart2js:noInline')
  static JoinFamilyRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JoinFamilyRequest>(create);
  static JoinFamilyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get inviteCode => $_getSZ(0);
  @$pb.TagNumber(1)
  set inviteCode($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInviteCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearInviteCode() => clearField(1);
}

class JoinFamilyResponse extends $pb.GeneratedMessage {
  factory JoinFamilyResponse({
    Family? family,
  }) {
    final $result = create();
    if (family != null) {
      $result.family = family;
    }
    return $result;
  }
  JoinFamilyResponse._() : super();
  factory JoinFamilyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory JoinFamilyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'JoinFamilyResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOM<Family>(1, _omitFieldNames ? '' : 'family', subBuilder: Family.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  JoinFamilyResponse clone() => JoinFamilyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  JoinFamilyResponse copyWith(void Function(JoinFamilyResponse) updates) => super.copyWith((message) => updates(message as JoinFamilyResponse)) as JoinFamilyResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JoinFamilyResponse create() => JoinFamilyResponse._();
  JoinFamilyResponse createEmptyInstance() => create();
  static $pb.PbList<JoinFamilyResponse> createRepeated() => $pb.PbList<JoinFamilyResponse>();
  @$core.pragma('dart2js:noInline')
  static JoinFamilyResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JoinFamilyResponse>(create);
  static JoinFamilyResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Family get family => $_getN(0);
  @$pb.TagNumber(1)
  set family(Family v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamily() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamily() => clearField(1);
  @$pb.TagNumber(1)
  Family ensureFamily() => $_ensure(0);
}

/// GetFamily
class GetFamilyRequest extends $pb.GeneratedMessage {
  factory GetFamilyRequest({
    $core.String? familyId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  GetFamilyRequest._() : super();
  factory GetFamilyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetFamilyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetFamilyRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetFamilyRequest clone() => GetFamilyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetFamilyRequest copyWith(void Function(GetFamilyRequest) updates) => super.copyWith((message) => updates(message as GetFamilyRequest)) as GetFamilyRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetFamilyRequest create() => GetFamilyRequest._();
  GetFamilyRequest createEmptyInstance() => create();
  static $pb.PbList<GetFamilyRequest> createRepeated() => $pb.PbList<GetFamilyRequest>();
  @$core.pragma('dart2js:noInline')
  static GetFamilyRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetFamilyRequest>(create);
  static GetFamilyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);
}

class GetFamilyResponse extends $pb.GeneratedMessage {
  factory GetFamilyResponse({
    Family? family,
    $core.Iterable<FamilyMember>? members,
  }) {
    final $result = create();
    if (family != null) {
      $result.family = family;
    }
    if (members != null) {
      $result.members.addAll(members);
    }
    return $result;
  }
  GetFamilyResponse._() : super();
  factory GetFamilyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetFamilyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetFamilyResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOM<Family>(1, _omitFieldNames ? '' : 'family', subBuilder: Family.create)
    ..pc<FamilyMember>(2, _omitFieldNames ? '' : 'members', $pb.PbFieldType.PM, subBuilder: FamilyMember.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetFamilyResponse clone() => GetFamilyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetFamilyResponse copyWith(void Function(GetFamilyResponse) updates) => super.copyWith((message) => updates(message as GetFamilyResponse)) as GetFamilyResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetFamilyResponse create() => GetFamilyResponse._();
  GetFamilyResponse createEmptyInstance() => create();
  static $pb.PbList<GetFamilyResponse> createRepeated() => $pb.PbList<GetFamilyResponse>();
  @$core.pragma('dart2js:noInline')
  static GetFamilyResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetFamilyResponse>(create);
  static GetFamilyResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Family get family => $_getN(0);
  @$pb.TagNumber(1)
  set family(Family v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamily() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamily() => clearField(1);
  @$pb.TagNumber(1)
  Family ensureFamily() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.List<FamilyMember> get members => $_getList(1);
}

/// GenerateInviteCode
class GenerateInviteCodeRequest extends $pb.GeneratedMessage {
  factory GenerateInviteCodeRequest({
    $core.String? familyId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  GenerateInviteCodeRequest._() : super();
  factory GenerateInviteCodeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GenerateInviteCodeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GenerateInviteCodeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GenerateInviteCodeRequest clone() => GenerateInviteCodeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GenerateInviteCodeRequest copyWith(void Function(GenerateInviteCodeRequest) updates) => super.copyWith((message) => updates(message as GenerateInviteCodeRequest)) as GenerateInviteCodeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateInviteCodeRequest create() => GenerateInviteCodeRequest._();
  GenerateInviteCodeRequest createEmptyInstance() => create();
  static $pb.PbList<GenerateInviteCodeRequest> createRepeated() => $pb.PbList<GenerateInviteCodeRequest>();
  @$core.pragma('dart2js:noInline')
  static GenerateInviteCodeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenerateInviteCodeRequest>(create);
  static GenerateInviteCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);
}

class GenerateInviteCodeResponse extends $pb.GeneratedMessage {
  factory GenerateInviteCodeResponse({
    $core.String? inviteCode,
    $1.Timestamp? expiresAt,
  }) {
    final $result = create();
    if (inviteCode != null) {
      $result.inviteCode = inviteCode;
    }
    if (expiresAt != null) {
      $result.expiresAt = expiresAt;
    }
    return $result;
  }
  GenerateInviteCodeResponse._() : super();
  factory GenerateInviteCodeResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GenerateInviteCodeResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GenerateInviteCodeResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'inviteCode')
    ..aOM<$1.Timestamp>(2, _omitFieldNames ? '' : 'expiresAt', subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GenerateInviteCodeResponse clone() => GenerateInviteCodeResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GenerateInviteCodeResponse copyWith(void Function(GenerateInviteCodeResponse) updates) => super.copyWith((message) => updates(message as GenerateInviteCodeResponse)) as GenerateInviteCodeResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GenerateInviteCodeResponse create() => GenerateInviteCodeResponse._();
  GenerateInviteCodeResponse createEmptyInstance() => create();
  static $pb.PbList<GenerateInviteCodeResponse> createRepeated() => $pb.PbList<GenerateInviteCodeResponse>();
  @$core.pragma('dart2js:noInline')
  static GenerateInviteCodeResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GenerateInviteCodeResponse>(create);
  static GenerateInviteCodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get inviteCode => $_getSZ(0);
  @$pb.TagNumber(1)
  set inviteCode($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasInviteCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearInviteCode() => clearField(1);

  @$pb.TagNumber(2)
  $1.Timestamp get expiresAt => $_getN(1);
  @$pb.TagNumber(2)
  set expiresAt($1.Timestamp v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasExpiresAt() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpiresAt() => clearField(2);
  @$pb.TagNumber(2)
  $1.Timestamp ensureExpiresAt() => $_ensure(1);
}

/// SetMemberRole
class SetMemberRoleRequest extends $pb.GeneratedMessage {
  factory SetMemberRoleRequest({
    $core.String? familyId,
    $core.String? userId,
    FamilyRole? role,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (role != null) {
      $result.role = role;
    }
    return $result;
  }
  SetMemberRoleRequest._() : super();
  factory SetMemberRoleRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetMemberRoleRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetMemberRoleRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..e<FamilyRole>(3, _omitFieldNames ? '' : 'role', $pb.PbFieldType.OE, defaultOrMaker: FamilyRole.FAMILY_ROLE_UNSPECIFIED, valueOf: FamilyRole.valueOf, enumValues: FamilyRole.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetMemberRoleRequest clone() => SetMemberRoleRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetMemberRoleRequest copyWith(void Function(SetMemberRoleRequest) updates) => super.copyWith((message) => updates(message as SetMemberRoleRequest)) as SetMemberRoleRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetMemberRoleRequest create() => SetMemberRoleRequest._();
  SetMemberRoleRequest createEmptyInstance() => create();
  static $pb.PbList<SetMemberRoleRequest> createRepeated() => $pb.PbList<SetMemberRoleRequest>();
  @$core.pragma('dart2js:noInline')
  static SetMemberRoleRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetMemberRoleRequest>(create);
  static SetMemberRoleRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  FamilyRole get role => $_getN(2);
  @$pb.TagNumber(3)
  set role(FamilyRole v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasRole() => $_has(2);
  @$pb.TagNumber(3)
  void clearRole() => clearField(3);
}

class SetMemberRoleResponse extends $pb.GeneratedMessage {
  factory SetMemberRoleResponse() => create();
  SetMemberRoleResponse._() : super();
  factory SetMemberRoleResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetMemberRoleResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetMemberRoleResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetMemberRoleResponse clone() => SetMemberRoleResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetMemberRoleResponse copyWith(void Function(SetMemberRoleResponse) updates) => super.copyWith((message) => updates(message as SetMemberRoleResponse)) as SetMemberRoleResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetMemberRoleResponse create() => SetMemberRoleResponse._();
  SetMemberRoleResponse createEmptyInstance() => create();
  static $pb.PbList<SetMemberRoleResponse> createRepeated() => $pb.PbList<SetMemberRoleResponse>();
  @$core.pragma('dart2js:noInline')
  static SetMemberRoleResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetMemberRoleResponse>(create);
  static SetMemberRoleResponse? _defaultInstance;
}

/// SetMemberPermissions
class SetMemberPermissionsRequest extends $pb.GeneratedMessage {
  factory SetMemberPermissionsRequest({
    $core.String? familyId,
    $core.String? userId,
    MemberPermissions? permissions,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (permissions != null) {
      $result.permissions = permissions;
    }
    return $result;
  }
  SetMemberPermissionsRequest._() : super();
  factory SetMemberPermissionsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetMemberPermissionsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetMemberPermissionsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOM<MemberPermissions>(3, _omitFieldNames ? '' : 'permissions', subBuilder: MemberPermissions.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetMemberPermissionsRequest clone() => SetMemberPermissionsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetMemberPermissionsRequest copyWith(void Function(SetMemberPermissionsRequest) updates) => super.copyWith((message) => updates(message as SetMemberPermissionsRequest)) as SetMemberPermissionsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetMemberPermissionsRequest create() => SetMemberPermissionsRequest._();
  SetMemberPermissionsRequest createEmptyInstance() => create();
  static $pb.PbList<SetMemberPermissionsRequest> createRepeated() => $pb.PbList<SetMemberPermissionsRequest>();
  @$core.pragma('dart2js:noInline')
  static SetMemberPermissionsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetMemberPermissionsRequest>(create);
  static SetMemberPermissionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => clearField(2);

  @$pb.TagNumber(3)
  MemberPermissions get permissions => $_getN(2);
  @$pb.TagNumber(3)
  set permissions(MemberPermissions v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasPermissions() => $_has(2);
  @$pb.TagNumber(3)
  void clearPermissions() => clearField(3);
  @$pb.TagNumber(3)
  MemberPermissions ensurePermissions() => $_ensure(2);
}

class SetMemberPermissionsResponse extends $pb.GeneratedMessage {
  factory SetMemberPermissionsResponse() => create();
  SetMemberPermissionsResponse._() : super();
  factory SetMemberPermissionsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetMemberPermissionsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetMemberPermissionsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetMemberPermissionsResponse clone() => SetMemberPermissionsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetMemberPermissionsResponse copyWith(void Function(SetMemberPermissionsResponse) updates) => super.copyWith((message) => updates(message as SetMemberPermissionsResponse)) as SetMemberPermissionsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetMemberPermissionsResponse create() => SetMemberPermissionsResponse._();
  SetMemberPermissionsResponse createEmptyInstance() => create();
  static $pb.PbList<SetMemberPermissionsResponse> createRepeated() => $pb.PbList<SetMemberPermissionsResponse>();
  @$core.pragma('dart2js:noInline')
  static SetMemberPermissionsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetMemberPermissionsResponse>(create);
  static SetMemberPermissionsResponse? _defaultInstance;
}

/// ListFamilyMembers
class ListFamilyMembersRequest extends $pb.GeneratedMessage {
  factory ListFamilyMembersRequest({
    $core.String? familyId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  ListFamilyMembersRequest._() : super();
  factory ListFamilyMembersRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListFamilyMembersRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListFamilyMembersRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListFamilyMembersRequest clone() => ListFamilyMembersRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListFamilyMembersRequest copyWith(void Function(ListFamilyMembersRequest) updates) => super.copyWith((message) => updates(message as ListFamilyMembersRequest)) as ListFamilyMembersRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListFamilyMembersRequest create() => ListFamilyMembersRequest._();
  ListFamilyMembersRequest createEmptyInstance() => create();
  static $pb.PbList<ListFamilyMembersRequest> createRepeated() => $pb.PbList<ListFamilyMembersRequest>();
  @$core.pragma('dart2js:noInline')
  static ListFamilyMembersRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListFamilyMembersRequest>(create);
  static ListFamilyMembersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);
}

class ListFamilyMembersResponse extends $pb.GeneratedMessage {
  factory ListFamilyMembersResponse({
    $core.Iterable<FamilyMember>? members,
  }) {
    final $result = create();
    if (members != null) {
      $result.members.addAll(members);
    }
    return $result;
  }
  ListFamilyMembersResponse._() : super();
  factory ListFamilyMembersResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListFamilyMembersResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListFamilyMembersResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..pc<FamilyMember>(1, _omitFieldNames ? '' : 'members', $pb.PbFieldType.PM, subBuilder: FamilyMember.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListFamilyMembersResponse clone() => ListFamilyMembersResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListFamilyMembersResponse copyWith(void Function(ListFamilyMembersResponse) updates) => super.copyWith((message) => updates(message as ListFamilyMembersResponse)) as ListFamilyMembersResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListFamilyMembersResponse create() => ListFamilyMembersResponse._();
  ListFamilyMembersResponse createEmptyInstance() => create();
  static $pb.PbList<ListFamilyMembersResponse> createRepeated() => $pb.PbList<ListFamilyMembersResponse>();
  @$core.pragma('dart2js:noInline')
  static ListFamilyMembersResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListFamilyMembersResponse>(create);
  static ListFamilyMembersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<FamilyMember> get members => $_getList(0);
}

/// LeaveFamily
class LeaveFamilyRequest extends $pb.GeneratedMessage {
  factory LeaveFamilyRequest({
    $core.String? familyId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  LeaveFamilyRequest._() : super();
  factory LeaveFamilyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LeaveFamilyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LeaveFamilyRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LeaveFamilyRequest clone() => LeaveFamilyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LeaveFamilyRequest copyWith(void Function(LeaveFamilyRequest) updates) => super.copyWith((message) => updates(message as LeaveFamilyRequest)) as LeaveFamilyRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveFamilyRequest create() => LeaveFamilyRequest._();
  LeaveFamilyRequest createEmptyInstance() => create();
  static $pb.PbList<LeaveFamilyRequest> createRepeated() => $pb.PbList<LeaveFamilyRequest>();
  @$core.pragma('dart2js:noInline')
  static LeaveFamilyRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LeaveFamilyRequest>(create);
  static LeaveFamilyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);
}

class LeaveFamilyResponse extends $pb.GeneratedMessage {
  factory LeaveFamilyResponse() => create();
  LeaveFamilyResponse._() : super();
  factory LeaveFamilyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory LeaveFamilyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'LeaveFamilyResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  LeaveFamilyResponse clone() => LeaveFamilyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  LeaveFamilyResponse copyWith(void Function(LeaveFamilyResponse) updates) => super.copyWith((message) => updates(message as LeaveFamilyResponse)) as LeaveFamilyResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LeaveFamilyResponse create() => LeaveFamilyResponse._();
  LeaveFamilyResponse createEmptyInstance() => create();
  static $pb.PbList<LeaveFamilyResponse> createRepeated() => $pb.PbList<LeaveFamilyResponse>();
  @$core.pragma('dart2js:noInline')
  static LeaveFamilyResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LeaveFamilyResponse>(create);
  static LeaveFamilyResponse? _defaultInstance;
}

/// TransferOwnership
class TransferOwnershipRequest extends $pb.GeneratedMessage {
  factory TransferOwnershipRequest({
    $core.String? familyId,
    $core.String? newOwnerId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    if (newOwnerId != null) {
      $result.newOwnerId = newOwnerId;
    }
    return $result;
  }
  TransferOwnershipRequest._() : super();
  factory TransferOwnershipRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TransferOwnershipRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TransferOwnershipRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..aOS(2, _omitFieldNames ? '' : 'newOwnerId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TransferOwnershipRequest clone() => TransferOwnershipRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TransferOwnershipRequest copyWith(void Function(TransferOwnershipRequest) updates) => super.copyWith((message) => updates(message as TransferOwnershipRequest)) as TransferOwnershipRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransferOwnershipRequest create() => TransferOwnershipRequest._();
  TransferOwnershipRequest createEmptyInstance() => create();
  static $pb.PbList<TransferOwnershipRequest> createRepeated() => $pb.PbList<TransferOwnershipRequest>();
  @$core.pragma('dart2js:noInline')
  static TransferOwnershipRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferOwnershipRequest>(create);
  static TransferOwnershipRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get newOwnerId => $_getSZ(1);
  @$pb.TagNumber(2)
  set newOwnerId($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNewOwnerId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewOwnerId() => clearField(2);
}

class TransferOwnershipResponse extends $pb.GeneratedMessage {
  factory TransferOwnershipResponse() => create();
  TransferOwnershipResponse._() : super();
  factory TransferOwnershipResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory TransferOwnershipResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'TransferOwnershipResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  TransferOwnershipResponse clone() => TransferOwnershipResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  TransferOwnershipResponse copyWith(void Function(TransferOwnershipResponse) updates) => super.copyWith((message) => updates(message as TransferOwnershipResponse)) as TransferOwnershipResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TransferOwnershipResponse create() => TransferOwnershipResponse._();
  TransferOwnershipResponse createEmptyInstance() => create();
  static $pb.PbList<TransferOwnershipResponse> createRepeated() => $pb.PbList<TransferOwnershipResponse>();
  @$core.pragma('dart2js:noInline')
  static TransferOwnershipResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TransferOwnershipResponse>(create);
  static TransferOwnershipResponse? _defaultInstance;
}

/// DeleteFamily
class DeleteFamilyRequest extends $pb.GeneratedMessage {
  factory DeleteFamilyRequest({
    $core.String? familyId,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    return $result;
  }
  DeleteFamilyRequest._() : super();
  factory DeleteFamilyRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteFamilyRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteFamilyRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteFamilyRequest clone() => DeleteFamilyRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteFamilyRequest copyWith(void Function(DeleteFamilyRequest) updates) => super.copyWith((message) => updates(message as DeleteFamilyRequest)) as DeleteFamilyRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteFamilyRequest create() => DeleteFamilyRequest._();
  DeleteFamilyRequest createEmptyInstance() => create();
  static $pb.PbList<DeleteFamilyRequest> createRepeated() => $pb.PbList<DeleteFamilyRequest>();
  @$core.pragma('dart2js:noInline')
  static DeleteFamilyRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteFamilyRequest>(create);
  static DeleteFamilyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);
}

class DeleteFamilyResponse extends $pb.GeneratedMessage {
  factory DeleteFamilyResponse() => create();
  DeleteFamilyResponse._() : super();
  factory DeleteFamilyResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteFamilyResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteFamilyResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteFamilyResponse clone() => DeleteFamilyResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteFamilyResponse copyWith(void Function(DeleteFamilyResponse) updates) => super.copyWith((message) => updates(message as DeleteFamilyResponse)) as DeleteFamilyResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteFamilyResponse create() => DeleteFamilyResponse._();
  DeleteFamilyResponse createEmptyInstance() => create();
  static $pb.PbList<DeleteFamilyResponse> createRepeated() => $pb.PbList<DeleteFamilyResponse>();
  @$core.pragma('dart2js:noInline')
  static DeleteFamilyResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteFamilyResponse>(create);
  static DeleteFamilyResponse? _defaultInstance;
}

/// GetAuditLog
class GetAuditLogRequest extends $pb.GeneratedMessage {
  factory GetAuditLogRequest({
    $core.String? familyId,
    $core.int? pageSize,
    $core.String? pageToken,
    $core.String? entityType,
  }) {
    final $result = create();
    if (familyId != null) {
      $result.familyId = familyId;
    }
    if (pageSize != null) {
      $result.pageSize = pageSize;
    }
    if (pageToken != null) {
      $result.pageToken = pageToken;
    }
    if (entityType != null) {
      $result.entityType = entityType;
    }
    return $result;
  }
  GetAuditLogRequest._() : super();
  factory GetAuditLogRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetAuditLogRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetAuditLogRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'familyId')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'pageSize', $pb.PbFieldType.O3)
    ..aOS(3, _omitFieldNames ? '' : 'pageToken')
    ..aOS(4, _omitFieldNames ? '' : 'entityType')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetAuditLogRequest clone() => GetAuditLogRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetAuditLogRequest copyWith(void Function(GetAuditLogRequest) updates) => super.copyWith((message) => updates(message as GetAuditLogRequest)) as GetAuditLogRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAuditLogRequest create() => GetAuditLogRequest._();
  GetAuditLogRequest createEmptyInstance() => create();
  static $pb.PbList<GetAuditLogRequest> createRepeated() => $pb.PbList<GetAuditLogRequest>();
  @$core.pragma('dart2js:noInline')
  static GetAuditLogRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetAuditLogRequest>(create);
  static GetAuditLogRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get familyId => $_getSZ(0);
  @$pb.TagNumber(1)
  set familyId($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFamilyId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFamilyId() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get pageSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set pageSize($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasPageSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageSize() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get pageToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set pageToken($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPageToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageToken() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get entityType => $_getSZ(3);
  @$pb.TagNumber(4)
  set entityType($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasEntityType() => $_has(3);
  @$pb.TagNumber(4)
  void clearEntityType() => clearField(4);
}

class GetAuditLogResponse extends $pb.GeneratedMessage {
  factory GetAuditLogResponse({
    $core.Iterable<AuditEntry>? entries,
    $core.String? nextPageToken,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    if (nextPageToken != null) {
      $result.nextPageToken = nextPageToken;
    }
    return $result;
  }
  GetAuditLogResponse._() : super();
  factory GetAuditLogResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory GetAuditLogResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'GetAuditLogResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..pc<AuditEntry>(1, _omitFieldNames ? '' : 'entries', $pb.PbFieldType.PM, subBuilder: AuditEntry.create)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  GetAuditLogResponse clone() => GetAuditLogResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  GetAuditLogResponse copyWith(void Function(GetAuditLogResponse) updates) => super.copyWith((message) => updates(message as GetAuditLogResponse)) as GetAuditLogResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAuditLogResponse create() => GetAuditLogResponse._();
  GetAuditLogResponse createEmptyInstance() => create();
  static $pb.PbList<GetAuditLogResponse> createRepeated() => $pb.PbList<GetAuditLogResponse>();
  @$core.pragma('dart2js:noInline')
  static GetAuditLogResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetAuditLogResponse>(create);
  static GetAuditLogResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<AuditEntry> get entries => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => clearField(2);
}

class AuditEntry extends $pb.GeneratedMessage {
  factory AuditEntry({
    $core.String? id,
    $core.String? userId,
    $core.String? userName,
    $core.String? action,
    $core.String? entityType,
    $core.String? entityId,
    $core.String? changesJson,
    $fixnum.Int64? createdAt,
  }) {
    final $result = create();
    if (id != null) {
      $result.id = id;
    }
    if (userId != null) {
      $result.userId = userId;
    }
    if (userName != null) {
      $result.userName = userName;
    }
    if (action != null) {
      $result.action = action;
    }
    if (entityType != null) {
      $result.entityType = entityType;
    }
    if (entityId != null) {
      $result.entityId = entityId;
    }
    if (changesJson != null) {
      $result.changesJson = changesJson;
    }
    if (createdAt != null) {
      $result.createdAt = createdAt;
    }
    return $result;
  }
  AuditEntry._() : super();
  factory AuditEntry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AuditEntry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AuditEntry', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'userName')
    ..aOS(4, _omitFieldNames ? '' : 'action')
    ..aOS(5, _omitFieldNames ? '' : 'entityType')
    ..aOS(6, _omitFieldNames ? '' : 'entityId')
    ..aOS(7, _omitFieldNames ? '' : 'changesJson')
    ..aInt64(8, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AuditEntry clone() => AuditEntry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AuditEntry copyWith(void Function(AuditEntry) updates) => super.copyWith((message) => updates(message as AuditEntry)) as AuditEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AuditEntry create() => AuditEntry._();
  AuditEntry createEmptyInstance() => create();
  static $pb.PbList<AuditEntry> createRepeated() => $pb.PbList<AuditEntry>();
  @$core.pragma('dart2js:noInline')
  static AuditEntry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AuditEntry>(create);
  static AuditEntry? _defaultInstance;

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
  $core.String get userName => $_getSZ(2);
  @$pb.TagNumber(3)
  set userName($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasUserName() => $_has(2);
  @$pb.TagNumber(3)
  void clearUserName() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get action => $_getSZ(3);
  @$pb.TagNumber(4)
  set action($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAction() => $_has(3);
  @$pb.TagNumber(4)
  void clearAction() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get entityType => $_getSZ(4);
  @$pb.TagNumber(5)
  set entityType($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasEntityType() => $_has(4);
  @$pb.TagNumber(5)
  void clearEntityType() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get entityId => $_getSZ(5);
  @$pb.TagNumber(6)
  set entityId($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasEntityId() => $_has(5);
  @$pb.TagNumber(6)
  void clearEntityId() => clearField(6);

  @$pb.TagNumber(7)
  $core.String get changesJson => $_getSZ(6);
  @$pb.TagNumber(7)
  set changesJson($core.String v) { $_setString(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasChangesJson() => $_has(6);
  @$pb.TagNumber(7)
  void clearChangesJson() => clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get createdAt => $_getI64(7);
  @$pb.TagNumber(8)
  set createdAt($fixnum.Int64 v) { $_setInt64(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => clearField(8);
}

/// ListMyFamilies — returns all families the current user belongs to
class ListMyFamiliesRequest extends $pb.GeneratedMessage {
  factory ListMyFamiliesRequest() => create();
  ListMyFamiliesRequest._() : super();
  factory ListMyFamiliesRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListMyFamiliesRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListMyFamiliesRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListMyFamiliesRequest clone() => ListMyFamiliesRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListMyFamiliesRequest copyWith(void Function(ListMyFamiliesRequest) updates) => super.copyWith((message) => updates(message as ListMyFamiliesRequest)) as ListMyFamiliesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListMyFamiliesRequest create() => ListMyFamiliesRequest._();
  ListMyFamiliesRequest createEmptyInstance() => create();
  static $pb.PbList<ListMyFamiliesRequest> createRepeated() => $pb.PbList<ListMyFamiliesRequest>();
  @$core.pragma('dart2js:noInline')
  static ListMyFamiliesRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListMyFamiliesRequest>(create);
  static ListMyFamiliesRequest? _defaultInstance;
}

class ListMyFamiliesResponse extends $pb.GeneratedMessage {
  factory ListMyFamiliesResponse({
    $core.Iterable<Family>? families,
    $core.Iterable<FamilyMember>? memberships,
  }) {
    final $result = create();
    if (families != null) {
      $result.families.addAll(families);
    }
    if (memberships != null) {
      $result.memberships.addAll(memberships);
    }
    return $result;
  }
  ListMyFamiliesResponse._() : super();
  factory ListMyFamiliesResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListMyFamiliesResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListMyFamiliesResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'familyledger.family.v1'), createEmptyInstance: create)
    ..pc<Family>(1, _omitFieldNames ? '' : 'families', $pb.PbFieldType.PM, subBuilder: Family.create)
    ..pc<FamilyMember>(2, _omitFieldNames ? '' : 'memberships', $pb.PbFieldType.PM, subBuilder: FamilyMember.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListMyFamiliesResponse clone() => ListMyFamiliesResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListMyFamiliesResponse copyWith(void Function(ListMyFamiliesResponse) updates) => super.copyWith((message) => updates(message as ListMyFamiliesResponse)) as ListMyFamiliesResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListMyFamiliesResponse create() => ListMyFamiliesResponse._();
  ListMyFamiliesResponse createEmptyInstance() => create();
  static $pb.PbList<ListMyFamiliesResponse> createRepeated() => $pb.PbList<ListMyFamiliesResponse>();
  @$core.pragma('dart2js:noInline')
  static ListMyFamiliesResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListMyFamiliesResponse>(create);
  static ListMyFamiliesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<Family> get families => $_getList(0);

  @$pb.TagNumber(2)
  $core.List<FamilyMember> get memberships => $_getList(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
