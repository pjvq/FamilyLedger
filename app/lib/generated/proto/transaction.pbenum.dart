// This is a generated file - do not edit.
//
// Generated from transaction.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class TransactionType extends $pb.ProtobufEnum {
  static const TransactionType TRANSACTION_TYPE_UNSPECIFIED = TransactionType._(
      0, _omitEnumNames ? '' : 'TRANSACTION_TYPE_UNSPECIFIED');
  static const TransactionType TRANSACTION_TYPE_INCOME =
      TransactionType._(1, _omitEnumNames ? '' : 'TRANSACTION_TYPE_INCOME');
  static const TransactionType TRANSACTION_TYPE_EXPENSE =
      TransactionType._(2, _omitEnumNames ? '' : 'TRANSACTION_TYPE_EXPENSE');

  static const $core.List<TransactionType> values = <TransactionType>[
    TRANSACTION_TYPE_UNSPECIFIED,
    TRANSACTION_TYPE_INCOME,
    TRANSACTION_TYPE_EXPENSE,
  ];

  static final $core.List<TransactionType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TransactionType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TransactionType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
