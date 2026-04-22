import 'package:flutter/material.dart';

/// 高性能虚拟化列表
///
/// 基于 ListView.builder 封装，固定 itemExtent 以优化性能。
/// 支持 1000+ 条目无掉帧。
class VirtualList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double itemExtent;
  final double topPadding;
  final double bottomPadding;
  final double horizontalPadding;
  final Widget? emptyWidget;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final ScrollPhysics? physics;

  const VirtualList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemExtent,
    this.topPadding = 0,
    this.bottomPadding = 80,
    this.horizontalPadding = 0,
    this.emptyWidget,
    this.onRefresh,
    this.controller,
    this.separatorBuilder,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    Widget listView;

    if (separatorBuilder != null) {
      listView = ListView.separated(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding, topPadding, horizontalPadding, bottomPadding,
        ),
        itemCount: items.length,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        separatorBuilder: separatorBuilder!,
        itemBuilder: (context, index) =>
            itemBuilder(context, items[index], index),
      );
    } else {
      listView = ListView.builder(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding, topPadding, horizontalPadding, bottomPadding,
        ),
        itemCount: items.length,
        itemExtent: itemExtent,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) =>
            itemBuilder(context, items[index], index),
      );
    }

    if (onRefresh != null) {
      return RefreshIndicator.adaptive(
        onRefresh: onRefresh!,
        child: listView,
      );
    }

    return listView;
  }
}

/// 固定高度的 Sliver 列表
class VirtualSliverList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double itemExtent;

  const VirtualSliverList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemExtent,
  });

  @override
  Widget build(BuildContext context) {
    return SliverFixedExtentList(
      itemExtent: itemExtent,
      delegate: SliverChildBuilderDelegate(
        (context, index) => itemBuilder(context, items[index], index),
        childCount: items.length,
      ),
    );
  }
}
