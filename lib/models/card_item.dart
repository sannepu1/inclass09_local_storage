/// Named CardItem so it doesn't clash with Flutter's Card widget.
class CardItem {
  const CardItem({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  static const suits = ['hearts', 'diamonds', 'clubs', 'spades'];

  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  static String symbolFor(String suit) {
    switch (suit) {
      case 'hearts':
        return '♥';
      case 'diamonds':
        return '♦';
      case 'clubs':
        return '♣';
      case 'spades':
        return '♠';
      default:
        return '?';
    }
  }

  static String labelFor(String suit) {
    if (suit.isEmpty) return suit;
    return suit[0].toUpperCase() + suit.substring(1);
  }

  factory CardItem.fromMap(Map<String, Object?> map) {
    return CardItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      suit: map['suit'] as String,
      notes: (map['notes'] as String?) ?? '',
      imageRef: map['image_ref'] as String?,
      folderId: map['folder_id'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'suit': suit,
      'notes': notes,
      'image_ref': imageRef,
      'folder_id': folderId,
    };
  }
}
