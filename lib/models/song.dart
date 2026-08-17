import 'dart:io';

class Song {
  final String id;
  final String name;
  final String filePath;
  final int bpm;
  final String? notes;

  const Song({
    required this.id,
    required this.name,
    required this.filePath,
    required this.bpm,
    this.notes,
  });

  /// Check if the song file exists at the stored path
  Future<bool> get fileExists async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        name: json['name'] as String,
        filePath: json['filePath'] as String,
        bpm: json['bpm'] as int,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'bpm': bpm,
        if (notes != null) 'notes': notes,
      };

  Song copyWith({
    String? id,
    String? name,
    String? filePath,
    int? bpm,
    String? notes,
    bool clearNotes = false,
  }) =>
      Song(
        id: id ?? this.id,
        name: name ?? this.name,
        filePath: filePath ?? this.filePath,
        bpm: bpm ?? this.bpm,
        notes: clearNotes ? null : (notes ?? this.notes),
      );
}
