//
//  Generated code. Do not modify.
//  source: family.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use familyRoleDescriptor instead')
const FamilyRole$json = {
  '1': 'FamilyRole',
  '2': [
    {'1': 'FAMILY_ROLE_UNSPECIFIED', '2': 0},
    {'1': 'FAMILY_ROLE_OWNER', '2': 1},
    {'1': 'FAMILY_ROLE_ADMIN', '2': 2},
    {'1': 'FAMILY_ROLE_MEMBER', '2': 3},
  ],
};

/// Descriptor for `FamilyRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List familyRoleDescriptor = $convert.base64Decode(
    'CgpGYW1pbHlSb2xlEhsKF0ZBTUlMWV9ST0xFX1VOU1BFQ0lGSUVEEAASFQoRRkFNSUxZX1JPTE'
    'VfT1dORVIQARIVChFGQU1JTFlfUk9MRV9BRE1JThACEhYKEkZBTUlMWV9ST0xFX01FTUJFUhAD');

@$core.Deprecated('Use memberPermissionsDescriptor instead')
const MemberPermissions$json = {
  '1': 'MemberPermissions',
  '2': [
    {'1': 'can_view', '3': 1, '4': 1, '5': 8, '10': 'canView'},
    {'1': 'can_create', '3': 2, '4': 1, '5': 8, '10': 'canCreate'},
    {'1': 'can_edit', '3': 3, '4': 1, '5': 8, '10': 'canEdit'},
    {'1': 'can_delete', '3': 4, '4': 1, '5': 8, '10': 'canDelete'},
    {'1': 'can_manage_accounts', '3': 5, '4': 1, '5': 8, '10': 'canManageAccounts'},
  ],
};

/// Descriptor for `MemberPermissions`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memberPermissionsDescriptor = $convert.base64Decode(
    'ChFNZW1iZXJQZXJtaXNzaW9ucxIZCghjYW5fdmlldxgBIAEoCFIHY2FuVmlldxIdCgpjYW5fY3'
    'JlYXRlGAIgASgIUgljYW5DcmVhdGUSGQoIY2FuX2VkaXQYAyABKAhSB2NhbkVkaXQSHQoKY2Fu'
    'X2RlbGV0ZRgEIAEoCFIJY2FuRGVsZXRlEi4KE2Nhbl9tYW5hZ2VfYWNjb3VudHMYBSABKAhSEW'
    'Nhbk1hbmFnZUFjY291bnRz');

@$core.Deprecated('Use familyDescriptor instead')
const Family$json = {
  '1': 'Family',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'owner_id', '3': 3, '4': 1, '5': 9, '10': 'ownerId'},
    {'1': 'invite_code', '3': 4, '4': 1, '5': 9, '10': 'inviteCode'},
    {'1': 'invite_expires_at', '3': 5, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'inviteExpiresAt'},
    {'1': 'created_at', '3': 6, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
    {'1': 'updated_at', '3': 7, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedAt'},
  ],
};

/// Descriptor for `Family`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List familyDescriptor = $convert.base64Decode(
    'CgZGYW1pbHkSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSGQoIb3duZXJfaW'
    'QYAyABKAlSB293bmVySWQSHwoLaW52aXRlX2NvZGUYBCABKAlSCmludml0ZUNvZGUSRgoRaW52'
    'aXRlX2V4cGlyZXNfYXQYBSABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUg9pbnZpdG'
    'VFeHBpcmVzQXQSOQoKY3JlYXRlZF9hdBgGIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3Rh'
    'bXBSCWNyZWF0ZWRBdBI5Cgp1cGRhdGVkX2F0GAcgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbW'
    'VzdGFtcFIJdXBkYXRlZEF0');

@$core.Deprecated('Use familyMemberDescriptor instead')
const FamilyMember$json = {
  '1': 'FamilyMember',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'email', '3': 3, '4': 1, '5': 9, '10': 'email'},
    {'1': 'role', '3': 4, '4': 1, '5': 14, '6': '.familyledger.family.v1.FamilyRole', '10': 'role'},
    {'1': 'permissions', '3': 5, '4': 1, '5': 11, '6': '.familyledger.family.v1.MemberPermissions', '10': 'permissions'},
    {'1': 'joined_at', '3': 6, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'joinedAt'},
  ],
};

/// Descriptor for `FamilyMember`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List familyMemberDescriptor = $convert.base64Decode(
    'CgxGYW1pbHlNZW1iZXISDgoCaWQYASABKAlSAmlkEhcKB3VzZXJfaWQYAiABKAlSBnVzZXJJZB'
    'IUCgVlbWFpbBgDIAEoCVIFZW1haWwSNgoEcm9sZRgEIAEoDjIiLmZhbWlseWxlZGdlci5mYW1p'
    'bHkudjEuRmFtaWx5Um9sZVIEcm9sZRJLCgtwZXJtaXNzaW9ucxgFIAEoCzIpLmZhbWlseWxlZG'
    'dlci5mYW1pbHkudjEuTWVtYmVyUGVybWlzc2lvbnNSC3Blcm1pc3Npb25zEjcKCWpvaW5lZF9h'
    'dBgGIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCGpvaW5lZEF0');

@$core.Deprecated('Use createFamilyRequestDescriptor instead')
const CreateFamilyRequest$json = {
  '1': 'CreateFamilyRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateFamilyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createFamilyRequestDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVGYW1pbHlSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWU=');

@$core.Deprecated('Use createFamilyResponseDescriptor instead')
const CreateFamilyResponse$json = {
  '1': 'CreateFamilyResponse',
  '2': [
    {'1': 'family', '3': 1, '4': 1, '5': 11, '6': '.familyledger.family.v1.Family', '10': 'family'},
  ],
};

/// Descriptor for `CreateFamilyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createFamilyResponseDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVGYW1pbHlSZXNwb25zZRI2CgZmYW1pbHkYASABKAsyHi5mYW1pbHlsZWRnZXIuZm'
    'FtaWx5LnYxLkZhbWlseVIGZmFtaWx5');

@$core.Deprecated('Use joinFamilyRequestDescriptor instead')
const JoinFamilyRequest$json = {
  '1': 'JoinFamilyRequest',
  '2': [
    {'1': 'invite_code', '3': 1, '4': 1, '5': 9, '10': 'inviteCode'},
  ],
};

/// Descriptor for `JoinFamilyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinFamilyRequestDescriptor = $convert.base64Decode(
    'ChFKb2luRmFtaWx5UmVxdWVzdBIfCgtpbnZpdGVfY29kZRgBIAEoCVIKaW52aXRlQ29kZQ==');

@$core.Deprecated('Use joinFamilyResponseDescriptor instead')
const JoinFamilyResponse$json = {
  '1': 'JoinFamilyResponse',
  '2': [
    {'1': 'family', '3': 1, '4': 1, '5': 11, '6': '.familyledger.family.v1.Family', '10': 'family'},
  ],
};

/// Descriptor for `JoinFamilyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List joinFamilyResponseDescriptor = $convert.base64Decode(
    'ChJKb2luRmFtaWx5UmVzcG9uc2USNgoGZmFtaWx5GAEgASgLMh4uZmFtaWx5bGVkZ2VyLmZhbW'
    'lseS52MS5GYW1pbHlSBmZhbWlseQ==');

@$core.Deprecated('Use getFamilyRequestDescriptor instead')
const GetFamilyRequest$json = {
  '1': 'GetFamilyRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `GetFamilyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFamilyRequestDescriptor = $convert.base64Decode(
    'ChBHZXRGYW1pbHlSZXF1ZXN0EhsKCWZhbWlseV9pZBgBIAEoCVIIZmFtaWx5SWQ=');

@$core.Deprecated('Use getFamilyResponseDescriptor instead')
const GetFamilyResponse$json = {
  '1': 'GetFamilyResponse',
  '2': [
    {'1': 'family', '3': 1, '4': 1, '5': 11, '6': '.familyledger.family.v1.Family', '10': 'family'},
    {'1': 'members', '3': 2, '4': 3, '5': 11, '6': '.familyledger.family.v1.FamilyMember', '10': 'members'},
  ],
};

/// Descriptor for `GetFamilyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFamilyResponseDescriptor = $convert.base64Decode(
    'ChFHZXRGYW1pbHlSZXNwb25zZRI2CgZmYW1pbHkYASABKAsyHi5mYW1pbHlsZWRnZXIuZmFtaW'
    'x5LnYxLkZhbWlseVIGZmFtaWx5Ej4KB21lbWJlcnMYAiADKAsyJC5mYW1pbHlsZWRnZXIuZmFt'
    'aWx5LnYxLkZhbWlseU1lbWJlclIHbWVtYmVycw==');

@$core.Deprecated('Use generateInviteCodeRequestDescriptor instead')
const GenerateInviteCodeRequest$json = {
  '1': 'GenerateInviteCodeRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `GenerateInviteCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateInviteCodeRequestDescriptor = $convert.base64Decode(
    'ChlHZW5lcmF0ZUludml0ZUNvZGVSZXF1ZXN0EhsKCWZhbWlseV9pZBgBIAEoCVIIZmFtaWx5SW'
    'Q=');

@$core.Deprecated('Use generateInviteCodeResponseDescriptor instead')
const GenerateInviteCodeResponse$json = {
  '1': 'GenerateInviteCodeResponse',
  '2': [
    {'1': 'invite_code', '3': 1, '4': 1, '5': 9, '10': 'inviteCode'},
    {'1': 'expires_at', '3': 2, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'expiresAt'},
  ],
};

/// Descriptor for `GenerateInviteCodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List generateInviteCodeResponseDescriptor = $convert.base64Decode(
    'ChpHZW5lcmF0ZUludml0ZUNvZGVSZXNwb25zZRIfCgtpbnZpdGVfY29kZRgBIAEoCVIKaW52aX'
    'RlQ29kZRI5CgpleHBpcmVzX2F0GAIgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJ'
    'ZXhwaXJlc0F0');

@$core.Deprecated('Use setMemberRoleRequestDescriptor instead')
const SetMemberRoleRequest$json = {
  '1': 'SetMemberRoleRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'role', '3': 3, '4': 1, '5': 14, '6': '.familyledger.family.v1.FamilyRole', '10': 'role'},
  ],
};

/// Descriptor for `SetMemberRoleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMemberRoleRequestDescriptor = $convert.base64Decode(
    'ChRTZXRNZW1iZXJSb2xlUmVxdWVzdBIbCglmYW1pbHlfaWQYASABKAlSCGZhbWlseUlkEhcKB3'
    'VzZXJfaWQYAiABKAlSBnVzZXJJZBI2CgRyb2xlGAMgASgOMiIuZmFtaWx5bGVkZ2VyLmZhbWls'
    'eS52MS5GYW1pbHlSb2xlUgRyb2xl');

@$core.Deprecated('Use setMemberRoleResponseDescriptor instead')
const SetMemberRoleResponse$json = {
  '1': 'SetMemberRoleResponse',
};

/// Descriptor for `SetMemberRoleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMemberRoleResponseDescriptor = $convert.base64Decode(
    'ChVTZXRNZW1iZXJSb2xlUmVzcG9uc2U=');

@$core.Deprecated('Use setMemberPermissionsRequestDescriptor instead')
const SetMemberPermissionsRequest$json = {
  '1': 'SetMemberPermissionsRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'permissions', '3': 3, '4': 1, '5': 11, '6': '.familyledger.family.v1.MemberPermissions', '10': 'permissions'},
  ],
};

/// Descriptor for `SetMemberPermissionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMemberPermissionsRequestDescriptor = $convert.base64Decode(
    'ChtTZXRNZW1iZXJQZXJtaXNzaW9uc1JlcXVlc3QSGwoJZmFtaWx5X2lkGAEgASgJUghmYW1pbH'
    'lJZBIXCgd1c2VyX2lkGAIgASgJUgZ1c2VySWQSSwoLcGVybWlzc2lvbnMYAyABKAsyKS5mYW1p'
    'bHlsZWRnZXIuZmFtaWx5LnYxLk1lbWJlclBlcm1pc3Npb25zUgtwZXJtaXNzaW9ucw==');

@$core.Deprecated('Use setMemberPermissionsResponseDescriptor instead')
const SetMemberPermissionsResponse$json = {
  '1': 'SetMemberPermissionsResponse',
};

/// Descriptor for `SetMemberPermissionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMemberPermissionsResponseDescriptor = $convert.base64Decode(
    'ChxTZXRNZW1iZXJQZXJtaXNzaW9uc1Jlc3BvbnNl');

@$core.Deprecated('Use listFamilyMembersRequestDescriptor instead')
const ListFamilyMembersRequest$json = {
  '1': 'ListFamilyMembersRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `ListFamilyMembersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listFamilyMembersRequestDescriptor = $convert.base64Decode(
    'ChhMaXN0RmFtaWx5TWVtYmVyc1JlcXVlc3QSGwoJZmFtaWx5X2lkGAEgASgJUghmYW1pbHlJZA'
    '==');

@$core.Deprecated('Use listFamilyMembersResponseDescriptor instead')
const ListFamilyMembersResponse$json = {
  '1': 'ListFamilyMembersResponse',
  '2': [
    {'1': 'members', '3': 1, '4': 3, '5': 11, '6': '.familyledger.family.v1.FamilyMember', '10': 'members'},
  ],
};

/// Descriptor for `ListFamilyMembersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listFamilyMembersResponseDescriptor = $convert.base64Decode(
    'ChlMaXN0RmFtaWx5TWVtYmVyc1Jlc3BvbnNlEj4KB21lbWJlcnMYASADKAsyJC5mYW1pbHlsZW'
    'RnZXIuZmFtaWx5LnYxLkZhbWlseU1lbWJlclIHbWVtYmVycw==');

@$core.Deprecated('Use leaveFamilyRequestDescriptor instead')
const LeaveFamilyRequest$json = {
  '1': 'LeaveFamilyRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `LeaveFamilyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveFamilyRequestDescriptor = $convert.base64Decode(
    'ChJMZWF2ZUZhbWlseVJlcXVlc3QSGwoJZmFtaWx5X2lkGAEgASgJUghmYW1pbHlJZA==');

@$core.Deprecated('Use leaveFamilyResponseDescriptor instead')
const LeaveFamilyResponse$json = {
  '1': 'LeaveFamilyResponse',
};

/// Descriptor for `LeaveFamilyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List leaveFamilyResponseDescriptor = $convert.base64Decode(
    'ChNMZWF2ZUZhbWlseVJlc3BvbnNl');

@$core.Deprecated('Use transferOwnershipRequestDescriptor instead')
const TransferOwnershipRequest$json = {
  '1': 'TransferOwnershipRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'new_owner_id', '3': 2, '4': 1, '5': 9, '10': 'newOwnerId'},
  ],
};

/// Descriptor for `TransferOwnershipRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferOwnershipRequestDescriptor = $convert.base64Decode(
    'ChhUcmFuc2Zlck93bmVyc2hpcFJlcXVlc3QSGwoJZmFtaWx5X2lkGAEgASgJUghmYW1pbHlJZB'
    'IgCgxuZXdfb3duZXJfaWQYAiABKAlSCm5ld093bmVySWQ=');

@$core.Deprecated('Use transferOwnershipResponseDescriptor instead')
const TransferOwnershipResponse$json = {
  '1': 'TransferOwnershipResponse',
};

/// Descriptor for `TransferOwnershipResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferOwnershipResponseDescriptor = $convert.base64Decode(
    'ChlUcmFuc2Zlck93bmVyc2hpcFJlc3BvbnNl');

@$core.Deprecated('Use deleteFamilyRequestDescriptor instead')
const DeleteFamilyRequest$json = {
  '1': 'DeleteFamilyRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `DeleteFamilyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteFamilyRequestDescriptor = $convert.base64Decode(
    'ChNEZWxldGVGYW1pbHlSZXF1ZXN0EhsKCWZhbWlseV9pZBgBIAEoCVIIZmFtaWx5SWQ=');

@$core.Deprecated('Use deleteFamilyResponseDescriptor instead')
const DeleteFamilyResponse$json = {
  '1': 'DeleteFamilyResponse',
};

/// Descriptor for `DeleteFamilyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteFamilyResponseDescriptor = $convert.base64Decode(
    'ChREZWxldGVGYW1pbHlSZXNwb25zZQ==');

@$core.Deprecated('Use getAuditLogRequestDescriptor instead')
const GetAuditLogRequest$json = {
  '1': 'GetAuditLogRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'page_size', '3': 2, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 3, '4': 1, '5': 9, '10': 'pageToken'},
    {'1': 'entity_type', '3': 4, '4': 1, '5': 9, '10': 'entityType'},
  ],
};

/// Descriptor for `GetAuditLogRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAuditLogRequestDescriptor = $convert.base64Decode(
    'ChJHZXRBdWRpdExvZ1JlcXVlc3QSGwoJZmFtaWx5X2lkGAEgASgJUghmYW1pbHlJZBIbCglwYW'
    'dlX3NpemUYAiABKAVSCHBhZ2VTaXplEh0KCnBhZ2VfdG9rZW4YAyABKAlSCXBhZ2VUb2tlbhIf'
    'CgtlbnRpdHlfdHlwZRgEIAEoCVIKZW50aXR5VHlwZQ==');

@$core.Deprecated('Use getAuditLogResponseDescriptor instead')
const GetAuditLogResponse$json = {
  '1': 'GetAuditLogResponse',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.familyledger.family.v1.AuditEntry', '10': 'entries'},
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
  ],
};

/// Descriptor for `GetAuditLogResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAuditLogResponseDescriptor = $convert.base64Decode(
    'ChNHZXRBdWRpdExvZ1Jlc3BvbnNlEjwKB2VudHJpZXMYASADKAsyIi5mYW1pbHlsZWRnZXIuZm'
    'FtaWx5LnYxLkF1ZGl0RW50cnlSB2VudHJpZXMSJgoPbmV4dF9wYWdlX3Rva2VuGAIgASgJUg1u'
    'ZXh0UGFnZVRva2Vu');

@$core.Deprecated('Use auditEntryDescriptor instead')
const AuditEntry$json = {
  '1': 'AuditEntry',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'user_name', '3': 3, '4': 1, '5': 9, '10': 'userName'},
    {'1': 'action', '3': 4, '4': 1, '5': 9, '10': 'action'},
    {'1': 'entity_type', '3': 5, '4': 1, '5': 9, '10': 'entityType'},
    {'1': 'entity_id', '3': 6, '4': 1, '5': 9, '10': 'entityId'},
    {'1': 'changes_json', '3': 7, '4': 1, '5': 9, '10': 'changesJson'},
    {'1': 'created_at', '3': 8, '4': 1, '5': 3, '10': 'createdAt'},
  ],
};

/// Descriptor for `AuditEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List auditEntryDescriptor = $convert.base64Decode(
    'CgpBdWRpdEVudHJ5Eg4KAmlkGAEgASgJUgJpZBIXCgd1c2VyX2lkGAIgASgJUgZ1c2VySWQSGw'
    'oJdXNlcl9uYW1lGAMgASgJUgh1c2VyTmFtZRIWCgZhY3Rpb24YBCABKAlSBmFjdGlvbhIfCgtl'
    'bnRpdHlfdHlwZRgFIAEoCVIKZW50aXR5VHlwZRIbCgllbnRpdHlfaWQYBiABKAlSCGVudGl0eU'
    'lkEiEKDGNoYW5nZXNfanNvbhgHIAEoCVILY2hhbmdlc0pzb24SHQoKY3JlYXRlZF9hdBgIIAEo'
    'A1IJY3JlYXRlZEF0');

@$core.Deprecated('Use listMyFamiliesRequestDescriptor instead')
const ListMyFamiliesRequest$json = {
  '1': 'ListMyFamiliesRequest',
};

/// Descriptor for `ListMyFamiliesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMyFamiliesRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0TXlGYW1pbGllc1JlcXVlc3Q=');

@$core.Deprecated('Use listMyFamiliesResponseDescriptor instead')
const ListMyFamiliesResponse$json = {
  '1': 'ListMyFamiliesResponse',
  '2': [
    {'1': 'families', '3': 1, '4': 3, '5': 11, '6': '.familyledger.family.v1.Family', '10': 'families'},
    {'1': 'memberships', '3': 2, '4': 3, '5': 11, '6': '.familyledger.family.v1.FamilyMember', '10': 'memberships'},
  ],
};

/// Descriptor for `ListMyFamiliesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMyFamiliesResponseDescriptor = $convert.base64Decode(
    'ChZMaXN0TXlGYW1pbGllc1Jlc3BvbnNlEjoKCGZhbWlsaWVzGAEgAygLMh4uZmFtaWx5bGVkZ2'
    'VyLmZhbWlseS52MS5GYW1pbHlSCGZhbWlsaWVzEkYKC21lbWJlcnNoaXBzGAIgAygLMiQuZmFt'
    'aWx5bGVkZ2VyLmZhbWlseS52MS5GYW1pbHlNZW1iZXJSC21lbWJlcnNoaXBz');

