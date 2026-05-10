import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';

/// A SegmentedButton that lets the user choose between personal and family scope.
/// Automatically defaults to family mode when the app is in family scope.
/// Returns null if user has no family (widget renders nothing).
class FamilyScopeSelector extends ConsumerStatefulWidget {
  final ValueChanged<String?> onChanged; // null = personal, familyId = family

  const FamilyScopeSelector({super.key, required this.onChanged});

  @override
  ConsumerState<FamilyScopeSelector> createState() =>
      _FamilyScopeSelectorState();
}

class _FamilyScopeSelectorState extends ConsumerState<FamilyScopeSelector> {
  late bool _isFamily;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final FamilyState familyState;
    try {
      familyState = ref.watch(familyProvider);
    } catch (_) {
      return const SizedBox.shrink();
    }
    final family = familyState.currentFamily;
    if (family == null) return const SizedBox.shrink();

    final familyId = family.id;

    // Initialize scope from current app mode (once)
    if (!_initialized) {
      _initialized = true;
      final currentFamilyId = ref.read(currentFamilyIdProvider);
      _isFamily = currentFamilyId != null && currentFamilyId.isNotEmpty;
      // Fire initial callback so parent knows the default
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged(_isFamily ? familyId : null);
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('归属', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              const ButtonSegment<bool>(
                  value: false, label: Text('个人'), icon: Icon(Icons.person)),
              ButtonSegment<bool>(
                  value: true,
                  label: Text(family.name),
                  icon: const Icon(Icons.family_restroom)),
            ],
            selected: {_isFamily},
            onSelectionChanged: (v) {
              setState(() => _isFamily = v.first);
              widget.onChanged(_isFamily ? familyId : null);
            },
          ),
        ],
      ),
    );
  }
}
