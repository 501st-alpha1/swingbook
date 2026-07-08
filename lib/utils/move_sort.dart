import '../models/move.dart';

/// Type display order: pass → push → whip → starter → throw out → pick up → other.
const _typeOrder = {
  MoveType.pass: 0,
  MoveType.push: 1,
  MoveType.whip: 2,
  MoveType.starterStep: 3,
  MoveType.throwOut: 4,
  MoveType.pickUp: 5,
  MoveType.other: 6,
};

/// Sorts [moves] by difficulty (beginner → intermediate → advanced), then
/// by type (pass → push → whip → other), then alphabetically by name.
/// Returns a new sorted list; the original is not modified.
List<Move> sortedMoves(List<Move> moves) {
  final sorted = [...moves];
  sorted.sort((a, b) {
    final byDifficulty = a.difficulty.index.compareTo(b.difficulty.index);
    if (byDifficulty != 0) return byDifficulty;
    final byType = (_typeOrder[a.type] ?? 3).compareTo(_typeOrder[b.type] ?? 3);
    if (byType != 0) return byType;
    return a.name.compareTo(b.name);
  });
  return sorted;
}
