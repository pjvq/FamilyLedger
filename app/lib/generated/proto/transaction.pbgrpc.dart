//
//  Generated code. Do not modify.
//  source: transaction.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'transaction.pb.dart' as $0;

export 'transaction.pb.dart';

@$pb.GrpcServiceName('familyledger.transaction.v1.TransactionService')
class TransactionServiceClient extends $grpc.Client {
  static final _$createTransaction = $grpc.ClientMethod<$0.CreateTransactionRequest, $0.CreateTransactionResponse>(
      '/familyledger.transaction.v1.TransactionService/CreateTransaction',
      ($0.CreateTransactionRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.CreateTransactionResponse.fromBuffer(value));
  static final _$updateTransaction = $grpc.ClientMethod<$0.UpdateTransactionRequest, $0.UpdateTransactionResponse>(
      '/familyledger.transaction.v1.TransactionService/UpdateTransaction',
      ($0.UpdateTransactionRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.UpdateTransactionResponse.fromBuffer(value));
  static final _$deleteTransaction = $grpc.ClientMethod<$0.DeleteTransactionRequest, $0.DeleteTransactionResponse>(
      '/familyledger.transaction.v1.TransactionService/DeleteTransaction',
      ($0.DeleteTransactionRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.DeleteTransactionResponse.fromBuffer(value));
  static final _$batchDeleteTransactions = $grpc.ClientMethod<$0.BatchDeleteTransactionsRequest, $0.BatchDeleteTransactionsResponse>(
      '/familyledger.transaction.v1.TransactionService/BatchDeleteTransactions',
      ($0.BatchDeleteTransactionsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.BatchDeleteTransactionsResponse.fromBuffer(value));
  static final _$uploadTransactionImage = $grpc.ClientMethod<$0.UploadTransactionImageRequest, $0.UploadTransactionImageResponse>(
      '/familyledger.transaction.v1.TransactionService/UploadTransactionImage',
      ($0.UploadTransactionImageRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.UploadTransactionImageResponse.fromBuffer(value));
  static final _$listTransactions = $grpc.ClientMethod<$0.ListTransactionsRequest, $0.ListTransactionsResponse>(
      '/familyledger.transaction.v1.TransactionService/ListTransactions',
      ($0.ListTransactionsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListTransactionsResponse.fromBuffer(value));
  static final _$getCategories = $grpc.ClientMethod<$0.GetCategoriesRequest, $0.GetCategoriesResponse>(
      '/familyledger.transaction.v1.TransactionService/GetCategories',
      ($0.GetCategoriesRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetCategoriesResponse.fromBuffer(value));
  static final _$createCategory = $grpc.ClientMethod<$0.CreateCategoryRequest, $0.CreateCategoryResponse>(
      '/familyledger.transaction.v1.TransactionService/CreateCategory',
      ($0.CreateCategoryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.CreateCategoryResponse.fromBuffer(value));
  static final _$updateCategory = $grpc.ClientMethod<$0.UpdateCategoryRequest, $0.UpdateCategoryResponse>(
      '/familyledger.transaction.v1.TransactionService/UpdateCategory',
      ($0.UpdateCategoryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.UpdateCategoryResponse.fromBuffer(value));
  static final _$deleteCategory = $grpc.ClientMethod<$0.DeleteCategoryRequest, $0.DeleteCategoryResponse>(
      '/familyledger.transaction.v1.TransactionService/DeleteCategory',
      ($0.DeleteCategoryRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.DeleteCategoryResponse.fromBuffer(value));
  static final _$reorderCategories = $grpc.ClientMethod<$0.ReorderCategoriesRequest, $0.ReorderCategoriesResponse>(
      '/familyledger.transaction.v1.TransactionService/ReorderCategories',
      ($0.ReorderCategoriesRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ReorderCategoriesResponse.fromBuffer(value));

  TransactionServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.CreateTransactionResponse> createTransaction($0.CreateTransactionRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateTransactionResponse> updateTransaction($0.UpdateTransactionRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteTransactionResponse> deleteTransaction($0.DeleteTransactionRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$0.BatchDeleteTransactionsResponse> batchDeleteTransactions($0.BatchDeleteTransactionsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$batchDeleteTransactions, request, options: options);
  }

  $grpc.ResponseFuture<$0.UploadTransactionImageResponse> uploadTransactionImage($0.UploadTransactionImageRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$uploadTransactionImage, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListTransactionsResponse> listTransactions($0.ListTransactionsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listTransactions, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetCategoriesResponse> getCategories($0.GetCategoriesRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getCategories, request, options: options);
  }

  $grpc.ResponseFuture<$0.CreateCategoryResponse> createCategory($0.CreateCategoryRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createCategory, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateCategoryResponse> updateCategory($0.UpdateCategoryRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateCategory, request, options: options);
  }

  $grpc.ResponseFuture<$0.DeleteCategoryResponse> deleteCategory($0.DeleteCategoryRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteCategory, request, options: options);
  }

  $grpc.ResponseFuture<$0.ReorderCategoriesResponse> reorderCategories($0.ReorderCategoriesRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$reorderCategories, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.transaction.v1.TransactionService')
abstract class TransactionServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.transaction.v1.TransactionService';

  TransactionServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateTransactionRequest, $0.CreateTransactionResponse>(
        'CreateTransaction',
        createTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateTransactionRequest.fromBuffer(value),
        ($0.CreateTransactionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateTransactionRequest, $0.UpdateTransactionResponse>(
        'UpdateTransaction',
        updateTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateTransactionRequest.fromBuffer(value),
        ($0.UpdateTransactionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteTransactionRequest, $0.DeleteTransactionResponse>(
        'DeleteTransaction',
        deleteTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteTransactionRequest.fromBuffer(value),
        ($0.DeleteTransactionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BatchDeleteTransactionsRequest, $0.BatchDeleteTransactionsResponse>(
        'BatchDeleteTransactions',
        batchDeleteTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BatchDeleteTransactionsRequest.fromBuffer(value),
        ($0.BatchDeleteTransactionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UploadTransactionImageRequest, $0.UploadTransactionImageResponse>(
        'UploadTransactionImage',
        uploadTransactionImage_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UploadTransactionImageRequest.fromBuffer(value),
        ($0.UploadTransactionImageResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListTransactionsRequest, $0.ListTransactionsResponse>(
        'ListTransactions',
        listTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListTransactionsRequest.fromBuffer(value),
        ($0.ListTransactionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetCategoriesRequest, $0.GetCategoriesResponse>(
        'GetCategories',
        getCategories_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetCategoriesRequest.fromBuffer(value),
        ($0.GetCategoriesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateCategoryRequest, $0.CreateCategoryResponse>(
        'CreateCategory',
        createCategory_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateCategoryRequest.fromBuffer(value),
        ($0.CreateCategoryResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateCategoryRequest, $0.UpdateCategoryResponse>(
        'UpdateCategory',
        updateCategory_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateCategoryRequest.fromBuffer(value),
        ($0.UpdateCategoryResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteCategoryRequest, $0.DeleteCategoryResponse>(
        'DeleteCategory',
        deleteCategory_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteCategoryRequest.fromBuffer(value),
        ($0.DeleteCategoryResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ReorderCategoriesRequest, $0.ReorderCategoriesResponse>(
        'ReorderCategories',
        reorderCategories_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ReorderCategoriesRequest.fromBuffer(value),
        ($0.ReorderCategoriesResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreateTransactionResponse> createTransaction_Pre($grpc.ServiceCall call, $async.Future<$0.CreateTransactionRequest> request) async {
    return createTransaction(call, await request);
  }

  $async.Future<$0.UpdateTransactionResponse> updateTransaction_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateTransactionRequest> request) async {
    return updateTransaction(call, await request);
  }

  $async.Future<$0.DeleteTransactionResponse> deleteTransaction_Pre($grpc.ServiceCall call, $async.Future<$0.DeleteTransactionRequest> request) async {
    return deleteTransaction(call, await request);
  }

  $async.Future<$0.BatchDeleteTransactionsResponse> batchDeleteTransactions_Pre($grpc.ServiceCall call, $async.Future<$0.BatchDeleteTransactionsRequest> request) async {
    return batchDeleteTransactions(call, await request);
  }

  $async.Future<$0.UploadTransactionImageResponse> uploadTransactionImage_Pre($grpc.ServiceCall call, $async.Future<$0.UploadTransactionImageRequest> request) async {
    return uploadTransactionImage(call, await request);
  }

  $async.Future<$0.ListTransactionsResponse> listTransactions_Pre($grpc.ServiceCall call, $async.Future<$0.ListTransactionsRequest> request) async {
    return listTransactions(call, await request);
  }

  $async.Future<$0.GetCategoriesResponse> getCategories_Pre($grpc.ServiceCall call, $async.Future<$0.GetCategoriesRequest> request) async {
    return getCategories(call, await request);
  }

  $async.Future<$0.CreateCategoryResponse> createCategory_Pre($grpc.ServiceCall call, $async.Future<$0.CreateCategoryRequest> request) async {
    return createCategory(call, await request);
  }

  $async.Future<$0.UpdateCategoryResponse> updateCategory_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateCategoryRequest> request) async {
    return updateCategory(call, await request);
  }

  $async.Future<$0.DeleteCategoryResponse> deleteCategory_Pre($grpc.ServiceCall call, $async.Future<$0.DeleteCategoryRequest> request) async {
    return deleteCategory(call, await request);
  }

  $async.Future<$0.ReorderCategoriesResponse> reorderCategories_Pre($grpc.ServiceCall call, $async.Future<$0.ReorderCategoriesRequest> request) async {
    return reorderCategories(call, await request);
  }

  $async.Future<$0.CreateTransactionResponse> createTransaction($grpc.ServiceCall call, $0.CreateTransactionRequest request);
  $async.Future<$0.UpdateTransactionResponse> updateTransaction($grpc.ServiceCall call, $0.UpdateTransactionRequest request);
  $async.Future<$0.DeleteTransactionResponse> deleteTransaction($grpc.ServiceCall call, $0.DeleteTransactionRequest request);
  $async.Future<$0.BatchDeleteTransactionsResponse> batchDeleteTransactions($grpc.ServiceCall call, $0.BatchDeleteTransactionsRequest request);
  $async.Future<$0.UploadTransactionImageResponse> uploadTransactionImage($grpc.ServiceCall call, $0.UploadTransactionImageRequest request);
  $async.Future<$0.ListTransactionsResponse> listTransactions($grpc.ServiceCall call, $0.ListTransactionsRequest request);
  $async.Future<$0.GetCategoriesResponse> getCategories($grpc.ServiceCall call, $0.GetCategoriesRequest request);
  $async.Future<$0.CreateCategoryResponse> createCategory($grpc.ServiceCall call, $0.CreateCategoryRequest request);
  $async.Future<$0.UpdateCategoryResponse> updateCategory($grpc.ServiceCall call, $0.UpdateCategoryRequest request);
  $async.Future<$0.DeleteCategoryResponse> deleteCategory($grpc.ServiceCall call, $0.DeleteCategoryRequest request);
  $async.Future<$0.ReorderCategoriesResponse> reorderCategories($grpc.ServiceCall call, $0.ReorderCategoriesRequest request);
}
