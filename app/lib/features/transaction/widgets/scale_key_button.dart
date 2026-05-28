import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

/// 带按压缩放动画的按键
///
/// 按下时 scale 缩到 0.92，松开弹回 1.0（spring curve）
class ScaleKeyButton extends StatefulWidget {
  final Widget child;
  final Color bg;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  const ScaleKeyButton({
    super.key,
    required this.child,
    required this.bg,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  @override
  State<ScaleKeyButton> createState() => _ScaleKeyButtonState();
}

class _ScaleKeyButtonState extends State<ScaleKeyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Semantics(
        label: widget.semanticLabel,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onTap();
          },
          onTapCancel: () => _controller.reverse(),
          onLongPress: widget.onLongPress != null
              ? () {
                  _controller.reverse();
                  widget.onLongPress!();
                }
              : null,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: widget.bg,
              borderRadius: BorderRadius.circular(RadiusTokens.md),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
