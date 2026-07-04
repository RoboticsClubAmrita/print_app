/// Parses a printer-style page range string (e.g. "1-5, 8, 11-13") into a
/// sorted, de-duplicated list of 1-based page numbers, validated against
/// [totalPages]. An empty/blank [input] means "all pages".
///
/// Throws [FormatException] with a user-facing message if the input is
/// malformed or references a page outside the document.
List<int> parsePageRange(String input, int totalPages) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'all') {
    return List<int>.generate(totalPages, (i) => i + 1);
  }

  final pages = <int>{};
  for (final rawPart in trimmed.split(',')) {
    final part = rawPart.trim();
    if (part.isEmpty) continue;

    if (part.contains('-')) {
      final bounds = part.split('-');
      if (bounds.length != 2) {
        throw FormatException('Invalid range "$part"');
      }
      final start = int.tryParse(bounds[0].trim());
      final end = int.tryParse(bounds[1].trim());
      if (start == null || end == null || start < 1 || end < start) {
        throw FormatException('Invalid range "$part"');
      }
      if (end > totalPages) {
        throw FormatException('Page $end is beyond the document\'s $totalPages pages');
      }
      for (var p = start; p <= end; p++) {
        pages.add(p);
      }
    } else {
      final page = int.tryParse(part);
      if (page == null || page < 1) {
        throw FormatException('Invalid page "$part"');
      }
      if (page > totalPages) {
        throw FormatException('Page $page is beyond the document\'s $totalPages pages');
      }
      pages.add(page);
    }
  }

  if (pages.isEmpty) {
    throw FormatException('Enter at least one page');
  }

  final sorted = pages.toList()..sort();
  return sorted;
}

/// Formats a sorted page list back into a compact range string, e.g.
/// [1,2,3,5,8,9] -> "1-3, 5, 8-9".
String formatPageRange(List<int> pages) {
  if (pages.isEmpty) return '';
  final parts = <String>[];
  var start = pages.first;
  var prev = pages.first;
  for (final p in pages.skip(1)) {
    if (p == prev + 1) {
      prev = p;
      continue;
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    start = p;
    prev = p;
  }
  parts.add(start == prev ? '$start' : '$start-$prev');
  return parts.join(', ');
}
