import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final students = appState.students;

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: students.isEmpty
          ? const _EmptyStudents()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: students.length,
              itemBuilder: (context, i) => _StudentTile(student: students[i]),
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
  const _StudentTile({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final roleLabel = student.roles.map((r) => r == Role.lead ? 'Lead' : 'Follow').join(' / ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.teal.withValues(alpha: 0.15),
          foregroundColor: AppTheme.teal,
          child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?'),
        ),
        title: Text(student.name),
        subtitle: Text(roleLabel.isEmpty ? 'No role set' : roleLabel),
        trailing: const Icon(Icons.chevron_right),
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
