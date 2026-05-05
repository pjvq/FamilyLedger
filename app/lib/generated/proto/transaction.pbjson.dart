//
//  Generated code. Do not modify.
//  source: transaction.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use transactionTypeDescriptor instead')
const TransactionType$json = {
  '1': 'TransactionType',
  '2': [
    {'1': 'TRANSACTION_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'TRANSACTION_TYPE_INCOME', '2': 1},
    {'1': 'TRANSACTION_TYPE_EXPENSE', '2': 2},
  ],
};

/// Descriptor for `TransactionType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List transactionTypeDescriptor = $convert.base64Decode(
    'Cg9UcmFuc2FjdGlvblR5cGUSIAocVFJBTlNBQ1RJT05fVFlQRV9VTlNQRUNJRklFRBAAEhsKF1'
    'RSQU5TQUNUSU9OX1RZUEVfSU5DT01FEAESHAoYVFJBTlNBQ1RJT05fVFlQRV9FWFBFTlNFEAI=');

@$core.Deprecated('Use transactionDescriptor instead')
const Transaction$json = {
  '1': 'Transaction',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'account_id', '3': 3, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'category_id', '3': 4, '4': 1, '5': 9, '10': 'categoryId'},
    {'1': 'amount', '3': 5, '4': 1, '5': 3, '10': 'amount'},
    {'1': 'currency', '3': 6, '4': 1, '5': 9, '10': 'currency'},
    {'1': 'amount_cny', '3': 7, '4': 1, '5': 3, '10': 'amountCny'},
    {'1': 'exchange_rate', '3': 8, '4': 1, '5': 1, '10': 'exchangeRate'},
    {'1': 'type', '3': 9, '4': 1, '5': 14, '6': '.familyledger.transaction.v1.TransactionType', '10': 'type'},
    {'1': 'note', '3': 10, '4': 1, '5': 9, '10': 'note'},
    {'1': 'txn_date', '3': 11, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'txnDate'},
    {'1': 'created_at', '3': 12, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
    {'1': 'updated_at', '3': 13, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedAt'},
    {'1': 'tags', '3': 14, '4': 3, '5': 9, '10': 'tags'},
    {'1': 'image_urls', '3': 15, '4': 3, '5': 9, '10': 'imageUrls'},
    {'1': 'deleted_at', '3': 16, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'deletedAt'},
  ],
};

/// Descriptor for `Transaction`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionDescriptor = $convert.base64Decode(
    'CgtUcmFuc2FjdGlvbhIOCgJpZBgBIAEoCVICaWQSFwoHdXNlcl9pZBgCIAEoCVIGdXNlcklkEh'
    '0KCmFjY291bnRfaWQYAyABKAlSCWFjY291bnRJZBIfCgtjYXRlZ29yeV9pZBgEIAEoCVIKY2F0'
    'ZWdvcnlJZBIWCgZhbW91bnQYBSABKANSBmFtb3VudBIaCghjdXJyZW5jeRgGIAEoCVIIY3Vycm'
    'VuY3kSHQoKYW1vdW50X2NueRgHIAEoA1IJYW1vdW50Q255EiMKDWV4Y2hhbmdlX3JhdGUYCCAB'
    'KAFSDGV4Y2hhbmdlUmF0ZRJACgR0eXBlGAkgASgOMiwuZmFtaWx5bGVkZ2VyLnRyYW5zYWN0aW'
    '9uLnYxLlRyYW5zYWN0aW9uVHlwZVIEdHlwZRISCgRub3RlGAogASgJUgRub3RlEjUKCHR4bl9k'
    'YXRlGAsgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIHdHhuRGF0ZRI5CgpjcmVhdG'
    'VkX2F0GAwgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRlZEF0EjkKCnVw'
    'ZGF0ZWRfYXQYDSABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgl1cGRhdGVkQXQSEg'
    'oEdGFncxgOIAMoCVIEdGFncxIdCgppbWFnZV91cmxzGA8gAygJUglpbWFnZVVybHMSOQoKZGVs'
    'ZXRlZF9hdBgQIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWRlbGV0ZWRBdA==');

@$core.Deprecated('Use categoryDescriptor instead')
const Category$json = {
  '1': 'Category',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'type', '3': 4, '4': 1, '5': 14, '6': '.familyledger.transaction.v1.TransactionType', '10': 'type'},
    {'1': 'is_preset', '3': 5, '4': 1, '5': 8, '10': 'isPreset'},
    {'1': 'sort_order', '3': 6, '4': 1, '5': 5, '10': 'sortOrder'},
    {'1': 'parent_id', '3': 7, '4': 1, '5': 9, '10': 'parentId'},
    {'1': 'icon_key', '3': 8, '4': 1, '5': 9, '10': 'iconKey'},
    {'1': 'children', '3': 9, '4': 3, '5': 11, '6': '.familyledger.transaction.v1.Category', '10': 'children'},
  ],
};

/// Descriptor for `Category`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryDescriptor = $convert.base64Decode(
    'CghDYXRlZ29yeRIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRISCgRpY29uGA'
    'MgASgJUgRpY29uEkAKBHR5cGUYBCABKA4yLC5mYW1pbHlsZWRnZXIudHJhbnNhY3Rpb24udjEu'
    'VHJhbnNhY3Rpb25UeXBlUgR0eXBlEhsKCWlzX3ByZXNldBgFIAEoCFIIaXNQcmVzZXQSHQoKc2'
    '9ydF9vcmRlchgGIAEoBVIJc29ydE9yZGVyEhsKCXBhcmVudF9pZBgHIAEoCVIIcGFyZW50SWQS'
    'GQoIaWNvbl9rZXkYCCABKAlSB2ljb25LZXkSQQoIY2hpbGRyZW4YCSADKAsyJS5mYW1pbHlsZW'
    'RnZXIudHJhbnNhY3Rpb24udjEuQ2F0ZWdvcnlSCGNoaWxkcmVu');

@$core.Deprecated('Use createTransactionRequestDescriptor instead')
const CreateTransactionRequest$json = {
  '1': 'CreateTransactionRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'category_id', '3': 2, '4': 1, '5': 9, '10': 'categoryId'},
    {'1': 'amount', '3': 3, '4': 1, '5': 3, '10': 'amount'},
    {'1': 'currency', '3': 4, '4': 1, '5': 9, '10': 'currency'},
    {'1': 'amount_cny', '3': 5, '4': 1, '5': 3, '10': 'amountCny'},
    {'1': 'exchange_rate', '3': 6, '4': 1, '5': 1, '10': 'exchangeRate'},
    {'1': 'type', '3': 7, '4': 1, '5': 14, '6': '.familyledger.transaction.v1.TransactionType', '10': 'type'},
    {'1': 'note', '3': 8, '4': 1, '5': 9, '10': 'note'},
    {'1': 'txn_date', '3': 9, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'txnDate'},
    {'1': 'tags', '3': 10, '4': 3, '5': 9, '10': 'tags'},
    {'1': 'image_urls', '3': 11, '4': 3, '5': 9, '10': 'imageUrls'},
  ],
};

/// Descriptor for `CreateTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTransactionRequestDescriptor = $convert.base64Decode(
    'ChhDcmVhdGVUcmFuc2FjdGlvblJlcXVlc3QSHQoKYWNjb3VudF9pZBgBIAEoCVIJYWNjb3VudE'
    'lkEh8KC2NhdGVnb3J5X2lkGAIgASgJUgpjYXRlZ29yeUlkEhYKBmFtb3VudBgDIAEoA1IGYW1v'
    'dW50EhoKCGN1cnJlbmN5GAQgASgJUghjdXJyZW5jeRIdCgphbW91bnRfY255GAUgASgDUglhbW'
    '91bnRDbnkSIwoNZXhjaGFuZ2VfcmF0ZRgGIAEoAVIMZXhjaGFuZ2VSYXRlEkAKBHR5cGUYByAB'
    'KA4yLC5mYW1pbHlsZWRnZXIudHJhbnNhY3Rpb24udjEuVHJhbnNhY3Rpb25UeXBlUgR0eXBlEh'
    'IKBG5vdGUYCCABKAlSBG5vdGUSNQoIdHhuX2RhdGUYCSABKAsyGi5nb29nbGUucHJvdG9idWYu'
    'VGltZXN0YW1wUgd0eG5EYXRlEhIKBHRhZ3MYCiADKAlSBHRhZ3MSHQoKaW1hZ2VfdXJscxgLIA'
    'MoCVIJaW1hZ2VVcmxz');

@$core.Deprecated('Use createTransactionResponseDescriptor instead')
const CreateTransactionResponse$json = {
  '1': 'CreateTransactionResponse',
  '2': [
    {'1': 'transaction', '3': 1, '4': 1, '5': 11, '6': '.familyledger.transaction.v1.Transaction', '10': 'transaction'},
  ],
};

/// Descriptor for `CreateTransactionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTransactionResponseDescriptor = $convert.base64Decode(
    'ChlDcmVhdGVUcmFuc2FjdGlvblJlc3BvbnNlEkoKC3RyYW5zYWN0aW9uGAEgASgLMiguZmFtaW'
    'x5bGVkZ2VyLnRyYW5zYWN0aW9uLnYxLlRyYW5zYWN0aW9uUgt0cmFuc2FjdGlvbg==');

@$core.Deprecated('Use listTransactionsRequestDescriptor instead')
const ListTransactionsRequest$json = {
  '1': 'ListTransactionsRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'start_date', '3': 2, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'startDate'},
    {'1': 'end_date', '3': 3, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'endDate'},
    {'1': 'page_size', '3': 4, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 5, '4': 1, '5': 9, '10': 'pageToken'},
    {'1': 'family_id', '3': 6, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'updated_since', '3': 7, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'updatedSince'},
    {'1': 'include_deleted', '3': 8, '4': 1, '5': 8, '10': 'includeDeleted'},
  ],
};

/// Descriptor for `ListTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTransactionsRequestDescriptor = $convert.base64Decode(
    'ChdMaXN0VHJhbnNhY3Rpb25zUmVxdWVzdBIdCgphY2NvdW50X2lkGAEgASgJUglhY2NvdW50SW'
    'QSOQoKc3RhcnRfZGF0ZRgCIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCXN0YXJ0'
    'RGF0ZRI1CghlbmRfZGF0ZRgDIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSB2VuZE'
    'RhdGUSGwoJcGFnZV9zaXplGAQgASgFUghwYWdlU2l6ZRIdCgpwYWdlX3Rva2VuGAUgASgJUglw'
    'YWdlVG9rZW4SGwoJZmFtaWx5X2lkGAYgASgJUghmYW1pbHlJZBI/Cg11cGRhdGVkX3NpbmNlGA'
    'cgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIMdXBkYXRlZFNpbmNlEicKD2luY2x1'
    'ZGVfZGVsZXRlZBgIIAEoCFIOaW5jbHVkZURlbGV0ZWQ=');

@$core.Deprecated('Use listTransactionsResponseDescriptor instead')
const ListTransactionsResponse$json = {
  '1': 'ListTransactionsResponse',
  '2': [
    {'1': 'transactions', '3': 1, '4': 3, '5': 11, '6': '.familyledger.transaction.v1.Transaction', '10': 'transactions'},
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
    {'1': 'total_count', '3': 3, '4': 1, '5': 5, '10': 'totalCount'},
  ],
};

/// Descriptor for `ListTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTransactionsResponseDescriptor = $convert.base64Decode(
    'ChhMaXN0VHJhbnNhY3Rpb25zUmVzcG9uc2USTAoMdHJhbnNhY3Rpb25zGAEgAygLMiguZmFtaW'
    'x5bGVkZ2VyLnRyYW5zYWN0aW9uLnYxLlRyYW5zYWN0aW9uUgx0cmFuc2FjdGlvbnMSJgoPbmV4'
    'dF9wYWdlX3Rva2VuGAIgASgJUg1uZXh0UGFnZVRva2VuEh8KC3RvdGFsX2NvdW50GAMgASgFUg'
    'p0b3RhbENvdW50');

@$core.Deprecated('Use updateTransactionRequestDescriptor instead')
const UpdateTransactionRequest$json = {
  '1': 'UpdateTransactionRequest',
  '2': [
    {'1': 'transaction_id', '3': 1, '4': 1, '5': 9, '10': 'transactionId'},
    {'1': 'amount', '3': 2, '4': 1, '5': 3, '9': 0, '10': 'amount', '17': true},
    {'1': 'category_id', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'categoryId', '17': true},
    {'1': 'note', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'note', '17': true},
    {'1': 'tags', '3': 5, '4': 1, '5': 9, '9': 3, '10': 'tags', '17': true},
    {'1': 'type', '3': 6, '4': 1, '5': 14, '6': '.familyledger.transaction.v1.TransactionType', '9': 4, '10': 'type', '17': true},
    {'1': 'currency', '3': 7, '4': 1, '5': 9, '9': 5, '10': 'currency', '17': true},
  ],
  '8': [
    {'1': '_amount'},
    {'1': '_category_id'},
    {'1': '_note'},
    {'1': '_tags'},
    {'1': '_type'},
    {'1': '_currency'},
  ],
};

/// Descriptor for `UpdateTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTransactionRequestDescriptor = $convert.base64Decode(
    'ChhVcGRhdGVUcmFuc2FjdGlvblJlcXVlc3QSJQoOdHJhbnNhY3Rpb25faWQYASABKAlSDXRyYW'
    '5zYWN0aW9uSWQSGwoGYW1vdW50GAIgASgDSABSBmFtb3VudIgBARIkCgtjYXRlZ29yeV9pZBgD'
    'IAEoCUgBUgpjYXRlZ29yeUlkiAEBEhcKBG5vdGUYBCABKAlIAlIEbm90ZYgBARIXCgR0YWdzGA'
    'UgASgJSANSBHRhZ3OIAQESRQoEdHlwZRgGIAEoDjIsLmZhbWlseWxlZGdlci50cmFuc2FjdGlv'
    'bi52MS5UcmFuc2FjdGlvblR5cGVIBFIEdHlwZYgBARIfCghjdXJyZW5jeRgHIAEoCUgFUghjdX'
    'JyZW5jeYgBAUIJCgdfYW1vdW50Qg4KDF9jYXRlZ29yeV9pZEIHCgVfbm90ZUIHCgVfdGFnc0IH'
    'CgVfdHlwZUILCglfY3VycmVuY3k=');

@$core.Deprecated('Use updateTransactionResponseDescriptor instead')
const UpdateTransactionResponse$json = {
  '1': 'UpdateTransactionResponse',
  '2': [
    {'1': 'transaction', '3': 1, '4': 1, '5': 11, '6': '.familyledger.transaction.v1.Transaction', '10': 'transaction'},
  ],
};

/// Descriptor for `UpdateTransactionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTransactionResponseDescriptor = $convert.base64Decode(
    'ChlVcGRhdGVUcmFuc2FjdGlvblJlc3BvbnNlEkoKC3RyYW5zYWN0aW9uGAEgASgLMiguZmFtaW'
    'x5bGVkZ2VyLnRyYW5zYWN0aW9uLnYxLlRyYW5zYWN0aW9uUgt0cmFuc2FjdGlvbg==');

@$core.Deprecated('Use deleteTransactionRequestDescriptor instead')
const DeleteTransactionRequest$json = {
  '1': 'DeleteTransactionRequest',
  '2': [
    {'1': 'transaction_id', '3': 1, '4': 1, '5': 9, '10': 'transactionId'},
  ],
};

/// Descriptor for `DeleteTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTransactionRequestDescriptor = $convert.base64Decode(
    'ChhEZWxldGVUcmFuc2FjdGlvblJlcXVlc3QSJQoOdHJhbnNhY3Rpb25faWQYASABKAlSDXRyYW'
    '5zYWN0aW9uSWQ=');

@$core.Deprecated('Use deleteTransactionResponseDescriptor instead')
const DeleteTransactionResponse$json = {
  '1': 'DeleteTransactionResponse',
};

/// Descriptor for `DeleteTransactionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTransactionResponseDescriptor = $convert.base64Decode(
    'ChlEZWxldGVUcmFuc2FjdGlvblJlc3BvbnNl');

@$core.Deprecated('Use batchCreateTransactionsRequestDescriptor instead')
const BatchCreateTransactionsRequest$json = {
  '1': 'BatchCreateTransactionsRequest',
  '2': [
    {'1': 'transactions', '3': 1, '4': 3, '5': 11, '6': '.familyledger.transaction.v1.CreateTransactionRequest', '10': 'transactions'},
    {'1': 'account_id', '3': 2, '4': 1, '5': 9, '10': 'accountId'},
  ],
};

/// Descriptor for `BatchCreateTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchCreateTransactionsRequestDescriptor = $convert.base64Decode(
    'Ch5CYXRjaENyZWF0ZVRyYW5zYWN0aW9uc1JlcXVlc3QSWQoMdHJhbnNhY3Rpb25zGAEgAygLMj'
    'UuZmFtaWx5bGVkZ2VyLnRyYW5zYWN0aW9uLnYxLkNyZWF0ZVRyYW5zYWN0aW9uUmVxdWVzdFIM'
    'dHJhbnNhY3Rpb25zEh0KCmFjY291bnRfaWQYAiABKAlSCWFjY291bnRJZA==');

@$core.Deprecated('Use batchCreateTransactionsResponseDescriptor instead')
const BatchCreateTransactionsResponse$json = {
  '1': 'BatchCreateTransactionsResponse',
  '2': [
    {'1': 'created_count', '3': 1, '4': 1, '5': 5, '10': 'createdCount'},
    {'1': 'transactions', '3': 2, '4': 3, '5': 11, '6': '.familyledger.transaction.v1.Transaction', '10': 'transactions'},
    {'1': 'errors', '3': 3, '4': 3, '5': 9, '10': 'errors'},
  ],
};

/// Descriptor for `BatchCreateTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchCreateTransactionsResponseDescriptor = $convert.base64Decode(
    'Ch9CYXRjaENyZWF0ZVRyYW5zYWN0aW9uc1Jlc3BvbnNlEiMKDWNyZWF0ZWRfY291bnQYASABKA'
    'VSDGNyZWF0ZWRDb3VudBJMCgx0cmFuc2FjdGlvbnMYAiADKAsyKC5mYW1pbHlsZWRnZXIudHJh'
    'bnNhY3Rpb24udjEuVHJhbnNhY3Rpb25SDHRyYW5zYWN0aW9ucxIWCgZlcnJvcnMYAyADKAlSBm'
    'Vycm9ycw==');

@$core.Deprecated('Use batchDeleteTransactionsRequestDescriptor instead')
const BatchDeleteTransactionsRequest$json = {
  '1': 'BatchDeleteTransactionsRequest',
  '2': [
    {'1': 'transaction_ids', '3': 1, '4': 3, '5': 9, '10': 'transactionIds'},
  ],
};

/// Descriptor for `BatchDeleteTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchDeleteTransactionsRequestDescriptor = $convert.base64Decode(
    'Ch5CYXRjaERlbGV0ZVRyYW5zYWN0aW9uc1JlcXVlc3QSJwoPdHJhbnNhY3Rpb25faWRzGAEgAy'
    'gJUg50cmFuc2FjdGlvbklkcw==');

@$core.Deprecated('Use batchDeleteTransactionsResponseDescriptor instead')
const BatchDeleteTransactionsResponse$json = {
  '1': 'BatchDeleteTransactionsResponse',
  '2': [
    {'1': 'deleted_count', '3': 1, '4': 1, '5': 5, '10': 'deletedCount'},
  ],
};

/// Descriptor for `BatchDeleteTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List batchDeleteTransactionsResponseDescriptor = $convert.base64Decode(
    'Ch9CYXRjaERlbGV0ZVRyYW5zYWN0aW9uc1Jlc3BvbnNlEiMKDWRlbGV0ZWRfY291bnQYASABKA'
    'VSDGRlbGV0ZWRDb3VudA==');

@$core.Deprecated('Use uploadTransactionImageRequestDescriptor instead')
const UploadTransactionImageRequest$json = {
  '1': 'UploadTransactionImageRequest',
  '2': [
    {'1': 'transaction_id', '3': 1, '4': 1, '5': 9, '10': 'transactionId'},
    {'1': 'filename', '3': 2, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
    {'1': 'content_type', '3': 4, '4': 1, '5': 9, '10': 'contentType'},
  ],
};

/// Descriptor for `UploadTransactionImageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadTransactionImageRequestDescriptor = $convert.base64Decode(
    'Ch1VcGxvYWRUcmFuc2FjdGlvbkltYWdlUmVxdWVzdBIlCg50cmFuc2FjdGlvbl9pZBgBIAEoCV'
    'INdHJhbnNhY3Rpb25JZBIaCghmaWxlbmFtZRgCIAEoCVIIZmlsZW5hbWUSEgoEZGF0YRgDIAEo'
    'DFIEZGF0YRIhCgxjb250ZW50X3R5cGUYBCABKAlSC2NvbnRlbnRUeXBl');

@$core.Deprecated('Use uploadTransactionImageResponseDescriptor instead')
const UploadTransactionImageResponse$json = {
  '1': 'UploadTransactionImageResponse',
  '2': [
    {'1': 'image_url', '3': 1, '4': 1, '5': 9, '10': 'imageUrl'},
  ],
};

/// Descriptor for `UploadTransactionImageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadTransactionImageResponseDescriptor = $convert.base64Decode(
    'Ch5VcGxvYWRUcmFuc2FjdGlvbkltYWdlUmVzcG9uc2USGwoJaW1hZ2VfdXJsGAEgASgJUghpbW'
    'FnZVVybA==');

@$core.Deprecated('Use getCategoriesRequestDescriptor instead')
const GetCategoriesRequest$json = {
  '1': 'GetCategoriesRequest',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 14, '6': '.familyledger.transaction.v1.TransactionType', '10': 'type'},
  ],
};

/// Descriptor for `GetCategoriesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCategoriesRequestDescriptor = $convert.base64Decode(
    'ChRHZXRDYXRlZ29yaWVzUmVxdWVzdBJACgR0eXBlGAEgASgOMiwuZmFtaWx5bGVkZ2VyLnRyYW'
    '5zYWN0aW9uLnYxLlRyYW5zYWN0aW9uVHlwZVIEdHlwZQ==');

@$core.Deprecated('Use getCategoriesResponseDescriptor instead')
const GetCategoriesResponse$json = {
  '1': 'GetCategoriesResponse',
  '2': [
    {'1': 'categories', '3': 1, '4': 3, '5': 11, '6': '.familyledger.transaction.v1.Category', '10': 'categories'},
  ],
};

/// Descriptor for `GetCategoriesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCategoriesResponseDescriptor = $convert.base64Decode(
    'ChVHZXRDYXRlZ29yaWVzUmVzcG9uc2USRQoKY2F0ZWdvcmllcxgBIAMoCzIlLmZhbWlseWxlZG'
    'dlci50cmFuc2FjdGlvbi52MS5DYXRlZ29yeVIKY2F0ZWdvcmllcw==');

@$core.Deprecated('Use createCategoryRequestDescriptor instead')
const CreateCategoryRequest$json = {
  '1': 'CreateCategoryRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'icon_key', '3': 2, '4': 1, '5': 9, '10': 'iconKey'},
    {'1': 'type', '3': 3, '4': 1, '5': 14, '6': '.familyledger.transaction.v1.TransactionType', '10': 'type'},
    {'1': 'parent_id', '3': 4, '4': 1, '5': 9, '10': 'parentId'},
  ],
};

/// Descriptor for `CreateCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createCategoryRequestDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVDYXRlZ29yeVJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZRIZCghpY29uX2tleR'
    'gCIAEoCVIHaWNvbktleRJACgR0eXBlGAMgASgOMiwuZmFtaWx5bGVkZ2VyLnRyYW5zYWN0aW9u'
    'LnYxLlRyYW5zYWN0aW9uVHlwZVIEdHlwZRIbCglwYXJlbnRfaWQYBCABKAlSCHBhcmVudElk');

@$core.Deprecated('Use createCategoryResponseDescriptor instead')
const CreateCategoryResponse$json = {
  '1': 'CreateCategoryResponse',
  '2': [
    {'1': 'category', '3': 1, '4': 1, '5': 11, '6': '.familyledger.transaction.v1.Category', '10': 'category'},
  ],
};

/// Descriptor for `CreateCategoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createCategoryResponseDescriptor = $convert.base64Decode(
    'ChZDcmVhdGVDYXRlZ29yeVJlc3BvbnNlEkEKCGNhdGVnb3J5GAEgASgLMiUuZmFtaWx5bGVkZ2'
    'VyLnRyYW5zYWN0aW9uLnYxLkNhdGVnb3J5UghjYXRlZ29yeQ==');

@$core.Deprecated('Use updateCategoryRequestDescriptor instead')
const UpdateCategoryRequest$json = {
  '1': 'UpdateCategoryRequest',
  '2': [
    {'1': 'category_id', '3': 1, '4': 1, '5': 9, '10': 'categoryId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {'1': 'icon_key', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'iconKey', '17': true},
  ],
  '8': [
    {'1': '_name'},
    {'1': '_icon_key'},
  ],
};

/// Descriptor for `UpdateCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateCategoryRequestDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVDYXRlZ29yeVJlcXVlc3QSHwoLY2F0ZWdvcnlfaWQYASABKAlSCmNhdGVnb3J5SW'
    'QSFwoEbmFtZRgCIAEoCUgAUgRuYW1liAEBEh4KCGljb25fa2V5GAMgASgJSAFSB2ljb25LZXmI'
    'AQFCBwoFX25hbWVCCwoJX2ljb25fa2V5');

@$core.Deprecated('Use updateCategoryResponseDescriptor instead')
const UpdateCategoryResponse$json = {
  '1': 'UpdateCategoryResponse',
  '2': [
    {'1': 'category', '3': 1, '4': 1, '5': 11, '6': '.familyledger.transaction.v1.Category', '10': 'category'},
  ],
};

/// Descriptor for `UpdateCategoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateCategoryResponseDescriptor = $convert.base64Decode(
    'ChZVcGRhdGVDYXRlZ29yeVJlc3BvbnNlEkEKCGNhdGVnb3J5GAEgASgLMiUuZmFtaWx5bGVkZ2'
    'VyLnRyYW5zYWN0aW9uLnYxLkNhdGVnb3J5UghjYXRlZ29yeQ==');

@$core.Deprecated('Use deleteCategoryRequestDescriptor instead')
const DeleteCategoryRequest$json = {
  '1': 'DeleteCategoryRequest',
  '2': [
    {'1': 'category_id', '3': 1, '4': 1, '5': 9, '10': 'categoryId'},
  ],
};

/// Descriptor for `DeleteCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCategoryRequestDescriptor = $convert.base64Decode(
    'ChVEZWxldGVDYXRlZ29yeVJlcXVlc3QSHwoLY2F0ZWdvcnlfaWQYASABKAlSCmNhdGVnb3J5SW'
    'Q=');

@$core.Deprecated('Use deleteCategoryResponseDescriptor instead')
const DeleteCategoryResponse$json = {
  '1': 'DeleteCategoryResponse',
};

/// Descriptor for `DeleteCategoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCategoryResponseDescriptor = $convert.base64Decode(
    'ChZEZWxldGVDYXRlZ29yeVJlc3BvbnNl');

@$core.Deprecated('Use reorderCategoriesRequestDescriptor instead')
const ReorderCategoriesRequest$json = {
  '1': 'ReorderCategoriesRequest',
  '2': [
    {'1': 'orders', '3': 1, '4': 3, '5': 11, '6': '.familyledger.transaction.v1.CategoryOrder', '10': 'orders'},
  ],
};

/// Descriptor for `ReorderCategoriesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderCategoriesRequestDescriptor = $convert.base64Decode(
    'ChhSZW9yZGVyQ2F0ZWdvcmllc1JlcXVlc3QSQgoGb3JkZXJzGAEgAygLMiouZmFtaWx5bGVkZ2'
    'VyLnRyYW5zYWN0aW9uLnYxLkNhdGVnb3J5T3JkZXJSBm9yZGVycw==');

@$core.Deprecated('Use categoryOrderDescriptor instead')
const CategoryOrder$json = {
  '1': 'CategoryOrder',
  '2': [
    {'1': 'category_id', '3': 1, '4': 1, '5': 9, '10': 'categoryId'},
    {'1': 'sort_order', '3': 2, '4': 1, '5': 5, '10': 'sortOrder'},
  ],
};

/// Descriptor for `CategoryOrder`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryOrderDescriptor = $convert.base64Decode(
    'Cg1DYXRlZ29yeU9yZGVyEh8KC2NhdGVnb3J5X2lkGAEgASgJUgpjYXRlZ29yeUlkEh0KCnNvcn'
    'Rfb3JkZXIYAiABKAVSCXNvcnRPcmRlcg==');

@$core.Deprecated('Use reorderCategoriesResponseDescriptor instead')
const ReorderCategoriesResponse$json = {
  '1': 'ReorderCategoriesResponse',
};

/// Descriptor for `ReorderCategoriesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderCategoriesResponseDescriptor = $convert.base64Decode(
    'ChlSZW9yZGVyQ2F0ZWdvcmllc1Jlc3BvbnNl');

