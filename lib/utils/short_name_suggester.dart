/// Suggests a short, scannable label from a longer free-form move
/// description, e.g. for moves that don't have one settled name.
///
/// This is a simple heuristic, not a smart summarizer: it splits the
/// description on strong separators (commas, semicolons, arrows), then
/// shortens each resulting segment to a few words and joins them with an
/// arrow. It's meant as a starting point to edit, not a final answer —
/// for genuinely tangled descriptions, expect to adjust the result by hand.
///
/// Example:
///   "right to left, to inside underarm spin, to stretch, back into reverse whip"
///   -> "Right To Left → Inside Underarm Spin → Stretch → Reverse Whip"
String suggestShortName(String description) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return '';

  // Split only on strong separators. Standalone "to"/"into" are often part
  // of a single connected phrase (e.g. "right to left") rather than a
  // boundary between distinct segments, so we deliberately don't split on
  // those — over-splitting produces more fragments than it's worth editing.
  final segments = trimmed
      .split(RegExp(r'[,;]|->|→'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (segments.isEmpty) return trimmed;

  final shortened = segments.map(_shortenSegment).where((s) => s.isNotEmpty).toList();
  return shortened.join(' → ');
}

/// Leading connector phrases to strip from the start of a segment, so
/// "to inside underarm spin" becomes "inside underarm spin". Ordered with
/// longer/more specific phrases first so e.g. "back into" is matched before
/// the shorter "into" would otherwise apply. We only trim leading
/// connectors (never mid-segment words) to avoid stripping meaningful words
/// like "back" when it's the actual subject of a short segment.
const _leadingConnectors = ['back into', 'back to', 'into', 'to', 'and', 'then'];

String _shortenSegment(String segment) {
  var working = segment;
  for (final connector in _leadingConnectors) {
    final pattern = RegExp('^${RegExp.escape(connector)}\\s+', caseSensitive: false);
    if (pattern.hasMatch(working)) {
      working = working.replaceFirst(pattern, '');
      break;
    }
  }
  // Also drop a leading article, if any (e.g. "a whip" -> "whip").
  working = working.replaceFirst(RegExp(r'^(a|an|the)\s+', caseSensitive: false), '');

  final words = working
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  // Keep at most the first 4 words to stay reasonably short.
  final kept = words.take(4).toList();
  return kept.map(_capitalize).join(' ');
}

String _capitalize(String word) {
  if (word.isEmpty) return word;
  return word[0].toUpperCase() + word.substring(1);
}
