import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';

class FamilyMembersPage extends ConsumerWidget {
  const FamilyMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyState = ref.watch(familyProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);

    // Check if current user is admin/owner
    final currentMember = familyState.members
        .where((m) => m.userId == currentUserId)
        .firstOrNull;
    final isAdmin = currentMember?.role == 'owner' ||
        currentMember?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭成员'),
      ),
      body: familyState.members.isEmpty
          ? _EmptyState(theme: theme)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: familyState.members.length,
              itemBuilder: (context, index) {
                final member = familyState.members[index];
                return _MemberTile(
                  member: member,
                  isCurrentUser: member.userId == currentUserId,
                  canManage: isAdmin && member.userId != currentUserId,
                  onTap: isAdmin && member.userId != currentUserId
                      ? () => _showMemberSheet(context, ref, member)
                      : null,
                );
              },
            ),
    );
  }

  void _showMemberSheet(
      BuildContext context, WidgetRef ref, FamilyMember member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MemberManageSheet(member: member, ref: ref),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.group_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无成员',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '邀请家人加入吧',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final FamilyMember member;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback? onTap;

  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.canManage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      label: '成员 ${member.email.isNotEmpty ? member.email : member.userId}',
      hint: '角色: ${_roleLabel(member.role)}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isDark
                ? AppColors.primaryDark.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              _avatarText(member),
              style: TextStyle(
                color: isDark ? AppColors.primaryDark : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  member.email.isNotEmpty ? member.email : member.userId,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '(我)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            _roleLabel(member.role),
            style: TextStyle(
              color: _roleColor(member.role),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: canManage
              ? Icon(
                  Icons.settings_rounded,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 20,
                )
              : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: onTap,
        ),
      ),
    );
  }

  String _avatarText(FamilyMember m) {
    if (m.email.isNotEmpty) return m.email[0].toUpperCase();
    return m.userId.isNotEmpty ? m.userId[0].toUpperCase() : '?';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return '创建者';
      case 'admin':
        return '管理员';
      case 'member':
        return '成员';
      default:
        return '成员';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return AppColors.income;
      case 'admin':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _MemberManageSheet extends StatefulWidget {
  final FamilyMember member;
  final WidgetRef ref;

  const _MemberManageSheet({required this.member, required this.ref});

  @override
  State<_MemberManageSheet> createState() => _MemberManageSheetState();
}

class _MemberManageSheetState extends State<_MemberManageSheet> {
  late String _selectedRole;
  late bool _canView;
  late bool _canCreate;
  late bool _canEdit;
  late bool _canDelete;
  late bool _canManageAccounts;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.member.role;
    _canView = widget.member.canView;
    _canCreate = widget.member.canCreate;
    _canEdit = widget.member.canEdit;
    _canDelete = widget.member.canDelete;
    _canManageAccounts = widget.member.canManageAccounts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '管理成员',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.member.email.isNotEmpty
                  ? widget.member.email
                  : widget.member.userId,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),

            // Role selector
            Text(
              '角色',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'admin', label: Text('管理员')),
                ButtonSegment(value: 'member', label: Text('成员')),
              ],
              selected: {_selectedRole == 'owner' ? 'admin' : _selectedRole},
              onSelectionChanged: (selection) {
                setState(() => _selectedRole = selection.first);
              },
            ),
            const SizedBox(height: 24),

            // Permission toggles
            Text(
              '权限',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _PermissionSwitch(
              label: '查看账本',
              value: _canView,
              onChanged: (v) => setState(() => _canView = v),
            ),
            _PermissionSwitch(
              label: '创建交易',
              value: _canCreate,
              onChanged: (v) => setState(() => _canCreate = v),
            ),
            _PermissionSwitch(
              label: '编辑交易',
              value: _canEdit,
              onChanged: (v) => setState(() => _canEdit = v),
            ),
            _PermissionSwitch(
              label: '删除交易',
              value: _canDelete,
              onChanged: (v) => setState(() => _canDelete = v),
            ),
            _PermissionSwitch(
              label: '管理账户',
              value: _canManageAccounts,
              onChanged: (v) => setState(() => _canManageAccounts = v),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final notifier = widget.ref.read(familyProvider.notifier);
    await notifier.setMemberRole(widget.member.userId, _selectedRole);
    await notifier.setMemberPermissions(
      targetUserId: widget.member.userId,
      canView: _canView,
      canCreate: _canCreate,
      canEdit: _canEdit,
      canDelete: _canDelete,
      canManageAccounts: _canManageAccounts,
    );
    Navigator.of(context).pop();
  }
}

class _PermissionSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      child: SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
