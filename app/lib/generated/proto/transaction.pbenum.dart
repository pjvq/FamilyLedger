//
//  Generated code. Do not modify.
//  source: transaction.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class TransactionType extends $pb.ProtobufEnum {
  static const TransactionType TRANSACTION_TYPE_UNSPECIFIED = TransactionType._(0, _omitEnumNames ? '' : 'TRANSACTION_TYPE_UNSPECIFIED');
  static const TransactionType TRANSACTION_TYPE_INCOME = TransactionType._(1, _omitEnumNames ? '' : 'TRANSACTION_TYPE_INCOME');
  static const TransactionType TRANSACTION_TYPE_EXPENSE = TransactionType._(2, _omitEnumNames ? '' : 'TRANSACTION_TYPE_EXPENSE');

  static const $core.List<TransactionType> values = <TransactionType> [
    TRANSACTION_TYPE_UNSPECIFIED,
    TRANSACTION_TYPE_INCOME,
    TRANSACTION_TYPE_EXPENSE,
  ];

  static final $core.Map<$core.int, TransactionType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static TransactionType? valueOf($core.int value) => _byValue[value];

  const TransactionType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
