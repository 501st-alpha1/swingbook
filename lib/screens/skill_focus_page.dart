import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/date_format.dart';

/// Full-page drill-down view for practising one [move] in a session.
///
/// Shows all session attendees ([sessionRoles] maps studentId → session role)
/// with their proficiency level and exposure count for this move. Students
/// who dance both roles (if any) get a separate row per role. The instructor
/// can update each person's level and adjust exposure counts from here,
/// then navigate back to the main session screen.
class SkillFocusPage extends StatelessWidget {
  const SkillFocusPage({
    super.key,
    required this.move,
    required this.sessionRoles,
    this.sessionExposureDeltas = const {},
    this.onExposureAdjusted,
  });

  final Move move;
  final Map<String, Set<Role>> sessionRoles;
  // In-memory session exposure deltas: studentId -> moveId -> net delta.
  final Map<String, Map<String, int>> sessionExposureDeltas;
  // Called whenever exposure is adjusted here, so the grid badge stays live.
  final void Function(String moveId, List<String> studentIds, int delta)? onExposureAdjusted;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final byId = {for (final s in appState.students) s.id: s};

    // Build a flat list of (student, role) pairs — one entry per
    // student-role combination, sorted by role then student name.
    final entries = <(Student, Role)>[];
    for (final entry in sessionRoles.entries) {
      final student = byId[entry.key];
      if (student == null) continue;
      for (final role in entry.value) {
        entries.add((student, role));
      }
    }
    entries.sort((a, b) {
      final byRole = a.$2.name.compareTo(b.$2.name); // lead before follow
      if (byRole != 0) return byRole;
      return a.$1.name.compareTo(b.$1.name);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(move.name),
        leading: const BackButton(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (move.hasDescription)
            _DescriptionBanner(description: move.description!),
          _ExposureBar(
            move: move,
            sessionRoles: sessionRoles,
            students: byId,
            onExposureAdjusted: onExposureAdjusted,
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No attendees in this session.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final (student, role) = entries[i];
                      final sessionDelta = sessionExposureDeltas[student.id]?[move.id] ?? 0;
                      return _AttendeeRow(
                        student: student,
                        role: role,
                        move: move,
                        sessionDelta: sessionDelta,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionBanner extends StatelessWidget {
  const _DescriptionBanner({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark
          ? AppTheme.tealDark.withValues(alpha: 0.15)
          : AppTheme.teal.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        description,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// A compact bar with a single +/- pair that increments exposures for
/// every session attendee at once, regardless of role. Since both leads
/// and follows are taught the same move at the same time, one button
/// covers everyone. Calls [onExposureAdjusted] to keep the grid badge live.
class _ExposureBar extends StatelessWidget {
  const _ExposureBar({
    required this.move,
    required this.sessionRoles,
    required this.students,
    required this.onExposureAdjusted,
  });

  final Move move;
  final Map<String, Set<Role>> sessionRoles;
  final Map<String, Student> students;
  final void Function(String moveId, List<String> studentIds, int delta)? onExposureAdjusted;

  void _adjust(BuildContext context, int delta) {
    final appState = context.read<AppState>();
    // Adjust per-role since AppState.adjustExposures is role-scoped.
    final leadIds = sessionRoles.entries.where((e) => e.value.contains(Role.lead)).map((e) => e.key).toList();
    final followIds = sessionRoles.entries.where((e) => e.value.contains(Role.follow)).map((e) => e.key).toList();
    if (leadIds.isNotEmpty) appState.adjustExposures(move.id, Role.lead, leadIds, delta);
    if (followIds.isNotEmpty) appState.adjustExposures(move.id, Role.follow, followIds, delta);
    // Notify the session screen so grid badges update.
    final allIds = sessionRoles.keys.toList();
    onExposureAdjusted?.call(move.id, allIds, delta);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teal = isDark ? AppTheme.tealDark : AppTheme.teal;

    return Container(
      color: isDark ? AppTheme.tealDark.withValues(alpha: 0.08) : AppTheme.teal.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.repeat, size: 18, color: teal),
          const SizedBox(width: 8),
          Text('Exposures (all):', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Undo exposure for everyone',
            onPressed: () => _adjust(context, -1),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Log exposure for everyone',
            onPressed: () => _adjust(context, 1),
          ),
        ],
      ),
    );
  }
}

/// One row per attendee-role combination, showing their name, role badge,
/// exposure count, and a level selector they can tap to update.
class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({
    required this.student,
    required this.role,
    required this.move,
    this.sessionDelta = 0,
  });

  final Student student;
  final Role role;
  final Move move;
  final int sessionDelta;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    // Re-read the student from state so the row reflects live updates.
    final live = appState.students.where((s) => s.id == student.id).firstOrNull ?? student;
    final progress = live.progressFor(move.id, role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(live.name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: 8),
                    _RoleBadge(role: role),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'exp: ${progress.exposures}×',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                  ),
                  if (sessionDelta != 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: sessionDelta > 0 ? AppTheme.gold.withValues(alpha: 0.85) : Colors.red.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sessionDelta > 0 ? '+$sessionDelta' : '$sessionDelta',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _PracticeStepper(
                  progress: progress,
                  onAdjust: (delta) => context.read<AppState>().adjustPracticeCount(
                        live.id, move.id, role, delta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _LevelSelector(
            level: progress.level,
            onChanged: (level) => context.read<AppState>().setLevel(live.id, move.id, role, level),
          ),
        ],
      ),
    );
  }
}

/// Compact practice count stepper with last-practiced date.
class _PracticeStepper extends StatelessWidget {
  const _PracticeStepper({required this.progress, required this.onAdjust});

  final MoveProgress progress;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teal = isDark ? AppTheme.tealDark : AppTheme.teal;

    return Row(
      children: [
        Icon(Icons.fitness_center, size: 14, color: teal),
        const SizedBox(width: 4),
        Text(
          'Practiced: ${progress.practiceCount}×',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: teal),
        ),
        if (progress.lastPracticed != null) ...[
          Text(
            '  ·  last ${formatShortDate(progress.lastPracticed!)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'Decrease practice count',
          onPressed: progress.practiceCount > 0 ? () => onAdjust(-1) : null,
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          tooltip: 'Log practice session',
          onPressed: () => onAdjust(1),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final Role role;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppTheme.tealDark : AppTheme.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role == Role.lead ? 'Lead' : 'Follow',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({required this.level, required this.onChanged});

  final ProficiencyLevel level;
  final ValueChanged<ProficiencyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final unselectedBg = isDark ? const Color(0xFF2A3032) : Colors.grey.shade100;
    final unselectedBorder = isDark ? const Color(0xFF3A4144) : Colors.grey.shade300;

    return Row(
      children: ProficiencyLevel.values.map((l) {
        final isSelected = l == level;
        final selectedColor = AppTheme.levelColor(l.index, brightness);
        final selectedText = l.index >= 3
            ? (isDark ? AppTheme.surfaceDark : Colors.white)
            : (isDark ? AppTheme.onSurfaceDark : AppTheme.charcoal);

        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(l),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : unselectedBg,
                borderRadius: BorderRadius.circular(8),
                border: isSelected ? null : Border.all(color: unselectedBorder),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.shortLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? selectedText : Colors.grey.shade500,
                    ),
                  ),
                  if (isSelected)
                    Text(
                      l.label,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected ? selectedText.withValues(alpha: 0.8) : Colors.grey.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
