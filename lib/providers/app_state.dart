import 'package:flutter/foundation.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  List<Move> _catalog = [];
  List<Student> _students = [];
  bool _loading = true;

  List<Move> get catalog => List.unmodifiable(_catalog);
  List<Student> get students => List.unmodifiable(_students);
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    _catalog = await StorageService.instance.loadCatalog();
    _students = await StorageService.instance.loadAllStudents();

    _loading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Catalog mutations
  // ---------------------------------------------------------------------------

  Future<void> addMove(Move move) async {
    _catalog = [..._catalog, move];
    await StorageService.instance.saveCatalog(_catalog);
    notifyListeners();
  }

  Future<void> updateMove(Move move) async {
    _catalog = [
      for (final m in _catalog) m.id == move.id ? move : m,
    ];
    await StorageService.instance.saveCatalog(_catalog);
    notifyListeners();
  }

  Future<void> deleteMove(String moveId) async {
    _catalog = _catalog.where((m) => m.id != moveId).toList();
    await StorageService.instance.saveCatalog(_catalog);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Student mutations
  // ---------------------------------------------------------------------------

  Future<void> addStudent(Student student) async {
    _students = [..._students, student]
      ..sort((a, b) => a.name.compareTo(b.name));
    await StorageService.instance.saveStudent(student);
    notifyListeners();
  }

  Future<void> updateStudent(Student student) async {
    _students = [
      for (final s in _students) s.id == student.id ? student : s,
    ]..sort((a, b) => a.name.compareTo(b.name));
    await StorageService.instance.saveStudent(student);
    notifyListeners();
  }

  Future<void> deleteStudent(String studentId) async {
    _students = _students.where((s) => s.id != studentId).toList();
    await StorageService.instance.deleteStudent(studentId);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Progress mutations (used from session screen)
  // ---------------------------------------------------------------------------

  /// Adjust exposure count for a move+role across a set of students by [delta]
  /// (positive or negative). Exposures are clamped at a minimum of 0.
  Future<void> adjustExposures(
    String moveId,
    Role role,
    List<String> studentIds,
    int delta,
  ) async {
    final updated = <Student>[];
    for (final student in _students) {
      if (!studentIds.contains(student.id)) continue;
      final movesMap = Map<String, Map<Role, MoveProgress>>.from(
        student.moves.map((k, v) => MapEntry(k, Map<Role, MoveProgress>.from(v))),
      );
      final roleMap = movesMap[moveId] ?? {};
      final current = roleMap[role] ?? const MoveProgress();
      final newExposures = (current.exposures + delta).clamp(0, 1 << 30);
      roleMap[role] = current.copyWith(exposures: newExposures);
      movesMap[moveId] = roleMap;
      updated.add(student.copyWith(moves: movesMap));
    }
    for (final s in updated) {
      await updateStudent(s);
    }
  }

  /// Convenience wrapper for adjusting a single student's exposure count.
  Future<void> adjustExposureForStudent(
    String studentId,
    String moveId,
    Role role,
    int delta,
  ) =>
      adjustExposures(moveId, role, [studentId], delta);

  /// Set proficiency level for a single student + move + role.
  Future<void> setLevel(
    String studentId,
    String moveId,
    Role role,
    ProficiencyLevel level,
  ) async {
    final student = _students.firstWhere((s) => s.id == studentId);
    final movesMap = Map<String, Map<Role, MoveProgress>>.from(
      student.moves.map((k, v) => MapEntry(k, Map<Role, MoveProgress>.from(v))),
    );
    final roleMap = movesMap[moveId] ?? {};
    final current = roleMap[role] ?? const MoveProgress();
    roleMap[role] = current.copyWith(level: level);
    movesMap[moveId] = roleMap;
    await updateStudent(student.copyWith(moves: movesMap));
  }

  /// Update BPM for a student + role.
  Future<void> setBpm(String studentId, Role role, int bpm) async {
    final student = _students.firstWhere((s) => s.id == studentId);
    final newBpm = Map<Role, int>.from(student.bpm)..[role] = bpm;
    await updateStudent(student.copyWith(bpm: newBpm));
  }
}
