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

  const Move({
    required this.id,
    required this.name,
    required this.type,
    required this.difficulty,
    this.description,
  });

  bool get hasDescription => description != null && description!.trim().isNotEmpty;

  factory Move.fromJson(Map<String, dynamic> json) => Move(
        id: json['id'] as String,
        name: json['name'] as String,
        type: MoveType.values.byName(json['type'] as String? ?? 'other'),
        difficulty: Difficulty.values
            .byName(json['difficulty'] as String? ?? 'beginner'),
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'difficulty': difficulty.name,
        if (description != null) 'description': description,
      };

  Move copyWith({
    String? id,
    String? name,
    MoveType? type,
    Difficulty? difficulty,
    String? description,
    bool clearDescription = false,
  }) =>
      Move(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        difficulty: difficulty ?? this.difficulty,
        description: clearDescription ? null : (description ?? this.description),
      );
}
