//
//  Generated code. Do not modify.
//  source: account.proto
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

import 'account.pb.dart' as $1;

export 'account.pb.dart';

@$pb.GrpcServiceName('familyledger.account.v1.AccountService')
class AccountServiceClient extends $grpc.Client {
  static final _$createAccount = $grpc.ClientMethod<$1.CreateAccountRequest, $1.CreateAccountResponse>(
      '/familyledger.account.v1.AccountService/CreateAccount',
      ($1.CreateAccountRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.CreateAccountResponse.fromBuffer(value));
  static final _$listAccounts = $grpc.ClientMethod<$1.ListAccountsRequest, $1.ListAccountsResponse>(
      '/familyledger.account.v1.AccountService/ListAccounts',
      ($1.ListAccountsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.ListAccountsResponse.fromBuffer(value));
  static final _$getAccount = $grpc.ClientMethod<$1.GetAccountRequest, $1.GetAccountResponse>(
      '/familyledger.account.v1.AccountService/GetAccount',
      ($1.GetAccountRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.GetAccountResponse.fromBuffer(value));
  static final _$updateAccount = $grpc.ClientMethod<$1.UpdateAccountRequest, $1.UpdateAccountResponse>(
      '/familyledger.account.v1.AccountService/UpdateAccount',
      ($1.UpdateAccountRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.UpdateAccountResponse.fromBuffer(value));
  static final _$deleteAccount = $grpc.ClientMethod<$1.DeleteAccountRequest, $1.DeleteAccountResponse>(
      '/familyledger.account.v1.AccountService/DeleteAccount',
      ($1.DeleteAccountRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.DeleteAccountResponse.fromBuffer(value));
  static final _$transferBetween = $grpc.ClientMethod<$1.TransferBetweenRequest, $1.TransferBetweenResponse>(
      '/familyledger.account.v1.AccountService/TransferBetween',
      ($1.TransferBetweenRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.TransferBetweenResponse.fromBuffer(value));

  AccountServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$1.CreateAccountResponse> createAccount($1.CreateAccountRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createAccount, request, options: options);
  }

  $grpc.ResponseFuture<$1.ListAccountsResponse> listAccounts($1.ListAccountsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listAccounts, request, options: options);
  }

  $grpc.ResponseFuture<$1.GetAccountResponse> getAccount($1.GetAccountRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getAccount, request, options: options);
  }

  $grpc.ResponseFuture<$1.UpdateAccountResponse> updateAccount($1.UpdateAccountRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateAccount, request, options: options);
  }

  $grpc.ResponseFuture<$1.DeleteAccountResponse> deleteAccount($1.DeleteAccountRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteAccount, request, options: options);
  }

  $grpc.ResponseFuture<$1.TransferBetweenResponse> transferBetween($1.TransferBetweenRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$transferBetween, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.account.v1.AccountService')
abstract class AccountServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.account.v1.AccountService';

  AccountServiceBase() {
    $addMethod($grpc.ServiceMethod<$1.CreateAccountRequest, $1.CreateAccountResponse>(
        'CreateAccount',
        createAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.CreateAccountRequest.fromBuffer(value),
        ($1.CreateAccountResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.ListAccountsRequest, $1.ListAccountsResponse>(
        'ListAccounts',
        listAccounts_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.ListAccountsRequest.fromBuffer(value),
        ($1.ListAccountsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.GetAccountRequest, $1.GetAccountResponse>(
        'GetAccount',
        getAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.GetAccountRequest.fromBuffer(value),
        ($1.GetAccountResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.UpdateAccountRequest, $1.UpdateAccountResponse>(
        'UpdateAccount',
        updateAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.UpdateAccountRequest.fromBuffer(value),
        ($1.UpdateAccountResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.DeleteAccountRequest, $1.DeleteAccountResponse>(
        'DeleteAccount',
        deleteAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.DeleteAccountRequest.fromBuffer(value),
        ($1.DeleteAccountResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.TransferBetweenRequest, $1.TransferBetweenResponse>(
        'TransferBetween',
        transferBetween_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.TransferBetweenRequest.fromBuffer(value),
        ($1.TransferBetweenResponse value) => value.writeToBuffer()));
  }

  $async.Future<$1.CreateAccountResponse> createAccount_Pre($grpc.ServiceCall call, $async.Future<$1.CreateAccountRequest> request) async {
    return createAccount(call, await request);
  }

  $async.Future<$1.ListAccountsResponse> listAccounts_Pre($grpc.ServiceCall call, $async.Future<$1.ListAccountsRequest> request) async {
    return listAccounts(call, await request);
  }

  $async.Future<$1.GetAccountResponse> getAccount_Pre($grpc.ServiceCall call, $async.Future<$1.GetAccountRequest> request) async {
    return getAccount(call, await request);
  }

  $async.Future<$1.UpdateAccountResponse> updateAccount_Pre($grpc.ServiceCall call, $async.Future<$1.UpdateAccountRequest> request) async {
    return updateAccount(call, await request);
  }

  $async.Future<$1.DeleteAccountResponse> deleteAccount_Pre($grpc.ServiceCall call, $async.Future<$1.DeleteAccountRequest> request) async {
    return deleteAccount(call, await request);
  }

  $async.Future<$1.TransferBetweenResponse> transferBetween_Pre($grpc.ServiceCall call, $async.Future<$1.TransferBetweenRequest> request) async {
    return transferBetween(call, await request);
  }

  $async.Future<$1.CreateAccountResponse> createAccount($grpc.ServiceCall call, $1.CreateAccountRequest request);
  $async.Future<$1.ListAccountsResponse> listAccounts($grpc.ServiceCall call, $1.ListAccountsRequest request);
  $async.Future<$1.GetAccountResponse> getAccount($grpc.ServiceCall call, $1.GetAccountRequest request);
  $async.Future<$1.UpdateAccountResponse> updateAccount($grpc.ServiceCall call, $1.UpdateAccountRequest request);
  $async.Future<$1.DeleteAccountResponse> deleteAccount($grpc.ServiceCall call, $1.DeleteAccountRequest request);
  $async.Future<$1.TransferBetweenResponse> transferBetween($grpc.ServiceCall call, $1.TransferBetweenRequest request);
}
