import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:waiting_room_app/geolocation_service.dart';
import 'package:waiting_room_app/local_queue_service.dart';
import 'package:waiting_room_app/models/client.dart';

export 'package:waiting_room_app/models/client.dart';

class QueueProvider extends ChangeNotifier {
  final LocalQueueService _localDb;
  GeolocationService _geoService;

  SupabaseClient? _supabase;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> get clients => _clients;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSupabaseConnected = false;
  bool get isSupabaseConnected => _isSupabaseConnected;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Accesseur d'aide pour le client en cours de traitement
  Map<String, dynamic>? get currentClient =>
      _clients.isNotEmpty ? _clients.first : null;

  /// Accesseur d'aide pour le nombre total de clients
  int get queueCount => _clients.length;

  /// Permet d'injecter un mock de GeolocationService pour les tests
  set geoService(GeolocationService service) {
    _geoService = service;
  }

  /// Constructeur standard avec injection de dépendances optionnelle (TDD)
  QueueProvider({
    SupabaseClient? client,
    LocalQueueService? localDb,
    GeolocationService? geoService,
  })  : _localDb = localDb ?? LocalQueueService(),
        _geoService = geoService ?? GeolocationService() {
    if (client != null) {
      _supabase = client;
      _isSupabaseConnected = true;
    } else {
      try {
        _supabase = Supabase.instance.client;
        _isSupabaseConnected = true;
      } catch (e) {
        // Supabase non initialisé (ex: mode hors-ligne / test local)
        _isSupabaseConnected = false;
      }
    }
    unawaited(initialize());
  }

  /// Constructeur nommé pour les tests
  QueueProvider.forTesting(
    SupabaseClient client, {
    LocalQueueService? localDb,
    GeolocationService? geoService,
  })  : _supabase = client,
        _localDb = localDb ?? LocalQueueService(inMemory: true),
        _geoService = geoService ?? GeolocationService(),
        _isSupabaseConnected = true;

  Future<void> initialize() async {
    await _loadQueue();
  }

  Future<void> _loadQueue() async {
    // 1. Load from local DB immediately (offline support)
    final localData = await _localDb.getClients();
    final existingIds = _clients.map((c) => c['id']?.toString()).toSet();
    for (final row in localData) {
      if (!existingIds.contains(row['id']?.toString())) {
        _clients.add(Client.fromMap(row));
      }
    }
    _clients.sort(
      (a, b) =>
          a['created_at'].toString().compareTo(b['created_at'].toString()),
    );
    notifyListeners();

    // 2. Sync unsynced records to Supabase
    await _syncLocalToRemote();

    // 3. Subscribe to real-time updates
    _setupRealtimeSubscription();
  }

  Future<void> _syncLocalToRemote() async {
    if (!_isSupabaseConnected || _supabase == null) return;

    final unsynced = await _localDb.getUnsyncedClients();
    for (var client in unsynced) {
      try {
        final remoteClient = Map<String, dynamic>.from(client)
          ..remove('is_synced');

        try {
          await _supabase!.from('clients').upsert(remoteClient);
        } catch (_) {
          // Fallback si la table Supabase distante n'a pas encore les colonnes lat/lng
          final fallbackClient = Map<String, dynamic>.from(remoteClient)
            ..remove('lat')
            ..remove('lng');
          await _supabase!.from('clients').upsert(fallbackClient);
        }

        await _localDb.markClientAsSynced(client['id'] as String);
      } catch (e) {
        debugPrint('Sync failed for ${client['id']}: $e');
      }
    }

    // Refresh UI if any sync succeeded
    final refreshed = await _localDb.getClients();
    _clients = refreshed.map(Client.fromMap).toList();
    notifyListeners();
  }

  /// Souscription temps réel Supabase
  void _setupRealtimeSubscription() {
    if (!_isSupabaseConnected || _supabase == null) return;
    _streamSubscription?.cancel();

    try {
      _streamSubscription = _supabase!
          .from('clients')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .listen(
        (data) async {
          // Conserver les clients locaux non encore synchronisés
          final unsynced = await _localDb.getUnsyncedClients();
          final unsyncedIds = unsynced.map((c) => c['id']?.toString()).toSet();

          // Mettre à jour le cache SQLite local avec les données distantes
          for (final remoteRow in data) {
            final localRow = <String, dynamic>{
              'id': remoteRow['id']?.toString() ?? const Uuid().v4(),
              'name': remoteRow['name']?.toString() ?? 'Anonyme',
              'lat': (remoteRow['lat'] as num?)?.toDouble(),
              'lng': (remoteRow['lng'] as num?)?.toDouble(),
              'created_at': remoteRow['created_at']?.toString() ??
                  DateTime.now().toIso8601String(),
              'is_synced': 1,
            };
            await _localDb.insertClientLocally(localRow);
          }

          final combined = <Map<String, dynamic>>[
            ...data.map((row) {
              final map = Map<String, dynamic>.from(row);
              map['is_synced'] = 1;
              return Client.fromMap(map);
            }),
            ...unsynced
                .where(
                  (u) => !data.any(
                    (r) => r['id']?.toString() == u['id']?.toString(),
                  ),
                )
                .map(Client.fromMap),
          ];

          combined.sort(
            (a, b) => a['created_at']
                .toString()
                .compareTo(b['created_at'].toString()),
          );

          // Nettoyer la base locale si un élément synchronisé a été supprimé à distance
          final remoteIds = data.map((r) => r['id']?.toString()).toSet();
          final allLocal = await _localDb.getClients();
          for (final localItem in allLocal) {
            final id = localItem['id']?.toString();
            if (id != null &&
                !remoteIds.contains(id) &&
                !unsyncedIds.contains(id)) {
              await _localDb.removeClientLocally(id);
            }
          }

          _clients = combined;
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = 'Erreur Realtime: $error';
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Impossible de se connecter à la table: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajouter un client dans la file d'attente (Offline-First + Geolocation)
  Future<void> addClient(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final newClient = Client.fromMap(<String, dynamic>{
      'id': const Uuid().v4(),
      'name': trimmedName,
      'lat': null,
      'lng': null,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });

    // Update UI instantly (optimistic update)
    _clients.add(newClient);
    _clients.sort(
      (a, b) =>
          a['created_at'].toString().compareTo(b['created_at'].toString()),
    );
    notifyListeners();

    // Capture device geolocation
    final position = await _geoService.getCurrentPosition();
    if (position != null) {
      newClient['lat'] = position.latitude;
      newClient['lng'] = position.longitude;
      notifyListeners();
    }

    // Save locally immediately
    await _localDb.insertClientLocally(newClient.toMap());

    // Attempt sync (non-blocking for UX)
    unawaited(_syncLocalToRemote());
  }

  /// Supprimer un client par son identifiant unique ou son nom
  Future<void> removeClient(String idOrName) async {
    _clients.removeWhere(
      (client) => client['id'] == idOrName || client['name'] == idOrName,
    );
    notifyListeners();

    await _localDb.removeClientLocally(idOrName);

    if (_isSupabaseConnected && _supabase != null) {
      try {
        await _supabase!
            .from('clients')
            .delete()
            .or('id.eq.$idOrName,name.eq.$idOrName');
      } catch (e) {
        _errorMessage = 'Erreur lors de la suppression: $e';
        notifyListeners();
      }
    }
  }

  /// Appeler et faire passer le premier client de la file
  Future<void> nextClient() async {
    if (_clients.isEmpty) return;

    final firstClient = _clients.first;
    await removeClient(firstClient['id'].toString());
  }

  /// Vider toute la file (utile pour maintenance)
  Future<void> clearQueue() async {
    _clients.clear();
    notifyListeners();

    await _localDb.clearClientsLocally();

    if (_isSupabaseConnected && _supabase != null) {
      try {
        await _supabase!
            .from('clients')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (e) {
        _errorMessage = 'Erreur lors du nettoyage: $e';
        notifyListeners();
      }
    }
  }

  /// Permet de relancer manuellement une synchronisation
  Future<void> syncNow() async {
    await _syncLocalToRemote();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
