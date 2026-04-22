import 'package:flutter/material.dart';

/// 动画 Tab 下划线指示器
///
/// 下划线跟随选中 tab 滑动，选中文字加粗。
class AnimatedTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final TextStyle? textStyle;
  final Color? indicatorColor;
  final double indicatorHeight;

  const AnimatedTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
    this.textStyle,
    this.indicatorColor,
    this.indicatorHeight = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = indicatorColor ?? theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabs.length;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = index == selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Semantics(
                      label: tabs[index],
                      selected: isSelected,
                      button: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: (textStyle ?? theme.textTheme.bodyMedium!)
                                .copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? activeColor
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                            ),
                            child: Text(tabs[index]),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(
              height: indicatorHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.06),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    left: selectedIndex * tabWidth + tabWidth * 0.2,
                    width: tabWidth * 0.6,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius:
                            BorderRadius.circular(indicatorHeight / 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
