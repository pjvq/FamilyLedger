//
//  Generated code. Do not modify.
//  source: account.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class AccountType extends $pb.ProtobufEnum {
  static const AccountType ACCOUNT_TYPE_UNSPECIFIED = AccountType._(0, _omitEnumNames ? '' : 'ACCOUNT_TYPE_UNSPECIFIED');
  static const AccountType ACCOUNT_TYPE_CASH = AccountType._(1, _omitEnumNames ? '' : 'ACCOUNT_TYPE_CASH');
  static const AccountType ACCOUNT_TYPE_BANK_CARD = AccountType._(2, _omitEnumNames ? '' : 'ACCOUNT_TYPE_BANK_CARD');
  static const AccountType ACCOUNT_TYPE_CREDIT_CARD = AccountType._(3, _omitEnumNames ? '' : 'ACCOUNT_TYPE_CREDIT_CARD');
  static const AccountType ACCOUNT_TYPE_ALIPAY = AccountType._(4, _omitEnumNames ? '' : 'ACCOUNT_TYPE_ALIPAY');
  static const AccountType ACCOUNT_TYPE_WECHAT_PAY = AccountType._(5, _omitEnumNames ? '' : 'ACCOUNT_TYPE_WECHAT_PAY');
  static const AccountType ACCOUNT_TYPE_INVESTMENT = AccountType._(6, _omitEnumNames ? '' : 'ACCOUNT_TYPE_INVESTMENT');
  static const AccountType ACCOUNT_TYPE_OTHER = AccountType._(7, _omitEnumNames ? '' : 'ACCOUNT_TYPE_OTHER');

  static const $core.List<AccountType> values = <AccountType> [
    ACCOUNT_TYPE_UNSPECIFIED,
    ACCOUNT_TYPE_CASH,
    ACCOUNT_TYPE_BANK_CARD,
    ACCOUNT_TYPE_CREDIT_CARD,
    ACCOUNT_TYPE_ALIPAY,
    ACCOUNT_TYPE_WECHAT_PAY,
    ACCOUNT_TYPE_INVESTMENT,
    ACCOUNT_TYPE_OTHER,
  ];

  static final $core.Map<$core.int, AccountType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static AccountType? valueOf($core.int value) => _byValue[value];

  const AccountType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
