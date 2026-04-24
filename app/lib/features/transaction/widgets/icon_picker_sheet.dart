import 'package:flutter/material.dart';
import '../../../core/constants/category_icons.dart';

/// 图标选择器 BottomSheet
/// 使用: showIconPickerSheet(context, selectedKey: 'food', onSelect: (key) { ... })
Future<void> showIconPickerSheet(
  BuildContext context, {
  String? selectedKey,
  required ValueChanged<String> onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _IconPickerSheet(
      selectedKey: selectedKey,
      onSelect: onSelect,
    ),
  );
}

class _IconPickerSheet extends StatefulWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const _IconPickerSheet({this.selectedKey, required this.onSelect});

  @override
  State<_IconPickerSheet> createState() => _IconPickerSheetState();
}

class _IconPickerSheetState extends State<_IconPickerSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late String? _selected;

  final _groups = CategoryIcons.kIconGroups.entries.toList();

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedKey;
    _tabController = TabController(length: _groups.length, vsync: this);

    // 自动跳到选中图标所在的 tab
    if (_selected != null) {
      for (int i = 0; i < _groups.length; i++) {
        if (_groups[i].value.contains(_selected)) {
          _tabController.index = i;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height * 0.6;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽条
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text('选择图标',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            indicatorSize: TabBarIndicatorSize.label,
            dividerHeight: 0.5,
            tabs: _groups
                .map((e) => Tab(text: e.key, height: 36))
                .toList(),
          ),
          // 图标网格
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _groups.map((group) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: group.value.length,
                  itemBuilder: (context, index) {
                    final key = group.value[index];
                    final isSelected = key == _selected;
                    final color = CategoryIcons.getColor(key);

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selected = key);
                        widget.onSelect(key);
                        Navigator.pop(context);
                      },
                      child: AnimatedScale(
                        scale: isSelected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: color, width: 2.5)
                                    : null,
                              ),
                              child: Icon(
                                CategoryIcons.getIcon(key),
                                size: 24,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CategoryIcons.getLabel(key),
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? color
                                    : theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
