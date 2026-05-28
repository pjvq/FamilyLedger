import 'package:flutter/material.dart';

/// Mapping from asset type string to display info (icon + label).
/// Using a Map instead of switch statements for DRY (review #9).
class AssetTypeInfo {
  final IconData icon;
  final String label;

  const AssetTypeInfo({required this.icon, required this.label});
}

const Map<String, AssetTypeInfo> assetTypeMap = {
  'real_estate': AssetTypeInfo(icon: Icons.home_rounded, label: '房产'),
  'vehicle': AssetTypeInfo(icon: Icons.directions_car_rounded, label: '车辆'),
  'electronics': AssetTypeInfo(icon: Icons.devices_rounded, label: '电子设备'),
  'jewelry': AssetTypeInfo(icon: Icons.diamond_rounded, label: '珠宝首饰'),
  'furniture': AssetTypeInfo(icon: Icons.chair_rounded, label: '家具家电'),
  'collectible': AssetTypeInfo(icon: Icons.collections_rounded, label: '收藏品'),
};

const _defaultInfo = AssetTypeInfo(icon: Icons.inventory_2_rounded, label: '其他');

AssetTypeInfo getAssetTypeInfo(String type) => assetTypeMap[type] ?? _defaultInfo;
