import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/micro_interactions.dart';
import '../../../data/local/database.dart';

/// Single account row in the assets tab.
class AccountItem extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;

  const AccountItem({super.key, required this.account, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPositive = account.balance >= 0;
    final amountColor = isPositive
        ? context.semanticColors.income
        : context.semanticColors.expense;

    return TapScale(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.base),
        child: Card(
          margin: const EdgeInsets.only(bottom: SpacingTokens.xs),
          clipBehavior: Clip.antiAlias,
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
                  child: Center(
                    child: Text(account.icon,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Text(
                    account.name,
                    style: TypographyTokens.bodyMd().copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '¥${formatCentsCompact(account.balance)}',
                  style: TypographyTokens.amount(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
