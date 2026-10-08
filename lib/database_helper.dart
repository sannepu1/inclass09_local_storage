import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = "MyDatabase.db";
  // Version 1 was Part I (my_table only). Version 2 adds folders and cards.
  static const _databaseVersion = 2;

  // Part I table (unchanged).
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  // Part II tables.
  static const foldersTable = 'folders';
  static const cardsTable = 'cards';

  late Database _db;

  /// The one shared connection. The catalog repository uses this.
  Database get db => _db;

  // this opens the database (and creates it if it doesn't exist)
  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Runs before create/upgrade on every open. Without this, SQLite ignores
  // FOREIGN KEY rules and ON DELETE CASCADE silently does nothing.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Fresh install: build the full version 2 schema (Part I table + new tables).
  // sqflite runs onCreate and onUpgrade inside a transaction, so a failure
  // part way through rolls back instead of leaving a half-built schema.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE $table (
$columnId INTEGER PRIMARY KEY,
$columnName TEXT NOT NULL,
$columnAge INTEGER NOT NULL
)
''');
    await _createCatalogTables(db);
  }

  // Existing Part I install (version 1): only ADD the new tables.
  // my_table and its rows are never dropped or recreated.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCatalogTables(db);
    }
  }

  Future<void> _createCatalogTables(Database db) async {
    await db.execute('''
CREATE TABLE $foldersTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE $cardsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  suit TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  image_ref TEXT,
  folder_id INTEGER NOT NULL,
  FOREIGN KEY (folder_id) REFERENCES $foldersTable(id) ON DELETE CASCADE
)
''');
    await db.execute(
      'CREATE INDEX idx_cards_folder_id ON $cardsTable(folder_id)',
    );
  }

// Helper methods for the Part I guest table (unchanged from Part I)
// Inserts a row in the database where each key in the
//Map is a column name
// and the value is the column value. The return value
//is the id of the
// inserted row.
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

// All of the rows are returned as a list of maps, where each map is
// a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(table, orderBy: '$columnId ASC');
  }

// All of the methods (insert, query, update, delete) can also be done using
// raw SQL commands. This method uses a raw query to give the row count.
  Future<int> queryRowCount() async {
    final results = await _db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(results) ?? 0;
  }

// We are assuming here that the id column in the map is set. The other
// column values will be used to update the row.
  Future<int> update(Map<String, dynamic> row) async {
    int id = row[columnId];
    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

// Deletes the row specified by the id. The number of affected rows is
// returned. This should be 1 as long as the row exists.
  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}
