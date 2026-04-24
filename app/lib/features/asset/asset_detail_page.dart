import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/providers/asset_provider.dart';
import 'update_valuation_dialog.dart';

class AssetDetailPage extends ConsumerStatefulWidget {
  final String assetId;
  const AssetDetailPage({super.key, required this.assetId});

  @override
  ConsumerState<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends ConsumerState<AssetDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assetProvider.notifier).getAsset(widget.assetId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final assetState = ref.watch(assetProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final asset = assetState.currentAsset;

    if (asset == null) {
      return Scaffold(
        appBar: AppBar(),
        body: assetState.isLoading
            ? const SkeletonList(count: 4, itemHeight: 72)
            : const Center(child: Text('资产不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(asset.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('删除资产'),
                    content: Text('确定要删除"${asset.name}"吗？所有估值记录也会被删除。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.expense,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await ref
                      .read(assetProvider.notifier)
                      .deleteAsset(widget.assetId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: AppColors.expense),
                    SizedBox(width: 8),
                    Text('删除'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            _HeaderCard(asset: asset, isDark: isDark, theme: theme),
            const SizedBox(height: 16),

            // Valuation chart
            _ValuationChart(
              valuations: assetState.valuations,
              isDark: isDark,
              theme: theme,
            ),
            const SizedBox(height: 16),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showUpdateValuation(context, ref),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('更新估值'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showDepreciationRuleDialog(context, ref, asset),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('折旧规则'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info card
            _AssetInfoCard(asset: asset, isDark: isDark, theme: theme),
            const SizedBox(height: 16),

            // Valuation records
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                '估值记录',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _ValuationList(
              valuations: assetState.valuations,
              theme: theme,
              isDark: isDark,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showUpdateValuation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => UpdateValuationDialog(
        assetId: widget.assetId,
        onSubmit: (value) async {
          await ref.read(assetProvider.notifier).updateValuation(
                widget.assetId,
                value,
                DateTime.now(),
              );
        },
      ),
    );
  }

  void _showDepreciationRuleDialog(
      BuildContext context, WidgetRef ref, AssetDisplayItem asset) {
    String method = asset.depreciationMethod;
    int years = asset.usefulLifeYears;
    double rate = asset.salvageRate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('折旧规则'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('折旧方式'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'none',
                        label: Text('不折旧', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: 'straight_line',
                        label: Text('直线法', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: 'double_declining',
                        label: Text('双倍余额', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {method},
                    onSelectionChanged: (s) =>
                        setDialogState(() => method = s.first),
                  ),
                ),
                if (method != 'none') ...[
                  const SizedBox(height: 16),
                  Text('使用年限: $years年'),
                  Slider(
                    value: years.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '$years年',
                    onChanged: (v) =>
                        setDialogState(() => years = v.round()),
                  ),
                  const SizedBox(height: 8),
                  Text('残值率: ${(rate * 100).toStringAsFixed(0)}%'),
                  Slider(
                    value: rate,
                    min: 0,
                    max: 0.30,
                    divisions: 30,
                    label: '${(rate * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => setDialogState(() => rate = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref.read(assetProvider.notifier).setDepreciationRule(
                      widget.assetId,
                      method: method,
                      usefulLifeYears: years,
                      salvageRate: rate,
                    );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header Card ──

class _HeaderCard extends StatelessWidget {
  final AssetDisplayItem asset;
  final bool isDark;
  final ThemeData theme;

  const _HeaderCard({
    required this.asset,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final icon = assetTypeIcon(asset.assetType);
    final typeLabel = assetTypeLabel(asset.assetType);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            label: '当前净值${_fmtYuan(asset.currentValue)}元',
            child: Text(
              '¥${_fmtYuan(asset.currentValue)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '当前净值',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          if (asset.depreciationMethod != 'none') ...[
            const SizedBox(height: 12),
            // Progress bar on dark bg
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已折旧 ${(asset.depreciationProgress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '购入 ¥${_fmtYuan(asset.purchasePrice)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: asset.depreciationProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
                minHeight: 6,
              ),
            ),
          ],
        ],
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

// ── Valuation Chart ──

class _ValuationChart extends StatelessWidget {
  final List<ValuationRecord> valuations;
  final bool isDark;
  final ThemeData theme;

  const _ValuationChart({
    required this.valuations,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (valuations.length < 2) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            '需要2条以上估值记录才能显示趋势图',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final sorted = List<ValuationRecord>.from(valuations)
      ..sort((a, b) => a.valuationDate.compareTo(b.valuationDate));

    final spots = sorted.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value / 100);
    }).toList();

    final chartColor = isDark ? AppColors.assetDark : AppColors.asset;

    return Semantics(
      label: '估值历史折线图，共${sorted.length}个数据点',
      child: SizedBox(
        height: 200,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final idx = spot.spotIndex;
                      if (idx >= 0 && idx < sorted.length) {
                        final record = sorted[idx];
                        final dateStr = DateFormat('yyyy/MM/dd')
                            .format(record.valuationDate);
                        return LineTooltipItem(
                          '¥${(record.value / 100).toStringAsFixed(2)}\n$dateStr',
                          TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }
                      return null;
                    }).toList();
                  },
                ),
                getTouchedSpotIndicator: (data, indexes) {
                  return indexes.map((i) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: chartColor.withValues(alpha: 0.4),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: chartColor,
                          strokeWidth: 2,
                          strokeColor: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    );
                  }).toList();
                },
                handleBuiltInTouches: true,
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: chartColor,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: sorted.length <= 20,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: chartColor,
                      strokeWidth: 1.5,
                      strokeColor: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        chartColor.withValues(alpha: 0.2),
                        chartColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
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

// ── Asset Info Card ──

class _AssetInfoCard extends StatelessWidget {
  final AssetDisplayItem asset;
  final bool isDark;
  final ThemeData theme;

  const _AssetInfoCard({
    required this.asset,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '资产信息',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('购入价格', '¥${_fmtYuan(asset.purchasePrice)}'),
            _infoRow(
              '购入日期',
              DateFormat('yyyy年M月d日').format(asset.purchaseDate),
            ),
            _infoRow(
              '折旧方式',
              depreciationMethodLabel(asset.depreciationMethod),
            ),
            if (asset.depreciationMethod != 'none') ...[
              _infoRow('使用年限', '${asset.usefulLifeYears}年'),
              _infoRow('残值率', '${(asset.salvageRate * 100).toStringAsFixed(0)}%'),
            ],
            if (asset.description.isNotEmpty)
              _infoRow('描述', asset.description),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
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

// ── Valuation List ──

class _ValuationList extends StatelessWidget {
  final List<ValuationRecord> valuations;
  final ThemeData theme;
  final bool isDark;

  const _ValuationList({
    required this.valuations,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (valuations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            '暂无估值记录',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    // Show newest first
    final sorted = List<ValuationRecord>.from(valuations)
      ..sort((a, b) => b.valuationDate.compareTo(a.valuationDate));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final record = sorted[index];
        final isManual = record.source == 'manual';
        final sourceLabel = isManual ? '手动估值' : '折旧计算';
        final sourceIcon = isManual
            ? Icons.edit_rounded
            : Icons.trending_down_rounded;
        final sourceColor = isManual
            ? (isDark ? AppColors.assetDark : AppColors.asset)
            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

        return Semantics(
          label: '$sourceLabel，${_fmtYuan(record.value)}元，${DateFormat('yyyy年M月d日').format(record.valuationDate)}',
          child: Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(sourceIcon, color: sourceColor, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sourceLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormat('yyyy-MM-dd')
                              .format(record.valuationDate),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '¥${_fmtYuan(record.value)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
