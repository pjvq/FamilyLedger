import 'package:flutter/material.dart';

/// 滑动删除组件
///
/// 左滑露出红色背景 + 删除图标。
/// 触发二次确认对话框，确认后执行删除回调。
class SwipeToDelete extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  final String confirmMessage;
  final String confirmTitle;
  final Key dismissKey;
  final String deleteLabel;
  final String cancelLabel;
  final Color backgroundColor;

  const SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
    required this.dismissKey,
    this.confirmMessage = '确定要删除这条记录吗？',
    this.confirmTitle = '删除确认',
    this.deleteLabel = '删除',
    this.cancelLabel = '取消',
    this.backgroundColor = const Color(0xFFFF3B30),
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _showConfirmDialog(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text(
              '删除',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmMessage),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelLabel,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              deleteLabel,
              style: const TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
