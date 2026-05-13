//
//  Generated code. Do not modify.
//  source: loan.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use loanTypeDescriptor instead')
const LoanType$json = {
  '1': 'LoanType',
  '2': [
    {'1': 'LOAN_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'LOAN_TYPE_MORTGAGE', '2': 1},
    {'1': 'LOAN_TYPE_CAR_LOAN', '2': 2},
    {'1': 'LOAN_TYPE_CREDIT_CARD', '2': 3},
    {'1': 'LOAN_TYPE_CONSUMER', '2': 4},
    {'1': 'LOAN_TYPE_BUSINESS', '2': 5},
    {'1': 'LOAN_TYPE_OTHER', '2': 6},
  ],
};

/// Descriptor for `LoanType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List loanTypeDescriptor = $convert.base64Decode(
    'CghMb2FuVHlwZRIZChVMT0FOX1RZUEVfVU5TUEVDSUZJRUQQABIWChJMT0FOX1RZUEVfTU9SVE'
    'dBR0UQARIWChJMT0FOX1RZUEVfQ0FSX0xPQU4QAhIZChVMT0FOX1RZUEVfQ1JFRElUX0NBUkQQ'
    'AxIWChJMT0FOX1RZUEVfQ09OU1VNRVIQBBIWChJMT0FOX1RZUEVfQlVTSU5FU1MQBRITCg9MT0'
    'FOX1RZUEVfT1RIRVIQBg==');

@$core.Deprecated('Use repaymentMethodDescriptor instead')
const RepaymentMethod$json = {
  '1': 'RepaymentMethod',
  '2': [
    {'1': 'REPAYMENT_METHOD_UNSPECIFIED', '2': 0},
    {'1': 'REPAYMENT_METHOD_EQUAL_INSTALLMENT', '2': 1},
    {'1': 'REPAYMENT_METHOD_EQUAL_PRINCIPAL', '2': 2},
    {'1': 'REPAYMENT_METHOD_INTEREST_ONLY', '2': 3},
    {'1': 'REPAYMENT_METHOD_BULLET', '2': 4},
    {'1': 'REPAYMENT_METHOD_EQUAL_INTEREST', '2': 5},
  ],
};

/// Descriptor for `RepaymentMethod`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List repaymentMethodDescriptor = $convert.base64Decode(
    'Cg9SZXBheW1lbnRNZXRob2QSIAocUkVQQVlNRU5UX01FVEhPRF9VTlNQRUNJRklFRBAAEiYKIl'
    'JFUEFZTUVOVF9NRVRIT0RfRVFVQUxfSU5TVEFMTE1FTlQQARIkCiBSRVBBWU1FTlRfTUVUSE9E'
    'X0VRVUFMX1BSSU5DSVBBTBACEiIKHlJFUEFZTUVOVF9NRVRIT0RfSU5URVJFU1RfT05MWRADEh'
    'sKF1JFUEFZTUVOVF9NRVRIT0RfQlVMTEVUEAQSIwofUkVQQVlNRU5UX01FVEhPRF9FUVVBTF9J'
    'TlRFUkVTVBAF');

@$core.Deprecated('Use prepaymentStrategyDescriptor instead')
const PrepaymentStrategy$json = {
  '1': 'PrepaymentStrategy',
  '2': [
    {'1': 'PREPAYMENT_STRATEGY_UNSPECIFIED', '2': 0},
    {'1': 'PREPAYMENT_STRATEGY_REDUCE_MONTHS', '2': 1},
    {'1': 'PREPAYMENT_STRATEGY_REDUCE_PAYMENT', '2': 2},
  ],
};

/// Descriptor for `PrepaymentStrategy`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List prepaymentStrategyDescriptor = $convert.base64Decode(
    'ChJQcmVwYXltZW50U3RyYXRlZ3kSIwofUFJFUEFZTUVOVF9TVFJBVEVHWV9VTlNQRUNJRklFRB'
    'AAEiUKIVBSRVBBWU1FTlRfU1RSQVRFR1lfUkVEVUNFX01PTlRIUxABEiYKIlBSRVBBWU1FTlRf'
    'U1RSQVRFR1lfUkVEVUNFX1BBWU1FTlQQAg==');

@$core.Deprecated('Use loanSubTypeDescriptor instead')
const LoanSubType$json = {
  '1': 'LoanSubType',
  '2': [
    {'1': 'LOAN_SUB_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'LOAN_SUB_TYPE_COMMERCIAL', '2': 1},
    {'1': 'LOAN_SUB_TYPE_PROVIDENT', '2': 2},
  ],
};

/// Descriptor for `LoanSubType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List loanSubTypeDescriptor = $convert.base64Decode(
    'CgtMb2FuU3ViVHlwZRIdChlMT0FOX1NVQl9UWVBFX1VOU1BFQ0lGSUVEEAASHAoYTE9BTl9TVU'
    'JfVFlQRV9DT01NRVJDSUFMEAESGwoXTE9BTl9TVUJfVFlQRV9QUk9WSURFTlQQAg==');

@$core.Deprecated('Use rateTypeDescriptor instead')
const RateType$json = {
  '1': 'RateType',
  '2': [
    {'1': 'RATE_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'RATE_TYPE_FIXED', '2': 1},
    {'1': 'RATE_TYPE_LPR_FLOATING', '2': 2},
  ],
};

/// Descriptor for `RateType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List rateTypeDescriptor = $convert.base64Decode(
    'CghSYXRlVHlwZRIZChVSQVRFX1RZUEVfVU5TUEVDSUZJRUQQABITCg9SQVRFX1RZUEVfRklYRU'
    'QQARIaChZSQVRFX1RZUEVfTFBSX0ZMT0FUSU5HEAI=');

@$core.Deprecated('Use interestCalcMethodDescriptor instead')
const InterestCalcMethod$json = {
  '1': 'InterestCalcMethod',
  '2': [
    {'1': 'INTEREST_CALC_MONTHLY', '2': 0},
    {'1': 'INTEREST_CALC_DAILY_ACT_365', '2': 1},
    {'1': 'INTEREST_CALC_DAILY_ACT_360', '2': 2},
  ],
};

/// Descriptor for `InterestCalcMethod`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List interestCalcMethodDescriptor = $convert.base64Decode(
    'ChJJbnRlcmVzdENhbGNNZXRob2QSGQoVSU5URVJFU1RfQ0FMQ19NT05USExZEAASHwobSU5URV'
    'JFU1RfQ0FMQ19EQUlMWV9BQ1RfMzY1EAESHwobSU5URVJFU1RfQ0FMQ19EQUlMWV9BQ1RfMzYw'
    'EAI=');

@$core.Deprecated('Use loanDescriptor instead')
const Loan$json = {
  '1': 'Loan',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'loan_type', '3': 4, '4': 1, '5': 14, '6': '.familyledger.loan.v1.LoanType', '10': 'loanType'},
    {'1': 'principal', '3': 5, '4': 1, '5': 3, '10': 'principal'},
    {'1': 'remaining_principal', '3': 6, '4': 1, '5': 3, '10': 'remainingPrincipal'},
    {'1': 'annual_rate', '3': 7, '4': 1, '5': 1, '10': 'annualRate'},
    {'1': 'total_months', '3': 8, '4': 1, '5': 5, '10': 'totalMonths'},
    {'1': 'paid_months', '3': 9, '4': 1, '5': 5, '10': 'paidMonths'},
    {'1': 'repayment_method', '3': 10, '4': 1, '5': 14, '6': '.familyledger.loan.v1.RepaymentMethod', '10': 'repaymentMethod'},
    {'1': 'payment_day', '3': 11, '4': 1, '5': 5, '10': 'paymentDay'},
    {'1': 'start_date', '3': 12, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'startDate'},
    {'1': 'created_at', '3': 13, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
    {'1': 'updated_at', '3': 14, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedAt'},
    {'1': 'account_id', '3': 15, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'group_id', '3': 16, '4': 1, '5': 9, '10': 'groupId'},
    {'1': 'sub_type', '3': 17, '4': 1, '5': 14, '6': '.familyledger.loan.v1.LoanSubType', '10': 'subType'},
    {'1': 'rate_type', '3': 18, '4': 1, '5': 14, '6': '.familyledger.loan.v1.RateType', '10': 'rateType'},
    {'1': 'lpr_base', '3': 19, '4': 1, '5': 1, '10': 'lprBase'},
    {'1': 'lpr_spread', '3': 20, '4': 1, '5': 1, '10': 'lprSpread'},
    {'1': 'rate_adjust_month', '3': 21, '4': 1, '5': 5, '10': 'rateAdjustMonth'},
    {'1': 'family_id', '3': 22, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'repayment_category_id', '3': 23, '4': 1, '5': 9, '10': 'repaymentCategoryId'},
    {'1': 'interest_calc_method', '3': 24, '4': 1, '5': 14, '6': '.familyledger.loan.v1.InterestCalcMethod', '10': 'interestCalcMethod'},
  ],
};

/// Descriptor for `Loan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loanDescriptor = $convert.base64Decode(
    'CgRMb2FuEg4KAmlkGAEgASgJUgJpZBIXCgd1c2VyX2lkGAIgASgJUgZ1c2VySWQSEgoEbmFtZR'
    'gDIAEoCVIEbmFtZRI7Cglsb2FuX3R5cGUYBCABKA4yHi5mYW1pbHlsZWRnZXIubG9hbi52MS5M'
    'b2FuVHlwZVIIbG9hblR5cGUSHAoJcHJpbmNpcGFsGAUgASgDUglwcmluY2lwYWwSLwoTcmVtYW'
    'luaW5nX3ByaW5jaXBhbBgGIAEoA1IScmVtYWluaW5nUHJpbmNpcGFsEh8KC2FubnVhbF9yYXRl'
    'GAcgASgBUgphbm51YWxSYXRlEiEKDHRvdGFsX21vbnRocxgIIAEoBVILdG90YWxNb250aHMSHw'
    'oLcGFpZF9tb250aHMYCSABKAVSCnBhaWRNb250aHMSUAoQcmVwYXltZW50X21ldGhvZBgKIAEo'
    'DjIlLmZhbWlseWxlZGdlci5sb2FuLnYxLlJlcGF5bWVudE1ldGhvZFIPcmVwYXltZW50TWV0aG'
    '9kEh8KC3BheW1lbnRfZGF5GAsgASgFUgpwYXltZW50RGF5EjkKCnN0YXJ0X2RhdGUYDCABKAsy'
    'Gi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUglzdGFydERhdGUSOQoKY3JlYXRlZF9hdBgNIA'
    'EoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWNyZWF0ZWRBdBI5Cgp1cGRhdGVkX2F0'
    'GA4gASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJdXBkYXRlZEF0Eh0KCmFjY291bn'
    'RfaWQYDyABKAlSCWFjY291bnRJZBIZCghncm91cF9pZBgQIAEoCVIHZ3JvdXBJZBI8CghzdWJf'
    'dHlwZRgRIAEoDjIhLmZhbWlseWxlZGdlci5sb2FuLnYxLkxvYW5TdWJUeXBlUgdzdWJUeXBlEj'
    'sKCXJhdGVfdHlwZRgSIAEoDjIeLmZhbWlseWxlZGdlci5sb2FuLnYxLlJhdGVUeXBlUghyYXRl'
    'VHlwZRIZCghscHJfYmFzZRgTIAEoAVIHbHByQmFzZRIdCgpscHJfc3ByZWFkGBQgASgBUglscH'
    'JTcHJlYWQSKgoRcmF0ZV9hZGp1c3RfbW9udGgYFSABKAVSD3JhdGVBZGp1c3RNb250aBIbCglm'
    'YW1pbHlfaWQYFiABKAlSCGZhbWlseUlkEjIKFXJlcGF5bWVudF9jYXRlZ29yeV9pZBgXIAEoCV'
    'ITcmVwYXltZW50Q2F0ZWdvcnlJZBJaChRpbnRlcmVzdF9jYWxjX21ldGhvZBgYIAEoDjIoLmZh'
    'bWlseWxlZGdlci5sb2FuLnYxLkludGVyZXN0Q2FsY01ldGhvZFISaW50ZXJlc3RDYWxjTWV0aG'
    '9k');

@$core.Deprecated('Use loanScheduleItemDescriptor instead')
const LoanScheduleItem$json = {
  '1': 'LoanScheduleItem',
  '2': [
    {'1': 'month_number', '3': 1, '4': 1, '5': 5, '10': 'monthNumber'},
    {'1': 'payment', '3': 2, '4': 1, '5': 3, '10': 'payment'},
    {'1': 'principal_part', '3': 3, '4': 1, '5': 3, '10': 'principalPart'},
    {'1': 'interest_part', '3': 4, '4': 1, '5': 3, '10': 'interestPart'},
    {'1': 'remaining_principal', '3': 5, '4': 1, '5': 3, '10': 'remainingPrincipal'},
    {'1': 'is_paid', '3': 6, '4': 1, '5': 8, '10': 'isPaid'},
    {'1': 'due_date', '3': 7, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'dueDate'},
    {'1': 'paid_date', '3': 8, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'paidDate'},
  ],
};

/// Descriptor for `LoanScheduleItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loanScheduleItemDescriptor = $convert.base64Decode(
    'ChBMb2FuU2NoZWR1bGVJdGVtEiEKDG1vbnRoX251bWJlchgBIAEoBVILbW9udGhOdW1iZXISGA'
    'oHcGF5bWVudBgCIAEoA1IHcGF5bWVudBIlCg5wcmluY2lwYWxfcGFydBgDIAEoA1INcHJpbmNp'
    'cGFsUGFydBIjCg1pbnRlcmVzdF9wYXJ0GAQgASgDUgxpbnRlcmVzdFBhcnQSLwoTcmVtYWluaW'
    '5nX3ByaW5jaXBhbBgFIAEoA1IScmVtYWluaW5nUHJpbmNpcGFsEhcKB2lzX3BhaWQYBiABKAhS'
    'BmlzUGFpZBI1CghkdWVfZGF0ZRgHIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSB2'
    'R1ZURhdGUSNwoJcGFpZF9kYXRlGAggASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFII'
    'cGFpZERhdGU=');

@$core.Deprecated('Use prepaymentSimulationDescriptor instead')
const PrepaymentSimulation$json = {
  '1': 'PrepaymentSimulation',
  '2': [
    {'1': 'prepayment_amount', '3': 1, '4': 1, '5': 3, '10': 'prepaymentAmount'},
    {'1': 'total_interest_before', '3': 2, '4': 1, '5': 3, '10': 'totalInterestBefore'},
    {'1': 'total_interest_after', '3': 3, '4': 1, '5': 3, '10': 'totalInterestAfter'},
    {'1': 'interest_saved', '3': 4, '4': 1, '5': 3, '10': 'interestSaved'},
    {'1': 'months_reduced', '3': 5, '4': 1, '5': 5, '10': 'monthsReduced'},
    {'1': 'new_monthly_payment', '3': 6, '4': 1, '5': 3, '10': 'newMonthlyPayment'},
    {'1': 'new_schedule', '3': 7, '4': 3, '5': 11, '6': '.familyledger.loan.v1.LoanScheduleItem', '10': 'newSchedule'},
  ],
};

/// Descriptor for `PrepaymentSimulation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List prepaymentSimulationDescriptor = $convert.base64Decode(
    'ChRQcmVwYXltZW50U2ltdWxhdGlvbhIrChFwcmVwYXltZW50X2Ftb3VudBgBIAEoA1IQcHJlcG'
    'F5bWVudEFtb3VudBIyChV0b3RhbF9pbnRlcmVzdF9iZWZvcmUYAiABKANSE3RvdGFsSW50ZXJl'
    'c3RCZWZvcmUSMAoUdG90YWxfaW50ZXJlc3RfYWZ0ZXIYAyABKANSEnRvdGFsSW50ZXJlc3RBZn'
    'RlchIlCg5pbnRlcmVzdF9zYXZlZBgEIAEoA1INaW50ZXJlc3RTYXZlZBIlCg5tb250aHNfcmVk'
    'dWNlZBgFIAEoBVINbW9udGhzUmVkdWNlZBIuChNuZXdfbW9udGhseV9wYXltZW50GAYgASgDUh'
    'FuZXdNb250aGx5UGF5bWVudBJJCgxuZXdfc2NoZWR1bGUYByADKAsyJi5mYW1pbHlsZWRnZXIu'
    'bG9hbi52MS5Mb2FuU2NoZWR1bGVJdGVtUgtuZXdTY2hlZHVsZQ==');

@$core.Deprecated('Use createLoanRequestDescriptor instead')
const CreateLoanRequest$json = {
  '1': 'CreateLoanRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'loan_type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.loan.v1.LoanType', '10': 'loanType'},
    {'1': 'principal', '3': 3, '4': 1, '5': 3, '10': 'principal'},
    {'1': 'annual_rate', '3': 4, '4': 1, '5': 1, '10': 'annualRate'},
    {'1': 'total_months', '3': 5, '4': 1, '5': 5, '10': 'totalMonths'},
    {'1': 'repayment_method', '3': 6, '4': 1, '5': 14, '6': '.familyledger.loan.v1.RepaymentMethod', '10': 'repaymentMethod'},
    {'1': 'payment_day', '3': 7, '4': 1, '5': 5, '10': 'paymentDay'},
    {'1': 'start_date', '3': 8, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'startDate'},
    {'1': 'account_id', '3': 9, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'family_id', '3': 10, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'interest_calc_method', '3': 11, '4': 1, '5': 14, '6': '.familyledger.loan.v1.InterestCalcMethod', '10': 'interestCalcMethod'},
  ],
};

/// Descriptor for `CreateLoanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createLoanRequestDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVMb2FuUmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEjsKCWxvYW5fdHlwZRgCIA'
    'EoDjIeLmZhbWlseWxlZGdlci5sb2FuLnYxLkxvYW5UeXBlUghsb2FuVHlwZRIcCglwcmluY2lw'
    'YWwYAyABKANSCXByaW5jaXBhbBIfCgthbm51YWxfcmF0ZRgEIAEoAVIKYW5udWFsUmF0ZRIhCg'
    'x0b3RhbF9tb250aHMYBSABKAVSC3RvdGFsTW9udGhzElAKEHJlcGF5bWVudF9tZXRob2QYBiAB'
    'KA4yJS5mYW1pbHlsZWRnZXIubG9hbi52MS5SZXBheW1lbnRNZXRob2RSD3JlcGF5bWVudE1ldG'
    'hvZBIfCgtwYXltZW50X2RheRgHIAEoBVIKcGF5bWVudERheRI5CgpzdGFydF9kYXRlGAggASgL'
    'MhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJc3RhcnREYXRlEh0KCmFjY291bnRfaWQYCS'
    'ABKAlSCWFjY291bnRJZBIbCglmYW1pbHlfaWQYCiABKAlSCGZhbWlseUlkEloKFGludGVyZXN0'
    'X2NhbGNfbWV0aG9kGAsgASgOMiguZmFtaWx5bGVkZ2VyLmxvYW4udjEuSW50ZXJlc3RDYWxjTW'
    'V0aG9kUhJpbnRlcmVzdENhbGNNZXRob2Q=');

@$core.Deprecated('Use getLoanRequestDescriptor instead')
const GetLoanRequest$json = {
  '1': 'GetLoanRequest',
  '2': [
    {'1': 'loan_id', '3': 1, '4': 1, '5': 9, '10': 'loanId'},
  ],
};

/// Descriptor for `GetLoanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLoanRequestDescriptor = $convert.base64Decode(
    'Cg5HZXRMb2FuUmVxdWVzdBIXCgdsb2FuX2lkGAEgASgJUgZsb2FuSWQ=');

@$core.Deprecated('Use listLoansRequestDescriptor instead')
const ListLoansRequest$json = {
  '1': 'ListLoansRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `ListLoansRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listLoansRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0TG9hbnNSZXF1ZXN0EhsKCWZhbWlseV9pZBgBIAEoCVIIZmFtaWx5SWQ=');

@$core.Deprecated('Use listLoansResponseDescriptor instead')
const ListLoansResponse$json = {
  '1': 'ListLoansResponse',
  '2': [
    {'1': 'loans', '3': 1, '4': 3, '5': 11, '6': '.familyledger.loan.v1.Loan', '10': 'loans'},
  ],
};

/// Descriptor for `ListLoansResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listLoansResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0TG9hbnNSZXNwb25zZRIwCgVsb2FucxgBIAMoCzIaLmZhbWlseWxlZGdlci5sb2FuLn'
    'YxLkxvYW5SBWxvYW5z');

@$core.Deprecated('Use updateLoanRequestDescriptor instead')
const UpdateLoanRequest$json = {
  '1': 'UpdateLoanRequest',
  '2': [
    {'1': 'loan_id', '3': 1, '4': 1, '5': 9, '10': 'loanId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'payment_day', '3': 3, '4': 1, '5': 5, '10': 'paymentDay'},
    {'1': 'account_id', '3': 4, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'repayment_category_id', '3': 5, '4': 1, '5': 9, '10': 'repaymentCategoryId'},
  ],
};

/// Descriptor for `UpdateLoanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateLoanRequestDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVMb2FuUmVxdWVzdBIXCgdsb2FuX2lkGAEgASgJUgZsb2FuSWQSEgoEbmFtZRgCIA'
    'EoCVIEbmFtZRIfCgtwYXltZW50X2RheRgDIAEoBVIKcGF5bWVudERheRIdCgphY2NvdW50X2lk'
    'GAQgASgJUglhY2NvdW50SWQSMgoVcmVwYXltZW50X2NhdGVnb3J5X2lkGAUgASgJUhNyZXBheW'
    '1lbnRDYXRlZ29yeUlk');

@$core.Deprecated('Use deleteLoanRequestDescriptor instead')
const DeleteLoanRequest$json = {
  '1': 'DeleteLoanRequest',
  '2': [
    {'1': 'loan_id', '3': 1, '4': 1, '5': 9, '10': 'loanId'},
  ],
};

/// Descriptor for `DeleteLoanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteLoanRequestDescriptor = $convert.base64Decode(
    'ChFEZWxldGVMb2FuUmVxdWVzdBIXCgdsb2FuX2lkGAEgASgJUgZsb2FuSWQ=');

@$core.Deprecated('Use getLoanScheduleRequestDescriptor instead')
const GetLoanScheduleRequest$json = {
  '1': 'GetLoanScheduleRequest',
  '2': [
    {'1': 'loan_id', '3': 1, '4': 1, '5': 9, '10': 'loanId'},
  ],
};

/// Descriptor for `GetLoanScheduleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLoanScheduleRequestDescriptor = $convert.base64Decode(
    'ChZHZXRMb2FuU2NoZWR1bGVSZXF1ZXN0EhcKB2xvYW5faWQYASABKAlSBmxvYW5JZA==');

@$core.Deprecated('Use loanScheduleResponseDescriptor instead')
const LoanScheduleResponse$json = {
  '1': 'LoanScheduleResponse',
  '2': [
    {'1': 'items', '3': 1, '4': 3, '5': 11, '6': '.familyledger.loan.v1.LoanScheduleItem', '10': 'items'},
  ],
};

/// Descriptor for `LoanScheduleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loanScheduleResponseDescriptor = $convert.base64Decode(
    'ChRMb2FuU2NoZWR1bGVSZXNwb25zZRI8CgVpdGVtcxgBIAMoCzImLmZhbWlseWxlZGdlci5sb2'
    'FuLnYxLkxvYW5TY2hlZHVsZUl0ZW1SBWl0ZW1z');

@$core.Deprecated('Use simulatePrepaymentRequestDescriptor instead')
const SimulatePrepaymentRequest$json = {
  '1': 'SimulatePrepaymentRequest',
  '2': [
    {'1': 'loan_id', '3': 1, '4': 1, '5': 9, '10': 'loanId'},
    {'1': 'prepayment_amount', '3': 2, '4': 1, '5': 3, '10': 'prepaymentAmount'},
    {'1': 'strategy', '3': 3, '4': 1, '5': 14, '6': '.familyledger.loan.v1.PrepaymentStrategy', '10': 'strategy'},
  ],
};

/// Descriptor for `SimulatePrepaymentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simulatePrepaymentRequestDescriptor = $convert.base64Decode(
    'ChlTaW11bGF0ZVByZXBheW1lbnRSZXF1ZXN0EhcKB2xvYW5faWQYASABKAlSBmxvYW5JZBIrCh'
    'FwcmVwYXltZW50X2Ftb3VudBgCIAEoA1IQcHJlcGF5bWVudEFtb3VudBJECghzdHJhdGVneRgD'
    'IAEoDjIoLmZhbWlseWxlZGdlci5sb2FuLnYxLlByZXBheW1lbnRTdHJhdGVneVIIc3RyYXRlZ3'
    'k=');

@$core.Deprecated('Use recordRateChangeRequestDescriptor instead')
const RecordRateChangeRequest$json = {
  '1': 'RecordRateChangeRequest',
  '2': [
    {'1': 'loan_id', '3': 1, '4': 1, '5': 9, '10': 'loanId'},
    {'1': 'new_rate', '3': 2, '4': 1, '5': 1, '10': 'newRate'},
    {'1': 'effective_date', '3': 3, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'effectiveDate'},
  ],
};

/// Descriptor for `RecordRateChangeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordRateChangeRequestDescriptor = $convert.base64Decode(
    'ChdSZWNvcmRSYXRlQ2hhbmdlUmVxdWVzdBIXCgdsb2FuX2lkGAEgASgJUgZsb2FuSWQSGQoIbm'
    'V3X3JhdGUYAiABKAFSB25ld1JhdGUSQQoOZWZmZWN0aXZlX2RhdGUYAyABKAsyGi5nb29nbGUu'
    'cHJvdG9idWYuVGltZXN0YW1wUg1lZmZlY3RpdmVEYXRl');

@$core.Deprecated('Use recordPaymentRequestDescriptor instead')
const RecordPaymentRequest$json = {
  '1': 'RecordPaymentRequest',
  '2': [
    {'1': 'loan_id', '3': 1, '4': 1, '5': 9, '10': 'loanId'},
    {'1': 'month_number', '3': 2, '4': 1, '5': 5, '10': 'monthNumber'},
  ],
};

/// Descriptor for `RecordPaymentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordPaymentRequestDescriptor = $convert.base64Decode(
    'ChRSZWNvcmRQYXltZW50UmVxdWVzdBIXCgdsb2FuX2lkGAEgASgJUgZsb2FuSWQSIQoMbW9udG'
    'hfbnVtYmVyGAIgASgFUgttb250aE51bWJlcg==');

@$core.Deprecated('Use loanGroupDescriptor instead')
const LoanGroup$json = {
  '1': 'LoanGroup',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'group_type', '3': 4, '4': 1, '5': 9, '10': 'groupType'},
    {'1': 'total_principal', '3': 5, '4': 1, '5': 3, '10': 'totalPrincipal'},
    {'1': 'payment_day', '3': 6, '4': 1, '5': 5, '10': 'paymentDay'},
    {'1': 'start_date', '3': 7, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'startDate'},
    {'1': 'account_id', '3': 8, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'sub_loans', '3': 9, '4': 3, '5': 11, '6': '.familyledger.loan.v1.Loan', '10': 'subLoans'},
    {'1': 'total_monthly_payment', '3': 10, '4': 1, '5': 3, '10': 'totalMonthlyPayment'},
    {'1': 'created_at', '3': 11, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
    {'1': 'updated_at', '3': 12, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedAt'},
    {'1': 'loan_type', '3': 13, '4': 1, '5': 14, '6': '.familyledger.loan.v1.LoanType', '10': 'loanType'},
    {'1': 'family_id', '3': 14, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'repayment_category_id', '3': 15, '4': 1, '5': 9, '10': 'repaymentCategoryId'},
  ],
};

/// Descriptor for `LoanGroup`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loanGroupDescriptor = $convert.base64Decode(
    'CglMb2FuR3JvdXASDgoCaWQYASABKAlSAmlkEhcKB3VzZXJfaWQYAiABKAlSBnVzZXJJZBISCg'
    'RuYW1lGAMgASgJUgRuYW1lEh0KCmdyb3VwX3R5cGUYBCABKAlSCWdyb3VwVHlwZRInCg90b3Rh'
    'bF9wcmluY2lwYWwYBSABKANSDnRvdGFsUHJpbmNpcGFsEh8KC3BheW1lbnRfZGF5GAYgASgFUg'
    'pwYXltZW50RGF5EjkKCnN0YXJ0X2RhdGUYByABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0'
    'YW1wUglzdGFydERhdGUSHQoKYWNjb3VudF9pZBgIIAEoCVIJYWNjb3VudElkEjcKCXN1Yl9sb2'
    'FucxgJIAMoCzIaLmZhbWlseWxlZGdlci5sb2FuLnYxLkxvYW5SCHN1YkxvYW5zEjIKFXRvdGFs'
    'X21vbnRobHlfcGF5bWVudBgKIAEoA1ITdG90YWxNb250aGx5UGF5bWVudBI5CgpjcmVhdGVkX2'
    'F0GAsgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRlZEF0EjkKCnVwZGF0'
    'ZWRfYXQYDCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgl1cGRhdGVkQXQSOwoJbG'
    '9hbl90eXBlGA0gASgOMh4uZmFtaWx5bGVkZ2VyLmxvYW4udjEuTG9hblR5cGVSCGxvYW5UeXBl'
    'EhsKCWZhbWlseV9pZBgOIAEoCVIIZmFtaWx5SWQSMgoVcmVwYXltZW50X2NhdGVnb3J5X2lkGA'
    '8gASgJUhNyZXBheW1lbnRDYXRlZ29yeUlk');

@$core.Deprecated('Use subLoanSpecDescriptor instead')
const SubLoanSpec$json = {
  '1': 'SubLoanSpec',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'sub_type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.loan.v1.LoanSubType', '10': 'subType'},
    {'1': 'principal', '3': 3, '4': 1, '5': 3, '10': 'principal'},
    {'1': 'annual_rate', '3': 4, '4': 1, '5': 1, '10': 'annualRate'},
    {'1': 'total_months', '3': 5, '4': 1, '5': 5, '10': 'totalMonths'},
    {'1': 'repayment_method', '3': 6, '4': 1, '5': 14, '6': '.familyledger.loan.v1.RepaymentMethod', '10': 'repaymentMethod'},
    {'1': 'rate_type', '3': 7, '4': 1, '5': 14, '6': '.familyledger.loan.v1.RateType', '10': 'rateType'},
    {'1': 'lpr_base', '3': 8, '4': 1, '5': 1, '10': 'lprBase'},
    {'1': 'lpr_spread', '3': 9, '4': 1, '5': 1, '10': 'lprSpread'},
    {'1': 'rate_adjust_month', '3': 10, '4': 1, '5': 5, '10': 'rateAdjustMonth'},
    {'1': 'interest_calc_method', '3': 11, '4': 1, '5': 14, '6': '.familyledger.loan.v1.InterestCalcMethod', '10': 'interestCalcMethod'},
  ],
};

/// Descriptor for `SubLoanSpec`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subLoanSpecDescriptor = $convert.base64Decode(
    'CgtTdWJMb2FuU3BlYxISCgRuYW1lGAEgASgJUgRuYW1lEjwKCHN1Yl90eXBlGAIgASgOMiEuZm'
    'FtaWx5bGVkZ2VyLmxvYW4udjEuTG9hblN1YlR5cGVSB3N1YlR5cGUSHAoJcHJpbmNpcGFsGAMg'
    'ASgDUglwcmluY2lwYWwSHwoLYW5udWFsX3JhdGUYBCABKAFSCmFubnVhbFJhdGUSIQoMdG90YW'
    'xfbW9udGhzGAUgASgFUgt0b3RhbE1vbnRocxJQChByZXBheW1lbnRfbWV0aG9kGAYgASgOMiUu'
    'ZmFtaWx5bGVkZ2VyLmxvYW4udjEuUmVwYXltZW50TWV0aG9kUg9yZXBheW1lbnRNZXRob2QSOw'
    'oJcmF0ZV90eXBlGAcgASgOMh4uZmFtaWx5bGVkZ2VyLmxvYW4udjEuUmF0ZVR5cGVSCHJhdGVU'
    'eXBlEhkKCGxwcl9iYXNlGAggASgBUgdscHJCYXNlEh0KCmxwcl9zcHJlYWQYCSABKAFSCWxwcl'
    'NwcmVhZBIqChFyYXRlX2FkanVzdF9tb250aBgKIAEoBVIPcmF0ZUFkanVzdE1vbnRoEloKFGlu'
    'dGVyZXN0X2NhbGNfbWV0aG9kGAsgASgOMiguZmFtaWx5bGVkZ2VyLmxvYW4udjEuSW50ZXJlc3'
    'RDYWxjTWV0aG9kUhJpbnRlcmVzdENhbGNNZXRob2Q=');

@$core.Deprecated('Use createLoanGroupRequestDescriptor instead')
const CreateLoanGroupRequest$json = {
  '1': 'CreateLoanGroupRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'group_type', '3': 2, '4': 1, '5': 9, '10': 'groupType'},
    {'1': 'payment_day', '3': 3, '4': 1, '5': 5, '10': 'paymentDay'},
    {'1': 'start_date', '3': 4, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'startDate'},
    {'1': 'account_id', '3': 5, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'sub_loans', '3': 6, '4': 3, '5': 11, '6': '.familyledger.loan.v1.SubLoanSpec', '10': 'subLoans'},
    {'1': 'loan_type', '3': 7, '4': 1, '5': 14, '6': '.familyledger.loan.v1.LoanType', '10': 'loanType'},
    {'1': 'family_id', '3': 8, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `CreateLoanGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createLoanGroupRequestDescriptor = $convert.base64Decode(
    'ChZDcmVhdGVMb2FuR3JvdXBSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSHQoKZ3JvdXBfdH'
    'lwZRgCIAEoCVIJZ3JvdXBUeXBlEh8KC3BheW1lbnRfZGF5GAMgASgFUgpwYXltZW50RGF5EjkK'
    'CnN0YXJ0X2RhdGUYBCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUglzdGFydERhdG'
    'USHQoKYWNjb3VudF9pZBgFIAEoCVIJYWNjb3VudElkEj4KCXN1Yl9sb2FucxgGIAMoCzIhLmZh'
    'bWlseWxlZGdlci5sb2FuLnYxLlN1YkxvYW5TcGVjUghzdWJMb2FucxI7Cglsb2FuX3R5cGUYBy'
    'ABKA4yHi5mYW1pbHlsZWRnZXIubG9hbi52MS5Mb2FuVHlwZVIIbG9hblR5cGUSGwoJZmFtaWx5'
    'X2lkGAggASgJUghmYW1pbHlJZA==');

@$core.Deprecated('Use getLoanGroupRequestDescriptor instead')
const GetLoanGroupRequest$json = {
  '1': 'GetLoanGroupRequest',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
  ],
};

/// Descriptor for `GetLoanGroupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLoanGroupRequestDescriptor = $convert.base64Decode(
    'ChNHZXRMb2FuR3JvdXBSZXF1ZXN0EhkKCGdyb3VwX2lkGAEgASgJUgdncm91cElk');

@$core.Deprecated('Use listLoanGroupsRequestDescriptor instead')
const ListLoanGroupsRequest$json = {
  '1': 'ListLoanGroupsRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `ListLoanGroupsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listLoanGroupsRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0TG9hbkdyb3Vwc1JlcXVlc3QSGwoJZmFtaWx5X2lkGAEgASgJUghmYW1pbHlJZA==');

@$core.Deprecated('Use listLoanGroupsResponseDescriptor instead')
const ListLoanGroupsResponse$json = {
  '1': 'ListLoanGroupsResponse',
  '2': [
    {'1': 'groups', '3': 1, '4': 3, '5': 11, '6': '.familyledger.loan.v1.LoanGroup', '10': 'groups'},
  ],
};

/// Descriptor for `ListLoanGroupsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listLoanGroupsResponseDescriptor = $convert.base64Decode(
    'ChZMaXN0TG9hbkdyb3Vwc1Jlc3BvbnNlEjcKBmdyb3VwcxgBIAMoCzIfLmZhbWlseWxlZGdlci'
    '5sb2FuLnYxLkxvYW5Hcm91cFIGZ3JvdXBz');

@$core.Deprecated('Use simulateGroupPrepaymentRequestDescriptor instead')
const SimulateGroupPrepaymentRequest$json = {
  '1': 'SimulateGroupPrepaymentRequest',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
    {'1': 'target_loan_id', '3': 2, '4': 1, '5': 9, '10': 'targetLoanId'},
    {'1': 'prepayment_amount', '3': 3, '4': 1, '5': 3, '10': 'prepaymentAmount'},
    {'1': 'strategy', '3': 4, '4': 1, '5': 14, '6': '.familyledger.loan.v1.PrepaymentStrategy', '10': 'strategy'},
  ],
};

/// Descriptor for `SimulateGroupPrepaymentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simulateGroupPrepaymentRequestDescriptor = $convert.base64Decode(
    'Ch5TaW11bGF0ZUdyb3VwUHJlcGF5bWVudFJlcXVlc3QSGQoIZ3JvdXBfaWQYASABKAlSB2dyb3'
    'VwSWQSJAoOdGFyZ2V0X2xvYW5faWQYAiABKAlSDHRhcmdldExvYW5JZBIrChFwcmVwYXltZW50'
    'X2Ftb3VudBgDIAEoA1IQcHJlcGF5bWVudEFtb3VudBJECghzdHJhdGVneRgEIAEoDjIoLmZhbW'
    'lseWxlZGdlci5sb2FuLnYxLlByZXBheW1lbnRTdHJhdGVneVIIc3RyYXRlZ3k=');

@$core.Deprecated('Use groupPrepaymentSimulationDescriptor instead')
const GroupPrepaymentSimulation$json = {
  '1': 'GroupPrepaymentSimulation',
  '2': [
    {'1': 'target_loan_id', '3': 1, '4': 1, '5': 9, '10': 'targetLoanId'},
    {'1': 'target_sim', '3': 2, '4': 1, '5': 11, '6': '.familyledger.loan.v1.PrepaymentSimulation', '10': 'targetSim'},
    {'1': 'total_interest_saved', '3': 3, '4': 1, '5': 3, '10': 'totalInterestSaved'},
  ],
};

/// Descriptor for `GroupPrepaymentSimulation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupPrepaymentSimulationDescriptor = $convert.base64Decode(
    'ChlHcm91cFByZXBheW1lbnRTaW11bGF0aW9uEiQKDnRhcmdldF9sb2FuX2lkGAEgASgJUgx0YX'
    'JnZXRMb2FuSWQSSQoKdGFyZ2V0X3NpbRgCIAEoCzIqLmZhbWlseWxlZGdlci5sb2FuLnYxLlBy'
    'ZXBheW1lbnRTaW11bGF0aW9uUgl0YXJnZXRTaW0SMAoUdG90YWxfaW50ZXJlc3Rfc2F2ZWQYAy'
    'ABKANSEnRvdGFsSW50ZXJlc3RTYXZlZA==');

@$core.Deprecated('Use executePrepaymentRequestDescriptor instead')
const ExecutePrepaymentRequest$json = {
  '1': 'ExecutePrepaymentRequest',
  '2': [
    {'1': 'loan_id', '3': 1, '4': 1, '5': 9, '10': 'loanId'},
    {'1': 'prepayment_amount', '3': 2, '4': 1, '5': 3, '10': 'prepaymentAmount'},
    {'1': 'strategy', '3': 3, '4': 1, '5': 14, '6': '.familyledger.loan.v1.PrepaymentStrategy', '10': 'strategy'},
  ],
};

/// Descriptor for `ExecutePrepaymentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List executePrepaymentRequestDescriptor = $convert.base64Decode(
    'ChhFeGVjdXRlUHJlcGF5bWVudFJlcXVlc3QSFwoHbG9hbl9pZBgBIAEoCVIGbG9hbklkEisKEX'
    'ByZXBheW1lbnRfYW1vdW50GAIgASgDUhBwcmVwYXltZW50QW1vdW50EkQKCHN0cmF0ZWd5GAMg'
    'ASgOMiguZmFtaWx5bGVkZ2VyLmxvYW4udjEuUHJlcGF5bWVudFN0cmF0ZWd5UghzdHJhdGVneQ'
    '==');

@$core.Deprecated('Use executePrepaymentResponseDescriptor instead')
const ExecutePrepaymentResponse$json = {
  '1': 'ExecutePrepaymentResponse',
  '2': [
    {'1': 'loan', '3': 1, '4': 1, '5': 11, '6': '.familyledger.loan.v1.Loan', '10': 'loan'},
    {'1': 'simulation', '3': 2, '4': 1, '5': 11, '6': '.familyledger.loan.v1.PrepaymentSimulation', '10': 'simulation'},
    {'1': 'new_schedule', '3': 3, '4': 3, '5': 11, '6': '.familyledger.loan.v1.LoanScheduleItem', '10': 'newSchedule'},
  ],
};

/// Descriptor for `ExecutePrepaymentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List executePrepaymentResponseDescriptor = $convert.base64Decode(
    'ChlFeGVjdXRlUHJlcGF5bWVudFJlc3BvbnNlEi4KBGxvYW4YASABKAsyGi5mYW1pbHlsZWRnZX'
    'IubG9hbi52MS5Mb2FuUgRsb2FuEkoKCnNpbXVsYXRpb24YAiABKAsyKi5mYW1pbHlsZWRnZXIu'
    'bG9hbi52MS5QcmVwYXltZW50U2ltdWxhdGlvblIKc2ltdWxhdGlvbhJJCgxuZXdfc2NoZWR1bG'
    'UYAyADKAsyJi5mYW1pbHlsZWRnZXIubG9hbi52MS5Mb2FuU2NoZWR1bGVJdGVtUgtuZXdTY2hl'
    'ZHVsZQ==');

@$core.Deprecated('Use executeGroupPrepaymentRequestDescriptor instead')
const ExecuteGroupPrepaymentRequest$json = {
  '1': 'ExecuteGroupPrepaymentRequest',
  '2': [
    {'1': 'group_id', '3': 1, '4': 1, '5': 9, '10': 'groupId'},
    {'1': 'target_loan_id', '3': 2, '4': 1, '5': 9, '10': 'targetLoanId'},
    {'1': 'prepayment_amount', '3': 3, '4': 1, '5': 3, '10': 'prepaymentAmount'},
    {'1': 'strategy', '3': 4, '4': 1, '5': 14, '6': '.familyledger.loan.v1.PrepaymentStrategy', '10': 'strategy'},
  ],
};

/// Descriptor for `ExecuteGroupPrepaymentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List executeGroupPrepaymentRequestDescriptor = $convert.base64Decode(
    'Ch1FeGVjdXRlR3JvdXBQcmVwYXltZW50UmVxdWVzdBIZCghncm91cF9pZBgBIAEoCVIHZ3JvdX'
    'BJZBIkCg50YXJnZXRfbG9hbl9pZBgCIAEoCVIMdGFyZ2V0TG9hbklkEisKEXByZXBheW1lbnRf'
    'YW1vdW50GAMgASgDUhBwcmVwYXltZW50QW1vdW50EkQKCHN0cmF0ZWd5GAQgASgOMiguZmFtaW'
    'x5bGVkZ2VyLmxvYW4udjEuUHJlcGF5bWVudFN0cmF0ZWd5UghzdHJhdGVneQ==');

@$core.Deprecated('Use executeGroupPrepaymentResponseDescriptor instead')
const ExecuteGroupPrepaymentResponse$json = {
  '1': 'ExecuteGroupPrepaymentResponse',
  '2': [
    {'1': 'target_loan_id', '3': 1, '4': 1, '5': 9, '10': 'targetLoanId'},
    {'1': 'loan', '3': 2, '4': 1, '5': 11, '6': '.familyledger.loan.v1.Loan', '10': 'loan'},
    {'1': 'simulation', '3': 3, '4': 1, '5': 11, '6': '.familyledger.loan.v1.PrepaymentSimulation', '10': 'simulation'},
    {'1': 'new_schedule', '3': 4, '4': 3, '5': 11, '6': '.familyledger.loan.v1.LoanScheduleItem', '10': 'newSchedule'},
  ],
};

/// Descriptor for `ExecuteGroupPrepaymentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List executeGroupPrepaymentResponseDescriptor = $convert.base64Decode(
    'Ch5FeGVjdXRlR3JvdXBQcmVwYXltZW50UmVzcG9uc2USJAoOdGFyZ2V0X2xvYW5faWQYASABKA'
    'lSDHRhcmdldExvYW5JZBIuCgRsb2FuGAIgASgLMhouZmFtaWx5bGVkZ2VyLmxvYW4udjEuTG9h'
    'blIEbG9hbhJKCgpzaW11bGF0aW9uGAMgASgLMiouZmFtaWx5bGVkZ2VyLmxvYW4udjEuUHJlcG'
    'F5bWVudFNpbXVsYXRpb25SCnNpbXVsYXRpb24SSQoMbmV3X3NjaGVkdWxlGAQgAygLMiYuZmFt'
    'aWx5bGVkZ2VyLmxvYW4udjEuTG9hblNjaGVkdWxlSXRlbVILbmV3U2NoZWR1bGU=');

