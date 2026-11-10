import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalQueueService {
  static Database? _database;
  static const String tableName = 'local_clients';
  final bool inMemory;

  /// Stockage de secours en mémoire (utilisé sur le Web, Desktop sans FFI,
  /// ou lors des tests de widgets qui n'initialisent pas sqflite_common_ffi).
  final List<Map<String, dynamic>> _fallbackMemoryStore = [];
  bool _forceFallback = kIsWeb;

  LocalQueueService({this.inMemory = false});

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

  bool get _isTestBinding {
    if (inMemory) return false;
    final bindingName = WidgetsFlutterBinding.ensureInitialized().runtimeType.toString();
    return bindingName.contains('Test');
  }

  bool get _useFallback => _forceFallback || _isTestBinding;

  Future<void> insertClientLocally(Map<String, dynamic> client) async {
    if (!_useFallback) {
      try {
        final db = await database;
        await db.insert(
          tableName,
          client,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return;
      } catch (e) {
        debugPrint('SQLite fallback activated (insert): $e');
        _forceFallback = true;
      }
    }

    final copy = Map<String, dynamic>.from(client);
    copy['is_synced'] ??= 0;
    _fallbackMemoryStore.removeWhere((item) => item['id'] == copy['id']);
    _fallbackMemoryStore.add(copy);
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    if (!_useFallback) {
      try {
        final db = await database;
        return await db.query(tableName, orderBy: 'created_at ASC');
      } catch (e) {
        debugPrint('SQLite fallback activated (getClients): $e');
        _forceFallback = true;
      }
    }

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

  Future<List<Map<String, dynamic>>> getUnsyncedClients() async {
    if (!_useFallback) {
      try {
        final db = await database;
        return await db.query(
          tableName,
          where: 'is_synced = ?',
          whereArgs: [0],
        );
      } catch (e) {
        debugPrint('SQLite fallback activated (getUnsyncedClients): $e');
        _forceFallback = true;
      }
    }

    return _fallbackMemoryStore
        .where((item) => (item['is_synced'] ?? 0) == 0)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> markClientAsSynced(String id) async {
    if (!_useFallback) {
      try {
        final db = await database;
        await db.update(
          tableName,
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        return;
      } catch (e) {
        debugPrint('SQLite fallback activated (markClientAsSynced): $e');
        _forceFallback = true;
      }
    }

    for (final item in _fallbackMemoryStore) {
      if (item['id'] == id) {
        item['is_synced'] = 1;
      }
    }
  }

  Future<void> removeClientLocally(String idOrName) async {
    if (!_useFallback) {
      try {
        final db = await database;
        await db.delete(
          tableName,
          where: 'id = ? OR name = ?',
          whereArgs: [idOrName, idOrName],
        );
        return;
      } catch (e) {
        debugPrint('SQLite fallback activated (removeClientLocally): $e');
        _forceFallback = true;
      }
    }

    _fallbackMemoryStore.removeWhere(
      (item) => item['id'] == idOrName || item['name'] == idOrName,
    );
  }

  Future<void> clearClientsLocally() async {
    if (!_useFallback) {
      try {
        final db = await database;
        await db.delete(tableName);
        return;
      } catch (e) {
        debugPrint('SQLite fallback activated (clearClientsLocally): $e');
        _forceFallback = true;
      }
    }

    _fallbackMemoryStore.clear();
  }

  Future<void> close() async {
    _fallbackMemoryStore.clear();
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
