import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final Set<String> _attendeeIds = {};
  bool _pickingAttendees = true;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (_pickingAttendees) {
      return _AttendeePicker(
        students: appState.students,
        selected: _attendeeIds,
        onToggle: (id) => setState(() {
          if (_attendeeIds.contains(id)) {
            _attendeeIds.remove(id);
          } else {
            _attendeeIds.add(id);
          }
        }),
        onStart: _attendeeIds.isEmpty ? null : () => setState(() => _pickingAttendees = false),
      );
    }

    final attendees = appState.students.where((s) => _attendeeIds.contains(s.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return _SessionGrid(
      attendees: attendees,
      onEditAttendees: () => setState(() => _pickingAttendees = true),
    );
  }
}

class _AttendeePicker extends StatelessWidget {
  const _AttendeePicker({
    required this.students,
    required this.selected,
    required this.onToggle,
    required this.onStart,
  });

  final List<Student> students;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
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
                final isSelected = selected.contains(student.id);
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final highlightColor = isDark ? AppTheme.goldDark : AppTheme.gold;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: isSelected ? highlightColor.withValues(alpha: isDark ? 0.2 : 0.15) : null,
                  child: CheckboxListTile(
                    title: Text(student.name),
                    value: isSelected,
                    onChanged: (_) => onToggle(student.id),
                    controlAffinity: ListTileControlAffinity.leading,
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
              selected.isEmpty ? 'Select attendees to start' : 'Start session (${selected.length})',
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionGrid extends StatefulWidget {
  const _SessionGrid({required this.attendees, required this.onEditAttendees});

  final List<Student> attendees;
  final VoidCallback onEditAttendees;

  @override
  State<_SessionGrid> createState() => _SessionGridState();
}

class _SessionGridState extends State<_SessionGrid> {
  Role _roleView = Role.follow;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final moves = [...appState.catalog]..sort((a, b) => a.name.compareTo(b.name));

    // Refresh attendee data from latest app state (in case of edits elsewhere).
    final attendeeIds = widget.attendees.map((s) => s.id).toSet();
    final attendees = appState.students.where((s) => attendeeIds.contains(s.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final visibleAttendees = attendees.where((s) => s.roles.contains(_roleView)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Session · ${attendees.length} here'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Edit attendees',
            onPressed: widget.onEditAttendees,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Viewing role: '),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Lead'),
                  selected: _roleView == Role.lead,
                  onSelected: (_) => setState(() => _roleView = Role.lead),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Follow'),
                  selected: _roleView == Role.follow,
                  onSelected: (_) => setState(() => _roleView = Role.follow),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (moves.isEmpty)
            const Expanded(child: Center(child: Text('No moves in catalog yet.')))
          else if (visibleAttendees.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'None of tonight\'s attendees dance ${_roleView == Role.lead ? "Lead" : "Follow"}.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _Grid(
                moves: moves,
                attendees: visibleAttendees,
                role: _roleView,
              ),
            ),
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

class _Grid extends StatelessWidget {
  const _Grid({required this.moves, required this.attendees, required this.role});

  final List<Move> moves;
  final List<Student> attendees;
  final Role role;

  static const double _nameColWidth = 140;
  static const double _cellWidth = 64;
  static const double _rowHeight = 56;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
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
                                  child: Text(
                                    move.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 18),
                                  tooltip: 'Log exposure for everyone shown',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => context.read<AppState>().incrementExposures(
                                        move.id,
                                        role,
                                        attendees.map((s) => s.id).toList(),
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
            padding: const EdgeInsets.all(16),
            child: Text(
              '${student.name} · ${move.name}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
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
