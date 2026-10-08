class Folder {
  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  final int? id;
  final String name;
  final String createdAt;

  /// Only filled in by getFoldersWithCounts(). Not a real column.
  final int cardCount;

  factory Folder.fromMap(Map<String, Object?> map) {
    return Folder(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['created_at'] as String,
      cardCount: (map['card_count'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }
}
