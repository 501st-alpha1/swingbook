import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/move.dart';
import '../models/student.dart';

class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  late final Directory _root;
  late final Directory _studentsDir;
  late final File _catalogFile;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _root = Directory('${appDir.path}/swingbook');
    _studentsDir = Directory('${_root.path}/students');
    _catalogFile = File('${_root.path}/catalog.json');

    await _root.create(recursive: true);
    await _studentsDir.create(recursive: true);

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  Future<List<Move>> loadCatalog() async {
    await init();
    if (!await _catalogFile.exists()) return [];
    final raw = await _catalogFile.readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['moves'] as List<dynamic>? ?? [];
    return list
        .map((e) => Move.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCatalog(List<Move> moves) async {
    await init();
    final json = {'moves': moves.map((m) => m.toJson()).toList()};
    await _catalogFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  // ---------------------------------------------------------------------------
  // Students
  // ---------------------------------------------------------------------------

  Future<List<Student>> loadAllStudents() async {
    await init();
    final files = await _studentsDir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final students = <Student>[];
    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        students.add(Student.fromJson(json));
      } catch (e) {
        // Skip malformed files; could log here
      }
    }
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  Future<void> saveStudent(Student student) async {
    await init();
    final file = File('${_studentsDir.path}/${student.id}.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(student.toJson()),
    );
  }

  Future<void> deleteStudent(String studentId) async {
    await init();
    final file = File('${_studentsDir.path}/$studentId.json');
    if (await file.exists()) await file.delete();
  }
}
