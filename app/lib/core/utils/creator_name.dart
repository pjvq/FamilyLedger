import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/app_providers.dart';
import '../../domain/providers/family_provider.dart';

/// Resolves a transaction creator's display name from the family member list.
///
/// Returns:
/// - `'我'` if the creator is the current user
/// - The member's email prefix (before @) if found in family members
/// - [fallback] if the member is not found (defaults to first 8 chars of userId)
/// - `null` if [txnUserId] is empty
String? creatorDisplayName(
  WidgetRef ref,
  String txnUserId, {
  String? Function(String userId)? fallback,
}) {
  if (txnUserId.isEmpty) return null;
  final currentUserId = ref.read(currentUserIdProvider);
  if (txnUserId == currentUserId) return '我';
  final members = ref.read(familyProvider).members;
  final member = members.where((m) => m.userId == txnUserId).firstOrNull;
  if (member == null) {
    return fallback != null ? fallback(txnUserId) : txnUserId.length > 8 ? txnUserId.substring(0, 8) : txnUserId;
  }
  final email = member.email;
  return email.contains('@') ? email.split('@').first : email;
}
