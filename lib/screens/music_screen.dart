import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/song.dart';
import '../providers/app_state.dart';

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final songs = appState.songs;

    return Scaffold(
      appBar: AppBar(title: const Text('Music Library')),
      body: songs.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return _SongTile(song: song);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSongDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No songs yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add songs from your files.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatefulWidget {
  const _SongTile({required this.song});

  final Song song;

  @override
  State<_SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<_SongTile> {
  bool? _fileExists;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  Future<void> _checkFileExists() async {
    final exists = await widget.song.fileExists;
    if (mounted) {
      setState(() => _fileExists = exists);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _buildFileIndicator(),
        title: Text(song.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${song.bpm} BPM'),
            if (song.notes != null && song.notes!.isNotEmpty)
              Text(
                song.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditSongDialog(context, song);
            } else if (value == 'delete') {
              _confirmDelete(context, song);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _showEditSongDialog(context, song),
      ),
    );
  }

  Widget _buildFileIndicator() {
    if (_fileExists == null) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    return Icon(
      _fileExists! ? Icons.music_note : Icons.music_off,
      color: _fileExists! ? Colors.teal : Colors.grey,
    );
  }
}

void _showAddSongDialog(BuildContext context) {
  _showSongDialog(context);
}

void _showEditSongDialog(BuildContext context, Song song) {
  _showSongDialog(context, existing: song);
}

void _showSongDialog(BuildContext context, {Song? existing}) {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final pathController = TextEditingController(text: existing?.filePath ?? '');
  final notesController = TextEditingController(text: existing?.notes ?? '');
  var bpm = existing?.bpm ?? 120;

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
            Text(
              existing == null ? 'Add Song' : 'Edit Song',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Song name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pathController,
                    decoration: const InputDecoration(
                      labelText: 'File path',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    final result = await FilePicker.pickFiles(
                      type: FileType.audio,
                      allowMultiple: false,
                    );
                    if (result != null && result.isNotEmpty) {
                      setState(() {
                        pathController.text = result.first.path ?? '';
                        // Auto-fill name from filename if empty
                        if (nameController.text.isEmpty && result.first.name.isNotEmpty) {
                          final name = result.first.name.replaceAll(RegExp(r'\.[^.]+$'), '');
                          nameController.text = name;
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Browse for file',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('BPM: $bpm', style: Theme.of(ctx).textTheme.bodyLarge),
                Expanded(
                  child: Slider(
                    value: bpm.toDouble(),
                    min: 60,
                    max: 300,
                    divisions: 240,
                    label: bpm.toString(),
                    onChanged: (v) => setState(() => bpm = v.round()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final path = pathController.text.trim();
                if (name.isEmpty || path.isEmpty) return;

                final notes = notesController.text.trim();
                final song = Song(
                  id: existing?.id ?? const Uuid().v4(),
                  name: name,
                  filePath: path,
                  bpm: bpm,
                  notes: notes.isEmpty ? null : notes,
                );

                final appState = ctx.read<AppState>();
                if (existing == null) {
                  appState.addSong(song);
                } else {
                  appState.updateSong(song);
                }

                Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Add Song' : 'Save Changes'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _confirmDelete(BuildContext context, Song song) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete song?'),
      content: Text('Remove "${song.name}" from the library?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            context.read<AppState>().deleteSong(song.id);
            Navigator.pop(ctx);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
