import 'package:flutter/material.dart';

/// Hero 动画 tag 生成辅助
class HeroTags {
  HeroTags._();

  static String transaction(String id) => 'transaction_$id';
  static String investment(String id) => 'investment_$id';
  static String asset(String id) => 'asset_$id';
  static String loan(String id) => 'loan_$id';
  static String account(String id) => 'account_$id';
  static String amount(String id) => 'amount_$id';
}

/// 共享元素包装器
///
/// 方便地包装任何 widget 为 Hero 动画元素。
class SharedElement extends StatelessWidget {
  final String tag;
  final Widget child;
  final CreateRectTween? createRectTween;
  final HeroPlaceholderBuilder? placeholderBuilder;

  const SharedElement({
    super.key,
    required this.tag,
    required this.child,
    this.createRectTween,
    this.placeholderBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      createRectTween: createRectTween ?? _materialRectTween,
      placeholderBuilder: placeholderBuilder,
      flightShuttleBuilder: _flightShuttleBuilder,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }

  static RectTween _materialRectTween(Rect? begin, Rect? end) {
    return MaterialRectArcTween(begin: begin, end: end);
  }

  Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Material(
          type: MaterialType.transparency,
          child: toHeroContext.widget,
        );
      },
    );
  }
}

/// 带 Hero 转场的页面路由
class SharedElementRoute<T> extends PageRouteBuilder<T> {
  SharedElementRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        );
}
