import 'student.dart'; // for Role

enum MoveType { push, pass, whip, starterStep, throwOut, pickUp, other }

extension MoveTypeLabel on MoveType {
  String get label => switch (this) {
        MoveType.push => 'Push',
        MoveType.pass => 'Pass',
        MoveType.whip => 'Whip',
        MoveType.starterStep => 'Starter step',
        MoveType.throwOut => 'Throw out',
        MoveType.pickUp => 'Pick up',
        MoveType.other => 'Other',
      };
}

enum Difficulty { beginner, intermediate, advanced }

class Move {
  final String id;
  final String name;
  final MoveType type;
  final Difficulty difficulty;

  /// Optional long-form description, e.g. a step-by-step reminder for a
  /// move that doesn't have a single settled name. Null/empty for most
  /// catalog moves with simple, well-known names.
  final String? description;

  /// Which role(s) this move applies to. Null means both lead and follow.
  /// Role.lead means lead-only, Role.follow means follow-only.
  final Role? applicableTo;

  const Move({
    required this.id,
    required this.name,
    required this.type,
    required this.difficulty,
    this.description,
    this.applicableTo,
  });

  bool get hasDescription => description != null && description!.trim().isNotEmpty;

  /// Returns true if this move applies to the given role.
  /// If applicableTo is null, it applies to all roles.
  bool appliesTo(Role role) => applicableTo == null || applicableTo == role;

  factory Move.fromJson(Map<String, dynamic> json) => Move(
        id: json['id'] as String,
        name: json['name'] as String,
        type: MoveType.values.byName(json['type'] as String? ?? 'other'),
        difficulty: Difficulty.values
            .byName(json['difficulty'] as String? ?? 'beginner'),
        description: json['description'] as String?,
        applicableTo: json['applicableTo'] != null
            ? Role.values.byName(json['applicableTo'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'difficulty': difficulty.name,
        if (description != null) 'description': description,
        if (applicableTo != null) 'applicableTo': applicableTo!.name,
      };

  Move copyWith({
    String? id,
    String? name,
    MoveType? type,
    Difficulty? difficulty,
    String? description,
    Role? applicableTo,
    bool clearDescription = false,
    bool clearApplicableTo = false,
  }) =>
      Move(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        difficulty: difficulty ?? this.difficulty,
        description: clearDescription ? null : (description ?? this.description),
        applicableTo: clearApplicableTo ? null : (applicableTo ?? this.applicableTo),
      );
}
