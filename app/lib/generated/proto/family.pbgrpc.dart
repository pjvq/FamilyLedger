//
//  Generated code. Do not modify.
//  source: family.proto
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

import 'family.pb.dart' as $0;

export 'family.pb.dart';

@$pb.GrpcServiceName('familyledger.family.v1.FamilyService')
class FamilyServiceClient extends $grpc.Client {
  static final _$createFamily = $grpc.ClientMethod<$0.CreateFamilyRequest, $0.CreateFamilyResponse>(
      '/familyledger.family.v1.FamilyService/CreateFamily',
      ($0.CreateFamilyRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.CreateFamilyResponse.fromBuffer(value));
  static final _$joinFamily = $grpc.ClientMethod<$0.JoinFamilyRequest, $0.JoinFamilyResponse>(
      '/familyledger.family.v1.FamilyService/JoinFamily',
      ($0.JoinFamilyRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.JoinFamilyResponse.fromBuffer(value));
  static final _$getFamily = $grpc.ClientMethod<$0.GetFamilyRequest, $0.GetFamilyResponse>(
      '/familyledger.family.v1.FamilyService/GetFamily',
      ($0.GetFamilyRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GetFamilyResponse.fromBuffer(value));
  static final _$generateInviteCode = $grpc.ClientMethod<$0.GenerateInviteCodeRequest, $0.GenerateInviteCodeResponse>(
      '/familyledger.family.v1.FamilyService/GenerateInviteCode',
      ($0.GenerateInviteCodeRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.GenerateInviteCodeResponse.fromBuffer(value));
  static final _$setMemberRole = $grpc.ClientMethod<$0.SetMemberRoleRequest, $0.SetMemberRoleResponse>(
      '/familyledger.family.v1.FamilyService/SetMemberRole',
      ($0.SetMemberRoleRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SetMemberRoleResponse.fromBuffer(value));
  static final _$setMemberPermissions = $grpc.ClientMethod<$0.SetMemberPermissionsRequest, $0.SetMemberPermissionsResponse>(
      '/familyledger.family.v1.FamilyService/SetMemberPermissions',
      ($0.SetMemberPermissionsRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.SetMemberPermissionsResponse.fromBuffer(value));
  static final _$listFamilyMembers = $grpc.ClientMethod<$0.ListFamilyMembersRequest, $0.ListFamilyMembersResponse>(
      '/familyledger.family.v1.FamilyService/ListFamilyMembers',
      ($0.ListFamilyMembersRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ListFamilyMembersResponse.fromBuffer(value));
  static final _$leaveFamily = $grpc.ClientMethod<$0.LeaveFamilyRequest, $0.LeaveFamilyResponse>(
      '/familyledger.family.v1.FamilyService/LeaveFamily',
      ($0.LeaveFamilyRequest value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.LeaveFamilyResponse.fromBuffer(value));

  FamilyServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseFuture<$0.CreateFamilyResponse> createFamily($0.CreateFamilyRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$createFamily, request, options: options);
  }

  $grpc.ResponseFuture<$0.JoinFamilyResponse> joinFamily($0.JoinFamilyRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$joinFamily, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetFamilyResponse> getFamily($0.GetFamilyRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$getFamily, request, options: options);
  }

  $grpc.ResponseFuture<$0.GenerateInviteCodeResponse> generateInviteCode($0.GenerateInviteCodeRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$generateInviteCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.SetMemberRoleResponse> setMemberRole($0.SetMemberRoleRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$setMemberRole, request, options: options);
  }

  $grpc.ResponseFuture<$0.SetMemberPermissionsResponse> setMemberPermissions($0.SetMemberPermissionsRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$setMemberPermissions, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListFamilyMembersResponse> listFamilyMembers($0.ListFamilyMembersRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$listFamilyMembers, request, options: options);
  }

  $grpc.ResponseFuture<$0.LeaveFamilyResponse> leaveFamily($0.LeaveFamilyRequest request, {$grpc.CallOptions? options}) {
    return $createUnaryCall(_$leaveFamily, request, options: options);
  }
}

@$pb.GrpcServiceName('familyledger.family.v1.FamilyService')
abstract class FamilyServiceBase extends $grpc.Service {
  $core.String get $name => 'familyledger.family.v1.FamilyService';

  FamilyServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateFamilyRequest, $0.CreateFamilyResponse>(
        'CreateFamily',
        createFamily_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateFamilyRequest.fromBuffer(value),
        ($0.CreateFamilyResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.JoinFamilyRequest, $0.JoinFamilyResponse>(
        'JoinFamily',
        joinFamily_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.JoinFamilyRequest.fromBuffer(value),
        ($0.JoinFamilyResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetFamilyRequest, $0.GetFamilyResponse>(
        'GetFamily',
        getFamily_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetFamilyRequest.fromBuffer(value),
        ($0.GetFamilyResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GenerateInviteCodeRequest, $0.GenerateInviteCodeResponse>(
        'GenerateInviteCode',
        generateInviteCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GenerateInviteCodeRequest.fromBuffer(value),
        ($0.GenerateInviteCodeResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetMemberRoleRequest, $0.SetMemberRoleResponse>(
        'SetMemberRole',
        setMemberRole_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SetMemberRoleRequest.fromBuffer(value),
        ($0.SetMemberRoleResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SetMemberPermissionsRequest, $0.SetMemberPermissionsResponse>(
        'SetMemberPermissions',
        setMemberPermissions_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SetMemberPermissionsRequest.fromBuffer(value),
        ($0.SetMemberPermissionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListFamilyMembersRequest, $0.ListFamilyMembersResponse>(
        'ListFamilyMembers',
        listFamilyMembers_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListFamilyMembersRequest.fromBuffer(value),
        ($0.ListFamilyMembersResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LeaveFamilyRequest, $0.LeaveFamilyResponse>(
        'LeaveFamily',
        leaveFamily_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LeaveFamilyRequest.fromBuffer(value),
        ($0.LeaveFamilyResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreateFamilyResponse> createFamily_Pre($grpc.ServiceCall call, $async.Future<$0.CreateFamilyRequest> request) async {
    return createFamily(call, await request);
  }

  $async.Future<$0.JoinFamilyResponse> joinFamily_Pre($grpc.ServiceCall call, $async.Future<$0.JoinFamilyRequest> request) async {
    return joinFamily(call, await request);
  }

  $async.Future<$0.GetFamilyResponse> getFamily_Pre($grpc.ServiceCall call, $async.Future<$0.GetFamilyRequest> request) async {
    return getFamily(call, await request);
  }

  $async.Future<$0.GenerateInviteCodeResponse> generateInviteCode_Pre($grpc.ServiceCall call, $async.Future<$0.GenerateInviteCodeRequest> request) async {
    return generateInviteCode(call, await request);
  }

  $async.Future<$0.SetMemberRoleResponse> setMemberRole_Pre($grpc.ServiceCall call, $async.Future<$0.SetMemberRoleRequest> request) async {
    return setMemberRole(call, await request);
  }

  $async.Future<$0.SetMemberPermissionsResponse> setMemberPermissions_Pre($grpc.ServiceCall call, $async.Future<$0.SetMemberPermissionsRequest> request) async {
    return setMemberPermissions(call, await request);
  }

  $async.Future<$0.ListFamilyMembersResponse> listFamilyMembers_Pre($grpc.ServiceCall call, $async.Future<$0.ListFamilyMembersRequest> request) async {
    return listFamilyMembers(call, await request);
  }

  $async.Future<$0.LeaveFamilyResponse> leaveFamily_Pre($grpc.ServiceCall call, $async.Future<$0.LeaveFamilyRequest> request) async {
    return leaveFamily(call, await request);
  }

  $async.Future<$0.CreateFamilyResponse> createFamily($grpc.ServiceCall call, $0.CreateFamilyRequest request);
  $async.Future<$0.JoinFamilyResponse> joinFamily($grpc.ServiceCall call, $0.JoinFamilyRequest request);
  $async.Future<$0.GetFamilyResponse> getFamily($grpc.ServiceCall call, $0.GetFamilyRequest request);
  $async.Future<$0.GenerateInviteCodeResponse> generateInviteCode($grpc.ServiceCall call, $0.GenerateInviteCodeRequest request);
  $async.Future<$0.SetMemberRoleResponse> setMemberRole($grpc.ServiceCall call, $0.SetMemberRoleRequest request);
  $async.Future<$0.SetMemberPermissionsResponse> setMemberPermissions($grpc.ServiceCall call, $0.SetMemberPermissionsRequest request);
  $async.Future<$0.ListFamilyMembersResponse> listFamilyMembers($grpc.ServiceCall call, $0.ListFamilyMembersRequest request);
  $async.Future<$0.LeaveFamilyResponse> leaveFamily($grpc.ServiceCall call, $0.LeaveFamilyRequest request);
}
