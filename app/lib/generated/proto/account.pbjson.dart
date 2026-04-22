//
//  Generated code. Do not modify.
//  source: account.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use accountTypeDescriptor instead')
const AccountType$json = {
  '1': 'AccountType',
  '2': [
    {'1': 'ACCOUNT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ACCOUNT_TYPE_CASH', '2': 1},
    {'1': 'ACCOUNT_TYPE_BANK_CARD', '2': 2},
    {'1': 'ACCOUNT_TYPE_CREDIT_CARD', '2': 3},
    {'1': 'ACCOUNT_TYPE_ALIPAY', '2': 4},
    {'1': 'ACCOUNT_TYPE_WECHAT_PAY', '2': 5},
    {'1': 'ACCOUNT_TYPE_INVESTMENT', '2': 6},
    {'1': 'ACCOUNT_TYPE_OTHER', '2': 7},
  ],
};

/// Descriptor for `AccountType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accountTypeDescriptor = $convert.base64Decode(
    'CgtBY2NvdW50VHlwZRIcChhBQ0NPVU5UX1RZUEVfVU5TUEVDSUZJRUQQABIVChFBQ0NPVU5UX1'
    'RZUEVfQ0FTSBABEhoKFkFDQ09VTlRfVFlQRV9CQU5LX0NBUkQQAhIcChhBQ0NPVU5UX1RZUEVf'
    'Q1JFRElUX0NBUkQQAxIXChNBQ0NPVU5UX1RZUEVfQUxJUEFZEAQSGwoXQUNDT1VOVF9UWVBFX1'
    'dFQ0hBVF9QQVkQBRIbChdBQ0NPVU5UX1RZUEVfSU5WRVNUTUVOVBAGEhYKEkFDQ09VTlRfVFlQ'
    'RV9PVEhFUhAH');

@$core.Deprecated('Use accountDescriptor instead')
const Account$json = {
  '1': 'Account',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'family_id', '3': 3, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type', '3': 5, '4': 1, '5': 14, '6': '.familyledger.account.v1.AccountType', '10': 'type'},
    {'1': 'currency', '3': 6, '4': 1, '5': 9, '10': 'currency'},
    {'1': 'icon', '3': 7, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'balance', '3': 8, '4': 1, '5': 3, '10': 'balance'},
    {'1': 'is_active', '3': 9, '4': 1, '5': 8, '10': 'isActive'},
    {'1': 'is_default', '3': 10, '4': 1, '5': 8, '10': 'isDefault'},
    {'1': 'created_at', '3': 11, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
    {'1': 'updated_at', '3': 12, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedAt'},
  ],
};

/// Descriptor for `Account`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accountDescriptor = $convert.base64Decode(
    'CgdBY2NvdW50Eg4KAmlkGAEgASgJUgJpZBIXCgd1c2VyX2lkGAIgASgJUgZ1c2VySWQSGwoJZm'
    'FtaWx5X2lkGAMgASgJUghmYW1pbHlJZBISCgRuYW1lGAQgASgJUgRuYW1lEjgKBHR5cGUYBSAB'
    'KA4yJC5mYW1pbHlsZWRnZXIuYWNjb3VudC52MS5BY2NvdW50VHlwZVIEdHlwZRIaCghjdXJyZW'
    '5jeRgGIAEoCVIIY3VycmVuY3kSEgoEaWNvbhgHIAEoCVIEaWNvbhIYCgdiYWxhbmNlGAggASgD'
    'UgdiYWxhbmNlEhsKCWlzX2FjdGl2ZRgJIAEoCFIIaXNBY3RpdmUSHQoKaXNfZGVmYXVsdBgKIA'
    'EoCFIJaXNEZWZhdWx0EjkKCmNyZWF0ZWRfYXQYCyABKAsyGi5nb29nbGUucHJvdG9idWYuVGlt'
    'ZXN0YW1wUgljcmVhdGVkQXQSOQoKdXBkYXRlZF9hdBgMIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi'
    '5UaW1lc3RhbXBSCXVwZGF0ZWRBdA==');

@$core.Deprecated('Use transferDescriptor instead')
const Transfer$json = {
  '1': 'Transfer',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'from_account_id', '3': 3, '4': 1, '5': 9, '10': 'fromAccountId'},
    {'1': 'to_account_id', '3': 4, '4': 1, '5': 9, '10': 'toAccountId'},
    {'1': 'amount', '3': 5, '4': 1, '5': 3, '10': 'amount'},
    {'1': 'note', '3': 6, '4': 1, '5': 9, '10': 'note'},
    {'1': 'created_at', '3': 7, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
  ],
};

/// Descriptor for `Transfer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferDescriptor = $convert.base64Decode(
    'CghUcmFuc2ZlchIOCgJpZBgBIAEoCVICaWQSFwoHdXNlcl9pZBgCIAEoCVIGdXNlcklkEiYKD2'
    'Zyb21fYWNjb3VudF9pZBgDIAEoCVINZnJvbUFjY291bnRJZBIiCg10b19hY2NvdW50X2lkGAQg'
    'ASgJUgt0b0FjY291bnRJZBIWCgZhbW91bnQYBSABKANSBmFtb3VudBISCgRub3RlGAYgASgJUg'
    'Rub3RlEjkKCmNyZWF0ZWRfYXQYByABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUglj'
    'cmVhdGVkQXQ=');

@$core.Deprecated('Use createAccountRequestDescriptor instead')
const CreateAccountRequest$json = {
  '1': 'CreateAccountRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type', '3': 2, '4': 1, '5': 14, '6': '.familyledger.account.v1.AccountType', '10': 'type'},
    {'1': 'currency', '3': 3, '4': 1, '5': 9, '10': 'currency'},
    {'1': 'icon', '3': 4, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'initial_balance', '3': 5, '4': 1, '5': 3, '10': 'initialBalance'},
    {'1': 'family_id', '3': 6, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `CreateAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAccountRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVBY2NvdW50UmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEjgKBHR5cGUYAiABKA'
    '4yJC5mYW1pbHlsZWRnZXIuYWNjb3VudC52MS5BY2NvdW50VHlwZVIEdHlwZRIaCghjdXJyZW5j'
    'eRgDIAEoCVIIY3VycmVuY3kSEgoEaWNvbhgEIAEoCVIEaWNvbhInCg9pbml0aWFsX2JhbGFuY2'
    'UYBSABKANSDmluaXRpYWxCYWxhbmNlEhsKCWZhbWlseV9pZBgGIAEoCVIIZmFtaWx5SWQ=');

@$core.Deprecated('Use createAccountResponseDescriptor instead')
const CreateAccountResponse$json = {
  '1': 'CreateAccountResponse',
  '2': [
    {'1': 'account', '3': 1, '4': 1, '5': 11, '6': '.familyledger.account.v1.Account', '10': 'account'},
  ],
};

/// Descriptor for `CreateAccountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAccountResponseDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVBY2NvdW50UmVzcG9uc2USOgoHYWNjb3VudBgBIAEoCzIgLmZhbWlseWxlZGdlci'
    '5hY2NvdW50LnYxLkFjY291bnRSB2FjY291bnQ=');

@$core.Deprecated('Use listAccountsRequestDescriptor instead')
const ListAccountsRequest$json = {
  '1': 'ListAccountsRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'include_inactive', '3': 2, '4': 1, '5': 8, '10': 'includeInactive'},
  ],
};

/// Descriptor for `ListAccountsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAccountsRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0QWNjb3VudHNSZXF1ZXN0EhsKCWZhbWlseV9pZBgBIAEoCVIIZmFtaWx5SWQSKQoQaW'
    '5jbHVkZV9pbmFjdGl2ZRgCIAEoCFIPaW5jbHVkZUluYWN0aXZl');

@$core.Deprecated('Use listAccountsResponseDescriptor instead')
const ListAccountsResponse$json = {
  '1': 'ListAccountsResponse',
  '2': [
    {'1': 'accounts', '3': 1, '4': 3, '5': 11, '6': '.familyledger.account.v1.Account', '10': 'accounts'},
  ],
};

/// Descriptor for `ListAccountsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAccountsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0QWNjb3VudHNSZXNwb25zZRI8CghhY2NvdW50cxgBIAMoCzIgLmZhbWlseWxlZGdlci'
    '5hY2NvdW50LnYxLkFjY291bnRSCGFjY291bnRz');

@$core.Deprecated('Use getAccountRequestDescriptor instead')
const GetAccountRequest$json = {
  '1': 'GetAccountRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
  ],
};

/// Descriptor for `GetAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAccountRequestDescriptor = $convert.base64Decode(
    'ChFHZXRBY2NvdW50UmVxdWVzdBIdCgphY2NvdW50X2lkGAEgASgJUglhY2NvdW50SWQ=');

@$core.Deprecated('Use getAccountResponseDescriptor instead')
const GetAccountResponse$json = {
  '1': 'GetAccountResponse',
  '2': [
    {'1': 'account', '3': 1, '4': 1, '5': 11, '6': '.familyledger.account.v1.Account', '10': 'account'},
  ],
};

/// Descriptor for `GetAccountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAccountResponseDescriptor = $convert.base64Decode(
    'ChJHZXRBY2NvdW50UmVzcG9uc2USOgoHYWNjb3VudBgBIAEoCzIgLmZhbWlseWxlZGdlci5hY2'
    'NvdW50LnYxLkFjY291bnRSB2FjY291bnQ=');

@$core.Deprecated('Use updateAccountRequestDescriptor instead')
const UpdateAccountRequest$json = {
  '1': 'UpdateAccountRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'icon', '17': true},
    {'1': 'is_active', '3': 4, '4': 1, '5': 8, '9': 2, '10': 'isActive', '17': true},
  ],
  '8': [
    {'1': '_name'},
    {'1': '_icon'},
    {'1': '_is_active'},
  ],
};

/// Descriptor for `UpdateAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateAccountRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVBY2NvdW50UmVxdWVzdBIdCgphY2NvdW50X2lkGAEgASgJUglhY2NvdW50SWQSFw'
    'oEbmFtZRgCIAEoCUgAUgRuYW1liAEBEhcKBGljb24YAyABKAlIAVIEaWNvbogBARIgCglpc19h'
    'Y3RpdmUYBCABKAhIAlIIaXNBY3RpdmWIAQFCBwoFX25hbWVCBwoFX2ljb25CDAoKX2lzX2FjdG'
    'l2ZQ==');

@$core.Deprecated('Use updateAccountResponseDescriptor instead')
const UpdateAccountResponse$json = {
  '1': 'UpdateAccountResponse',
  '2': [
    {'1': 'account', '3': 1, '4': 1, '5': 11, '6': '.familyledger.account.v1.Account', '10': 'account'},
  ],
};

/// Descriptor for `UpdateAccountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateAccountResponseDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVBY2NvdW50UmVzcG9uc2USOgoHYWNjb3VudBgBIAEoCzIgLmZhbWlseWxlZGdlci'
    '5hY2NvdW50LnYxLkFjY291bnRSB2FjY291bnQ=');

@$core.Deprecated('Use deleteAccountRequestDescriptor instead')
const DeleteAccountRequest$json = {
  '1': 'DeleteAccountRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
  ],
};

/// Descriptor for `DeleteAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAccountRequestDescriptor = $convert.base64Decode(
    'ChREZWxldGVBY2NvdW50UmVxdWVzdBIdCgphY2NvdW50X2lkGAEgASgJUglhY2NvdW50SWQ=');

@$core.Deprecated('Use deleteAccountResponseDescriptor instead')
const DeleteAccountResponse$json = {
  '1': 'DeleteAccountResponse',
};

/// Descriptor for `DeleteAccountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAccountResponseDescriptor = $convert.base64Decode(
    'ChVEZWxldGVBY2NvdW50UmVzcG9uc2U=');

@$core.Deprecated('Use transferBetweenRequestDescriptor instead')
const TransferBetweenRequest$json = {
  '1': 'TransferBetweenRequest',
  '2': [
    {'1': 'from_account_id', '3': 1, '4': 1, '5': 9, '10': 'fromAccountId'},
    {'1': 'to_account_id', '3': 2, '4': 1, '5': 9, '10': 'toAccountId'},
    {'1': 'amount', '3': 3, '4': 1, '5': 3, '10': 'amount'},
    {'1': 'note', '3': 4, '4': 1, '5': 9, '10': 'note'},
  ],
};

/// Descriptor for `TransferBetweenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferBetweenRequestDescriptor = $convert.base64Decode(
    'ChZUcmFuc2ZlckJldHdlZW5SZXF1ZXN0EiYKD2Zyb21fYWNjb3VudF9pZBgBIAEoCVINZnJvbU'
    'FjY291bnRJZBIiCg10b19hY2NvdW50X2lkGAIgASgJUgt0b0FjY291bnRJZBIWCgZhbW91bnQY'
    'AyABKANSBmFtb3VudBISCgRub3RlGAQgASgJUgRub3Rl');

@$core.Deprecated('Use transferBetweenResponseDescriptor instead')
const TransferBetweenResponse$json = {
  '1': 'TransferBetweenResponse',
  '2': [
    {'1': 'transfer', '3': 1, '4': 1, '5': 11, '6': '.familyledger.account.v1.Transfer', '10': 'transfer'},
  ],
};

/// Descriptor for `TransferBetweenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transferBetweenResponseDescriptor = $convert.base64Decode(
    'ChdUcmFuc2ZlckJldHdlZW5SZXNwb25zZRI9Cgh0cmFuc2ZlchgBIAEoCzIhLmZhbWlseWxlZG'
    'dlci5hY2NvdW50LnYxLlRyYW5zZmVyUgh0cmFuc2Zlcg==');

