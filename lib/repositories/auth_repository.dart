import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:uuid/uuid.dart';
import '../models/auth_user.dart';
import '../storage/local_queue_storage.dart';

class AppAuthException implements Exception {
  final String message;
  const AppAuthException(this.message);

  @override
  String toString() => message;
}

class AuthRepository {
  final SupabaseClient? _supabase;
  final LocalQueueStorage? _storage;

  bool tableMissingInSupabase = false;

  AuthRepository(this._supabase, [this._storage]);

  static const String defaultAdminEmail = 'admin@gmail.com';
  static const String defaultAdminPassword = '123456';

  bool _isTableMissingError(Object error) {
    if (error is PostgrestException) {
      return error.code == 'PGRST205' ||
          error.code == '42P01' ||
          error.message.contains('authentification');
    }
    final msg = error.toString();
    return msg.contains('PGRST205') ||
        msg.contains('42P01') ||
        msg.contains("Could not find the table 'public.authentification'");
  }

  bool _isUniqueViolationError(Object error) {
    if (error is PostgrestException) {
      return error.code == '23505' ||
          error.message.toLowerCase().contains('unique') ||
          error.message.toLowerCase().contains('duplicate');
    }
    final msg = error.toString().toLowerCase();
    return msg.contains('23505') ||
        msg.contains('unique') ||
        msg.contains('duplicate');
  }

  Future<AuthUser> registerClient({
    required String nom,
    required String prenom,
    required String email,
    required String tel,
    required String password,
  }) async {
    final cleanNom = nom.trim();
    final cleanPrenom = prenom.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final cleanTel = tel.trim();

    if (cleanNom.isEmpty ||
        cleanPrenom.isEmpty ||
        normalizedEmail.isEmpty ||
        password.isEmpty) {
      throw const AppAuthException(
          'Veuillez remplir tous les champs obligatoires.');
    }

    if (normalizedEmail == defaultAdminEmail) {
      throw const AppAuthException(
          'Cet email est réservé au compte administrateur.');
    }

    // 1. Vérifier l'unicité de l'email sur Supabase si configuré
    bool savedToSupabase = false;
    if (_supabase != null) {
      try {
        final existing = await _supabase
            .from('authentification')
            .select('id')
            .eq('email', normalizedEmail)
            .maybeSingle();

        tableMissingInSupabase = false;
        if (existing != null) {
          throw const AppAuthException(
              'Un compte existe déjà avec cet email.');
        }

        final user = AuthUser(
          id: const Uuid().v4(),
          nom: cleanNom,
          prenom: cleanPrenom,
          email: normalizedEmail,
          tel: cleanTel,
          motDePasse: password,
          role: UserRole.client,
          createdAt: DateTime.now(),
        );

        await _supabase.from('authentification').insert(user.toSupabaseMap());
        savedToSupabase = true;

        if (_storage != null) {
          await _storage.saveAuthUser(user.toLocalMap());
        }
        return user;
      } catch (e) {
        if (e is AppAuthException) rethrow;
        if (_isUniqueViolationError(e)) {
          throw const AppAuthException(
              'Un compte existe déjà avec cet email.');
        }
        if (_isTableMissingError(e)) {
          tableMissingInSupabase = true;
          debugPrint(
              'Table authentification absente dans Supabase. Sauvegarde locale uniquement.');
        } else {
          // Autre erreur réseau : on tente la vérification / sauvegarde locale
          debugPrint('Supabase register fallback to local: $e');
        }
      }
    }

    // 2. Fallback local (hors-ligne ou tests unitaires ou table pas encore créée)
    if (!savedToSupabase && _storage != null) {
      final existingLocal = await _storage.getAuthUserByEmail(normalizedEmail);
      if (existingLocal != null) {
        throw const AppAuthException('Un compte existe déjà avec cet email.');
      }

      final user = AuthUser(
        id: const Uuid().v4(),
        nom: cleanNom,
        prenom: cleanPrenom,
        email: normalizedEmail,
        tel: cleanTel,
        motDePasse: password,
        role: UserRole.client,
        createdAt: DateTime.now(),
      );
      await _storage.saveAuthUser(user.toLocalMap());
      return user;
    }

    // 3. Dernier recours en mémoire (ex: tests sans SQLite ni Supabase)
    return AuthUser(
      id: const Uuid().v4(),
      nom: cleanNom,
      prenom: cleanPrenom,
      email: normalizedEmail,
      tel: cleanTel,
      motDePasse: password,
      role: UserRole.client,
      createdAt: DateTime.now(),
    );
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AppAuthException('Veuillez saisir votre email et mot de passe.');
    }

    // 1. Vérification distante Supabase
    if (_supabase != null) {
      try {
        final record = await _supabase
            .from('authentification')
            .select()
            .eq('email', normalizedEmail)
            .maybeSingle();

        tableMissingInSupabase = false;

        if (record != null) {
          final user = AuthUser.fromMap(Map<String, dynamic>.from(record));
          if (user.motDePasse != password) {
            throw const AppAuthException('Email ou mot de passe incorrect.');
          }
          if (_storage != null) {
            await _storage.saveAuthUser(user.toLocalMap());
          }
          return user;
        }

        // Si le compte admin par défaut n'a pas encore été inséré dans la table,
        // on l'initialise automatiquement s'il s'agit des identifiants admin définis.
        if (normalizedEmail == defaultAdminEmail &&
            password == defaultAdminPassword) {
          final adminUser = AuthUser(
            id: '00000000-0000-0000-0000-000000000001',
            nom: 'Admin',
            prenom: 'Système',
            email: defaultAdminEmail,
            tel: '00000000',
            motDePasse: defaultAdminPassword,
            role: UserRole.admin,
            createdAt: DateTime.now(),
          );
          try {
            await _supabase
                .from('authentification')
                .upsert(adminUser.toSupabaseMap());
          } catch (_) {}
          if (_storage != null) {
            await _storage.saveAuthUser(adminUser.toLocalMap());
          }
          return adminUser;
        }

        throw const AppAuthException('Aucun compte trouvé avec cet email.');
      } catch (e) {
        if (e is AppAuthException) rethrow;
        if (_isTableMissingError(e)) {
          tableMissingInSupabase = true;
          debugPrint('Table authentification non trouvée sur Supabase.');
        } else {
          debugPrint('Supabase login fallback to local: $e');
        }
      }
    }

    // 2. Fallback local SQLite
    if (_storage != null) {
      final localRecord = await _storage.getAuthUserByEmail(normalizedEmail);
      if (localRecord != null) {
        final user = AuthUser.fromMap(localRecord);
        if (user.motDePasse != password) {
          throw const AppAuthException('Email ou mot de passe incorrect.');
        }
        return user;
      }
    }

    // 3. Fallback Admin par défaut (même si aucun stockage disponible dans un test)
    if (normalizedEmail == defaultAdminEmail &&
        password == defaultAdminPassword) {
      return AuthUser(
        id: '00000000-0000-0000-0000-000000000001',
        nom: 'Admin',
        prenom: 'Système',
        email: defaultAdminEmail,
        tel: '00000000',
        motDePasse: defaultAdminPassword,
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );
    }

    throw const AppAuthException('Email ou mot de passe incorrect.');
  }

  Future<List<AuthUser>> fetchAllUsers() async {
    if (_supabase != null) {
      try {
        final rows = await _supabase
            .from('authentification')
            .select()
            .order('created_at', ascending: false);
        tableMissingInSupabase = false;
        final users = (rows as List)
            .map((r) => AuthUser.fromMap(Map<String, dynamic>.from(r)))
            .toList();
        if (_storage != null) {
          for (final u in users) {
            await _storage.saveAuthUser(u.toLocalMap());
          }
        }
        return users;
      } catch (e) {
        if (_isTableMissingError(e)) {
          tableMissingInSupabase = true;
        }
      }
    }

    if (_storage != null) {
      final localRows = await _storage.getAllAuthUsers();
      return localRows.map(AuthUser.fromMap).toList();
    }

    return [];
  }
}
