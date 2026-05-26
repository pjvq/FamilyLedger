import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../domain/providers/transaction_flow_provider.dart';

/// 视图模式切换栏（按时间 / 按分类 / 按账户）。
class ViewModeBar extends StatelessWidget {
  static final _pillRadius = BorderRadius.circular(RadiusTokens.full);

  final FlowViewMode current;
  final ValueChanged<FlowViewMode> onChanged;

  const ViewModeBar({super.key, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.base,
        vertical: SpacingTokens.sm,
      ),
      child: Row(
        children: FlowViewMode.values.map((mode) {
          final isSelected = mode == current;
          return Padding(
            padding: const EdgeInsets.only(right: SpacingTokens.sm),
            child: Material(
              color: Colors.transparent,
              borderRadius: _pillRadius,
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  color: isSelected
                      ? ColorTokens.primaryLight
                      : (isDark
                          ? NeutralColorsDark.neutral2
                          : NeutralColorsLight.neutral2),
                  borderRadius: _pillRadius,
                ),
                child: InkWell(
                  borderRadius: _pillRadius,
                  onTap: () => onChanged(mode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.md,
                      vertical: SpacingTokens.sm,
                    ),
                    child: Text(
                      _modeLabel(mode),
                      style: TypographyTokens.bodySm(
                        color: isSelected
                            ? ColorTokens.primary
                            : (isDark
                                ? NeutralColorsDark.neutral5
                                : NeutralColorsLight.neutral5),
                      ).copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _modeLabel(FlowViewMode mode) {
    switch (mode) {
      case FlowViewMode.byTime:
        return '按时间';
      case FlowViewMode.byCategory:
        return '按分类';
      case FlowViewMode.byAccount:
        return '按账户';
    }
  }
}
