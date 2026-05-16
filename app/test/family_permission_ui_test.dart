/// Family permission provider tests — validates that permission providers
/// correctly respond to personal/family mode states.
///
/// Uses ProviderContainer (no widget pumping needed), avoiding flutter_tester
/// subprocess which can segfault on memory-constrained CI runners.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Notifier, FamilyNotifier;
import 'package:familyledger/domain/providers/family_provider.dart';
import 'package:familyledger/domain/providers/app_providers.dart';
import 'package:familyledger/generated/proto/family.pb.dart' as pb_model;

/// Creates a ProviderContainer with permission overrides.
ProviderContainer makeContainer({
  String? familyId,
  pb_model.MemberPermissions? permissions,
}) {
  return ProviderContainer(
    overrides: [
      currentFamilyIdProvider.overrideWith((ref) => familyId),
      familyProvider.overrideWith(
          (_) => _FixedFamilyNotifier(FamilyState(myPermissions: permissions))),
    ],
  );
}

void main() {
  group('Family Permission Provider Tests', () {
    group('Personal mode (no family)', () {
      test('all permissions true when no family is set', () {
        final container = makeContainer(familyId: null);
        addTearDown(container.dispose);

        expect(container.read(canEditProvider), true);
        expect(container.read(canDeleteProvider), true);
        expect(container.read(canManageAccountsProvider), true);
        expect(container.read(canCreateProvider), true);
      });
    });

    group('Family mode - member (restricted)', () {
      test('canEdit=false returns false', () {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = false
          ..canDelete = false
          ..canManageAccounts = false;

        final container =
            makeContainer(familyId: 'fam1', permissions: perms);
        addTearDown(container.dispose);

        expect(container.read(canEditProvider), false);
        expect(container.read(canDeleteProvider), false);
        expect(container.read(canManageAccountsProvider), false);
        expect(container.read(canCreateProvider), true);
      });

      test('canDelete=false returns false', () {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = true
          ..canDelete = false
          ..canManageAccounts = false;

        final container =
            makeContainer(familyId: 'fam1', permissions: perms);
        addTearDown(container.dispose);

        expect(container.read(canEditProvider), true);
        expect(container.read(canDeleteProvider), false);
        expect(container.read(canManageAccountsProvider), false);
      });

      test('canManageAccounts=false returns false', () {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = true
          ..canDelete = true
          ..canManageAccounts = false;

        final container =
            makeContainer(familyId: 'fam1', permissions: perms);
        addTearDown(container.dispose);

        expect(container.read(canEditProvider), true);
        expect(container.read(canDeleteProvider), true);
        expect(container.read(canManageAccountsProvider), false);
      });
    });

    group('Family mode - owner/admin (full access)', () {
      test('owner sees all permissions true', () {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = true
          ..canDelete = true
          ..canManageAccounts = true;

        final container =
            makeContainer(familyId: 'fam1', permissions: perms);
        addTearDown(container.dispose);

        expect(container.read(canEditProvider), true);
        expect(container.read(canDeleteProvider), true);
        expect(container.read(canManageAccountsProvider), true);
        expect(container.read(canCreateProvider), true);
      });
    });

    group('Family mode - null permissions (fallback)', () {
      test('null permissions means no access in family mode', () {
        final container =
            makeContainer(familyId: 'fam1', permissions: null);
        addTearDown(container.dispose);

        expect(container.read(canEditProvider), false);
        expect(container.read(canDeleteProvider), false);
        expect(container.read(canManageAccountsProvider), false);
        expect(container.read(canCreateProvider), false);
      });
    });

    group('Mixed permission combinations', () {
      test('can create but nothing else', () {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = false
          ..canDelete = false
          ..canManageAccounts = false;

        final container =
            makeContainer(familyId: 'fam1', permissions: perms);
        addTearDown(container.dispose);

        expect(container.read(canCreateProvider), true);
        expect(container.read(canEditProvider), false);
        expect(container.read(canDeleteProvider), false);
        expect(container.read(canManageAccountsProvider), false);
      });

      test('can edit and delete but cannot manage accounts', () {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = true
          ..canDelete = true
          ..canManageAccounts = false;

        final container =
            makeContainer(familyId: 'fam1', permissions: perms);
        addTearDown(container.dispose);

        expect(container.read(canEditProvider), true);
        expect(container.read(canDeleteProvider), true);
        expect(container.read(canManageAccountsProvider), false);
        expect(container.read(canCreateProvider), true);
      });
    });
  });
}

/// A minimal FamilyNotifier that holds fixed state.
class _FixedFamilyNotifier extends StateNotifier<FamilyState>
    implements FamilyNotifier {
  _FixedFamilyNotifier(super.initialState);

  @override
  Future<String?> createFamily(String name) async => null;
  @override
  Future<String?> joinFamily(String inviteCode) async => null;
  @override
  Future<String?> generateInviteCode() async => null;
  @override
  Future<void> setMemberRole(String targetUserId, String role) async {}
  @override
  Future<void> setMemberPermissions({
    required String targetUserId,
    required bool canView,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
    required bool canManageAccounts,
  }) async {}
  @override
  Future<void> leaveFamily() async {}
  @override
  Future<void> refreshMembers() async {}
}
