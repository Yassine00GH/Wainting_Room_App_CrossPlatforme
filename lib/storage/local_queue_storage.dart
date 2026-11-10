import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sync_status.dart';

class LocalQueueStorage {
  static Database? _database;
  final bool inMemory;

  LocalQueueStorage({this.inMemory = false});

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (inMemory) {
      return openDatabase(
        ':memory:',
        version: 1,
        onCreate: (db, version) async {
          await _createTables(db);
        },
      );
    }
    final path = join(await getDatabasesPath(), 'waiting_queue.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL,
        lng REAL,
        location_accuracy_m REAL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
  }

  Future<void> saveClient(Map<String, dynamic> client) async {
    final db = await database;
    await db.insert(
      'clients',
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    final db = await database;
    return db.query('clients', orderBy: 'created_at DESC, id DESC');
  }

  /// Corrected: Fetches both 'pending' and 'failed' records for retry logic
  Future<List<Map<String, dynamic>>> getPendingClients() async {
    final db = await database;
    return db.query(
      'clients',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC, id ASC',
    );
  }

  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    final db = await database;
    await db.update(
      'clients',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removeClient(String id) async {
    final db = await database;
    await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('clients');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

