//
//  Generated code. Do not modify.
//  source: loan.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class LoanType extends $pb.ProtobufEnum {
  static const LoanType LOAN_TYPE_UNSPECIFIED = LoanType._(0, _omitEnumNames ? '' : 'LOAN_TYPE_UNSPECIFIED');
  static const LoanType LOAN_TYPE_MORTGAGE = LoanType._(1, _omitEnumNames ? '' : 'LOAN_TYPE_MORTGAGE');
  static const LoanType LOAN_TYPE_CAR_LOAN = LoanType._(2, _omitEnumNames ? '' : 'LOAN_TYPE_CAR_LOAN');
  static const LoanType LOAN_TYPE_CREDIT_CARD = LoanType._(3, _omitEnumNames ? '' : 'LOAN_TYPE_CREDIT_CARD');
  static const LoanType LOAN_TYPE_CONSUMER = LoanType._(4, _omitEnumNames ? '' : 'LOAN_TYPE_CONSUMER');
  static const LoanType LOAN_TYPE_BUSINESS = LoanType._(5, _omitEnumNames ? '' : 'LOAN_TYPE_BUSINESS');
  static const LoanType LOAN_TYPE_OTHER = LoanType._(6, _omitEnumNames ? '' : 'LOAN_TYPE_OTHER');

  static const $core.List<LoanType> values = <LoanType> [
    LOAN_TYPE_UNSPECIFIED,
    LOAN_TYPE_MORTGAGE,
    LOAN_TYPE_CAR_LOAN,
    LOAN_TYPE_CREDIT_CARD,
    LOAN_TYPE_CONSUMER,
    LOAN_TYPE_BUSINESS,
    LOAN_TYPE_OTHER,
  ];

  static final $core.Map<$core.int, LoanType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static LoanType? valueOf($core.int value) => _byValue[value];

  const LoanType._($core.int v, $core.String n) : super(v, n);
}

class RepaymentMethod extends $pb.ProtobufEnum {
  static const RepaymentMethod REPAYMENT_METHOD_UNSPECIFIED = RepaymentMethod._(0, _omitEnumNames ? '' : 'REPAYMENT_METHOD_UNSPECIFIED');
  static const RepaymentMethod REPAYMENT_METHOD_EQUAL_INSTALLMENT = RepaymentMethod._(1, _omitEnumNames ? '' : 'REPAYMENT_METHOD_EQUAL_INSTALLMENT');
  static const RepaymentMethod REPAYMENT_METHOD_EQUAL_PRINCIPAL = RepaymentMethod._(2, _omitEnumNames ? '' : 'REPAYMENT_METHOD_EQUAL_PRINCIPAL');

  static const $core.List<RepaymentMethod> values = <RepaymentMethod> [
    REPAYMENT_METHOD_UNSPECIFIED,
    REPAYMENT_METHOD_EQUAL_INSTALLMENT,
    REPAYMENT_METHOD_EQUAL_PRINCIPAL,
  ];

  static final $core.Map<$core.int, RepaymentMethod> _byValue = $pb.ProtobufEnum.initByValue(values);
  static RepaymentMethod? valueOf($core.int value) => _byValue[value];

  const RepaymentMethod._($core.int v, $core.String n) : super(v, n);
}

class PrepaymentStrategy extends $pb.ProtobufEnum {
  static const PrepaymentStrategy PREPAYMENT_STRATEGY_UNSPECIFIED = PrepaymentStrategy._(0, _omitEnumNames ? '' : 'PREPAYMENT_STRATEGY_UNSPECIFIED');
  static const PrepaymentStrategy PREPAYMENT_STRATEGY_REDUCE_MONTHS = PrepaymentStrategy._(1, _omitEnumNames ? '' : 'PREPAYMENT_STRATEGY_REDUCE_MONTHS');
  static const PrepaymentStrategy PREPAYMENT_STRATEGY_REDUCE_PAYMENT = PrepaymentStrategy._(2, _omitEnumNames ? '' : 'PREPAYMENT_STRATEGY_REDUCE_PAYMENT');

  static const $core.List<PrepaymentStrategy> values = <PrepaymentStrategy> [
    PREPAYMENT_STRATEGY_UNSPECIFIED,
    PREPAYMENT_STRATEGY_REDUCE_MONTHS,
    PREPAYMENT_STRATEGY_REDUCE_PAYMENT,
  ];

  static final $core.Map<$core.int, PrepaymentStrategy> _byValue = $pb.ProtobufEnum.initByValue(values);
  static PrepaymentStrategy? valueOf($core.int value) => _byValue[value];

  const PrepaymentStrategy._($core.int v, $core.String n) : super(v, n);
}

class LoanSubType extends $pb.ProtobufEnum {
  static const LoanSubType LOAN_SUB_TYPE_UNSPECIFIED = LoanSubType._(0, _omitEnumNames ? '' : 'LOAN_SUB_TYPE_UNSPECIFIED');
  static const LoanSubType LOAN_SUB_TYPE_COMMERCIAL = LoanSubType._(1, _omitEnumNames ? '' : 'LOAN_SUB_TYPE_COMMERCIAL');
  static const LoanSubType LOAN_SUB_TYPE_PROVIDENT = LoanSubType._(2, _omitEnumNames ? '' : 'LOAN_SUB_TYPE_PROVIDENT');

  static const $core.List<LoanSubType> values = <LoanSubType> [
    LOAN_SUB_TYPE_UNSPECIFIED,
    LOAN_SUB_TYPE_COMMERCIAL,
    LOAN_SUB_TYPE_PROVIDENT,
  ];

  static final $core.Map<$core.int, LoanSubType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static LoanSubType? valueOf($core.int value) => _byValue[value];

  const LoanSubType._($core.int v, $core.String n) : super(v, n);
}

class RateType extends $pb.ProtobufEnum {
  static const RateType RATE_TYPE_UNSPECIFIED = RateType._(0, _omitEnumNames ? '' : 'RATE_TYPE_UNSPECIFIED');
  static const RateType RATE_TYPE_FIXED = RateType._(1, _omitEnumNames ? '' : 'RATE_TYPE_FIXED');
  static const RateType RATE_TYPE_LPR_FLOATING = RateType._(2, _omitEnumNames ? '' : 'RATE_TYPE_LPR_FLOATING');

  static const $core.List<RateType> values = <RateType> [
    RATE_TYPE_UNSPECIFIED,
    RATE_TYPE_FIXED,
    RATE_TYPE_LPR_FLOATING,
  ];

  static final $core.Map<$core.int, RateType> _byValue = $pb.ProtobufEnum.initByValue(values);
  static RateType? valueOf($core.int value) => _byValue[value];

  const RateType._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
