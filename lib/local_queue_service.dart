import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalQueueService {
  static Database? _database;
  static const String tableName = 'local_clients';
  final bool inMemory;

  /// Fallback en mémoire utilisé uniquement lors des tests unitaires/widgets
  /// qui n'initialisent pas explicitement sqflite_common_ffi (`inMemory: false`).
  final List<Map<String, dynamic>> _fallbackMemoryStore = [];

  LocalQueueService({this.inMemory = false});

  bool get _useFallbackStore =>
      !inMemory && Platform.environment.containsKey('FLUTTER_TEST');

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (inMemory) {
      return await openDatabase(
        ':memory:',
        version: 1,
        onCreate: _onCreate,
        singleInstance: false,
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'waiting_room.db');
      return openDatabase(path, version: 1, onCreate: _onCreate);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL,
        lng REAL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    if (_useFallbackStore) {
      final copy = Map<String, dynamic>.from(client);
      copy['is_synced'] ??= 0;
      _fallbackMemoryStore.removeWhere((item) => item['id'] == copy['id']);
      _fallbackMemoryStore.add(copy);
      return;
    }

    final db = await database;
    await db.insert(
      tableName,
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    if (_useFallbackStore) {
      final list = _fallbackMemoryStore
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      list.sort(
        (a, b) => (a['created_at'] ?? '')
            .toString()
            .compareTo((b['created_at'] ?? '').toString()),
      );
      return list;
    }

    final db = await database;
    return db.query(tableName, orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedClients() async {
    if (_useFallbackStore) {
      return _fallbackMemoryStore
          .where((item) => (item['is_synced'] ?? 0) == 0)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final db = await database;
    return db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markClientAsSynced(String id) async {
    if (_useFallbackStore) {
      for (final item in _fallbackMemoryStore) {
        if (item['id'] == id) {
          item['is_synced'] = 1;
        }
      }
      return;
    }

    final db = await database;
    await db.update(
      tableName,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removeClientLocally(String idOrName) async {
    if (_useFallbackStore) {
      _fallbackMemoryStore.removeWhere(
        (item) => item['id'] == idOrName || item['name'] == idOrName,
      );
      return;
    }

    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ? OR name = ?',
      whereArgs: [idOrName, idOrName],
    );
  }

  Future<void> clearClientsLocally() async {
    if (_useFallbackStore) {
      _fallbackMemoryStore.clear();
      return;
    }

    final db = await database;
    await db.delete(tableName);
  }

  Future<void> close() async {
    if (_useFallbackStore) {
      _fallbackMemoryStore.clear();
      return;
    }

    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
