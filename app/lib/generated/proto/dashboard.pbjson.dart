//
//  Generated code. Do not modify.
//  source: dashboard.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use getNetWorthRequestDescriptor instead')
const GetNetWorthRequest$json = {
  '1': 'GetNetWorthRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
  ],
};

/// Descriptor for `GetNetWorthRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNetWorthRequestDescriptor = $convert.base64Decode(
    'ChJHZXROZXRXb3J0aFJlcXVlc3QSGwoJZmFtaWx5X2lkGAEgASgJUghmYW1pbHlJZA==');

@$core.Deprecated('Use netWorthDescriptor instead')
const NetWorth$json = {
  '1': 'NetWorth',
  '2': [
    {'1': 'total', '3': 1, '4': 1, '5': 3, '10': 'total'},
    {'1': 'cash_and_bank', '3': 2, '4': 1, '5': 3, '10': 'cashAndBank'},
    {'1': 'investment_value', '3': 3, '4': 1, '5': 3, '10': 'investmentValue'},
    {'1': 'fixed_asset_value', '3': 4, '4': 1, '5': 3, '10': 'fixedAssetValue'},
    {'1': 'loan_balance', '3': 5, '4': 1, '5': 3, '10': 'loanBalance'},
    {'1': 'change_from_last_month', '3': 6, '4': 1, '5': 3, '10': 'changeFromLastMonth'},
    {'1': 'change_percent', '3': 7, '4': 1, '5': 1, '10': 'changePercent'},
    {'1': 'composition', '3': 8, '4': 3, '5': 11, '6': '.familyledger.dashboard.v1.AssetComposition', '10': 'composition'},
  ],
};

/// Descriptor for `NetWorth`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List netWorthDescriptor = $convert.base64Decode(
    'CghOZXRXb3J0aBIUCgV0b3RhbBgBIAEoA1IFdG90YWwSIgoNY2FzaF9hbmRfYmFuaxgCIAEoA1'
    'ILY2FzaEFuZEJhbmsSKQoQaW52ZXN0bWVudF92YWx1ZRgDIAEoA1IPaW52ZXN0bWVudFZhbHVl'
    'EioKEWZpeGVkX2Fzc2V0X3ZhbHVlGAQgASgDUg9maXhlZEFzc2V0VmFsdWUSIQoMbG9hbl9iYW'
    'xhbmNlGAUgASgDUgtsb2FuQmFsYW5jZRIzChZjaGFuZ2VfZnJvbV9sYXN0X21vbnRoGAYgASgD'
    'UhNjaGFuZ2VGcm9tTGFzdE1vbnRoEiUKDmNoYW5nZV9wZXJjZW50GAcgASgBUg1jaGFuZ2VQZX'
    'JjZW50Ek0KC2NvbXBvc2l0aW9uGAggAygLMisuZmFtaWx5bGVkZ2VyLmRhc2hib2FyZC52MS5B'
    'c3NldENvbXBvc2l0aW9uUgtjb21wb3NpdGlvbg==');

@$core.Deprecated('Use assetCompositionDescriptor instead')
const AssetComposition$json = {
  '1': 'AssetComposition',
  '2': [
    {'1': 'category', '3': 1, '4': 1, '5': 9, '10': 'category'},
    {'1': 'label', '3': 2, '4': 1, '5': 9, '10': 'label'},
    {'1': 'value', '3': 3, '4': 1, '5': 3, '10': 'value'},
    {'1': 'weight', '3': 4, '4': 1, '5': 1, '10': 'weight'},
  ],
};

/// Descriptor for `AssetComposition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assetCompositionDescriptor = $convert.base64Decode(
    'ChBBc3NldENvbXBvc2l0aW9uEhoKCGNhdGVnb3J5GAEgASgJUghjYXRlZ29yeRIUCgVsYWJlbB'
    'gCIAEoCVIFbGFiZWwSFAoFdmFsdWUYAyABKANSBXZhbHVlEhYKBndlaWdodBgEIAEoAVIGd2Vp'
    'Z2h0');

@$core.Deprecated('Use trendRequestDescriptor instead')
const TrendRequest$json = {
  '1': 'TrendRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'family_id', '3': 2, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'period', '3': 3, '4': 1, '5': 9, '10': 'period'},
    {'1': 'count', '3': 4, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `TrendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trendRequestDescriptor = $convert.base64Decode(
    'CgxUcmVuZFJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhsKCWZhbWlseV9pZBgCIA'
    'EoCVIIZmFtaWx5SWQSFgoGcGVyaW9kGAMgASgJUgZwZXJpb2QSFAoFY291bnQYBCABKAVSBWNv'
    'dW50');

@$core.Deprecated('Use trendResponseDescriptor instead')
const TrendResponse$json = {
  '1': 'TrendResponse',
  '2': [
    {'1': 'points', '3': 1, '4': 3, '5': 11, '6': '.familyledger.dashboard.v1.TrendPoint', '10': 'points'},
  ],
};

/// Descriptor for `TrendResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trendResponseDescriptor = $convert.base64Decode(
    'Cg1UcmVuZFJlc3BvbnNlEj0KBnBvaW50cxgBIAMoCzIlLmZhbWlseWxlZGdlci5kYXNoYm9hcm'
    'QudjEuVHJlbmRQb2ludFIGcG9pbnRz');

@$core.Deprecated('Use trendPointDescriptor instead')
const TrendPoint$json = {
  '1': 'TrendPoint',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'income', '3': 2, '4': 1, '5': 3, '10': 'income'},
    {'1': 'expense', '3': 3, '4': 1, '5': 3, '10': 'expense'},
    {'1': 'net', '3': 4, '4': 1, '5': 3, '10': 'net'},
  ],
};

/// Descriptor for `TrendPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trendPointDescriptor = $convert.base64Decode(
    'CgpUcmVuZFBvaW50EhQKBWxhYmVsGAEgASgJUgVsYWJlbBIWCgZpbmNvbWUYAiABKANSBmluY2'
    '9tZRIYCgdleHBlbnNlGAMgASgDUgdleHBlbnNlEhAKA25ldBgEIAEoA1IDbmV0');

@$core.Deprecated('Use categoryBreakdownRequestDescriptor instead')
const CategoryBreakdownRequest$json = {
  '1': 'CategoryBreakdownRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'family_id', '3': 2, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'year', '3': 3, '4': 1, '5': 5, '10': 'year'},
    {'1': 'month', '3': 4, '4': 1, '5': 5, '10': 'month'},
    {'1': 'type', '3': 5, '4': 1, '5': 9, '10': 'type'},
  ],
};

/// Descriptor for `CategoryBreakdownRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryBreakdownRequestDescriptor = $convert.base64Decode(
    'ChhDYXRlZ29yeUJyZWFrZG93blJlcXVlc3QSFwoHdXNlcl9pZBgBIAEoCVIGdXNlcklkEhsKCW'
    'ZhbWlseV9pZBgCIAEoCVIIZmFtaWx5SWQSEgoEeWVhchgDIAEoBVIEeWVhchIUCgVtb250aBgE'
    'IAEoBVIFbW9udGgSEgoEdHlwZRgFIAEoCVIEdHlwZQ==');

@$core.Deprecated('Use categoryBreakdownResponseDescriptor instead')
const CategoryBreakdownResponse$json = {
  '1': 'CategoryBreakdownResponse',
  '2': [
    {'1': 'total', '3': 1, '4': 1, '5': 3, '10': 'total'},
    {'1': 'items', '3': 2, '4': 3, '5': 11, '6': '.familyledger.dashboard.v1.CategoryItem', '10': 'items'},
  ],
};

/// Descriptor for `CategoryBreakdownResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryBreakdownResponseDescriptor = $convert.base64Decode(
    'ChlDYXRlZ29yeUJyZWFrZG93blJlc3BvbnNlEhQKBXRvdGFsGAEgASgDUgV0b3RhbBI9CgVpdG'
    'VtcxgCIAMoCzInLmZhbWlseWxlZGdlci5kYXNoYm9hcmQudjEuQ2F0ZWdvcnlJdGVtUgVpdGVt'
    'cw==');

@$core.Deprecated('Use categoryItemDescriptor instead')
const CategoryItem$json = {
  '1': 'CategoryItem',
  '2': [
    {'1': 'category_id', '3': 1, '4': 1, '5': 9, '10': 'categoryId'},
    {'1': 'category_name', '3': 2, '4': 1, '5': 9, '10': 'categoryName'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'amount', '3': 4, '4': 1, '5': 3, '10': 'amount'},
    {'1': 'weight', '3': 5, '4': 1, '5': 1, '10': 'weight'},
    {'1': 'children', '3': 6, '4': 3, '5': 11, '6': '.familyledger.dashboard.v1.CategoryItem', '10': 'children'},
    {'1': 'icon_key', '3': 7, '4': 1, '5': 9, '10': 'iconKey'},
  ],
};

/// Descriptor for `CategoryItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryItemDescriptor = $convert.base64Decode(
    'CgxDYXRlZ29yeUl0ZW0SHwoLY2F0ZWdvcnlfaWQYASABKAlSCmNhdGVnb3J5SWQSIwoNY2F0ZW'
    'dvcnlfbmFtZRgCIAEoCVIMY2F0ZWdvcnlOYW1lEhIKBGljb24YAyABKAlSBGljb24SFgoGYW1v'
    'dW50GAQgASgDUgZhbW91bnQSFgoGd2VpZ2h0GAUgASgBUgZ3ZWlnaHQSQwoIY2hpbGRyZW4YBi'
    'ADKAsyJy5mYW1pbHlsZWRnZXIuZGFzaGJvYXJkLnYxLkNhdGVnb3J5SXRlbVIIY2hpbGRyZW4S'
    'GQoIaWNvbl9rZXkYByABKAlSB2ljb25LZXk=');

@$core.Deprecated('Use budgetSummaryRequestDescriptor instead')
const BudgetSummaryRequest$json = {
  '1': 'BudgetSummaryRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'month', '3': 3, '4': 1, '5': 5, '10': 'month'},
  ],
};

/// Descriptor for `BudgetSummaryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetSummaryRequestDescriptor = $convert.base64Decode(
    'ChRCdWRnZXRTdW1tYXJ5UmVxdWVzdBIbCglmYW1pbHlfaWQYASABKAlSCGZhbWlseUlkEhIKBH'
    'llYXIYAiABKAVSBHllYXISFAoFbW9udGgYAyABKAVSBW1vbnRo');

@$core.Deprecated('Use budgetSummaryResponseDescriptor instead')
const BudgetSummaryResponse$json = {
  '1': 'BudgetSummaryResponse',
  '2': [
    {'1': 'total_budget', '3': 1, '4': 1, '5': 3, '10': 'totalBudget'},
    {'1': 'total_spent', '3': 2, '4': 1, '5': 3, '10': 'totalSpent'},
    {'1': 'execution_rate', '3': 3, '4': 1, '5': 1, '10': 'executionRate'},
    {'1': 'categories', '3': 4, '4': 3, '5': 11, '6': '.familyledger.dashboard.v1.CategoryBudgetItem', '10': 'categories'},
  ],
};

/// Descriptor for `BudgetSummaryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetSummaryResponseDescriptor = $convert.base64Decode(
    'ChVCdWRnZXRTdW1tYXJ5UmVzcG9uc2USIQoMdG90YWxfYnVkZ2V0GAEgASgDUgt0b3RhbEJ1ZG'
    'dldBIfCgt0b3RhbF9zcGVudBgCIAEoA1IKdG90YWxTcGVudBIlCg5leGVjdXRpb25fcmF0ZRgD'
    'IAEoAVINZXhlY3V0aW9uUmF0ZRJNCgpjYXRlZ29yaWVzGAQgAygLMi0uZmFtaWx5bGVkZ2VyLm'
    'Rhc2hib2FyZC52MS5DYXRlZ29yeUJ1ZGdldEl0ZW1SCmNhdGVnb3JpZXM=');

@$core.Deprecated('Use categoryBudgetItemDescriptor instead')
const CategoryBudgetItem$json = {
  '1': 'CategoryBudgetItem',
  '2': [
    {'1': 'category_id', '3': 1, '4': 1, '5': 9, '10': 'categoryId'},
    {'1': 'category_name', '3': 2, '4': 1, '5': 9, '10': 'categoryName'},
    {'1': 'budget_amount', '3': 3, '4': 1, '5': 3, '10': 'budgetAmount'},
    {'1': 'spent_amount', '3': 4, '4': 1, '5': 3, '10': 'spentAmount'},
    {'1': 'execution_rate', '3': 5, '4': 1, '5': 1, '10': 'executionRate'},
    {'1': 'children', '3': 6, '4': 3, '5': 11, '6': '.familyledger.dashboard.v1.CategoryBudgetItem', '10': 'children'},
  ],
};

/// Descriptor for `CategoryBudgetItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryBudgetItemDescriptor = $convert.base64Decode(
    'ChJDYXRlZ29yeUJ1ZGdldEl0ZW0SHwoLY2F0ZWdvcnlfaWQYASABKAlSCmNhdGVnb3J5SWQSIw'
    'oNY2F0ZWdvcnlfbmFtZRgCIAEoCVIMY2F0ZWdvcnlOYW1lEiMKDWJ1ZGdldF9hbW91bnQYAyAB'
    'KANSDGJ1ZGdldEFtb3VudBIhCgxzcGVudF9hbW91bnQYBCABKANSC3NwZW50QW1vdW50EiUKDm'
    'V4ZWN1dGlvbl9yYXRlGAUgASgBUg1leGVjdXRpb25SYXRlEkkKCGNoaWxkcmVuGAYgAygLMi0u'
    'ZmFtaWx5bGVkZ2VyLmRhc2hib2FyZC52MS5DYXRlZ29yeUJ1ZGdldEl0ZW1SCGNoaWxkcmVu');

