import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/move_filters.dart';
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
  });

  final Map<String, Role> sessionRoles;
  final VoidCallback onEditAttendees;
  final Set<String> activeFilterIds;
  final ValueChanged<String> onToggleFilter;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final moves = [...appState.catalog]..sort((a, b) => a.name.compareTo(b.name));

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
    final leadMoves = _filteredMoves(moves, leads, Role.lead, activeFilters);
    final followMoves = _filteredMoves(moves, follows, Role.follow, activeFilters);

    return Scaffold(
      appBar: AppBar(
        title: Text('Session · ${sessionRoles.length} here'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: activeFilterIds.isNotEmpty,
              label: Text('${activeFilterIds.length}'),
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filter moves',
            onPressed: () => _showFilterSheet(context, activeFilterIds, onToggleFilter),
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
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (leads.isNotEmpty) ...[
                  _SectionHeader(label: 'Leads'),
                  if (leadMoves.isEmpty)
                    const _AllFilteredNotice()
                  else
                    _Grid(moves: leadMoves, attendees: leads, role: Role.lead),
                ],
                if (follows.isNotEmpty) ...[
                  _SectionHeader(label: 'Follows'),
                  if (followMoves.isEmpty)
                    const _AllFilteredNotice()
                  else
                    _Grid(moves: followMoves, attendees: follows, role: Role.follow),
                ],
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

/// Applies all active filters to [moves] for a single section (one role's
/// worth of attendees). A move is hidden if any active filter's
/// [MoveFilter.shouldHide] returns true for it. If [attendees] is empty,
/// no filtering is applied (there's nothing to judge "everyone" against).
List<Move> _filteredMoves(
  List<Move> moves,
  List<Student> attendees,
  Role role,
  List<MoveFilter> activeFilters,
) {
  if (attendees.isEmpty || activeFilters.isEmpty) return moves;
  return moves.where((move) {
    return !activeFilters.any((f) => f.shouldHide(move, attendees, role));
  }).toList();
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

void _showFilterSheet(
  BuildContext context,
  Set<String> activeFilterIds,
  ValueChanged<String> onToggleFilter,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Filter moves', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              ...allMoveFilters.map((filter) {
                final isActive = activeFilterIds.contains(filter.id);
                return SwitchListTile(
                  title: Text(filter.label),
                  subtitle: Text(filter.description),
                  value: isActive,
                  onChanged: (_) {
                    onToggleFilter(filter.id);
                    setState(() {}); // refresh the sheet's own checkmarks
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.moves, required this.attendees, required this.role});

  final List<Move> moves;
  final List<Student> attendees;
  final Role role;

  static const double _nameColWidth = 160;
  static const double _cellWidth = 64;
  static const double _rowHeight = 56;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: attendee names
          Row(
            children: [
              const SizedBox(width: _nameColWidth, height: _rowHeight),
              ...attendees.map((s) => SizedBox(
                    width: _cellWidth,
                    height: _rowHeight,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          s.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          const Divider(height: 1),
          // Move rows
          ...moves.map((move) => Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: _nameColWidth,
                        height: _rowHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: move.hasDescription
                                      ? () => showMoveDescription(context, move)
                                      : null,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          move.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                decoration: move.hasDescription
                                                    ? TextDecoration.underline
                                                    : null,
                                                decorationStyle: TextDecorationStyle.dotted,
                                                decorationColor: Colors.grey.shade400,
                                              ),
                                        ),
                                      ),
                                      if (move.hasDescription)
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
                                onPressed: () => context.read<AppState>().adjustExposures(
                                      move.id,
                                      role,
                                      attendees.map((s) => s.id).toList(),
                                      -1,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                tooltip: 'Log exposure for everyone shown',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () => context.read<AppState>().adjustExposures(
                                      move.id,
                                      role,
                                      attendees.map((s) => s.id).toList(),
                                      1,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ...attendees.map((student) {
                        final progress = student.progressFor(move.id, role);
                        return SizedBox(
                          width: _cellWidth,
                          height: _rowHeight,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _Cell(
                              progress: progress,
                              onTap: () => _showLevelPicker(context, student, move, role, progress.level),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const Divider(height: 1),
                ],
              )),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.progress, required this.onTap});

  final MoveProgress progress;
  final VoidCallback onTap;

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
      child: Container(
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
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
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
