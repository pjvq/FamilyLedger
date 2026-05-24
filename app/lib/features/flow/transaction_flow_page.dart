import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../transaction/transaction_history_page.dart';

/// 流水页 — Tab 级全量交易列表。
///
/// Phase 1: 直接复用 [TransactionHistoryPage] 的内容，
/// 去掉顶层 AppBar 的返回按钮（因为它现在是 Tab 页面）。
class TransactionFlowPage extends ConsumerWidget {
  const TransactionFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse existing TransactionHistoryPage — it already handles
    // pagination, refresh, and grouping. It has its own Scaffold with AppBar.
    return const TransactionHistoryPage();
  }
}
