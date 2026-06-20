import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../providers/app_state.dart';
import '../theme.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Role? _roleFilter; // null = show all roles the student has

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final student = appState.students.where((s) => s.id == widget.studentId).firstOrNull;

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student')),
        body: const Center(child: Text('Student not found.')),
      );
    }

    final visibleRoles = (_roleFilter != null ? [_roleFilter!] : student.roles.toList())
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit student',
            onPressed: () => _showEditStudent(context, student),
          ),
        ],
      ),
      body: Column(
        children: [
          _BpmSection(student: student, roles: visibleRoles),
          if (student.roles.length > 1) _RoleFilterBar(
            roles: student.roles,
            selected: _roleFilter,
            onChanged: (r) => setState(() => _roleFilter = r),
          ),
          const Divider(height: 1),
          Expanded(
            child: _MovesList(student: student, visibleRoles: visibleRoles),
          ),
        ],
      ),
    );
  }
}

class _BpmSection extends StatelessWidget {
  const _BpmSection({required this.student, required this.roles});

  final Student student;
  final List<Role> roles;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.teal.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: roles.map((role) {
          final bpm = student.bpm[role];
          return InkWell(
            onTap: () => _editBpm(context, student, role),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed, size: 18, color: AppTheme.teal),
                const SizedBox(width: 6),
                Text(
                  '${role == Role.lead ? "Lead" : "Follow"} max BPM: ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  bpm != null ? '$bpm' : 'Not set',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.teal,
                      ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 14, color: Colors.grey),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

void _editBpm(BuildContext context, Student student, Role role) {
  final controller = TextEditingController(text: student.bpm[role]?.toString() ?? '');
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${role == Role.lead ? "Lead" : "Follow"} max BPM'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'BPM'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final value = int.tryParse(controller.text.trim());
            if (value != null) {
              ctx.read<AppState>().setBpm(student.id, role, value);
            }
            Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _RoleFilterBar extends StatelessWidget {
  const _RoleFilterBar({required this.roles, required this.selected, required this.onChanged});

  final Set<Role> roles;
  final Role? selected;
  final ValueChanged<Role?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Both'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          ...roles.map((r) => ChoiceChip(
                label: Text(r == Role.lead ? 'Lead' : 'Follow'),
                selected: selected == r,
                onSelected: (_) => onChanged(r),
              )),
        ],
      ),
    );
  }
}

class _MovesList extends StatelessWidget {
  const _MovesList({required this.student, required this.visibleRoles});

  final Student student;
  final List<Role> visibleRoles;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final moves = [...appState.catalog]..sort((a, b) => a.name.compareTo(b.name));

    if (moves.isEmpty) {
      return const Center(child: Text('No moves in catalog yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: moves.length,
      itemBuilder: (context, i) {
        final move = moves[i];
        return _MoveRow(student: student, move: move, roles: visibleRoles);
      },
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.student, required this.move, required this.roles});

  final Student student;
  final Move move;
  final List<Role> roles;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(move.name, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...roles.map((role) {
              final progress = student.progressFor(move.id, role);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        role == Role.lead ? 'Lead' : 'Follow',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(
                      child: _LevelSelector(
                        level: progress.level,
                        onChanged: (level) => context
                            .read<AppState>()
                            .setLevel(student.id, move.id, role, level),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${progress.exposures}×',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
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
    return Row(
      children: ProficiencyLevel.values.map((l) {
        final isSelected = l == level;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(l),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.levelColor(l.index) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: isSelected ? null : Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(
                l.shortLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? (l.index >= 3 ? Colors.white : AppTheme.charcoal)
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

void _showEditStudent(BuildContext context, Student student) {
  final nameController = TextEditingController(text: student.name);
  final roles = Set<Role>.from(student.roles);

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
            Text('Edit student', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text('Roles', style: Theme.of(ctx).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Lead'),
                  selected: roles.contains(Role.lead),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      roles.add(Role.lead);
                    } else {
                      roles.remove(Role.lead);
                    }
                  }),
                ),
                FilterChip(
                  label: const Text('Follow'),
                  selected: roles.contains(Role.follow),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      roles.add(Role.follow);
                    } else {
                      roles.remove(Role.follow);
                    }
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty || roles.isEmpty) return;
                ctx.read<AppState>().updateStudent(
                      student.copyWith(name: name, roles: roles),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Save changes'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _confirmDeleteStudent(ctx, student),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete student'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _confirmDeleteStudent(BuildContext context, Student student) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Delete student?'),
      content: Text('This permanently removes ${student.name} and all their progress data.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            dialogCtx.read<AppState>().deleteStudent(student.id);
            Navigator.pop(dialogCtx); // close confirm dialog
            Navigator.pop(dialogCtx); // close edit sheet
            Navigator.pop(dialogCtx); // close detail screen
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
