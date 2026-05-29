import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/category_icon_widget.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/micro_interactions.dart';
import '../../../data/local/database.dart';

/// 单笔交易列表项。
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;
  final VoidCallback onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.category,
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.amount > 0;
    final amountColor = isIncome
        ? context.semanticColors.income
        : context.semanticColors.expense;

    return TapScale(
      child: ListTile(
        onTap: () => hapticTap(onTap),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SpacingTokens.base,
        ),
        leading: category != null
            ? CategoryIconWidget(iconKey: category!.iconKey, size: 40)
            : CircleAvatar(
                radius: 20,
                backgroundColor: isDark
                    ? NeutralColorsDark.neutral2
                    : NeutralColorsLight.neutral2,
                child: const Icon(Icons.receipt_outlined, size: 20),
              ),
        title: Text(
          category?.name ?? '未分类',
          style: TypographyTokens.bodyMd(),
        ),
        subtitle: Text(
          [
            if (transaction.note.isNotEmpty) transaction.note,
            if (account != null) account!.name,
          ].join(' · '),
          style: TypographyTokens.caption(
            color: isDark
                ? NeutralColorsDark.neutral4
                : NeutralColorsLight.neutral4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          formatCents(transaction.amount, showSign: true),
          style: TypographyTokens.amount(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: amountColor,
          ),
        ),
      ),
    );
  }
}
