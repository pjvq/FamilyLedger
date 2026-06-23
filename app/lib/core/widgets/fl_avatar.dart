import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Avatar size presets.
enum FlAvatarSize {
  /// Small — 32px.
  sm,

  /// Medium — 40px (default).
  md,

  /// Large — 56px.
  lg,

  /// Extra large — 64px.
  xl,
}

/// 用户/家庭成员头像组件。
///
/// 支持网络图片和首字母回退。圆形裁剪，可选 border。
///
/// ```dart
/// FlAvatar(
///   imageUrl: user.avatarUrl,
///   name: user.name,
///   size: FlAvatarSize.lg,
/// )
/// ```
class FlAvatar extends StatelessWidget {
  /// Creates an [FlAvatar].
  const FlAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = FlAvatarSize.md,
    this.showBorder = false,
  });

  /// Network image URL. If null or loading fails, shows initials fallback.
  final String? imageUrl;

  /// User name for generating initials fallback.
  final String? name;

  /// Avatar size preset.
  final FlAvatarSize size;

  /// Whether to show a primary-colored border.
  final bool showBorder;

  double get _diameter {
    switch (size) {
      case FlAvatarSize.sm:
        return 32;
      case FlAvatarSize.md:
        return 40;
      case FlAvatarSize.lg:
        return 56;
      case FlAvatarSize.xl:
        return 64;
    }
  }

  double get _fontSize {
    switch (size) {
      case FlAvatarSize.sm:
        return 12;
      case FlAvatarSize.md:
        return 14;
      case FlAvatarSize.lg:
        return 20;
      case FlAvatarSize.xl:
        return 24;
    }
  }

  String get _initials {
    if (name == null || name!.trim().isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    final first = parts.first.characters.firstOrNull ?? '?';
    if (parts.length >= 2) {
      final second = parts[1].characters.firstOrNull ?? '';
      return '$first$second'.toUpperCase();
    }
    return first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final fallbackBg = isLight
        ? NeutralColorsLight.neutral5
        : NeutralColorsDark.neutral5;

    Widget avatar;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: _diameter / 2,
        backgroundImage: NetworkImage(imageUrl!),
        backgroundColor: fallbackBg,
        child: null,
      );
    } else {
      avatar = CircleAvatar(
        radius: _diameter / 2,
        backgroundColor: fallbackBg,
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: _fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (!showBorder)
      return SizedBox.square(dimension: _diameter, child: avatar);

    return Container(
      width: _diameter + 4,
      height: _diameter + 4,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: ColorTokens.primary, width: 2),
        ),
      ),
      child: Center(child: avatar),
    );
  }
}
