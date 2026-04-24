import 'package:flutter/material.dart';

/// 滑动删除组件
///
/// 左滑露出红色渐变背景 + 缩放删除图标。
/// 触发二次确认对话框，确认后执行删除回调。
class SwipeToDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final String confirmMessage;
  final String confirmTitle;
  final Key dismissKey;
  final String deleteLabel;
  final String cancelLabel;
  final Color backgroundColor;
  final Duration movementDuration;
  final double borderRadius;

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
    this.movementDuration = const Duration(milliseconds: 300),
    this.borderRadius = 16,
  });

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _bgOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.movementDuration,
    );
    _iconScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDismissUpdate(DismissUpdateDetails details) {
    final progress = details.progress.clamp(0.0, 1.0);
    _controller.value = progress;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFFB22222) : widget.backgroundColor;
    final radius = BorderRadius.circular(widget.borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: Dismissible(
        key: widget.dismissKey,
        direction: DismissDirection.endToStart,
        movementDuration: widget.movementDuration,
        confirmDismiss: (direction) => _showConfirmDialog(context),
        onDismissed: (_) => widget.onDelete(),
        onUpdate: _onDismissUpdate,
        background: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final opacity = _bgOpacity.value;
            return Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    bgColor.withValues(alpha: opacity),
                    bgColor.withValues(alpha: opacity * 0.3),
                  ],
                ),
              ),
              child: Transform.scale(
                scale: _iconScale.value,
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
            );
          },
        ),
        child: widget.child,
      ),
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.confirmTitle),
        content: Text(widget.confirmMessage),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              widget.cancelLabel,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              widget.deleteLabel,
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
