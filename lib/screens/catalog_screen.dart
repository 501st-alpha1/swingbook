import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/move.dart';
import '../providers/app_state.dart';
import '../utils/short_name_suggester.dart';
import '../widgets/move_description_dialog.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final moves = [...appState.catalog]
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: moves.isEmpty
          ? const _EmptyCatalog()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: moves.length,
              itemBuilder: (context, i) {
                final move = moves[i];
                return _MoveTile(move: move);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMoveEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list_alt, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No moves yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first move.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({required this.move});

  final Move move;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(move.name),
        subtitle: Text('${_typeLabel(move.type)} · ${_difficultyLabel(move.difficulty)}'),
        onTap: move.hasDescription ? () => showMovePopup(context, move, const {}) : null,
        leading: move.hasDescription
            ? Icon(Icons.notes, size: 20, color: Colors.grey.shade500)
            : null,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showMoveEditor(context, existing: move);
            } else if (value == 'delete') {
              _confirmDelete(context, move);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(MoveType type) => type.label;

String _difficultyLabel(Difficulty d) => switch (d) {
      Difficulty.beginner => 'Beginner',
      Difficulty.intermediate => 'Intermediate',
      Difficulty.advanced => 'Advanced',
    };

void _confirmDelete(BuildContext context, Move move) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete move?'),
      content: Text(
        'This removes "${move.name}" from the catalog. Existing student progress for this move will be kept but hidden.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            ctx.read<AppState>().deleteMove(move.id);
            Navigator.pop(ctx);
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

void _showMoveEditor(BuildContext context, {Move? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _MoveEditorSheet(existing: existing),
  );
}

class _MoveEditorSheet extends StatefulWidget {
  const _MoveEditorSheet({this.existing});

  final Move? existing;

  @override
  State<_MoveEditorSheet> createState() => _MoveEditorSheetState();
}

class _MoveEditorSheetState extends State<_MoveEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late MoveType _type;
  late Difficulty _difficulty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
    _type = widget.existing?.type ?? MoveType.push;
    _difficulty = widget.existing?.difficulty ?? Difficulty.beginner;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _applySuggestedName() {
    final suggestion = suggestShortName(_descriptionController.text);
    if (suggestion.isEmpty) return;
    setState(() {
      _nameController.text = suggestion;
      _nameController.selection = TextSelection.collapsed(offset: suggestion.length);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final description = _descriptionController.text.trim();

    final appState = context.read<AppState>();
    if (widget.existing == null) {
      final id = _slugify(name);
      appState.addMove(Move(
        id: id,
        name: name,
        type: _type,
        difficulty: _difficulty,
        description: description.isEmpty ? null : description,
      ));
    } else {
      appState.updateMove(widget.existing!.copyWith(
        name: name,
        type: _type,
        difficulty: _difficulty,
        description: description.isEmpty ? null : description,
        clearDescription: description.isEmpty,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
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
          Text(
            isEditing ? 'Edit move' : 'New move',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: !isEditing,
            decoration: const InputDecoration(
              labelText: 'Move name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'For moves without one settled name — e.g. step-by-step reminder',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _applySuggestedName,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Suggest name from description'),
            ),
          ),
          DropdownButtonFormField<MoveType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: MoveType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Difficulty>(
            initialValue: _difficulty,
            decoration: const InputDecoration(
              labelText: 'Difficulty',
              border: OutlineInputBorder(),
            ),
            items: Difficulty.values
                .map((d) => DropdownMenuItem(value: d, child: Text(_difficultyLabel(d))))
                .toList(),
            onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(isEditing ? 'Save changes' : 'Add move'),
          ),
        ],
      ),
    );
  }
}

String _slugify(String name) {
  final base = name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  // Append a short suffix to reduce collision risk between similarly named moves.
  final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(6);
  return '${base}_$suffix';
}
