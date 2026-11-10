import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/queue_state.dart';
import '../models/sync_status.dart';
import '../repositories/queue_repository.dart';
import '../services/geolocation_service.dart';
import '../services/sync_service.dart';
import '../storage/local_queue_storage.dart';

class QueueProvider extends ChangeNotifier {
  final QueueRepository _repository;
  GeolocationService _geolocationService;
  final LocalQueueStorage? _storage;
  final SyncService? _syncService;

  final List<Client> _clients = [];
  QueueState _state = QueueState.initial;
  String? _errorMessage;

  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  QueueProvider({
    QueueRepository? repository,
    GeolocationService? geolocationService,
    GeolocationService? geoService,
    LocalQueueStorage? storage,
    SyncService? syncService,
  })  : _repository = repository ?? QueueRepository(null),
        _geolocationService =
            geoService ?? geolocationService ?? GeolocationService(),
        // ignore: prefer_initializing_formals
        _storage = storage,
        // ignore: prefer_initializing_formals
        _syncService = syncService;

  set geoService(GeolocationService service) {
    _geolocationService = service;
  }

  List<Client> get clients => List.unmodifiable(_clients);
  QueueState get state => _state;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  Client? get currentClient => _clients.isNotEmpty ? _clients.first : null;
  int get queueCount => _clients.length;

  Future<void> fetchInitialQueue() async {
    _state = QueueState.loading;
    _page = 0;
    _hasMore = true;
    notifyListeners();

    try {
      final data = await _repository.fetchPage(
        offset: 0,
        limit: _pageSize,
      );
      _clients.clear();
      _clients.addAll(data);
      _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      if (data.length < _pageSize) _hasMore = false;
    } catch (e) {
      if (_storage != null) {
        final localData = await _storage.getClients();
        if (localData.isNotEmpty) {
          _clients.clear();
          _clients.addAll(localData.map(Client.fromLocalMap));
          _state = QueueState.loaded;
          notifyListeners();
          return;
        }
      }
      _errorMessage = 'Failed to load queue';
      _state = QueueState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      _page++;
      final newClients = await _repository.fetchPage(
        offset: _page * _pageSize,
        limit: _pageSize,
      );
      final existingIds = _clients.map((c) => c.id).toSet();
      final uniqueNewClients =
          newClients.where((c) => !existingIds.contains(c.id));
      _clients.addAll(uniqueNewClients);
      if (newClients.length < _pageSize) _hasMore = false;
    } catch (_) {
      _page--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void handleRealtimeInsert(Client client) {
    final exists = _clients.any((c) => c.id == client.id);
    if (!exists) {
      _clients.add(client);
      _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (_state == QueueState.empty || _state == QueueState.initial) {
        _state = QueueState.loaded;
      }
      notifyListeners();
    }
  }

  void handleRealtimeDelete(String id) {
    _clients.removeWhere((c) => c.id == id);
    if (_clients.isEmpty) {
      _state = QueueState.empty;
    }
    notifyListeners();
  }

  Future<void> addClient(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    var client = Client(
      id: const Uuid().v4(),
      name: trimmedName,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    // Ajout synchrone dans la file (FIFO) et notification immédiate
    _clients.add(client);
    if (_state == QueueState.empty || _state == QueueState.initial) {
      _state = QueueState.loaded;
    }
    notifyListeners();

    // Sauvegarde locale immédiate
    if (_storage != null) {
      await _storage.saveClient(client.toLocalMap());
    }

    // Récupération asynchrone de la géolocalisation
    try {
      final pos = await _geolocationService.getCurrentPosition();
      if (pos != null) {
        client = client.copyWith(
          lat: pos.latitude,
          lng: pos.longitude,
          locationAccuracy: pos.accuracy,
        );
        final index = _clients.indexWhere((c) => c.id == client.id);
        if (index != -1) {
          _clients[index] = client;
          notifyListeners();
        }
        if (_storage != null) {
          await _storage.saveClient(client.toLocalMap());
        }
      }
    } catch (_) {}

    // Tentative de synchronisation distante
    try {
      final serverClient = await _repository.registerOnServer(client);
      if (_storage != null) {
        await _storage.updateSyncStatus(client.id, SyncStatus.synced);
      }
      final index = _clients.indexWhere((c) => c.id == client.id);
      if (index != -1) {
        _clients[index] = serverClient;
        notifyListeners();
      }
    } catch (_) {
      if (_storage != null) {
        await _storage.updateSyncStatus(client.id, SyncStatus.failed);
      }
    }
  }

  Future<void> deleteClient(String id) async {
    _clients.removeWhere((c) => c.id == id);
    if (_clients.isEmpty) {
      _state = QueueState.empty;
    }
    notifyListeners();

    if (_storage != null) {
      await _storage.removeClient(id);
    }

    try {
      await _repository.deleteClient(id);
    } catch (_) {}
  }

  Future<void> removeClient(String idOrName) async {
    final client = _clients.cast<Client?>().firstWhere(
      (c) => c?.id == idOrName || c?.name == idOrName,
      orElse: () => null,
    );
    if (client != null) {
      await deleteClient(client.id);
    } else {
      await deleteClient(idOrName);
    }
  }

  Future<void> nextClient() async {
    if (_clients.isEmpty) return;
    final firstClient = _clients.first;
    await deleteClient(firstClient.id);
  }

  Future<void> clearQueue() async {
    _clients.clear();
    _state = QueueState.empty;
    notifyListeners();
    if (_storage != null) {
      await _storage.clear();
    }
  }

  Future<void> syncPending() async {
    if (_syncService != null) {
      await _syncService.synchronize();
      await fetchInitialQueue();
    }
  }
}
