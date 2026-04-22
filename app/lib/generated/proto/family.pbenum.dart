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

import 'package:protobuf/protobuf.dart' as $pb;

class FamilyRole extends $pb.ProtobufEnum {
  static const FamilyRole FAMILY_ROLE_UNSPECIFIED = FamilyRole._(0, _omitEnumNames ? '' : 'FAMILY_ROLE_UNSPECIFIED');
  static const FamilyRole FAMILY_ROLE_OWNER = FamilyRole._(1, _omitEnumNames ? '' : 'FAMILY_ROLE_OWNER');
  static const FamilyRole FAMILY_ROLE_ADMIN = FamilyRole._(2, _omitEnumNames ? '' : 'FAMILY_ROLE_ADMIN');
  static const FamilyRole FAMILY_ROLE_MEMBER = FamilyRole._(3, _omitEnumNames ? '' : 'FAMILY_ROLE_MEMBER');

  static const $core.List<FamilyRole> values = <FamilyRole> [
    FAMILY_ROLE_UNSPECIFIED,
    FAMILY_ROLE_OWNER,
    FAMILY_ROLE_ADMIN,
    FAMILY_ROLE_MEMBER,
  ];

  static final $core.Map<$core.int, FamilyRole> _byValue = $pb.ProtobufEnum.initByValue(values);
  static FamilyRole? valueOf($core.int value) => _byValue[value];

  const FamilyRole._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
