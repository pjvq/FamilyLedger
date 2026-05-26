/// Family permission provider tests — validates that permission providers
/// correctly respond to personal/family mode states.
///
/// Uses ProviderContainer (no widget pumping needed), avoiding flutter_tester
/// subprocess which can segfault on memory-constrained CI runners.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
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

  // Widget-level smoke tests: verify provider values actually affect rendered UI.
  _widgetSmokeTests();
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
  @override
  void switchMode({required bool toFamily}) {}
}

/// Minimal widget that reads permission providers to show/hide buttons.
class _PermissionTestWidget extends ConsumerWidget {
  const _PermissionTestWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(canEditProvider);
    final canDelete = ref.watch(canDeleteProvider);
    final canManage = ref.watch(canManageAccountsProvider);
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            if (canEdit)
              const ElevatedButton(onPressed: null, child: Text('Edit')),
            if (canDelete)
              const ElevatedButton(onPressed: null, child: Text('Delete')),
            if (canManage)
              const ElevatedButton(onPressed: null, child: Text('Manage')),
          ],
        ),
      ),
    );
  }
}

void _widgetSmokeTests() {
  group('Widget smoke tests', () {
    testWidgets('restricted member: no edit/delete/manage buttons',
        (tester) async {
      final perms = pb_model.MemberPermissions()
        ..canView = true
        ..canCreate = true
        ..canEdit = false
        ..canDelete = false
        ..canManageAccounts = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentFamilyIdProvider.overrideWith((ref) => 'fam1'),
            familyProvider.overrideWith(
                (_) => _FixedFamilyNotifier(FamilyState(myPermissions: perms))),
          ],
          child: const _PermissionTestWidget(),
        ),
      );

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Manage'), findsNothing);
    });

    testWidgets('owner: all buttons visible', (tester) async {
      final perms = pb_model.MemberPermissions()
        ..canView = true
        ..canCreate = true
        ..canEdit = true
        ..canDelete = true
        ..canManageAccounts = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentFamilyIdProvider.overrideWith((ref) => 'fam1'),
            familyProvider.overrideWith(
                (_) => _FixedFamilyNotifier(FamilyState(myPermissions: perms))),
          ],
          child: const _PermissionTestWidget(),
        ),
      );

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);
    });

    testWidgets('mixed: canEdit=true, canDelete=false, canManage=false',
        (tester) async {
      final perms = pb_model.MemberPermissions()
        ..canView = true
        ..canCreate = true
        ..canEdit = true
        ..canDelete = false
        ..canManageAccounts = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentFamilyIdProvider.overrideWith((ref) => 'fam1'),
            familyProvider.overrideWith(
                (_) => _FixedFamilyNotifier(FamilyState(myPermissions: perms))),
          ],
          child: const _PermissionTestWidget(),
        ),
      );

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Manage'), findsNothing);
    });
  });
}
