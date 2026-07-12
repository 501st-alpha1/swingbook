import '../models/move.dart';
import '../models/student.dart';
import 'move_sort.dart';

/// One named sort option for the session grid.
///
/// Attendee-dependent sorts (level, counts, last-practiced) rank each move
/// by the *minimum* value across all attendees in that section — worst-case
/// first, so the moves most in need of attention rise to the top.
///
/// To add a new sort option, add a new instance to [allSessionSorts] below.
class SessionSort {
  const SessionSort({
    required this.id,
    required this.label,
    required this.comparator,
  });

  /// Stable identifier used to track the active sort (a single String id,
  /// since only one sort is active at a time).
  final String id;

  /// Short label shown in the sort picker.
  final String label;

  /// Compares two moves given the current section's [attendees] and [role].
  /// Returns negative/zero/positive like [Comparator].
  final int Function(Move a, Move b, List<Student> attendees, Role role) comparator;
}

/// The default sort — difficulty → type → name — with no attendee context
/// needed. Defined as a top-level constant so callers can reference it
/// directly (e.g. to reset to default).
const String defaultSessionSortId = 'difficulty_type_name';

/// All sort options available in the session screen, in display order.
/// Add new options here.
final List<SessionSort> allSessionSorts = [
  SessionSort(
    id: defaultSessionSortId,
    label: 'Difficulty → type → name',
    comparator: (a, b, attendees, role) => _defaultCompare(a, b),
  ),
  SessionSort(
    id: 'name',
    label: 'Name (A → Z)',
    comparator: (a, b, attendees, role) => a.name.compareTo(b.name),
  ),
  SessionSort(
    id: 'level_asc',
    label: 'Level (lowest first)',
    comparator: (a, b, attendees, role) {
      final diff = _minLevel(a, attendees, role) - _minLevel(b, attendees, role);
      return diff != 0 ? diff : _defaultCompare(a, b);
    },
  ),
  SessionSort(
    id: 'exposure_asc',
    label: 'Exposure count (lowest first)',
    comparator: (a, b, attendees, role) {
      final diff = _minExposures(a, attendees, role) - _minExposures(b, attendees, role);
      return diff != 0 ? diff : _defaultCompare(a, b);
    },
  ),
  SessionSort(
    id: 'practice_asc',
    label: 'Practice count (lowest first)',
    comparator: (a, b, attendees, role) {
      final diff = _minPractice(a, attendees, role) - _minPractice(b, attendees, role);
      return diff != 0 ? diff : _defaultCompare(a, b);
    },
  ),
  SessionSort(
    id: 'last_practiced_asc',
    label: 'Last practiced (oldest first)',
    comparator: (a, b, attendees, role) {
      // Null (never practiced) sorts before any date — most neglected first.
      final dateA = _minLastPracticed(a, attendees, role);
      final dateB = _minLastPracticed(b, attendees, role);
      if (dateA == null && dateB == null) return _defaultCompare(a, b);
      if (dateA == null) return -1;
      if (dateB == null) return 1;
      final dateDiff = dateA.compareTo(dateB);
      return dateDiff != 0 ? dateDiff : _defaultCompare(a, b);
    },
  ),
];

/// Returns a sort function suitable for [List.sort] given an active sort id,
/// the section's [attendees], and their [role].
Comparator<Move> sessionSortComparator(
  String sortId,
  List<Student> attendees,
  Role role,
) {
  final sort = allSessionSorts.firstWhere(
    (s) => s.id == sortId,
    orElse: () => allSessionSorts.first,
  );
  return (a, b) => sort.comparator(a, b, attendees, role);
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

int _defaultCompare(Move a, Move b) {
  // Reuse the catalog sort: difficulty → type → name.
  return sortedMoves([a, b]).first == a ? -1 : 1;
}

int _minLevel(Move move, List<Student> attendees, Role role) =>
    attendees.map((s) => s.progressFor(move.id, role).level.index).reduce((a, b) => a < b ? a : b);

int _minExposures(Move move, List<Student> attendees, Role role) =>
    attendees.map((s) => s.progressFor(move.id, role).exposures).reduce((a, b) => a < b ? a : b);

int _minPractice(Move move, List<Student> attendees, Role role) =>
    attendees.map((s) => s.progressFor(move.id, role).practiceCount).reduce((a, b) => a < b ? a : b);

/// Returns the lexicographically minimum ISO date string across attendees,
/// or null if any attendee has never practiced (null sorts first = oldest).
String? _minLastPracticed(Move move, List<Student> attendees, Role role) {
  final dates = attendees.map((s) => s.progressFor(move.id, role).lastPracticed).toList();
  if (dates.any((d) => d == null)) return null;
  return dates.cast<String>().reduce((a, b) => a.compareTo(b) < 0 ? a : b);
}
