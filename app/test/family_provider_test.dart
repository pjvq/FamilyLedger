import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:familyledger/data/local/database.dart';
import 'package:familyledger/domain/providers/family_provider.dart';
import 'package:familyledger/generated/proto/family.pb.dart' as pb_model;
import 'package:familyledger/generated/proto/family.pbenum.dart' as pb_enum;
import 'package:familyledger/generated/proto/family.pbgrpc.dart' as pb;

// ─── Fake gRPC ResponseFuture ────────────────────────────────

class FakeResponseFuture<T> implements ResponseFuture<T> {
  final Future<T> _future;
  FakeResponseFuture.value(T value) : _future = Future.value(value);
  FakeResponseFuture.error(Object error) : _future = Future.error(error);

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);
  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      _future.catchError(onError, test: test);
  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);
  @override
  Stream<T> asStream() => _future.asStream();
  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);
  @override
  Future<Map<String, String>> get headers => Future.value({});
  @override
  Future<Map<String, String>> get trailers => Future.value({});
  @override
  Future<void> cancel() => Future.value();
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Fake FamilyServiceClient ────────────────────────────────

class FakeFamilyClient implements pb.FamilyServiceClient {
  pb_model.CreateFamilyResponse? createResponse;
  pb_model.JoinFamilyResponse? joinResponse;
  pb_model.ListFamilyMembersResponse? membersResponse;
  GrpcError? createError;
  GrpcError? joinError;
  GrpcError? leaveError;
  bool leaveCalled = false;

  @override
  ResponseFuture<pb_model.CreateFamilyResponse> createFamily(
      pb_model.CreateFamilyRequest request,
      {CallOptions? options}) {
    if (createError != null) return FakeResponseFuture.error(createError!);
    return FakeResponseFuture.value(createResponse ??
        pb_model.CreateFamilyResponse(
          family: pb_model.Family(
            id: 'server_family_1',
            name: request.name,
            ownerId: 'user1',
          ),
        ));
  }

  @override
  ResponseFuture<pb_model.JoinFamilyResponse> joinFamily(
      pb_model.JoinFamilyRequest request,
      {CallOptions? options}) {
    if (joinError != null) return FakeResponseFuture.error(joinError!);
    return FakeResponseFuture.value(joinResponse ??
        pb_model.JoinFamilyResponse(
          family: pb_model.Family(
            id: 'joined_family',
            name: '被邀请的家庭',
            ownerId: 'owner_user',
          ),
        ));
  }

  @override
  ResponseFuture<pb_model.LeaveFamilyResponse> leaveFamily(
      pb_model.LeaveFamilyRequest request,
      {CallOptions? options}) {
    leaveCalled = true;
    if (leaveError != null) return FakeResponseFuture.error(leaveError!);
    return FakeResponseFuture.value(pb_model.LeaveFamilyResponse());
  }

  @override
  ResponseFuture<pb_model.ListFamilyMembersResponse> listFamilyMembers(
      pb_model.ListFamilyMembersRequest request,
      {CallOptions? options}) {
    return FakeResponseFuture.value(
        membersResponse ?? pb_model.ListFamilyMembersResponse());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not implemented');
}

// ─── DB Setup ────────────────────────────────────────────────

Future<AppDatabase> _setupDb({bool withFamily = false}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customStatement(
      "INSERT OR IGNORE INTO users (id, email, created_at) "
      "VALUES ('user1', 'test@test.com', "
      "${DateTime.now().millisecondsSinceEpoch ~/ 1000})");

  if (withFamily) {
    await db.insertFamily(FamiliesCompanion.insert(
      id: 'existing_family',
      name: '测试家庭',
      ownerId: 'other_owner',
    ));
    await db.insertFamilyMember(FamilyMembersCompanion.insert(
      id: 'member_1',
      familyId: 'existing_family',
      userId: 'user1',
      role: const Value('member'),
      canView: const Value(true),
      canCreate: const Value(true),
      canEdit: const Value(false),
      canDelete: const Value(false),
    ));
  }

  return db;
}

// ─── Tests ───────────────────────────────────────────────────

void main() {
  group('FamilyNotifier', () {
    group('createFamily', () {
      test('online: uses server-assigned family ID', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient();

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final familyId = await notifier.createFamily('小Q家');

        expect(familyId, 'server_family_1');
        expect(notifier.state.currentFamily, isNotNull);
        expect(notifier.state.currentFamily!.name, '小Q家');
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);

        // Verify local DB persisted
        final families = await db.getAllFamilies();
        expect(families.length, 1);
        expect(families.first.id, 'server_family_1');

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });

      test('offline: creates local family with UUID', () async {
        final db = await _setupDb();

        // null client = offline
        final notifier = FamilyNotifier(db, 'user1', null);
        await Future.delayed(const Duration(milliseconds: 100));

        final familyId = await notifier.createFamily('离线家庭');

        expect(familyId, isNotNull);
        expect(familyId!.length, 36); // UUID format
        expect(notifier.state.currentFamily, isNotNull);
        expect(notifier.state.currentFamily!.name, '离线家庭');

        // user1 should be owner
        final members = await db.getFamilyMembers(familyId);
        expect(members.length, 1);
        expect(members.first.role, 'owner');

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });

      test('gRPC error: falls back to local creation', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient();
        client.createError = GrpcError.unavailable('server down');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final familyId = await notifier.createFamily('回退测试');

        // Should still succeed (local fallback)
        expect(familyId, isNotNull);
        expect(familyId!.length, 36);
        expect(notifier.state.error, isNull);

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });
    });

    group('joinFamily', () {
      test('valid invite code: joins successfully', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient();

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final familyId = await notifier.joinFamily('ABC123');

        expect(familyId, 'joined_family');
        expect(notifier.state.currentFamily, isNotNull);
        expect(notifier.state.currentFamily!.name, '被邀请的家庭');

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });

      test('invalid invite code: sets error', () async {
        final db = await _setupDb();
        final client = FakeFamilyClient();
        client.joinError = GrpcError.notFound('invalid invite code');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 100));

        final familyId = await notifier.joinFamily('INVALID');

        expect(familyId, isNull);
        expect(notifier.state.error, contains('加入家庭失败'));

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });

      test('null client (offline): returns error message', () async {
        final db = await _setupDb();

        final notifier = FamilyNotifier(db, 'user1', null);
        await Future.delayed(const Duration(milliseconds: 100));

        final familyId = await notifier.joinFamily('ABC123');

        expect(familyId, isNull);
        expect(notifier.state.error, '需要网络连接才能加入家庭');

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });
    });

    group('permissions', () {
      test('owner gets all permissions', () async {
        final db = await _setupDb();
        // Create family as owner
        final notifier = FamilyNotifier(db, 'user1', null);
        await Future.delayed(const Duration(milliseconds: 100));
        await notifier.createFamily('权限测试');
        await Future.delayed(const Duration(milliseconds: 200));

        expect(notifier.state.myPermissions, isNotNull);
        expect(notifier.state.myPermissions!.canView, true);
        expect(notifier.state.myPermissions!.canCreate, true);
        expect(notifier.state.myPermissions!.canEdit, true);
        expect(notifier.state.myPermissions!.canDelete, true);
        expect(notifier.state.myPermissions!.canManageAccounts, true);

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });

      test('member has limited permissions (canEdit=false, canDelete=false)',
          () async {
        final db = await _setupDb(withFamily: true);

        final notifier = FamilyNotifier(db, 'user1', null);
        await Future.delayed(const Duration(milliseconds: 200));

        expect(notifier.state.myPermissions, isNotNull);
        expect(notifier.state.myPermissions!.canView, true);
        expect(notifier.state.myPermissions!.canCreate, true);
        expect(notifier.state.myPermissions!.canEdit, false);
        expect(notifier.state.myPermissions!.canDelete, false);
        expect(notifier.state.myPermissions!.canManageAccounts, false);

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });
    });

    group('leaveFamily', () {
      test('non-owner can leave', () async {
        final db = await _setupDb(withFamily: true);
        final client = FakeFamilyClient();

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 200));

        expect(notifier.state.currentFamily, isNotNull);
        await notifier.leaveFamily();
        await Future.delayed(const Duration(milliseconds: 200));

        expect(client.leaveCalled, true);
        // After leave, family record still exists in local DB (member deleted)
        // NOTE: This is arguably a bug — user left but family still shows.
        // For now, verify that member was removed from local DB.
        final members = await db.getFamilyMembers('existing_family');
        expect(members.where((m) => m.userId == 'user1'), isEmpty);

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });

      test('owner cannot leave: shows error', () async {
        final db = await _setupDb();
        // Create family as owner first
        final notifier = FamilyNotifier(db, 'user1', null);
        await Future.delayed(const Duration(milliseconds: 100));
        await notifier.createFamily('创建者测试');
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.leaveFamily();

        expect(notifier.state.error, contains('创建者不能直接退出'));
        expect(notifier.state.currentFamily, isNotNull); // Still in family

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });

      test('gRPC error: shows error, does not remove locally', () async {
        final db = await _setupDb(withFamily: true);
        final client = FakeFamilyClient();
        client.leaveError = GrpcError.internal('server error');

        final notifier = FamilyNotifier(db, 'user1', client);
        await Future.delayed(const Duration(milliseconds: 200));

        await notifier.leaveFamily();
        await Future.delayed(const Duration(milliseconds: 100));

        expect(notifier.state.error, contains('退出家庭失败'));
        // Should still be in family (server rejected)
        expect(notifier.state.currentFamily, isNotNull);

        await Future.delayed(const Duration(milliseconds: 100));
        notifier.dispose();
        await db.close();
      });
    });
  });
}
