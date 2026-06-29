/// Suggests a short, scannable label from a longer free-form move
/// description, e.g. for moves that don't have one settled name.
///
/// This is a simple heuristic, not a smart summarizer: it splits the
/// description on strong separators (commas, semicolons, arrows), then
/// compresses each segment into a short initialism (first letter of each
/// word, with a few common connector words replaced by a digit/symbol
/// instead of their initial), and joins the segments with an arrow. It's
/// meant as a starting point to edit, not a final answer — for genuinely
/// tangled descriptions, expect to adjust the result by hand.
///
/// Example:
///   "right to left, to inside underarm spin, to stretch, back into reverse whip"
///   -> "R2L→IUS→S→RW"
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
  return shortened.join('→');
}

/// Connector words replaced by a digit/symbol instead of their initial
/// letter, since the symbol reads more clearly in a compressed initialism
/// (e.g. "to" -> "2" rather than "T", which could be mistaken for a real
/// initial). Checked as whole words only, case-insensitive.
const _wordSubstitutions = {
  'to': '2',
  'into': '2',
  'for': '4',
  'and': '&',
};

/// Words dropped entirely rather than contributing a letter or symbol —
/// articles carry no identifying information even as an initial.
const _droppedWords = {'a', 'an', 'the'};

/// Leading connector words to strip from the very start of a segment
/// before building the initialism. When a sentence is split on commas like
/// "right to left, to inside underarm spin", the leading "to" on the second
/// segment is really a joiner carried over from the comma, not a
/// meaningful part of that segment — unlike the "to" inside "right to
/// left", which is meaningful and should still become "2". So we only
/// strip a connector when it's the first word of the segment.
const _leadingStripWords = {'to', 'into', 'and', 'then', 'back'};

String _shortenSegment(String segment) {
  var words = segment
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  // Strip leading connector words one at a time (e.g. "back into x" sheds
  // both "back" and "into" if both are leading), but never strip the last
  // remaining word, so a segment that's just "back" on its own still
  // produces something rather than being emptied out.
  while (words.length > 1 && _leadingStripWords.contains(words.first.toLowerCase())) {
    words = words.skip(1).toList();
  }
  // Strip a leading article too, same rule.
  while (words.length > 1 && _droppedWords.contains(words.first.toLowerCase())) {
    words = words.skip(1).toList();
  }

  final parts = <String>[];
  for (final word in words) {
    final lower = word.toLowerCase();
    if (_droppedWords.contains(lower)) continue;
    final substitution = _wordSubstitutions[lower];
    if (substitution != null) {
      parts.add(substitution);
    } else {
      parts.add(word[0].toUpperCase());
    }
  }

  return parts.join();
}
