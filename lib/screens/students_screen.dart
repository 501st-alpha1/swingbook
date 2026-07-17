import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final active = appState.students.where((s) => !s.isArchived).toList();
    final archived = appState.students.where((s) => s.isArchived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: active.isEmpty && archived.isEmpty
          ? const _EmptyStudents()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'No active students.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
                    ),
                  )
                else
                  ...active.map((s) => _StudentTile(student: s)),
                if (archived.isNotEmpty) ...[
                  InkWell(
                    onTap: () => setState(() => _showArchived = !_showArchived),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            _showArchived ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Archived (${archived.length})',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showArchived)
                    ...archived.map((s) => _StudentTile(student: s, isArchived: true)),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStudent(context),
        child: const Icon(Icons.person_add_alt),
      ),
    );
  }
}

class _EmptyStudents extends StatelessWidget {
  const _EmptyStudents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No students yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first student.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, this.isArchived = false});

  final Student student;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    final roleLabel = student.roles.map((r) => r == Role.lead ? 'Lead' : 'Follow').join(' / ');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarColor = isDark ? AppTheme.tealDark : AppTheme.teal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isArchived
          ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
          : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColor.withValues(alpha: isArchived ? 0.08 : (isDark ? 0.25 : 0.15)),
          foregroundColor: isArchived ? Colors.grey.shade500 : avatarColor,
          child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?'),
        ),
        title: Text(
          student.name,
          style: isArchived
              ? TextStyle(color: Colors.grey.shade500)
              : null,
        ),
        subtitle: Text(
          roleLabel.isEmpty ? 'No role set' : roleLabel,
          style: isArchived ? TextStyle(color: Colors.grey.shade400) : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                size: 20,
                color: Colors.grey.shade500,
              ),
              tooltip: isArchived ? 'Unarchive' : 'Archive',
              onPressed: () => context
                  .read<AppState>()
                  .setStudentArchived(student.id, archived: !isArchived),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentDetailScreen(studentId: student.id)),
        ),
      ),
    );
  }
}

void _showAddStudent(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _AddStudentSheet(),
  );
}

class _AddStudentSheet extends StatefulWidget {
  const _AddStudentSheet();

  @override
  State<_AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<_AddStudentSheet> {
  final _nameController = TextEditingController();
  final Set<Role> _roles = {Role.lead, Role.follow};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || _roles.isEmpty) return;

    final id = '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(6)}';

    context.read<AppState>().addStudent(Student(
          id: id,
          name: name,
          roles: _roles,
          bpm: {},
          moves: {},
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New student', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text('Roles', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Lead'),
                selected: _roles.contains(Role.lead),
                onSelected: (sel) => setState(() {
                  if (sel) {
                    _roles.add(Role.lead);
                  } else {
                    _roles.remove(Role.lead);
                  }
                }),
              ),
              FilterChip(
                label: const Text('Follow'),
                selected: _roles.contains(Role.follow),
                onSelected: (sel) => setState(() {
                  if (sel) {
                    _roles.add(Role.follow);
                  } else {
                    _roles.remove(Role.follow);
                  }
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Add student'),
          ),
        ],
      ),
    );
  }
}
