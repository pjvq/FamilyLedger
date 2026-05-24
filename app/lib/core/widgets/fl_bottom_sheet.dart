import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// 标准 Bottom Sheet 封装组件。
///
/// 包含拖拽条、可选标题区、内容区。
/// 提供 [showFlBottomSheet] 便捷方法快速弹出。
///
/// ```dart
/// showFlBottomSheet(
///   context: context,
///   title: '选择分类',
///   builder: (context) => CategoryList(),
/// );
/// ```
class FlBottomSheet extends StatelessWidget {
  /// Creates an [FlBottomSheet].
  const FlBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding,
  });

  /// Sheet content.
  final Widget child;

  /// Optional title displayed below the drag handle.
  final String? title;

  /// Optional trailing widget in the title area (e.g. close button).
  final Widget? trailing;

  /// Content padding. Defaults to horizontal [SpacingTokens.base].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;

    final bgColor =
        isLight ? NeutralColorsLight.neutral0 : NeutralColorsDark.neutral0;
    final handleColor =
        isLight ? NeutralColorsLight.neutral4 : NeutralColorsDark.neutral4;
    final titleColor =
        isLight ? NeutralColorsLight.neutral7 : NeutralColorsDark.neutral7;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RadiusTokens.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: SpacingTokens.sm),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.base,
                vertical: SpacingTokens.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style:
                          TypographyTokens.headlineMd(color: titleColor),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ] else
            const SizedBox(height: SpacingTokens.md),
          Flexible(
            child: Padding(
              padding: padding ??
                  const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
              child: child,
            ),
          ),
          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// 显示 FamilyLedger 风格的底部弹出面板。
///
/// [title] — 可选标题。
/// [builder] — 构建面板内容。
/// [isScrollControlled] — 是否允许内容滚动控制高度（默认 true）。
/// [useSafeArea] — 是否使用安全区域（默认 true）。
Future<T?> showFlBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  Widget? trailing,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool isDismissible = true,
  EdgeInsetsGeometry? padding,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    builder: (context) => FlBottomSheet(
      title: title,
      trailing: trailing,
      padding: padding,
      child: builder(context),
    ),
  );
}
