/// Input sanitization utilities for user-provided text.
///
/// All text from user input is untrusted. This module provides
/// validation and sanitization before persistence or transmission.
library;

import 'package:characters/characters.dart';

/// Maximum length for transaction notes (server enforces 1000,
/// we enforce the same client-side to fail fast).
const int maxNoteLength = 1000;

/// Maximum length for transaction tags.
const int maxTagsLength = 500;

/// Maximum length for image URLs field.
const int maxImageUrlsLength = 2000;

/// Sanitizes a user-provided note string.
///
/// - Trims leading/trailing whitespace
/// - Strips control characters (except newline/tab)
/// - Truncates to [maxNoteLength] using grapheme-safe boundary
/// - Returns empty string for null input
///
/// This does NOT strip HTML because notes are rendered as plain text.
/// If notes are ever rendered in a WebView, add HTML escaping here.
String sanitizeNote(String? input) {
  if (input == null || input.isEmpty) return '';

  // Strip control characters except \n and \t (which users may legitimately type).
  // Note: sanitizeTags uses a broader range (includes \n/\t) because tags
  // are single-line comma-separated values where newlines are never valid.
  final cleaned = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

  final trimmed = cleaned.trim();
  if (trimmed.length > maxNoteLength) {
    return _truncateGraphemeSafe(trimmed, maxNoteLength);
  }
  return trimmed;
}

/// Sanitizes tags string (comma-separated values).
///
/// - Trims each tag
/// - Removes empty tags
/// - Strips ALL control characters (tags are single-line; \n and \t are invalid)
/// - Truncates total length to [maxTagsLength] using grapheme-safe boundary
String sanitizeTags(String? input) {
  if (input == null || input.isEmpty) return '';

  final tags = input
      .split(',')
      .map((t) => t.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ''))
      .where((t) => t.isNotEmpty)
      .toList();

  final joined = tags.join(',');
  if (joined.length > maxTagsLength) {
    return _truncateGraphemeSafe(joined, maxTagsLength);
  }
  return joined;
}

/// Sanitizes image URLs field.
///
/// - Strips control characters
/// - Validates each URL starts with http/https
/// - Truncates total length to [maxImageUrlsLength]
String sanitizeImageUrls(String? input) {
  if (input == null || input.isEmpty) return '';

  final urls = input
      .split(',')
      .map((u) => u.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ''))
      .where((u) => u.startsWith('https://'))
      .toList();

  final joined = urls.join(',');
  if (joined.length > maxImageUrlsLength) {
    // Truncate at last comma before limit to avoid cutting a URL mid-way
    final sub = joined.substring(0, maxImageUrlsLength);
    final lastComma = sub.lastIndexOf(',');
    return lastComma > 0 ? sub.substring(0, lastComma) : sub;
  }
  return joined;
}

/// Truncates a string at a grapheme cluster boundary to avoid splitting
/// surrogate pairs or combined emoji sequences.
///
/// Uses the `characters` package (ICU-based) to iterate grapheme clusters.
/// Stops accumulating when adding the next cluster would exceed [maxCodeUnits].
String _truncateGraphemeSafe(String input, int maxCodeUnits) {
  final buffer = StringBuffer();
  for (final grapheme in input.characters) {
    if (buffer.length + grapheme.length > maxCodeUnits) break;
    buffer.write(grapheme);
  }
  return buffer.toString();
}
