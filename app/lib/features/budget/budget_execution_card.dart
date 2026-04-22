import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Circular progress ring showing budget execution rate.
/// Includes pulse animation when overspent (rate >= 1.0).
class BudgetExecutionCard extends StatefulWidget {
  final double executionRate;
  final int totalBudget; // cents
  final int totalSpent; // cents

  const BudgetExecutionCard({
    super.key,
    required this.executionRate,
    required this.totalBudget,
    required this.totalSpent,
  });

  @override
  State<BudgetExecutionCard> createState() => _BudgetExecutionCardState();
}

class _BudgetExecutionCardState extends State<BudgetExecutionCard>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _pulseController;
  late Animation<double> _ringAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _ringAnimation = Tween<double>(begin: 0.0, end: widget.executionRate)
        .animate(CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    ));
    _ringController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.executionRate >= 1.0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BudgetExecutionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.executionRate != widget.executionRate) {
      _ringAnimation = Tween<double>(
        begin: _ringAnimation.value,
        end: widget.executionRate,
      ).animate(CurvedAnimation(
        parent: _ringController,
        curve: Curves.easeOutCubic,
      ));
      _ringController
        ..reset()
        ..forward();

      if (widget.executionRate >= 1.0) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _rateColor(double rate) {
    if (rate >= 0.8) return AppColors.expense;
    if (rate >= 0.6) return const Color(0xFFFF9500);
    return AppColors.income;
  }

  String _formatAmount(int cents) {
    final yuan = cents / 100;
    final str = yuan.toStringAsFixed(2);
    // Add thousand separators
    final parts = str.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }
    return '¥${buffer.toString()}.$decPart';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pctText =
        '${(widget.executionRate * 100).clamp(0, 999).toStringAsFixed(0)}%';

    return Semantics(
      label:
          '预算执行率 $pctText，已用 ${_formatAmount(widget.totalSpent)}，'
          '预算 ${_formatAmount(widget.totalBudget)}',
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Ring + percentage
              SizedBox(
                width: 160,
                height: 160,
                child: AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _RingPainter(
                        progress: _ringAnimation.value.clamp(0.0, 1.0),
                        color: _rateColor(widget.executionRate),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        strokeWidth: 12,
                      ),
                      child: Center(
                        child: Text(
                          pctText,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _rateColor(widget.executionRate),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Spent / Budget text
              Text(
                '已用 ${_formatAmount(widget.totalSpent)} / 预算 ${_formatAmount(widget.totalBudget)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start from top
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor;
}
