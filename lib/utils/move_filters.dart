import '../models/move.dart';
import '../models/student.dart';

/// A named, toggleable rule for hiding moves from a session grid section.
///
/// Each filter is evaluated independently per section (e.g. the Leads grid
/// and the Follows grid are filtered separately, each against only the
/// attendees and role shown in that section). A move is hidden from a
/// section if any *enabled* filter's [shouldHide] returns true for it.
///
/// To add a new filter, add a new instance to [allMoveFilters] below — no
/// other wiring is needed, since the session screen iterates that list
/// generically.
class MoveFilter {
  const MoveFilter({
    required this.id,
    required this.label,
    required this.description,
    required this.shouldHide,
  });

  /// Stable identifier, used as the key for tracking which filters are
  /// enabled (e.g. in a Set<String> of active filter ids).
  final String id;

  /// Short label shown next to the toggle in the filter menu.
  final String label;

  /// Longer explanation shown under the label, if there's room.
  final String description;

  /// Returns true if [move] should be hidden from a section made up of
  /// [attendees], all of whom are dancing [role] in this section.
  /// [attendees] is never empty when this is called.
  final bool Function(Move move, List<Student> attendees, Role role) shouldHide;
}

/// All filters available in the session screen's filter menu, in display
/// order. Add new filters here.
final List<MoveFilter> allMoveFilters = [
  MoveFilter(
    id: 'hide_mastered_by_all',
    label: 'Hide moves everyone has mastered',
    description: 'Hides a move from a section if every attendee shown there is at "Owns it" for it.',
    shouldHide: (move, attendees, role) {
      return attendees.every(
        (s) => s.progressFor(move.id, role).level == ProficiencyLevel.ownsIt,
      );
    },
  ),
];
