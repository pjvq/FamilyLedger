import 'package:flutter/material.dart';

/// 闪光效果 shimmer 动画
class ShimmerEffect extends StatefulWidget {
  final Widget child;

  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E8E8);
    final highlightColor =
        isDark ? const Color(0xFF4A4A4C) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = _controller.value * 2 - 0.5;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + dx * 2, 0),
              end: Alignment(0.0 + dx * 2, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

/// 骨架文字占位
class SkeletonText extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonText({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 骨架卡片占位
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 100});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerEffect(
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonText(width: 120, height: 16),
            SizedBox(height: 12),
            SkeletonText(width: double.infinity, height: 12),
            SizedBox(height: 8),
            SkeletonText(width: 180, height: 12),
          ],
        ),
      ),
    );
  }
}

/// 骨架列表占位
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.count = 5,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerEffect(
      child: Column(
        children: List.generate(count, (index) {
          return Container(
            height: itemHeight,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonText(
                        width: 80.0 + (index % 3) * 30.0,
                        height: 14,
                      ),
                      const SizedBox(height: 8),
                      SkeletonText(
                        width: 120.0 + (index % 2) * 40.0,
                        height: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const SkeletonText(width: 60, height: 16),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// 骨架仪表盘
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: 8),
          SkeletonCard(height: 140),
          SizedBox(height: 4),
          SkeletonCard(height: 80),
          SizedBox(height: 4),
          SkeletonList(count: 4, itemHeight: 64),
        ],
      ),
    );
  }
}
