import 'package:flutter/foundation.dart';
import '../models/auth_user.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  List<AuthUser> _registeredUsers = [];

  AuthProvider([AuthRepository? repository])
      : _repository = repository ?? AuthRepository(null);

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isClient => _currentUser?.isClient ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get tableMissingInSupabase => _repository.tableMissingInSupabase;
  List<AuthUser> get registeredUsers => List.unmodifiable(_registeredUsers);

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.login(
        email: email,
        password: password,
      );
      if (_currentUser?.isAdmin == true) {
        _registeredUsers = await _repository.fetchAllUsers();
      }
      return true;
    } on AppAuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Erreur de connexion : $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AuthUser?> registerClient({
    required String nom,
    required String prenom,
    required String email,
    required String tel,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.registerClient(
        nom: nom,
        prenom: prenom,
        email: email,
        tel: tel,
        password: password,
      );
      _currentUser = user;
      return user;
    } on AppAuthException catch (e) {
      _errorMessage = e.message;
      return null;
    } catch (e) {
      _errorMessage = 'Erreur lors de l\'inscription : $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRegisteredUsers() async {
    try {
      _registeredUsers = await _repository.fetchAllUsers();
      notifyListeners();
    } catch (_) {}
  }

  void logout() {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }
}
