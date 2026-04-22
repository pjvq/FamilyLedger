import 'package:flutter/material.dart';

/// 自定义下拉刷新指示器
///
/// 下拉时显示自定义图标 + 旋转动画。
class CustomRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final IconData icon;
  final Color? iconColor;
  final double displacement;

  const CustomRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.icon = Icons.account_balance_wallet_rounded,
    this.iconColor,
    this.displacement = 40.0,
  });

  @override
  State<CustomRefreshIndicator> createState() =>
      _CustomRefreshIndicatorState();
}

class _CustomRefreshIndicatorState extends State<CustomRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.iconColor ?? theme.colorScheme.primary;

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        _rotationController.repeat();
        try {
          await widget.onRefresh();
        } finally {
          if (mounted) {
            _rotationController.stop();
            _rotationController.reset();
          }
        }
      },
      displacement: widget.displacement,
      color: color,
      child: widget.child,
    );
  }
}

/// 更简洁的刷新包装器
class EasyRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const EasyRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}
