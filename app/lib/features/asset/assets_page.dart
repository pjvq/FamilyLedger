import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/providers/asset_provider.dart';
import '../../sync/sync_engine.dart';

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assetProvider.notifier).listAssets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final assetState = ref.watch(assetProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('固定资产'),
      ),
      body: assetState.isLoading && assetState.assets.isEmpty
          ? const SkeletonList(count: 4, itemHeight: 80)
          : assetState.error != null && assetState.assets.isEmpty
              ? ErrorState(
                  message: assetState.error!,
                  onRetry: () => ref.read(assetProvider.notifier).listAssets(),
                )
              : assetState.assets.isEmpty
              ? _EmptyState(theme: theme)
              : CustomRefreshIndicator(
                  onRefresh: () async {
                      await ref.read(syncEngineProvider).forcePull();
                      await ref.read(assetProvider.notifier).listAssets();
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // Summary card
                      _SummaryCard(
                        totalNetValue: assetState.totalNetValue,
                        count: assetState.assets.length,
                        isDark: isDark,
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      // Asset cards
                      ...assetState.assets.map((asset) => _AssetCard(
                            asset: asset,
                            isDark: isDark,
                            theme: theme,
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRouter.assetDetail,
                              arguments: asset.id,
                            ),
                          )),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed(AppRouter.addAsset);
          if (mounted) {
            ref.read(assetProvider.notifier).listAssets();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加资产'),
      ),
    );
  }
}

// ── Summary Card ──

class _SummaryCard extends StatelessWidget {
  final int totalNetValue;
  final int count;
  final bool isDark;
  final ThemeData theme;

  const _SummaryCard({
    required this.totalNetValue,
    required this.count,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '资产总净值${_fmtYuan(totalNetValue)}元，共$count项',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2A3A), const Color(0xFF0F1F2F)]
                : [AppColors.asset, const Color(0xFF0056CC)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '资产总净值',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '¥ ${_fmtYuan(totalNetValue)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '共 $count 项资产',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtYuan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }
}

// ── Asset Card ──

class _AssetCard extends StatelessWidget {
  final AssetDisplayItem asset;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _AssetCard({
    required this.asset,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = assetTypeIcon(asset.assetType);
    final typeLabel = assetTypeLabel(asset.assetType);

    return Semantics(
      label: '${asset.name}，$typeLabel，当前净值${_fmtYuan(asset.currentValue)}元',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Type icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.assetDark.withValues(alpha: 0.15)
                            : AppColors.asset.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3A3A3C)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Current value
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${_fmtYuan(asset.currentValue)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isDark ? AppColors.assetDark : AppColors.asset,
                          ),
                        ),
                        Text(
                          '购入 ¥${_fmtYuan(asset.purchasePrice)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Depreciation progress bar
                if (asset.depreciationMethod != 'none') ...[
                  const SizedBox(height: 12),
                  _DepreciationProgressBar(
                    progress: asset.depreciationProgress,
                    isDark: isDark,
                    theme: theme,
                  ),
                ],
                // Purchase date
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${asset.purchaseDate.year}-${asset.purchaseDate.month.toString().padLeft(2, '0')}-${asset.purchaseDate.day.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                    if (asset.depreciationMethod != 'none') ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.trending_down_rounded,
                        size: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        depreciationMethodLabel(asset.depreciationMethod),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtYuan(int cents) {
    final yuan = cents / 100;
    if (yuan.abs() >= 10000) {
      return '${(yuan / 10000).toStringAsFixed(2)}万';
    }
    return yuan.toStringAsFixed(2);
  }
}

// ── Depreciation Progress Bar ──

class _DepreciationProgressBar extends StatelessWidget {
  final double progress;
  final bool isDark;
  final ThemeData theme;

  const _DepreciationProgressBar({
    required this.progress,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? const Color(0xFF2A3A4A)
        : const Color(0xFFD6E8FF);
    final fillColor = isDark
        ? AppColors.assetDark
        : AppColors.asset;

    return Semantics(
      label: '折旧进度${(progress * 100).toStringAsFixed(0)}%',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已折旧',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fillColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: bgColor,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.real_estate_agent_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有固定资产',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加您的房产、车辆、电子设备等\n自动计算折旧，跟踪资产净值',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
