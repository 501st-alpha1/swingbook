import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/linked_scroll_group.dart';
import '../utils/move_filters.dart';
import '../utils/move_session_sort.dart';
import '../utils/move_sort.dart';
import '../widgets/move_description_dialog.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  // studentId -> the role they're playing for this session
  final Map<String, Role> _sessionRoles = {};
  bool _pickingAttendees = true;

  // ids of currently-enabled filters from allMoveFilters
  final Set<String> _activeFilterIds = {};

  // id of the active sort from allSessionSorts
  String _activeSortId = defaultSessionSortId;

  // In-memory session exposure deltas: studentId -> moveId -> net delta
  // for this session. Persisted to disk via AppState but only tracked
  // in memory here so it resets when the attendee picker resets.
  final Map<String, Map<String, int>> _sessionExposureDeltas = {};

  void _recordExposureDelta(String moveId, List<String> studentIds, int delta) {
    setState(() {
      for (final id in studentIds) {
        _sessionExposureDeltas.putIfAbsent(id, () => {})[moveId] =
            (_sessionExposureDeltas[id]?[moveId] ?? 0) + delta;
      }
    });
  }

  int _deltaFor(String studentId, String moveId) =>
      _sessionExposureDeltas[studentId]?[moveId] ?? 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (_pickingAttendees) {
      return _AttendeePicker(
        students: appState.students,
        sessionRoles: _sessionRoles,
        onSetRole: (id, role) => setState(() {
          if (role == null) {
            _sessionRoles.remove(id);
          } else {
            _sessionRoles[id] = role;
          }
        }),
        onStart: _sessionRoles.isEmpty ? null : () => setState(() => _pickingAttendees = false),
      );
    }

    return _SessionGrid(
      sessionRoles: _sessionRoles,
      onEditAttendees: () => setState(() => _pickingAttendees = true),
      activeFilterIds: _activeFilterIds,
      onToggleFilter: (id) => setState(() {
        if (_activeFilterIds.contains(id)) {
          _activeFilterIds.remove(id);
        } else {
          _activeFilterIds.add(id);
        }
      }),
      activeSortId: _activeSortId,
      onSortChanged: (id) => setState(() => _activeSortId = id),
      sessionExposureDeltas: _sessionExposureDeltas,
      onExposureAdjusted: _recordExposureDelta,
    );
  }
}

class _AttendeePicker extends StatelessWidget {
  const _AttendeePicker({
    required this.students,
    required this.sessionRoles,
    required this.onSetRole,
    required this.onStart,
  });

  final List<Student> students;
  final Map<String, Role> sessionRoles;
  final void Function(String studentId, Role? role) onSetRole;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final sorted = [...students]..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text("Who's here tonight?")),
      body: sorted.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No students yet. Add students from the Students tab first.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final student = sorted[i];
                final assignedRole = sessionRoles[student.id];
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final highlightColor = isDark ? AppTheme.goldDark : AppTheme.gold;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: assignedRole != null ? highlightColor.withValues(alpha: isDark ? 0.2 : 0.15) : null,
                  child: ListTile(
                    title: Text(student.name),
                    trailing: _RoleToggle(
                      student: student,
                      assignedRole: assignedRole,
                      onSetRole: (role) => onSetRole(student.id, role),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              sessionRoles.isEmpty ? 'Assign roles to start' : 'Start session (${sessionRoles.length})',
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets you pick the session role for a student. If the student only has
/// one role on their profile, only that option is offered.
class _RoleToggle extends StatelessWidget {
  const _RoleToggle({
    required this.student,
    required this.assignedRole,
    required this.onSetRole,
  });

  final Student student;
  final Role? assignedRole;
  final ValueChanged<Role?> onSetRole;

  @override
  Widget build(BuildContext context) {
    final availableRoles = student.roles.toList()..sort((a, b) => a.name.compareTo(b.name));

    if (availableRoles.isEmpty) {
      return Text(
        'No roles set',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
      );
    }

    return Wrap(
      spacing: 6,
      children: availableRoles.map((role) {
        final isSelected = assignedRole == role;
        return ChoiceChip(
          label: Text(role == Role.lead ? 'Lead' : 'Follow'),
          selected: isSelected,
          onSelected: (sel) => onSetRole(sel ? role : null),
        );
      }).toList(),
    );
  }
}

class _SessionGrid extends StatelessWidget {
  const _SessionGrid({
    required this.sessionRoles,
    required this.onEditAttendees,
    required this.activeFilterIds,
    required this.onToggleFilter,
    required this.activeSortId,
    required this.onSortChanged,
    required this.sessionExposureDeltas,
    required this.onExposureAdjusted,
  });

  final Map<String, Role> sessionRoles;
  final VoidCallback onEditAttendees;
  final Set<String> activeFilterIds;
  final ValueChanged<String> onToggleFilter;
  final String activeSortId;
  final ValueChanged<String> onSortChanged;
  // studentId -> moveId -> net exposure delta for this session
  final Map<String, Map<String, int>> sessionExposureDeltas;
  final void Function(String moveId, List<String> studentIds, int delta) onExposureAdjusted;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final moves = sortedMoves(appState.catalog);

    // Pull latest student records (in case of edits elsewhere) and pair each
    // with their assigned session role.
    final byId = {for (final s in appState.students) s.id: s};
    final leads = <Student>[];
    final follows = <Student>[];
    for (final entry in sessionRoles.entries) {
      final student = byId[entry.key];
      if (student == null) continue;
      if (entry.value == Role.lead) {
        leads.add(student);
      } else {
        follows.add(student);
      }
    }
    leads.sort((a, b) => a.name.compareTo(b.name));
    follows.sort((a, b) => a.name.compareTo(b.name));

    final activeFilters = allMoveFilters.where((f) => activeFilterIds.contains(f.id)).toList();
    final leadMoves = _sortedFilteredMoves(moves, leads, Role.lead, activeFilters, activeSortId);
    final followMoves = _sortedFilteredMoves(moves, follows, Role.follow, activeFilters, activeSortId);

    final hasActiveOptions = activeFilterIds.isNotEmpty || activeSortId != defaultSessionSortId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Session · ${sessionRoles.length} here'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hasActiveOptions,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'Sort & filter',
            onPressed: () => _showSortFilterSheet(
              context,
              activeFilterIds,
              onToggleFilter,
              activeSortId,
              onSortChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Edit attendees',
            onPressed: onEditAttendees,
          ),
        ],
      ),
      body: moves.isEmpty
          ? const Center(child: Text('No moves in catalog yet.'))
          : CustomScrollView(
              slivers: [
                if (leads.isNotEmpty)
                  if (leadMoves.isEmpty)
                    const SliverToBoxAdapter(child: _AllFilteredNotice())
                  else
                    _GridSection(
                      moves: leadMoves,
                      attendees: leads,
                      role: Role.lead,
                      sessionRoles: sessionRoles,
                      sessionExposureDeltas: sessionExposureDeltas,
                      onExposureAdjusted: onExposureAdjusted,
                    ),
                if (follows.isNotEmpty)
                  if (followMoves.isEmpty)
                    const SliverToBoxAdapter(child: _AllFilteredNotice())
                  else
                    _GridSection(
                      moves: followMoves,
                      attendees: follows,
                      role: Role.follow,
                      sessionRoles: sessionRoles,
                      sessionExposureDeltas: sessionExposureDeltas,
                      onExposureAdjusted: onExposureAdjusted,
                    ),
                // Bottom padding so the last row isn't flush against the
                // floating action button.
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAddMove(context),
        icon: const Icon(Icons.add),
        label: const Text('Quick add move'),
      ),
    );
  }
}

/// Applies all active filters then the active sort to [moves] for a single
/// section. Filtering is skipped when [attendees] is empty or no filters are
/// active. Sorting always applies (falls back to catalog order when the sort
/// needs attendee data but there are none).
List<Move> _sortedFilteredMoves(
  List<Move> moves,
  List<Student> attendees,
  Role role,
  List<MoveFilter> activeFilters,
  String activeSortId,
) {
  var result = moves;
  if (attendees.isNotEmpty && activeFilters.isNotEmpty) {
    result = moves.where((move) {
      return !activeFilters.any((f) => f.shouldHide(move, attendees, role));
    }).toList();
  }
  if (attendees.isNotEmpty) {
    result = [...result]..sort(sessionSortComparator(activeSortId, attendees, role));
  }
  return result;
}

class _AllFilteredNotice extends StatelessWidget {
  const _AllFilteredNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        'All moves are hidden by your current filters.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
      ),
    );
  }
}

void _showSortFilterSheet(
  BuildContext context,
  Set<String> activeFilterIds,
  ValueChanged<String> onToggleFilter,
  String activeSortId,
  ValueChanged<String> onSortChanged,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Sort', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                ...allSessionSorts.map((sort) {
                  final isActive = sort.id == activeSortId;
                  return RadioListTile<String>(
                    title: Text(sort.label),
                    value: sort.id,
                    groupValue: activeSortId,
                    onChanged: (id) {
                      if (id != null) {
                        onSortChanged(id);
                        setState(() {});
                      }
                    },
                    selected: isActive,
                  );
                }),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text('Filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                ...allMoveFilters.map((filter) {
                  final isActive = activeFilterIds.contains(filter.id);
                  return SwitchListTile(
                    title: Text(filter.label),
                    subtitle: Text(filter.description),
                    value: isActive,
                    onChanged: (_) {
                      onToggleFilter(filter.id);
                      setState(() {});
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// One sticky section of the session grid: a pinned attendee-name header
/// row (with the role label in its corner cell) followed by a list of move
/// rows, all sharing one section-local horizontal scroll position. Built as
/// a sliver so multiple sections can sit in one CustomScrollView with each
/// section's header pinning in turn as it scrolls to the top, then getting
/// pushed off by the next section's header (via SliverMainAxisGroup).
class _GridSection extends StatefulWidget {
  const _GridSection({
    required this.moves,
    required this.attendees,
    required this.role,
    required this.sessionRoles,
    required this.sessionExposureDeltas,
    required this.onExposureAdjusted,
  });

  final List<Move> moves;
  final List<Student> attendees;
  final Role role;
  final Map<String, Role> sessionRoles;
  final Map<String, Map<String, int>> sessionExposureDeltas;
  final void Function(String moveId, List<String> studentIds, int delta) onExposureAdjusted;

  @override
  State<_GridSection> createState() => _GridSectionState();
}

class _GridSectionState extends State<_GridSection> {
  static const double _nameColWidth = 180;
  static const double _cellWidth = 64;
  static const double _rowHeight = 56;

  // All horizontal scrollables in this section (the header row, plus one
  // per move row) share their offset through this group. A plain shared
  // ScrollController can't be attached to more than one Scrollable at a
  // time, so each scrollable gets its own controller from the group and
  // the group keeps them all in sync, including ones created/disposed
  // later as the row list is lazily built.
  final LinkedScrollGroup _scrollGroup = LinkedScrollGroup();
  late final ScrollController _headerController;

  @override
  void initState() {
    super.initState();
    _headerController = _scrollGroup.addAndGet();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moves = widget.moves;
    final attendees = widget.attendees;
    final role = widget.role;

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _SectionHeaderDelegate(
            height: _rowHeight,
            nameColWidth: _nameColWidth,
            cellWidth: _cellWidth,
            role: role,
            attendees: attendees,
            scrollController: _headerController,
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final move = moves[index];
              return _MoveRow(
                key: ValueKey(move.id),
                move: move,
                role: role,
                attendees: attendees,
                scrollGroup: _scrollGroup,
                nameColWidth: _nameColWidth,
                cellWidth: _cellWidth,
                rowHeight: _rowHeight,
                sessionRoles: widget.sessionRoles,
                sessionExposureDeltas: widget.sessionExposureDeltas,
                onExposureAdjusted: widget.onExposureAdjusted,
              );
            },
            childCount: moves.length,
          ),
        ),
      ],
    );
  }
}

/// One move row within a [_GridSection]: the pinned move-name cell plus a
/// horizontally scrollable row of level cells, one per attendee. Owns its
/// own [ScrollController] obtained from the section's [LinkedScrollGroup]
/// so its horizontal position stays in sync with the header and every
/// other row, even as rows are built and disposed lazily.
class _MoveRow extends StatefulWidget {
  const _MoveRow({
    super.key,
    required this.move,
    required this.role,
    required this.attendees,
    required this.scrollGroup,
    required this.nameColWidth,
    required this.cellWidth,
    required this.rowHeight,
    required this.sessionRoles,
    required this.sessionExposureDeltas,
    required this.onExposureAdjusted,
  });

  final Move move;
  final Role role;
  final List<Student> attendees;
  final LinkedScrollGroup scrollGroup;
  final double nameColWidth;
  final double cellWidth;
  final double rowHeight;
  final Map<String, Role> sessionRoles;
  final Map<String, Map<String, int>> sessionExposureDeltas;
  final void Function(String moveId, List<String> studentIds, int delta) onExposureAdjusted;

  @override
  State<_MoveRow> createState() => _MoveRowState();
}

class _MoveRowState extends State<_MoveRow> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.scrollGroup.addAndGet();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = widget.move;
    final role = widget.role;
    final attendees = widget.attendees;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MoveNameCell(
              move: move,
              role: role,
              attendees: attendees,
              height: widget.rowHeight,
              width: widget.nameColWidth,
              sessionRoles: widget.sessionRoles,
              sessionExposureDeltas: widget.sessionExposureDeltas,
              onExposureAdjusted: widget.onExposureAdjusted,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: attendees.map((student) {
                    final progress = student.progressFor(move.id, role);
                    final sessionDelta = widget.sessionExposureDeltas[student.id]?[move.id] ?? 0;
                    return SizedBox(
                      width: widget.cellWidth,
                      height: widget.rowHeight,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: _Cell(
                          progress: progress,
                          sessionDelta: sessionDelta,
                          onTap: () => _showLevelPicker(
                            context,
                            student,
                            move,
                            role,
                            progress.level,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Delegate for the pinned attendee-name header row of one [_GridSection].
/// Renders the role-label corner cell plus a horizontally scrollable row
/// of attendee names, kept in sync with the section's move rows via a
/// shared [ScrollController].
class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({
    required this.height,
    required this.nameColWidth,
    required this.cellWidth,
    required this.role,
    required this.attendees,
    required this.scrollController,
  });

  final double height;
  final double nameColWidth;
  final double cellWidth;
  final Role role;
  final List<Student> attendees;
  final ScrollController scrollController;

  // +1 accounts for the hairline Divider rendered below the name row.
  @override
  double get minExtent => height + 1;

  @override
  double get maxExtent => height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height,
            child: Row(
              children: [
                SizedBox(
                  width: nameColWidth,
                  height: height,
                  child: Center(
                    child: Text(
                      role == Role.lead ? 'Lead' : 'Follow',
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Row(
                      children: attendees.map((s) => SizedBox(
                            width: cellWidth,
                            height: height,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  s.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return oldDelegate.attendees != attendees ||
        oldDelegate.role != role ||
        oldDelegate.height != height ||
        oldDelegate.nameColWidth != nameColWidth ||
        oldDelegate.cellWidth != cellWidth;
  }
}

/// The move-name cell at the start of each row: name (tappable for
/// description) plus the +/- exposure controls, applying to all attendees
/// shown in this section.
class _MoveNameCell extends StatelessWidget {
  const _MoveNameCell({
    required this.move,
    required this.role,
    required this.attendees,
    required this.height,
    required this.width,
    required this.sessionRoles,
    required this.sessionExposureDeltas,
    required this.onExposureAdjusted,
  });

  final Move move;
  final Role role;
  final List<Student> attendees;
  final double height;
  final double width;
  final Map<String, Role> sessionRoles;
  final Map<String, Map<String, int>> sessionExposureDeltas;
  final void Function(String moveId, List<String> studentIds, int delta) onExposureAdjusted;

  void _adjust(BuildContext context, int delta) {
    final ids = attendees.map((s) => s.id).toList();
    context.read<AppState>().adjustExposures(move.id, role, ids, delta);
    onExposureAdjusted(move.id, ids, delta);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => showMovePopup(
                  context,
                  move,
                  sessionRoles,
                  sessionExposureDeltas: sessionExposureDeltas,
                  onExposureAdjusted: onExposureAdjusted,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        move.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              decoration: move.hasDescription ? TextDecoration.underline : null,
                              decorationStyle: TextDecorationStyle.dotted,
                              decorationColor: Colors.grey.shade400,
                            ),
                      ),
                    ),
                    Icon(Icons.info_outline, size: 12, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              tooltip: 'Undo exposure for everyone shown',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _adjust(context, -1),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              tooltip: 'Log exposure for everyone shown',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _adjust(context, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.progress, required this.onTap, this.sessionDelta = 0});

  final MoveProgress progress;
  final VoidCallback onTap;
  final int sessionDelta;

  @override
  Widget build(BuildContext context) {
    final level = progress.level;
    final brightness = Theme.of(context).brightness;
    final cellColor = AppTheme.levelColor(level.index, brightness);
    final isDark = brightness == Brightness.dark;
    final textColor = level.index >= 3
        ? (isDark ? AppTheme.surfaceDark : Colors.white)
        : (isDark ? AppTheme.onSurfaceDark : AppTheme.charcoal);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  level.shortLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (progress.exposures > 0)
                  Text(
                    '${progress.exposures}×',
                    style: TextStyle(
                      fontSize: 10,
                      color: level.index >= 3
                          ? textColor.withValues(alpha: 0.75)
                          : (isDark ? AppTheme.onSurfaceDark.withValues(alpha: 0.6) : Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
          if (sessionDelta != 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: sessionDelta > 0 ? AppTheme.gold : Colors.red.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sessionDelta > 0 ? '+$sessionDelta' : '$sessionDelta',
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showLevelPicker(
  BuildContext context,
  Student student,
  Move move,
  Role role,
  ProficiencyLevel current,
) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              '${student.name} · ${move.name}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          if (move.hasDescription)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                move.description!,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 8),
          ...ProficiencyLevel.values.map((level) => ListTile(
                leading: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.levelColor(level.index, Theme.of(ctx).brightness),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                title: Text(level.label),
                trailing: level == current ? const Icon(Icons.check) : null,
                onTap: () {
                  ctx.read<AppState>().setLevel(student.id, move.id, role, level);
                  Navigator.pop(ctx);
                },
              )),
        ],
      ),
    ),
  );
}

void _showQuickAddMove(BuildContext context) {
  final nameController = TextEditingController();
  MoveType type = MoveType.push;
  Difficulty difficulty = Difficulty.beginner;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quick add move', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Move name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MoveType>(
              initialValue: type,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: MoveType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => type = v ?? type),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Difficulty>(
              initialValue: difficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty',
                border: OutlineInputBorder(),
              ),
              items: Difficulty.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                  .toList(),
              onChanged: (v) => setState(() => difficulty = v ?? difficulty),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final id = '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(6)}';
                ctx.read<AppState>().addMove(Move(id: id, name: name, type: type, difficulty: difficulty));
                Navigator.pop(ctx);
              },
              child: const Text('Add & use in session'),
            ),
          ],
        ),
      ),
    ),
  );
}
