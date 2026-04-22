//
//  Generated code. Do not modify.
//  source: budget.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use budgetDescriptor instead')
const Budget$json = {
  '1': 'Budget',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'family_id', '3': 3, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'year', '3': 4, '4': 1, '5': 5, '10': 'year'},
    {'1': 'month', '3': 5, '4': 1, '5': 5, '10': 'month'},
    {'1': 'total_amount', '3': 6, '4': 1, '5': 3, '10': 'totalAmount'},
    {'1': 'category_budgets', '3': 7, '4': 3, '5': 11, '6': '.familyledger.budget.v1.CategoryBudget', '10': 'categoryBudgets'},
    {'1': 'created_at', '3': 8, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'createdAt'},
  ],
};

/// Descriptor for `Budget`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetDescriptor = $convert.base64Decode(
    'CgZCdWRnZXQSDgoCaWQYASABKAlSAmlkEhcKB3VzZXJfaWQYAiABKAlSBnVzZXJJZBIbCglmYW'
    '1pbHlfaWQYAyABKAlSCGZhbWlseUlkEhIKBHllYXIYBCABKAVSBHllYXISFAoFbW9udGgYBSAB'
    'KAVSBW1vbnRoEiEKDHRvdGFsX2Ftb3VudBgGIAEoA1ILdG90YWxBbW91bnQSUQoQY2F0ZWdvcn'
    'lfYnVkZ2V0cxgHIAMoCzImLmZhbWlseWxlZGdlci5idWRnZXQudjEuQ2F0ZWdvcnlCdWRnZXRS'
    'D2NhdGVnb3J5QnVkZ2V0cxI5CgpjcmVhdGVkX2F0GAggASgLMhouZ29vZ2xlLnByb3RvYnVmLl'
    'RpbWVzdGFtcFIJY3JlYXRlZEF0');

@$core.Deprecated('Use categoryBudgetDescriptor instead')
const CategoryBudget$json = {
  '1': 'CategoryBudget',
  '2': [
    {'1': 'category_id', '3': 1, '4': 1, '5': 9, '10': 'categoryId'},
    {'1': 'amount', '3': 2, '4': 1, '5': 3, '10': 'amount'},
  ],
};

/// Descriptor for `CategoryBudget`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryBudgetDescriptor = $convert.base64Decode(
    'Cg5DYXRlZ29yeUJ1ZGdldBIfCgtjYXRlZ29yeV9pZBgBIAEoCVIKY2F0ZWdvcnlJZBIWCgZhbW'
    '91bnQYAiABKANSBmFtb3VudA==');

@$core.Deprecated('Use budgetExecutionDescriptor instead')
const BudgetExecution$json = {
  '1': 'BudgetExecution',
  '2': [
    {'1': 'total_budget', '3': 1, '4': 1, '5': 3, '10': 'totalBudget'},
    {'1': 'total_spent', '3': 2, '4': 1, '5': 3, '10': 'totalSpent'},
    {'1': 'execution_rate', '3': 3, '4': 1, '5': 1, '10': 'executionRate'},
    {'1': 'category_executions', '3': 4, '4': 3, '5': 11, '6': '.familyledger.budget.v1.CategoryExecution', '10': 'categoryExecutions'},
  ],
};

/// Descriptor for `BudgetExecution`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetExecutionDescriptor = $convert.base64Decode(
    'Cg9CdWRnZXRFeGVjdXRpb24SIQoMdG90YWxfYnVkZ2V0GAEgASgDUgt0b3RhbEJ1ZGdldBIfCg'
    't0b3RhbF9zcGVudBgCIAEoA1IKdG90YWxTcGVudBIlCg5leGVjdXRpb25fcmF0ZRgDIAEoAVIN'
    'ZXhlY3V0aW9uUmF0ZRJaChNjYXRlZ29yeV9leGVjdXRpb25zGAQgAygLMikuZmFtaWx5bGVkZ2'
    'VyLmJ1ZGdldC52MS5DYXRlZ29yeUV4ZWN1dGlvblISY2F0ZWdvcnlFeGVjdXRpb25z');

@$core.Deprecated('Use categoryExecutionDescriptor instead')
const CategoryExecution$json = {
  '1': 'CategoryExecution',
  '2': [
    {'1': 'category_id', '3': 1, '4': 1, '5': 9, '10': 'categoryId'},
    {'1': 'category_name', '3': 2, '4': 1, '5': 9, '10': 'categoryName'},
    {'1': 'budget_amount', '3': 3, '4': 1, '5': 3, '10': 'budgetAmount'},
    {'1': 'spent_amount', '3': 4, '4': 1, '5': 3, '10': 'spentAmount'},
    {'1': 'execution_rate', '3': 5, '4': 1, '5': 1, '10': 'executionRate'},
  ],
};

/// Descriptor for `CategoryExecution`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryExecutionDescriptor = $convert.base64Decode(
    'ChFDYXRlZ29yeUV4ZWN1dGlvbhIfCgtjYXRlZ29yeV9pZBgBIAEoCVIKY2F0ZWdvcnlJZBIjCg'
    '1jYXRlZ29yeV9uYW1lGAIgASgJUgxjYXRlZ29yeU5hbWUSIwoNYnVkZ2V0X2Ftb3VudBgDIAEo'
    'A1IMYnVkZ2V0QW1vdW50EiEKDHNwZW50X2Ftb3VudBgEIAEoA1ILc3BlbnRBbW91bnQSJQoOZX'
    'hlY3V0aW9uX3JhdGUYBSABKAFSDWV4ZWN1dGlvblJhdGU=');

@$core.Deprecated('Use createBudgetRequestDescriptor instead')
const CreateBudgetRequest$json = {
  '1': 'CreateBudgetRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
    {'1': 'month', '3': 3, '4': 1, '5': 5, '10': 'month'},
    {'1': 'total_amount', '3': 4, '4': 1, '5': 3, '10': 'totalAmount'},
    {'1': 'category_budgets', '3': 5, '4': 3, '5': 11, '6': '.familyledger.budget.v1.CategoryBudget', '10': 'categoryBudgets'},
  ],
};

/// Descriptor for `CreateBudgetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createBudgetRequestDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVCdWRnZXRSZXF1ZXN0EhsKCWZhbWlseV9pZBgBIAEoCVIIZmFtaWx5SWQSEgoEeW'
    'VhchgCIAEoBVIEeWVhchIUCgVtb250aBgDIAEoBVIFbW9udGgSIQoMdG90YWxfYW1vdW50GAQg'
    'ASgDUgt0b3RhbEFtb3VudBJRChBjYXRlZ29yeV9idWRnZXRzGAUgAygLMiYuZmFtaWx5bGVkZ2'
    'VyLmJ1ZGdldC52MS5DYXRlZ29yeUJ1ZGdldFIPY2F0ZWdvcnlCdWRnZXRz');

@$core.Deprecated('Use createBudgetResponseDescriptor instead')
const CreateBudgetResponse$json = {
  '1': 'CreateBudgetResponse',
  '2': [
    {'1': 'budget', '3': 1, '4': 1, '5': 11, '6': '.familyledger.budget.v1.Budget', '10': 'budget'},
  ],
};

/// Descriptor for `CreateBudgetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createBudgetResponseDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVCdWRnZXRSZXNwb25zZRI2CgZidWRnZXQYASABKAsyHi5mYW1pbHlsZWRnZXIuYn'
    'VkZ2V0LnYxLkJ1ZGdldFIGYnVkZ2V0');

@$core.Deprecated('Use getBudgetRequestDescriptor instead')
const GetBudgetRequest$json = {
  '1': 'GetBudgetRequest',
  '2': [
    {'1': 'budget_id', '3': 1, '4': 1, '5': 9, '10': 'budgetId'},
  ],
};

/// Descriptor for `GetBudgetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBudgetRequestDescriptor = $convert.base64Decode(
    'ChBHZXRCdWRnZXRSZXF1ZXN0EhsKCWJ1ZGdldF9pZBgBIAEoCVIIYnVkZ2V0SWQ=');

@$core.Deprecated('Use getBudgetResponseDescriptor instead')
const GetBudgetResponse$json = {
  '1': 'GetBudgetResponse',
  '2': [
    {'1': 'budget', '3': 1, '4': 1, '5': 11, '6': '.familyledger.budget.v1.Budget', '10': 'budget'},
    {'1': 'execution', '3': 2, '4': 1, '5': 11, '6': '.familyledger.budget.v1.BudgetExecution', '10': 'execution'},
  ],
};

/// Descriptor for `GetBudgetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBudgetResponseDescriptor = $convert.base64Decode(
    'ChFHZXRCdWRnZXRSZXNwb25zZRI2CgZidWRnZXQYASABKAsyHi5mYW1pbHlsZWRnZXIuYnVkZ2'
    'V0LnYxLkJ1ZGdldFIGYnVkZ2V0EkUKCWV4ZWN1dGlvbhgCIAEoCzInLmZhbWlseWxlZGdlci5i'
    'dWRnZXQudjEuQnVkZ2V0RXhlY3V0aW9uUglleGVjdXRpb24=');

@$core.Deprecated('Use listBudgetsRequestDescriptor instead')
const ListBudgetsRequest$json = {
  '1': 'ListBudgetsRequest',
  '2': [
    {'1': 'family_id', '3': 1, '4': 1, '5': 9, '10': 'familyId'},
    {'1': 'year', '3': 2, '4': 1, '5': 5, '10': 'year'},
  ],
};

/// Descriptor for `ListBudgetsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBudgetsRequestDescriptor = $convert.base64Decode(
    'ChJMaXN0QnVkZ2V0c1JlcXVlc3QSGwoJZmFtaWx5X2lkGAEgASgJUghmYW1pbHlJZBISCgR5ZW'
    'FyGAIgASgFUgR5ZWFy');

@$core.Deprecated('Use listBudgetsResponseDescriptor instead')
const ListBudgetsResponse$json = {
  '1': 'ListBudgetsResponse',
  '2': [
    {'1': 'budgets', '3': 1, '4': 3, '5': 11, '6': '.familyledger.budget.v1.Budget', '10': 'budgets'},
  ],
};

/// Descriptor for `ListBudgetsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBudgetsResponseDescriptor = $convert.base64Decode(
    'ChNMaXN0QnVkZ2V0c1Jlc3BvbnNlEjgKB2J1ZGdldHMYASADKAsyHi5mYW1pbHlsZWRnZXIuYn'
    'VkZ2V0LnYxLkJ1ZGdldFIHYnVkZ2V0cw==');

@$core.Deprecated('Use updateBudgetRequestDescriptor instead')
const UpdateBudgetRequest$json = {
  '1': 'UpdateBudgetRequest',
  '2': [
    {'1': 'budget_id', '3': 1, '4': 1, '5': 9, '10': 'budgetId'},
    {'1': 'total_amount', '3': 2, '4': 1, '5': 3, '10': 'totalAmount'},
    {'1': 'category_budgets', '3': 3, '4': 3, '5': 11, '6': '.familyledger.budget.v1.CategoryBudget', '10': 'categoryBudgets'},
  ],
};

/// Descriptor for `UpdateBudgetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateBudgetRequestDescriptor = $convert.base64Decode(
    'ChNVcGRhdGVCdWRnZXRSZXF1ZXN0EhsKCWJ1ZGdldF9pZBgBIAEoCVIIYnVkZ2V0SWQSIQoMdG'
    '90YWxfYW1vdW50GAIgASgDUgt0b3RhbEFtb3VudBJRChBjYXRlZ29yeV9idWRnZXRzGAMgAygL'
    'MiYuZmFtaWx5bGVkZ2VyLmJ1ZGdldC52MS5DYXRlZ29yeUJ1ZGdldFIPY2F0ZWdvcnlCdWRnZX'
    'Rz');

@$core.Deprecated('Use updateBudgetResponseDescriptor instead')
const UpdateBudgetResponse$json = {
  '1': 'UpdateBudgetResponse',
  '2': [
    {'1': 'budget', '3': 1, '4': 1, '5': 11, '6': '.familyledger.budget.v1.Budget', '10': 'budget'},
  ],
};

/// Descriptor for `UpdateBudgetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateBudgetResponseDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVCdWRnZXRSZXNwb25zZRI2CgZidWRnZXQYASABKAsyHi5mYW1pbHlsZWRnZXIuYn'
    'VkZ2V0LnYxLkJ1ZGdldFIGYnVkZ2V0');

@$core.Deprecated('Use deleteBudgetRequestDescriptor instead')
const DeleteBudgetRequest$json = {
  '1': 'DeleteBudgetRequest',
  '2': [
    {'1': 'budget_id', '3': 1, '4': 1, '5': 9, '10': 'budgetId'},
  ],
};

/// Descriptor for `DeleteBudgetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteBudgetRequestDescriptor = $convert.base64Decode(
    'ChNEZWxldGVCdWRnZXRSZXF1ZXN0EhsKCWJ1ZGdldF9pZBgBIAEoCVIIYnVkZ2V0SWQ=');

@$core.Deprecated('Use deleteBudgetResponseDescriptor instead')
const DeleteBudgetResponse$json = {
  '1': 'DeleteBudgetResponse',
};

/// Descriptor for `DeleteBudgetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteBudgetResponseDescriptor = $convert.base64Decode(
    'ChREZWxldGVCdWRnZXRSZXNwb25zZQ==');

@$core.Deprecated('Use getBudgetExecutionRequestDescriptor instead')
const GetBudgetExecutionRequest$json = {
  '1': 'GetBudgetExecutionRequest',
  '2': [
    {'1': 'budget_id', '3': 1, '4': 1, '5': 9, '10': 'budgetId'},
  ],
};

/// Descriptor for `GetBudgetExecutionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBudgetExecutionRequestDescriptor = $convert.base64Decode(
    'ChlHZXRCdWRnZXRFeGVjdXRpb25SZXF1ZXN0EhsKCWJ1ZGdldF9pZBgBIAEoCVIIYnVkZ2V0SW'
    'Q=');

@$core.Deprecated('Use getBudgetExecutionResponseDescriptor instead')
const GetBudgetExecutionResponse$json = {
  '1': 'GetBudgetExecutionResponse',
  '2': [
    {'1': 'execution', '3': 1, '4': 1, '5': 11, '6': '.familyledger.budget.v1.BudgetExecution', '10': 'execution'},
  ],
};

/// Descriptor for `GetBudgetExecutionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBudgetExecutionResponseDescriptor = $convert.base64Decode(
    'ChpHZXRCdWRnZXRFeGVjdXRpb25SZXNwb25zZRJFCglleGVjdXRpb24YASABKAsyJy5mYW1pbH'
    'lsZWRnZXIuYnVkZ2V0LnYxLkJ1ZGdldEV4ZWN1dGlvblIJZXhlY3V0aW9u');

