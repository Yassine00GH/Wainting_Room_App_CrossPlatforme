import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectivityService {
  final Connectivity _connectivity;
  final SupabaseClient? _supabase;

  ConnectivityService(
    this._supabase, {
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity();

  Future<bool> hasNetwork() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  Stream<bool> get networkChanges {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((result) => result != ConnectivityResult.none),
    );
  }

  Future<bool> isSupabaseAvailable() async {
    if (_supabase == null) return false;
    try {
      await _supabase
          .from('clients')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }
}

