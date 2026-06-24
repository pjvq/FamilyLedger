import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Haptic feedback intensity levels for tap interactions.
enum HapticType { none, selectionClick, lightImpact, mediumImpact }

/// A pure visual wrapper that adds a subtle scale-down effect on press.
///
/// Uses [Listener] (non-competitive) to drive the animation — does NOT
/// participate in the gesture arena, so child [InkWell]/[ListTile] handles
/// tap recognition, ripple, and callbacks independently.
///
/// Respects `MediaQuery.disableAnimations` (Reduce Motion).
class TapScale extends StatefulWidget {
  final Widget child;
  final double scaleFactor;

  const TapScale({super.key, required this.child, this.scaleFactor = 0.96});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) return widget.child;

    return Listener(
      onPointerDown: (_) => _ctrl.forward(),
      onPointerUp: (_) => _ctrl.reverse(),
      onPointerCancel: (_) => _ctrl.reverse(),
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}

/// Helper: wraps onTap with haptic feedback.
/// Use inside InkWell.onTap when TapScale is the outer wrapper.
void withHaptic(
  VoidCallback callback, {
  HapticType haptic = HapticType.selectionClick,
}) {
  switch (haptic) {
    case HapticType.none:
      break;
    case HapticType.selectionClick:
      HapticFeedback.selectionClick();
    case HapticType.lightImpact:
      HapticFeedback.lightImpact();
    case HapticType.mediumImpact:
      HapticFeedback.mediumImpact();
  }
  callback();
}

/// Staggered fade + slide animation for list items.
///
/// Only animates once (on first build). Respects Reduce Motion.
/// Cap stagger at 10 items to avoid long waits on large lists.
class SlideInItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration duration;

  const SlideInItem({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<SlideInItem> createState() => _SlideInItemState();
}

class _SlideInItemState extends State<SlideInItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _slideAnim = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasAnimated) return;
    _hasAnimated = true;

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _ctrl.value = 1.0;
      return;
    }

    // Only animate first 10 items to cap stagger delay
    if (widget.index > 10) {
      _ctrl.value = 1.0;
      return;
    }

    final delay = widget.baseDelay * widget.index;
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: widget.child),
    );
  }
}

/// Animated number that counts up/down smoothly.
/// Great for balance displays, totals, percentages.
class AnimatedNumber extends StatelessWidget {
  final int value; // in cents
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final bool useWanUnit; // true = show ×万 for large numbers

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 500),
    this.useWanUnit = true,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      final yuan = value / 100;
      String text;
      if (useWanUnit && yuan.abs() >= 10000) {
        text = '$prefix${(yuan / 10000).toStringAsFixed(2)}万$suffix';
      } else {
        text = '$prefix${yuan.toStringAsFixed(2)}$suffix';
      }
      return Text(text, style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final yuan = v / 100;
        String text;
        if (useWanUnit && yuan.abs() >= 10000) {
          text = '$prefix${(yuan / 10000).toStringAsFixed(2)}万$suffix';
        } else {
          text = '$prefix${yuan.toStringAsFixed(2)}$suffix';
        }
        return Text(text, style: style);
      },
    );
  }
}

/// A pulsating dot for indicating live/syncing states.
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 8});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Animated progress bar with smooth width transitions.
class AnimatedProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0+
  final Color color;
  final Color? backgroundColor;
  final double height;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    required this.color,
    this.backgroundColor,
    this.height = 6,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor =
        backgroundColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: bgColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              width: constraints.maxWidth * progress.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            );
          },
        ),
      ),
    );
  }
}
