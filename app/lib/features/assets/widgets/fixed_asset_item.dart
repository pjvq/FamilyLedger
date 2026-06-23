import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/micro_interactions.dart';
import '../../../domain/providers/asset_provider.dart';
import 'asset_type_info.dart';

/// Single fixed asset row with type icon and current value.
class FixedAssetItem extends StatelessWidget {
  final AssetDisplayItem asset;
  final VoidCallback? onTap;

  const FixedAssetItem({super.key, required this.asset, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeInfo = getAssetTypeInfo(asset.assetType);

    return TapScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
        child: Card(
          margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => withHaptic(() => onTap?.call()),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.base,
                vertical: SpacingTokens.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? NeutralColorsDark.neutral2
                          : NeutralColorsLight.neutral2,
                      borderRadius: BorderRadius.circular(RadiusTokens.md),
                    ),
                    child: Icon(
                      typeInfo.icon,
                      size: 20,
                      color: ChartColors.slot7,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.name,
                          style: TypographyTokens.bodyMd().copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeInfo.label,
                          style: TypographyTokens.caption(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '¥${formatCentsWan(asset.currentValue)}',
                    style: TypographyTokens.amount(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
