import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sync_status.dart';

class LocalQueueStorage {
  static Database? _database;
  Database? _inMemoryDb;
  final bool inMemory;

  // Fallback en mémoire pour Flutter Web (Chrome) où sqflite natif n'est pas supporté
  final List<Map<String, dynamic>> _webClients = [];
  final List<Map<String, dynamic>> _webAuthUsers = [
    {
      'id': '00000000-0000-0000-0000-000000000001',
      'nom': 'Admin',
      'prenom': 'Système',
      'email': 'admin@gmail.com',
      'tel': '00000000',
      'mot_de_passe': '123456',
      'role': 'admin',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    }
  ];

  LocalQueueStorage({this.inMemory = false});

  Future<Database> get database async {
    if (inMemory) {
      _inMemoryDb ??= await _initDB();
      return _inMemoryDb!;
    }
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (inMemory) {
      return openDatabase(
        ':memory:',
        version: 2,
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedDefaultAdmin(db);
        },
      );
    }
    final path = join(await getDatabasesPath(), 'waiting_queue.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDefaultAdmin(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAuthTable(db);
          await _seedDefaultAdmin(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL,
        lng REAL,
        location_accuracy_m REAL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
    await _createAuthTable(db);
  }

  Future<void> _createAuthTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS authentification (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        tel TEXT,
        mot_de_passe TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'client',
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedDefaultAdmin(Database db) async {
    await db.insert(
      'authentification',
      {
        'id': '00000000-0000-0000-0000-000000000001',
        'nom': 'Admin',
        'prenom': 'Système',
        'email': 'admin@gmail.com',
        'tel': '00000000',
        'mot_de_passe': '123456',
        'role': 'admin',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> saveClient(Map<String, dynamic> client) async {
    if (kIsWeb) {
      _webClients.removeWhere((c) => c['id'] == client['id']);
      _webClients.add(Map<String, dynamic>.from(client));
      return;
    }
    final db = await database;
    await db.insert(
      'clients',
      client,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getClients() async {
    if (kIsWeb) {
      final list = _webClients.map((e) => Map<String, dynamic>.from(e)).toList();
      list.sort((a, b) =>
          (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
      return list;
    }
    final db = await database;
    return db.query('clients', orderBy: 'created_at ASC, id ASC');
  }

  /// Fetches both 'pending' and 'failed' records for retry logic
  Future<List<Map<String, dynamic>>> getPendingClients() async {
    if (kIsWeb) {
      final list = _webClients
          .where((c) => c['sync_status'] == 'pending' || c['sync_status'] == 'failed')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      list.sort((a, b) =>
          (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
      return list;
    }
    final db = await database;
    return db.query(
      'clients',
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC, id ASC',
    );
  }

  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    if (kIsWeb) {
      for (final c in _webClients) {
        if (c['id'] == id) c['sync_status'] = status.name;
      }
      return;
    }
    final db = await database;
    await db.update(
      'clients',
      {'sync_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> removeClient(String id) async {
    if (kIsWeb) {
      _webClients.removeWhere((c) => c['id'] == id);
      return;
    }
    final db = await database;
    await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clear() async {
    if (kIsWeb) {
      _webClients.clear();
      return;
    }
    final db = await database;
    await db.delete('clients');
  }

  // --- Méthodes locales pour la table authentification ---

  Future<void> saveAuthUser(Map<String, dynamic> user) async {
    if (kIsWeb) {
      final email = (user['email'] ?? '').toString().toLowerCase();
      _webAuthUsers.removeWhere(
        (u) => (u['email'] ?? '').toString().toLowerCase() == email,
      );
      _webAuthUsers.add(Map<String, dynamic>.from(user));
      return;
    }
    final db = await database;
    await db.insert(
      'authentification',
      user,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAuthUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (kIsWeb) {
      for (final u in _webAuthUsers) {
        if ((u['email'] ?? '').toString().toLowerCase() == normalized) {
          return Map<String, dynamic>.from(u);
        }
      }
      return null;
    }
    final db = await database;
    final rows = await db.query(
      'authentification',
      where: 'LOWER(email) = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getAllAuthUsers() async {
    if (kIsWeb) {
      final list = _webAuthUsers.map((e) => Map<String, dynamic>.from(e)).toList();
      list.sort((a, b) =>
          (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
      return list;
    }
    final db = await database;
    return db.query('authentification', orderBy: 'created_at DESC');
  }

  Future<void> close() async {
    if (kIsWeb) return;
    if (inMemory) {
      if (_inMemoryDb != null) {
        await _inMemoryDb!.close();
        _inMemoryDb = null;
      }
      return;
    }
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
