/// Input sanitization utilities for user-provided text.
///
/// All text from user input is untrusted. This module provides
/// validation and sanitization before persistence or transmission.
library;

/// Maximum length for transaction notes (server enforces 1000,
/// we enforce the same client-side to fail fast).
const int maxNoteLength = 1000;

/// Maximum length for transaction tags.
const int maxTagsLength = 500;

/// Sanitizes a user-provided note string.
///
/// - Trims leading/trailing whitespace
/// - Strips control characters (except newline/tab)
/// - Truncates to [maxNoteLength]
/// - Returns empty string for null input
///
/// This does NOT strip HTML because notes are rendered as plain text.
/// If notes are ever rendered in a WebView, add HTML escaping here.
String sanitizeNote(String? input) {
  if (input == null || input.isEmpty) return '';

  // Strip control characters except \n and \t (which users may legitimately type)
  final cleaned = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

  final trimmed = cleaned.trim();
  if (trimmed.length > maxNoteLength) {
    return trimmed.substring(0, maxNoteLength);
  }
  return trimmed;
}

/// Sanitizes tags string (comma-separated values).
///
/// - Trims each tag
/// - Removes empty tags
/// - Strips control characters
/// - Truncates total length to [maxTagsLength]
String sanitizeTags(String? input) {
  if (input == null || input.isEmpty) return '';

  final tags = input
      .split(',')
      .map((t) => t.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ''))
      .where((t) => t.isNotEmpty)
      .toList();

  final joined = tags.join(',');
  if (joined.length > maxTagsLength) {
    return joined.substring(0, maxTagsLength);
  }
  return joined;
}
