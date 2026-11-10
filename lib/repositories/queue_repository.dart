import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client.dart';

class QueueRepository {
  final SupabaseClient? _supabase;

  QueueRepository(this._supabase);

  Future<Client> registerOnServer(Client client) async {
    if (_supabase == null) {
      throw Exception('Supabase client is not available');
    }

    try {
      // 1. Appel RPC PostgreSQL register_queue_client (Workshop 6 - Section 4.2)
      final response = await _supabase.rpc(
        'register_queue_client',
        params: {
          'p_id': client.id,
          'p_name': client.name,
          'p_lat': client.lat,
          'p_lng': client.lng,
          'p_accuracy': client.locationAccuracy,
          'p_created_at': client.createdAt.toIso8601String(),
        },
      );

      if (response is List && response.isNotEmpty) {
        return Client.fromSupabaseMap(
            Map<String, dynamic>.from(response.first));
      }
    } catch (_) {
      // 2. Fallback 1 : Upsert direct avec tous les champs du modèle
      try {
        await _supabase.from('clients').upsert(client.toSupabaseMap());
        return client;
      } catch (_) {
        // 3. Fallback 2 : Si la table Supabase n'a pas encore location_accuracy_m
        final withoutAccuracy =
            Map<String, dynamic>.from(client.toSupabaseMap())
              ..remove('location_accuracy_m');
        try {
          await _supabase.from('clients').upsert(withoutAccuracy);
          return client;
        } catch (_) {
          // 4. Fallback 3 : Schéma minimal (id, name, created_at)
          final minimalMap = <String, dynamic>{
            'id': client.id,
            'name': client.name,
            'created_at': client.createdAt.toIso8601String(),
          };
          await _supabase.from('clients').upsert(minimalMap);
          return client;
        }
      }
    }
    return client;
  }

  Future<List<Client>> fetchPage({
    required int offset,
    required int limit,
  }) async {
    if (_supabase == null) return [];
    final response = await _supabase
        .from('clients')
        .select()
        .order('created_at', ascending: true)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((row) => Client.fromSupabaseMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> deleteClient(String id) async {
    if (_supabase == null) return;
    await _supabase.from('clients').delete().eq('id', id);
  }

  RealtimeChannel? subscribeToInserts(void Function(Client client) onInsert) {
    if (_supabase == null) return null;
    final channel = _supabase.channel('public:clients');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'clients',
      callback: (payload) {
        final client = Client.fromSupabaseMap(payload.newRecord);
        onInsert(client);
      },
    ).subscribe();
    return channel;
  }

  RealtimeChannel? subscribeToDeletes(void Function(String id) onDelete) {
    if (_supabase == null) return null;
    final channel = _supabase.channel('public:clients_delete');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'clients',
      callback: (payload) {
        final id = payload.oldRecord['id']?.toString();
        if (id != null) {
          onDelete(id);
        }
      },
    ).subscribe();
    return channel;
  }
}

