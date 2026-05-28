import 'package:flutter/material.dart';

import '../../../core/theme/design_tokens.dart';

/// "查看全部" button used at the bottom of truncated sections.
class ShowMoreButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const ShowMoreButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.base,
        vertical: SpacingTokens.xs,
      ),
      child: TextButton(
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
