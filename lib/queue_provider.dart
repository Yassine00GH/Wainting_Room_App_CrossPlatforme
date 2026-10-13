import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waiting_room_app/models/client.dart';

class QueueProvider extends ChangeNotifier {
  List<Client> _clients = [];
  List<Client> get clients => _clients;

  SupabaseClient? _supabase;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSupabaseConnected = false;
  bool get isSupabaseConnected => _isSupabaseConnected;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Accesseur d'aide pour le client en cours de traitement
  Client? get currentClient => _clients.isNotEmpty ? _clients.first : null;

  // Accesseur d'aide pour le nombre total de clients
  int get queueCount => _clients.length;

  /// Constructeur standard
  QueueProvider({SupabaseClient? client}) {
    if (client != null) {
      _supabase = client;
      _initSupabase();
    } else {
      try {
        _supabase = Supabase.instance.client;
        _initSupabase();
      } catch (e) {
        // Supabase non initialisé (ex: mode démo/test ou pas de clés)
        _isSupabaseConnected = false;
      }
    }
  }

  /// Constructeur nommé pour les tests
  QueueProvider.forTesting(SupabaseClient client) {
    _supabase = client;
  }

  void _initSupabase() {
    if (_supabase == null) return;
    _isSupabaseConnected = true;
    _isLoading = true;
    notifyListeners();

    try {
      // Souscription au flux Realtime Supabase (v2 API)
      // Synchronise automatiquement INSERT, UPDATE, DELETE en temps réel
      _streamSubscription = _supabase!
          .from('clients')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .listen(
        (data) {
          _clients = data.map(Client.fromMap).toList();
          _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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

  /// Ajouter un client dans la file d'attente
  Future<void> addClient(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    if (_isSupabaseConnected && _supabase != null) {
      try {
        await _supabase!.from('clients').insert({'name': trimmedName});
      } catch (e) {
        _errorMessage = "Erreur lors de l'ajout: $e";
        notifyListeners();
      }
    } else {
      // Fallback local en mémoire avec ID unique
      final uniqueId = '${DateTime.now().microsecondsSinceEpoch}_${_clients.length}';
      final newClient = Client(
        id: uniqueId,
        name: trimmedName,
        createdAt: DateTime.now(),
      );
      _clients.add(newClient);
      _clients.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
    }
  }

  /// Supprimer un client par son identifiant unique ou son nom
  Future<void> removeClient(String idOrName) async {
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
    } else {
      // Fallback local en mémoire
      _clients.removeWhere((client) => client.id == idOrName || client.name == idOrName);
      notifyListeners();
    }
  }

  /// Appeler et faire passer le premier client de la file
  Future<void> nextClient() async {
    if (_clients.isEmpty) return;

    final firstClient = _clients.first;
    await removeClient(firstClient.id);
  }

  /// Vider toute la file (utile pour maintenance)
  Future<void> clearQueue() async {
    if (_isSupabaseConnected && _supabase != null) {
      try {
        await _supabase!.from('clients').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (e) {
        _errorMessage = 'Erreur lors du nettoyage: $e';
        notifyListeners();
      }
    } else {
      _clients.clear();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
