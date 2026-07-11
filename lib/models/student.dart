enum Role { lead, follow }

/// 0 = not tried, 1 = Trying, 2 = Getting it, 3 = Solid, 4 = Owns it
enum ProficiencyLevel {
  notTried,
  trying,
  gettingIt,
  solid,
  ownsIt;

  String get label => switch (this) {
        ProficiencyLevel.notTried => '—',
        ProficiencyLevel.trying => 'Trying',
        ProficiencyLevel.gettingIt => 'Getting it',
        ProficiencyLevel.solid => 'Solid',
        ProficiencyLevel.ownsIt => 'Owns it',
      };

  /// Short label for grid cells
  String get shortLabel => switch (this) {
        ProficiencyLevel.notTried => '—',
        ProficiencyLevel.trying => '1',
        ProficiencyLevel.gettingIt => '2',
        ProficiencyLevel.solid => '3',
        ProficiencyLevel.ownsIt => '4',
      };
}

class MoveProgress {
  final ProficiencyLevel level;
  final int exposures;
  final int practiceCount;

  /// ISO-8601 date string (yyyy-MM-dd) of the last time practice was logged,
  /// or null if never practiced.
  final String? lastPracticed;

  const MoveProgress({
    this.level = ProficiencyLevel.notTried,
    this.exposures = 0,
    this.practiceCount = 0,
    this.lastPracticed,
  });

  factory MoveProgress.fromJson(Map<String, dynamic> json) => MoveProgress(
        level: ProficiencyLevel.values[json['level'] as int? ?? 0],
        exposures: json['exposures'] as int? ?? 0,
        practiceCount: json['practiceCount'] as int? ?? 0,
        lastPracticed: json['lastPracticed'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'level': level.index,
        'exposures': exposures,
        if (practiceCount > 0) 'practiceCount': practiceCount,
        if (lastPracticed != null) 'lastPracticed': lastPracticed,
      };

  MoveProgress copyWith({
    ProficiencyLevel? level,
    int? exposures,
    int? practiceCount,
    String? lastPracticed,
    bool clearLastPracticed = false,
  }) =>
      MoveProgress(
        level: level ?? this.level,
        exposures: exposures ?? this.exposures,
        practiceCount: practiceCount ?? this.practiceCount,
        lastPracticed: clearLastPracticed ? null : (lastPracticed ?? this.lastPracticed),
      );
}

class Student {
  final String id;
  final String name;

  /// Which roles this student actively uses. Determines which role columns show.
  final Set<Role> roles;

  /// BPM per role
  final Map<Role, int> bpm;

  /// moveId -> role -> progress
  final Map<String, Map<Role, MoveProgress>> moves;

  const Student({
    required this.id,
    required this.name,
    required this.roles,
    required this.bpm,
    required this.moves,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    final rolesJson = (json['roles'] as List<dynamic>? ?? []);
    final roles = rolesJson
        .map((r) => Role.values.byName(r as String))
        .toSet();

    final bpmJson = (json['bpm'] as Map<String, dynamic>? ?? {});
    final bpm = {
      for (final e in bpmJson.entries)
        Role.values.byName(e.key): e.value as int,
    };

    final movesJson = (json['moves'] as Map<String, dynamic>? ?? {});
    final moves = <String, Map<Role, MoveProgress>>{};
    for (final moveEntry in movesJson.entries) {
      final roleMap = moveEntry.value as Map<String, dynamic>;
      moves[moveEntry.key] = {
        for (final roleEntry in roleMap.entries)
          Role.values.byName(roleEntry.key):
              MoveProgress.fromJson(roleEntry.value as Map<String, dynamic>),
      };
    }

    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
      roles: roles,
      bpm: bpm,
      moves: moves,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roles': roles.map((r) => r.name).toList(),
        'bpm': {for (final e in bpm.entries) e.key.name: e.value},
        'moves': {
          for (final moveEntry in moves.entries)
            moveEntry.key: {
              for (final roleEntry in moveEntry.value.entries)
                roleEntry.key.name: roleEntry.value.toJson(),
            },
        },
      };

  Student copyWith({
    String? id,
    String? name,
    Set<Role>? roles,
    Map<Role, int>? bpm,
    Map<String, Map<Role, MoveProgress>>? moves,
  }) =>
      Student(
        id: id ?? this.id,
        name: name ?? this.name,
        roles: roles ?? this.roles,
        bpm: bpm ?? this.bpm,
        moves: moves ?? this.moves,
      );

  MoveProgress progressFor(String moveId, Role role) =>
      moves[moveId]?[role] ?? const MoveProgress();
}
