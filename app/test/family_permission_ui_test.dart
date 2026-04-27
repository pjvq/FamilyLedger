/// Family permission UI tests — validates that UI correctly responds to
/// permission states (canEdit, canDelete, canManageAccounts).
///
/// Uses ProviderScope overrides with fixed state, no `noSuchMethod` fakes
/// needed for the permission providers since they are simple Providers derived
/// from state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Notifier, FamilyNotifier;
import 'package:familyledger/domain/providers/family_provider.dart';
import 'package:familyledger/domain/providers/app_providers.dart';
import 'package:familyledger/generated/proto/family.pb.dart' as pb_model;

void main() {
  group('Family Permission UI Tests', () {
    // Helper: build a simple widget that reads permission providers and shows
    // buttons conditionally (mirrors what the real UI does).
    Widget buildPermissionTestWidget({
      required List<Override> overrides,
    }) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final canEdit = ref.watch(canEditProvider);
              final canDelete = ref.watch(canDeleteProvider);
              final canManageAccounts = ref.watch(canManageAccountsProvider);
              final canCreate = ref.watch(canCreateProvider);

              return Scaffold(
                body: Column(
                  children: [
                    if (canEdit)
                      ElevatedButton(
                        key: const Key('edit_button'),
                        onPressed: () {},
                        child: const Text('编辑'),
                      ),
                    if (canDelete)
                      ElevatedButton(
                        key: const Key('delete_button'),
                        onPressed: () {},
                        child: const Text('删除'),
                      ),
                    if (canManageAccounts)
                      ElevatedButton(
                        key: const Key('manage_accounts_button'),
                        onPressed: () {},
                        child: const Text('管理账户'),
                      ),
                    if (canCreate)
                      ElevatedButton(
                        key: const Key('create_button'),
                        onPressed: () {},
                        child: const Text('新建'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    /// Creates standard overrides for permission testing.
    /// When familyId is null, personal mode (all permissions true).
    /// When familyId is set, family mode, permissions come from FamilyState.
    List<Override> makeOverrides({
      String? familyId,
      pb_model.MemberPermissions? permissions,
    }) {
      return [
        currentFamilyIdProvider.overrideWith((ref) => familyId),
        familyProvider.overrideWith((_) => _FixedFamilyNotifier(
              FamilyState(myPermissions: permissions),
            )),
      ];
    }

    group('Personal mode (no family)', () {
      testWidgets('all buttons visible when no family is set', (tester) async {
        await tester.pumpWidget(buildPermissionTestWidget(
          overrides: makeOverrides(familyId: null),
        ));

        expect(find.byKey(const Key('edit_button')), findsOneWidget);
        expect(find.byKey(const Key('delete_button')), findsOneWidget);
        expect(find.byKey(const Key('manage_accounts_button')), findsOneWidget);
        expect(find.byKey(const Key('create_button')), findsOneWidget);
      });
    });

    group('Family mode - member (restricted)', () {
      testWidgets('canEdit=false hides edit button', (tester) async {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = false
          ..canDelete = false
          ..canManageAccounts = false;

        await tester.pumpWidget(buildPermissionTestWidget(
          overrides: makeOverrides(familyId: 'fam1', permissions: perms),
        ));

        expect(find.byKey(const Key('edit_button')), findsNothing);
        expect(find.byKey(const Key('delete_button')), findsNothing);
        expect(find.byKey(const Key('manage_accounts_button')), findsNothing);
        // canCreate is true for member
        expect(find.byKey(const Key('create_button')), findsOneWidget);
      });

      testWidgets('canDelete=false hides delete button', (tester) async {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = true
          ..canDelete = false
          ..canManageAccounts = false;

        await tester.pumpWidget(buildPermissionTestWidget(
          overrides: makeOverrides(familyId: 'fam1', permissions: perms),
        ));

        expect(find.byKey(const Key('edit_button')), findsOneWidget);
        expect(find.byKey(const Key('delete_button')), findsNothing);
        expect(find.byKey(const Key('manage_accounts_button')), findsNothing);
      });

      testWidgets('canManageAccounts=false hides account management',
          (tester) async {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = true
          ..canDelete = true
          ..canManageAccounts = false;

        await tester.pumpWidget(buildPermissionTestWidget(
          overrides: makeOverrides(familyId: 'fam1', permissions: perms),
        ));

        expect(find.byKey(const Key('edit_button')), findsOneWidget);
        expect(find.byKey(const Key('delete_button')), findsOneWidget);
        expect(find.byKey(const Key('manage_accounts_button')), findsNothing);
      });
    });

    group('Family mode - owner/admin (full access)', () {
      testWidgets('owner sees all buttons', (tester) async {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = true
          ..canDelete = true
          ..canManageAccounts = true;

        await tester.pumpWidget(buildPermissionTestWidget(
          overrides: makeOverrides(familyId: 'fam1', permissions: perms),
        ));

        expect(find.byKey(const Key('edit_button')), findsOneWidget);
        expect(find.byKey(const Key('delete_button')), findsOneWidget);
        expect(find.byKey(const Key('manage_accounts_button')), findsOneWidget);
        expect(find.byKey(const Key('create_button')), findsOneWidget);
      });
    });

    group('Family mode - null permissions (fallback)', () {
      testWidgets('null permissions means no access in family mode',
          (tester) async {
        // When permissions is null (e.g. user not found in members), all
        // permission providers return false in family mode.
        await tester.pumpWidget(buildPermissionTestWidget(
          overrides: makeOverrides(familyId: 'fam1', permissions: null),
        ));

        expect(find.byKey(const Key('edit_button')), findsNothing);
        expect(find.byKey(const Key('delete_button')), findsNothing);
        expect(find.byKey(const Key('manage_accounts_button')), findsNothing);
        // canCreate also defaults to false when null
        expect(find.byKey(const Key('create_button')), findsNothing);
      });
    });

    group('Mixed permission combinations', () {
      testWidgets('can create but nothing else', (tester) async {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = false
          ..canDelete = false
          ..canManageAccounts = false;

        await tester.pumpWidget(buildPermissionTestWidget(
          overrides: makeOverrides(familyId: 'fam1', permissions: perms),
        ));

        expect(find.byKey(const Key('create_button')), findsOneWidget);
        expect(find.byKey(const Key('edit_button')), findsNothing);
        expect(find.byKey(const Key('delete_button')), findsNothing);
        expect(find.byKey(const Key('manage_accounts_button')), findsNothing);
      });

      testWidgets('can edit and delete but cannot manage accounts',
          (tester) async {
        final perms = pb_model.MemberPermissions()
          ..canView = true
          ..canCreate = true
          ..canEdit = true
          ..canDelete = true
          ..canManageAccounts = false;

        await tester.pumpWidget(buildPermissionTestWidget(
          overrides: makeOverrides(familyId: 'fam1', permissions: perms),
        ));

        expect(find.byKey(const Key('edit_button')), findsOneWidget);
        expect(find.byKey(const Key('delete_button')), findsOneWidget);
        expect(find.byKey(const Key('manage_accounts_button')), findsNothing);
        expect(find.byKey(const Key('create_button')), findsOneWidget);
      });
    });
  });
}

/// A minimal FamilyNotifier that holds fixed state and does nothing.
/// No `noSuchMethod` — all methods that might be called are no-ops.
class _FixedFamilyNotifier extends StateNotifier<FamilyState>
    implements FamilyNotifier {
  _FixedFamilyNotifier(FamilyState initialState) : super(initialState);

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
