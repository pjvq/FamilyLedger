//
//  Generated code. Do not modify.
//  source: loan.proto
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

import 'google/protobuf/empty.pb.dart' as $1;
import 'loan.pb.dart' as $0;

export 'loan.pb.dart';

@$pb.GrpcServiceName('familyledger.loan.v1.LoanService')
class LoanServiceClient extends $grpc.Client {
  static final _$createLoan = $grpc.ClientMethod<$0.CreateLoanRequest, $0.Loan>(
      '/familyledger.loan.v1.LoanService/CreateLoan',
      ($0.CreateLoanRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Loan.fromBuffer(value));
  static final _$getLoan = $grpc.ClientMethod<$0.GetLoanRequest, $0.Loan>(
      '/familyledger.loan.v1.LoanService/GetLoan',
      ($0.GetLoanRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Loan.fromBuffer(value));
  static final _$listLoans = $grpc.ClientMethod<$0.ListLoansRequest, $0.ListLoansResponse>(
      '/familyledger.loan.v1.LoanService/ListLoans',
      ($0.ListLoansRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListLoansResponse.fromBuffer(value));
  static final _$updateLoan = $grpc.ClientMethod<$0.UpdateLoanRequest, $0.Loan>(
      '/familyledger.loan.v1.LoanService/UpdateLoan',
      ($0.UpdateLoanRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Loan.fromBuffer(value));
  static final _$deleteLoan = $grpc.ClientMethod<$0.DeleteLoanRequest, $1.Empty>(
      '/familyledger.loan.v1.LoanService/DeleteLoan',
      ($0.DeleteLoanRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $1.Empty.fromBuffer(value));
  static final _$getLoanSchedule = $grpc.ClientMethod<$0.GetLoanScheduleRequest, $0.LoanScheduleResponse>(
      '/familyledger.loan.v1.LoanService/GetLoanSchedule',
      ($0.GetLoanScheduleRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.LoanScheduleResponse.fromBuffer(value));
  static final _$simulatePrepayment = $grpc.ClientMethod<$0.SimulatePrepaymentRequest, $0.PrepaymentSimulation>(
      '/familyledger.loan.v1.LoanService/SimulatePrepayment',
      ($0.SimulatePrepaymentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.PrepaymentSimulation.fromBuffer(value));
  static final _$recordRateChange = $grpc.ClientMethod<$0.RecordRateChangeRequest, $0.Loan>(
      '/familyledger.loan.v1.LoanService/RecordRateChange',
      ($0.RecordRateChangeRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.Loan.fromBuffer(value));
  static final _$recordPayment = $grpc.ClientMethod<$0.RecordPaymentRequest, $0.LoanScheduleItem>(
      '/familyledger.loan.v1.LoanService/RecordPayment',
      ($0.RecordPaymentRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.LoanScheduleItem.fromBuffer(value));

  LoanServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.Loan> createLoan($0.CreateLoanRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createLoan, request, options: options);
  }

  $grpc.ResponseFuture<$0.Loan> getLoan($0.GetLoanRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getLoan, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListLoansResponse> listLoans($0.ListLoansRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listLoans, request, options: options);
  }

  $grpc.ResponseFuture<$0.Loan> updateLoan($0.UpdateLoanRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$updateLoan, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteLoan($0.DeleteLoanRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$deleteLoan, request, options: options);
  }

  $grpc.ResponseFuture<$0.LoanScheduleResponse> getLoanSchedule($0.GetLoanScheduleRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getLoanSchedule, request, options: options);
  }

  $grpc.ResponseFuture<$0.PrepaymentSimulation> simulatePrepayment($0.SimulatePrepaymentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$simulatePrepayment, request, options: options);
  }

  $grpc.ResponseFuture<$0.Loan> recordRateChange($0.RecordRateChangeRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$recordRateChange, request, options: options);
  }

  $grpc.ResponseFuture<$0.LoanScheduleItem> recordPayment($0.RecordPaymentRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$recordPayment, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.loan.v1.LoanService')
abstract class LoanServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.loan.v1.LoanService';

  LoanServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateLoanRequest, $0.Loan>(
        'CreateLoan',
        createLoan_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateLoanRequest.fromBuffer(value),
        ($0.Loan value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetLoanRequest, $0.Loan>(
        'GetLoan',
        getLoan_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetLoanRequest.fromBuffer(value),
        ($0.Loan value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListLoansRequest, $0.ListLoansResponse>(
        'ListLoans',
        listLoans_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListLoansRequest.fromBuffer(value),
        ($0.ListLoansResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateLoanRequest, $0.Loan>(
        'UpdateLoan',
        updateLoan_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateLoanRequest.fromBuffer(value),
        ($0.Loan value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteLoanRequest, $1.Empty>(
        'DeleteLoan',
        deleteLoan_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteLoanRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetLoanScheduleRequest, $0.LoanScheduleResponse>(
        'GetLoanSchedule',
        getLoanSchedule_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetLoanScheduleRequest.fromBuffer(value),
        ($0.LoanScheduleResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SimulatePrepaymentRequest, $0.PrepaymentSimulation>(
        'SimulatePrepayment',
        simulatePrepayment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SimulatePrepaymentRequest.fromBuffer(value),
        ($0.PrepaymentSimulation value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RecordRateChangeRequest, $0.Loan>(
        'RecordRateChange',
        recordRateChange_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RecordRateChangeRequest.fromBuffer(value),
        ($0.Loan value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RecordPaymentRequest, $0.LoanScheduleItem>(
        'RecordPayment',
        recordPayment_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RecordPaymentRequest.fromBuffer(value),
        ($0.LoanScheduleItem value) => value.writeToBuffer()));
  }

  $async.Future<$0.Loan> createLoan_Pre($grpc.ServiceCall call, $async.Future<$0.CreateLoanRequest> request) async {
    return createLoan(call, await request);
  }

  $async.Future<$0.Loan> getLoan_Pre($grpc.ServiceCall call, $async.Future<$0.GetLoanRequest> request) async {
    return getLoan(call, await request);
  }

  $async.Future<$0.ListLoansResponse> listLoans_Pre($grpc.ServiceCall call, $async.Future<$0.ListLoansRequest> request) async {
    return listLoans(call, await request);
  }

  $async.Future<$0.Loan> updateLoan_Pre($grpc.ServiceCall call, $async.Future<$0.UpdateLoanRequest> request) async {
    return updateLoan(call, await request);
  }

  $async.Future<$1.Empty> deleteLoan_Pre($grpc.ServiceCall call, $async.Future<$0.DeleteLoanRequest> request) async {
    return deleteLoan(call, await request);
  }

  $async.Future<$0.LoanScheduleResponse> getLoanSchedule_Pre($grpc.ServiceCall call, $async.Future<$0.GetLoanScheduleRequest> request) async {
    return getLoanSchedule(call, await request);
  }

  $async.Future<$0.PrepaymentSimulation> simulatePrepayment_Pre($grpc.ServiceCall call, $async.Future<$0.SimulatePrepaymentRequest> request) async {
    return simulatePrepayment(call, await request);
  }

  $async.Future<$0.Loan> recordRateChange_Pre($grpc.ServiceCall call, $async.Future<$0.RecordRateChangeRequest> request) async {
    return recordRateChange(call, await request);
  }

  $async.Future<$0.LoanScheduleItem> recordPayment_Pre($grpc.ServiceCall call, $async.Future<$0.RecordPaymentRequest> request) async {
    return recordPayment(call, await request);
  }

  $async.Future<$0.Loan> createLoan($grpc.ServiceCall call, $0.CreateLoanRequest request);
  $async.Future<$0.Loan> getLoan($grpc.ServiceCall call, $0.GetLoanRequest request);
  $async.Future<$0.ListLoansResponse> listLoans($grpc.ServiceCall call, $0.ListLoansRequest request);
  $async.Future<$0.Loan> updateLoan($grpc.ServiceCall call, $0.UpdateLoanRequest request);
  $async.Future<$1.Empty> deleteLoan($grpc.ServiceCall call, $0.DeleteLoanRequest request);
  $async.Future<$0.LoanScheduleResponse> getLoanSchedule($grpc.ServiceCall call, $0.GetLoanScheduleRequest request);
  $async.Future<$0.PrepaymentSimulation> simulatePrepayment($grpc.ServiceCall call, $0.SimulatePrepaymentRequest request);
  $async.Future<$0.Loan> recordRateChange($grpc.ServiceCall call, $0.RecordRateChangeRequest request);
  $async.Future<$0.LoanScheduleItem> recordPayment($grpc.ServiceCall call, $0.RecordPaymentRequest request);
}
