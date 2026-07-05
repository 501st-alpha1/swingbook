import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../providers/app_state.dart';
import '../theme.dart';

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
  });

  final Move move;

  /// The session attendee map: studentId → role they're dancing tonight.
  /// Sourced from _SessionScreenState._sessionRoles so only tonight's
  /// attendees appear.
  final Map<String, Role> sessionRoles;

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
      entries.add((student, entry.value));
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
          _ExposureBar(move: move, sessionRoles: sessionRoles, students: byId),
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
                      return _AttendeeRow(
                        student: student,
                        role: role,
                        move: move,
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

/// A compact bar showing the total exposure count across tonight's
/// attendees (for quick reference) plus +/- buttons to adjust everyone's
/// count at once, same as the session grid's exposure buttons.
class _ExposureBar extends StatelessWidget {
  const _ExposureBar({
    required this.move,
    required this.sessionRoles,
    required this.students,
  });

  final Move move;
  final Map<String, Role> sessionRoles;
  final Map<String, Student> students;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teal = isDark ? AppTheme.tealDark : AppTheme.teal;

    // Group student ids by role for the bulk exposure buttons.
    final leadIds = sessionRoles.entries
        .where((e) => e.value == Role.lead)
        .map((e) => e.key)
        .toList();
    final followIds = sessionRoles.entries
        .where((e) => e.value == Role.follow)
        .map((e) => e.key)
        .toList();
    final allIds = sessionRoles.keys.toList();

    return Container(
      color: isDark ? AppTheme.tealDark.withValues(alpha: 0.08) : AppTheme.teal.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.repeat, size: 18, color: teal),
          const SizedBox(width: 8),
          Text('Exposures tonight:', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          // Per-role bulk buttons when there are both leads and follows,
          // otherwise a single pair covering everyone.
          if (leadIds.isNotEmpty && followIds.isNotEmpty) ...[
            _BulkExposureButtons(
              label: 'L',
              moveId: move.id,
              role: Role.lead,
              studentIds: leadIds,
            ),
            const SizedBox(width: 8),
            _BulkExposureButtons(
              label: 'F',
              moveId: move.id,
              role: Role.follow,
              studentIds: followIds,
            ),
          ] else
            _BulkExposureButtons(
              label: 'All',
              moveId: move.id,
              role: sessionRoles.values.first,
              studentIds: allIds,
            ),
        ],
      ),
    );
  }
}

class _BulkExposureButtons extends StatelessWidget {
  const _BulkExposureButtons({
    required this.label,
    required this.moveId,
    required this.role,
    required this.studentIds,
  });

  final String label;
  final String moveId;
  final Role role;
  final List<String> studentIds;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Decrease exposure for $label',
          onPressed: () => context.read<AppState>().adjustExposures(moveId, role, studentIds, -1),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Increase exposure for $label',
          onPressed: () => context.read<AppState>().adjustExposures(moveId, role, studentIds, 1),
        ),
      ],
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
  });

  final Student student;
  final Role role;
  final Move move;

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
              Text(
                '${progress.exposures}×',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
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
