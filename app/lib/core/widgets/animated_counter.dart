import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 数字滚动计数器
///
/// 数字变化时产生类似老虎机的滚动效果。
/// 支持 ¥ 前缀和自定义样式。
class AnimatedCounter extends StatelessWidget {
  final int value;
  final String prefix;
  final TextStyle? style;
  final Duration duration;
  final int decimalPlaces;
  final bool useWanUnit;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '¥',
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.decimalPlaces = 2,
    this.useWanUnit = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animValue, _) {
        final displayValue = animValue / 100;
        String text;
        if (useWanUnit && displayValue.abs() >= 10000) {
          text =
              '$prefix${(displayValue / 10000).toStringAsFixed(decimalPlaces)}万';
        } else {
          text = '$prefix${displayValue.toStringAsFixed(decimalPlaces)}';
        }

        return Text(
          text,
          style: (style ?? Theme.of(context).textTheme.headlineSmall)
              ?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}

/// 单数字滚轮 — 用于更精致的老虎机效果
class RollingCounter extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final int decimalPlaces;

  const RollingCounter({
    super.key,
    required this.value,
    this.prefix = '¥',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.decimalPlaces = 2,
  });

  @override
  State<RollingCounter> createState() => _RollingCounterState();
}

class _RollingCounterState extends State<RollingCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didUpdateWidget(RollingCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        (widget.style ?? Theme.of(context).textTheme.headlineSmall)?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final currentValue = _oldValue + (widget.value - _oldValue) * t;
        final text = currentValue.toStringAsFixed(widget.decimalPlaces);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.prefix.isNotEmpty)
              Text(widget.prefix, style: effectiveStyle),
            ...text.split('').map((char) {
              if (char == '.' || char == '-') {
                return Text(char, style: effectiveStyle);
              }
              return _SingleDigit(
                digit: int.tryParse(char) ?? 0,
                style: effectiveStyle!,
                progress: t,
              );
            }),
            if (widget.suffix.isNotEmpty)
              Text(widget.suffix, style: effectiveStyle),
          ],
        );
      },
    );
  }
}

class _SingleDigit extends StatelessWidget {
  final int digit;
  final TextStyle style;
  final double progress;

  const _SingleDigit({
    required this.digit,
    required this.style,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final offset = math.sin(progress * math.pi) * 2;
    return Transform.translate(
      offset: Offset(0, -offset),
      child: Text('$digit', style: style),
    );
  }
}
