enum MoveType { push, pass, whip, other }

enum Difficulty { beginner, intermediate, advanced }

class Move {
  final String id;
  final String name;
  final MoveType type;
  final Difficulty difficulty;

  const Move({
    required this.id,
    required this.name,
    required this.type,
    required this.difficulty,
  });

  factory Move.fromJson(Map<String, dynamic> json) => Move(
        id: json['id'] as String,
        name: json['name'] as String,
        type: MoveType.values.byName(json['type'] as String? ?? 'other'),
        difficulty: Difficulty.values
            .byName(json['difficulty'] as String? ?? 'beginner'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'difficulty': difficulty.name,
      };

  Move copyWith({
    String? id,
    String? name,
    MoveType? type,
    Difficulty? difficulty,
  }) =>
      Move(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        difficulty: difficulty ?? this.difficulty,
      );
}
