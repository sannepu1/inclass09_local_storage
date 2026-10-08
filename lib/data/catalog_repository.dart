import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/card_item.dart';
import '../models/folder.dart';

/// The only place the folder/card screens get data from.
/// All SQL for Part II lives here, and every value is bound with whereArgs.
class CatalogRepository {
  CatalogRepository(this.db);

  final Database db;

  static const _folders = DatabaseHelper.foldersTable;
  static const _cards = DatabaseHelper.cardsTable;

  // ---------- Folders ----------

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await db.rawQuery('''
SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
FROM $_folders f
LEFT JOIN $_cards c ON c.folder_id = f.id
GROUP BY f.id
ORDER BY f.name COLLATE NOCASE ASC
''');
    return rows.map(Folder.fromMap).toList();
  }

  /// Returns the new folder's id. Throws if the name already exists (UNIQUE).
  Future<int> insertFolder(String name) {
    final folder = Folder(
      name: name,
      createdAt: DateTime.now().toIso8601String(),
    );
    return db.insert(
      _folders,
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Returns the number of rows changed (0 means the folder is gone).
  Future<int> renameFolder(int id, String name) {
    return db.update(
      _folders,
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deleting a folder also deletes its cards through ON DELETE CASCADE.
  Future<int> deleteFolder(int id) {
    return db.delete(_folders, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Cards ----------

  Future<List<CardItem>> getCards(int folderId) async {
    final rows = await db.query(
      _cards,
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(CardItem.fromMap).toList();
  }

  /// Returns the new card's id.
  Future<int> insertCard(CardItem card) {
    return db.insert(
      _cards,
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Returns the number of rows changed (0 means the card is gone).
  Future<int> updateCard(CardItem card) {
    return db.update(
      _cards,
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) {
    return db.delete(_cards, where: 'id = ?', whereArgs: [id]);
  }
}
