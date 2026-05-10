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

  // Two sections: Material Icons groups + Emoji groups
  // First tab is a special "Emoji" super-tab, rest are Material Icons groups
  static const _emojiTabLabel = 'Emoji';
  final _materialGroups = CategoryIcons.kIconGroups.entries.toList();

  late final List<String> _allTabLabels;
  int _emojiSubIndex = 0; // which emoji sub-group is selected

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedKey;
    _allTabLabels = [
      ..._materialGroups.map((e) => e.key),
      _emojiTabLabel,
    ];
    _tabController = TabController(length: _allTabLabels.length, vsync: this);

    // Auto-jump to selected icon's tab
    if (_selected != null) {
      if (_selected!.startsWith('emoji:')) {
        _tabController.index = _allTabLabels.length - 1; // Emoji tab
      } else {
        for (int i = 0; i < _materialGroups.length; i++) {
          if (_materialGroups[i].value.contains(_selected)) {
            _tabController.index = i;
            break;
          }
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
    final height = MediaQuery.of(context).size.height * 0.65;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
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
            tabs: _allTabLabels
                .map((label) => Tab(text: label, height: 36))
                .toList(),
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Material Icons tabs
                ..._materialGroups.map((group) => _buildMaterialGrid(
                    group.value, theme)),
                // Emoji tab
                _buildEmojiTab(theme),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildMaterialGrid(List<String> keys, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
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
                    color: color.withValues(alpha: 0.12),
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
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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
  }

  Widget _buildEmojiTab(ThemeData theme) {
    final emojiEntries = CategoryIcons.kEmojiGroups.entries.toList();
    final currentEmojis = emojiEntries[_emojiSubIndex].value;
    // Find which sub-group contains the selected emoji (for cross-group indicator)
    final selectedEmoji = (_selected != null && _selected!.startsWith('emoji:'))
        ? _selected!.substring(6)
        : null;
    int? selectedGroupIndex;
    if (selectedEmoji != null) {
      for (int i = 0; i < emojiEntries.length; i++) {
        if (emojiEntries[i].value.contains(selectedEmoji)) {
          selectedGroupIndex = i;
          break;
        }
      }
    }

    return Column(
      children: [
        // Emoji sub-group chips
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: emojiEntries.length,
            itemBuilder: (context, index) {
              final isActive = index == _emojiSubIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  label: Text(
                      (selectedGroupIndex == index && index != _emojiSubIndex)
                          ? '${emojiEntries[index].key} ●'
                          : emojiEntries[index].key,
                      style: const TextStyle(fontSize: 12)),
                  selected: isActive,
                  onSelected: (_) =>
                      setState(() => _emojiSubIndex = index),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  showCheckmark: false,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Emoji grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: currentEmojis.length,
            itemBuilder: (context, index) {
              final emoji = currentEmojis[index];
              final emojiKey = 'emoji:$emoji';
              final isSelected = emojiKey == _selected;

              return GestureDetector(
                onTap: () {
                  setState(() => _selected = emojiKey);
                  widget.onSelect(emojiKey);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
