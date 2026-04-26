import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:drift/drift.dart';
import 'package:grpc/grpc.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database.dart';
import '../../data/remote/grpc_clients.dart';
import '../../generated/proto/family.pbgrpc.dart' as pb;
import '../../generated/proto/family.pb.dart' as pb_model;
import '../../generated/proto/family.pbenum.dart' as pb_enum;
import 'app_providers.dart';

class FamilyState {
  final Family? currentFamily;
  final List<Family> families;
  final List<FamilyMember> members;
  final pb_model.MemberPermissions? myPermissions;
  final bool isLoading;
  final String? error;

  const FamilyState({
    this.currentFamily,
    this.families = const [],
    this.members = const [],
    this.myPermissions,
    this.isLoading = false,
    this.error,
  });

  FamilyState copyWith({
    Family? currentFamily,
    bool clearCurrentFamily = false,
    List<Family>? families,
    List<FamilyMember>? members,
    pb_model.MemberPermissions? myPermissions,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      FamilyState(
        currentFamily:
            clearCurrentFamily ? null : (currentFamily ?? this.currentFamily),
        families: families ?? this.families,
        members: members ?? this.members,
        myPermissions: myPermissions ?? this.myPermissions,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class FamilyNotifier extends StateNotifier<FamilyState> {
  final AppDatabase _db;
  final String _userId;
  final pb.FamilyServiceClient? _familyClient;
  final _uuid = const Uuid();
  static final _callOpts = CallOptions(timeout: const Duration(seconds: 5));

  FamilyNotifier(this._db, this._userId, this._familyClient)
      : super(const FamilyState()) {
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      final allFamilies = await _db.getAllFamilies();
      Family? current;
      List<FamilyMember> members = [];

      if (allFamilies.isNotEmpty) {
        // Use first family as current for now
        current = allFamilies.first;
        members = await _db.getFamilyMembers(current.id);
      }

      // Derive permissions from role
      pb_model.MemberPermissions? myPerms;
      if (current != null && members.isNotEmpty) {
        final me = members.where((m) => m.userId == _userId).firstOrNull;
        if (me != null) {
          final role = me.role;
          if (role == 'owner' || role == 'admin') {
            myPerms = pb_model.MemberPermissions()
              ..canView = true
              ..canCreate = true
              ..canEdit = true
              ..canDelete = true
              ..canManageAccounts = true;
          } else {
            myPerms = pb_model.MemberPermissions()
              ..canView = true
              ..canCreate = true
              ..canEdit = false
              ..canDelete = false
              ..canManageAccounts = false;
          }
        }
      }

      state = state.copyWith(
        currentFamily: current,
        clearCurrentFamily: current == null,
        families: allFamilies,
        members: members,
        myPermissions: myPerms,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createFamily(String name) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Try gRPC first
      if (_familyClient != null) {
        try {
          final resp = await _familyClient.createFamily(
            pb_model.CreateFamilyRequest()..name = name,
            options: _callOpts,
          );
          final family = resp.family;
          // Save to local DB
          await _db.insertFamily(FamiliesCompanion.insert(
            id: family.id,
            name: family.name,
            ownerId: family.ownerId,
          ));
          // Add self as owner member
          await _db.insertFamilyMember(FamilyMembersCompanion.insert(
            id: _uuid.v4(),
            familyId: family.id,
            userId: _userId,
            role: Value('owner'),
            canView: Value(true),
            canCreate: Value(true),
            canEdit: Value(true),
            canDelete: Value(true),
            canManageAccounts: Value(true),
          ));
          await _load();
          return;
        } catch (e) {
          dev.log('FamilyNotifier: gRPC createFamily failed, fallback local: $e',
              name: 'family');
        }
      }

      // Fallback: local only
      final familyId = _uuid.v4();
      await _db.insertFamily(FamiliesCompanion.insert(
        id: familyId,
        name: name,
        ownerId: _userId,
      ));
      await _db.insertFamilyMember(FamilyMembersCompanion.insert(
        id: _uuid.v4(),
        familyId: familyId,
        userId: _userId,
        role: Value('owner'),
        canView: Value(true),
        canCreate: Value(true),
        canEdit: Value(true),
        canDelete: Value(true),
        canManageAccounts: Value(true),
      ));
      await _load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '创建家庭失败: $e');
    }
  }

  Future<void> joinFamily(String inviteCode) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (_familyClient != null) {
        try {
          final resp = await _familyClient.joinFamily(
            pb_model.JoinFamilyRequest()..inviteCode = inviteCode,
            options: _callOpts,
          );
          final family = resp.family;
          // Save to local
          await _db.insertFamily(FamiliesCompanion.insert(
            id: family.id,
            name: family.name,
            ownerId: family.ownerId,
          ));
          await _db.insertFamilyMember(FamilyMembersCompanion.insert(
            id: _uuid.v4(),
            familyId: family.id,
            userId: _userId,
            role: Value('member'),
          ));

          // Pull members
          try {
            final membersResp = await _familyClient.listFamilyMembers(
              pb_model.ListFamilyMembersRequest()..familyId = family.id,
              options: _callOpts,
            );
            for (final m in membersResp.members) {
              if (m.userId == _userId) continue; // skip self, already added
              await _db.insertFamilyMember(FamilyMembersCompanion.insert(
                id: m.id,
                familyId: family.id,
                userId: m.userId,
                email: Value(m.email),
                role: Value(_protoRoleToString(m.role)),
              ));
            }
          } catch (_) {}

          await _load();
          return;
        } catch (e) {
          state = state.copyWith(
              isLoading: false, error: '加入家庭失败: ${e.toString()}');
          return;
        }
      }
      state = state.copyWith(isLoading: false, error: '需要网络连接才能加入家庭');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加入家庭失败: $e');
    }
  }

  Future<String?> generateInviteCode() async {
    final family = state.currentFamily;
    if (family == null) return null;

    try {
      if (_familyClient != null) {
        try {
          final resp = await _familyClient.generateInviteCode(
            pb_model.GenerateInviteCodeRequest()..familyId = family.id,
            options: _callOpts,
          );
          // Update local family
          final expiresAt = resp.hasExpiresAt()
              ? DateTime.fromMillisecondsSinceEpoch(
                  resp.expiresAt.seconds.toInt() * 1000)
              : DateTime.now().add(const Duration(days: 7));
          await _db.updateFamily(FamiliesCompanion(
            id: Value(family.id),
            name: Value(family.name),
            ownerId: Value(family.ownerId),
            inviteCode: Value(resp.inviteCode),
            inviteExpiresAt: Value(expiresAt),
          ));
          await _load();
          return resp.inviteCode;
        } catch (e) {
          dev.log('FamilyNotifier: gRPC generateInviteCode failed: $e',
              name: 'family');
        }
      }
      // Fallback: generate local code (6-char alphanumeric)
      final code = _uuid.v4().substring(0, 8).toUpperCase();
      final expires = DateTime.now().add(const Duration(days: 7));
      await _db.updateFamily(FamiliesCompanion(
        id: Value(family.id),
        name: Value(family.name),
        ownerId: Value(family.ownerId),
        inviteCode: Value(code),
        inviteExpiresAt: Value(expires),
      ));
      await _load();
      return code;
    } catch (e) {
      state = state.copyWith(error: '生成邀请码失败: $e');
      return null;
    }
  }

  Future<void> setMemberRole(String targetUserId, String role) async {
    final family = state.currentFamily;
    if (family == null) return;

    try {
      if (_familyClient != null) {
        try {
          await _familyClient.setMemberRole(
            pb_model.SetMemberRoleRequest()
              ..familyId = family.id
              ..userId = targetUserId
              ..role = _stringToProtoRole(role),
            options: _callOpts,
          );
        } catch (e) {
          dev.log('FamilyNotifier: gRPC setMemberRole failed: $e',
              name: 'family');
        }
      }
      await _db.updateFamilyMemberRole(family.id, targetUserId, role);
      await _load();
    } catch (e) {
      state = state.copyWith(error: '设置角色失败: $e');
    }
  }

  Future<void> setMemberPermissions({
    required String targetUserId,
    required bool canView,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
    required bool canManageAccounts,
  }) async {
    final family = state.currentFamily;
    if (family == null) return;

    try {
      if (_familyClient != null) {
        try {
          await _familyClient.setMemberPermissions(
            pb_model.SetMemberPermissionsRequest()
              ..familyId = family.id
              ..userId = targetUserId
              ..permissions = (pb_model.MemberPermissions()
                ..canView = canView
                ..canCreate = canCreate
                ..canEdit = canEdit
                ..canDelete = canDelete
                ..canManageAccounts = canManageAccounts),
            options: _callOpts,
          );
        } catch (e) {
          dev.log('FamilyNotifier: gRPC setMemberPermissions failed: $e',
              name: 'family');
        }
      }
      await _db.updateFamilyMemberPermissions(
        familyId: family.id,
        userId: targetUserId,
        canView: canView,
        canCreate: canCreate,
        canEdit: canEdit,
        canDelete: canDelete,
        canManageAccounts: canManageAccounts,
      );
      await _load();
    } catch (e) {
      state = state.copyWith(error: '设置权限失败: $e');
    }
  }

  Future<void> leaveFamily() async {
    final family = state.currentFamily;
    if (family == null) return;

    // Owner cannot leave — must transfer ownership or delete family first
    if (family.ownerId == _userId) {
      state = state.copyWith(error: '创建者不能直接退出家庭，请先转让所有权');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (_familyClient != null) {
        // gRPC is authoritative — if it fails, abort
        await _familyClient.leaveFamily(
          pb_model.LeaveFamilyRequest()..familyId = family.id,
          options: _callOpts,
        );
      }
      // Clean up local only after server success (or offline)
      await _db.deleteFamilyMember(family.id, _userId);
      await _load();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '退出家庭失败: $e');
    }
  }

  Future<void> refreshMembers() async {
    final family = state.currentFamily;
    if (family == null) return;

    if (_familyClient != null) {
      try {
        final resp = await _familyClient.listFamilyMembers(
          pb_model.ListFamilyMembersRequest()..familyId = family.id,
          options: _callOpts,
        );
        // Clear and re-insert
        await _db.deleteAllFamilyMembers(family.id);
        for (final m in resp.members) {
          await _db.insertFamilyMember(FamilyMembersCompanion.insert(
            id: m.id,
            familyId: family.id,
            userId: m.userId,
            email: Value(m.email),
            role: Value(_protoRoleToString(m.role)),
            canView: Value(m.permissions.canView),
            canCreate: Value(m.permissions.canCreate),
            canEdit: Value(m.permissions.canEdit),
            canDelete: Value(m.permissions.canDelete),
            canManageAccounts: Value(m.permissions.canManageAccounts),
          ));
        }
      } catch (e) {
        dev.log('FamilyNotifier: refreshMembers failed: $e', name: 'family');
      }
    }
    final members = await _db.getFamilyMembers(family.id);
    state = state.copyWith(members: members);
  }

  String _protoRoleToString(pb_enum.FamilyRole role) {
    switch (role) {
      case pb_enum.FamilyRole.FAMILY_ROLE_OWNER:
        return 'owner';
      case pb_enum.FamilyRole.FAMILY_ROLE_ADMIN:
        return 'admin';
      case pb_enum.FamilyRole.FAMILY_ROLE_MEMBER:
        return 'member';
      default:
        return 'member';
    }
  }

  pb_enum.FamilyRole _stringToProtoRole(String role) {
    switch (role) {
      case 'owner':
        return pb_enum.FamilyRole.FAMILY_ROLE_OWNER;
      case 'admin':
        return pb_enum.FamilyRole.FAMILY_ROLE_ADMIN;
      case 'member':
        return pb_enum.FamilyRole.FAMILY_ROLE_MEMBER;
      default:
        return pb_enum.FamilyRole.FAMILY_ROLE_MEMBER;
    }
  }
}

final familyProvider =
    StateNotifierProvider<FamilyNotifier, FamilyState>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  pb.FamilyServiceClient? familyClient;
  try {
    familyClient = ref.watch(familyClientProvider);
  } catch (_) {}
  return FamilyNotifier(db, userId ?? '', familyClient);
});

/// Whether the current user can delete in family mode.
/// In personal mode, always true.
final canDeleteProvider = Provider<bool>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return true; // personal mode
  final perms = ref.watch(familyProvider).myPermissions;
  return perms?.canDelete ?? false;
});

/// Whether the current user can edit in family mode.
final canEditProvider = Provider<bool>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return true;
  final perms = ref.watch(familyProvider).myPermissions;
  return perms?.canEdit ?? false;
});

/// Whether the current user can manage accounts in family mode.
final canManageAccountsProvider = Provider<bool>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return true;
  final perms = ref.watch(familyProvider).myPermissions;
  return perms?.canManageAccounts ?? false;
});

/// Whether the current user can create in family mode.
final canCreateProvider = Provider<bool>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return true;
  final perms = ref.watch(familyProvider).myPermissions;
  return perms?.canCreate ?? false;
});
