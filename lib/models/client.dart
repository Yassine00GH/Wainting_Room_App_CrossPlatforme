import 'dart:collection';

/// Modèle de données pour un client dans la salle d'attente.
/// Étend [MapBase<String, dynamic>] pour être 100% compatible à la fois :
/// - avec l'accès par propriétés (`client.name`, `client.id`, `client.lat`, `client.lng`)
/// - avec l'accès par clés Map du TP5 (`client['name']`, `client['lat']`, `client['lng']`)
class Client extends MapBase<String, dynamic> {
  final Map<String, dynamic> _data;

  Client({
    required String id,
    required String name,
    required DateTime createdAt,
    double? lat,
    double? lng,
    int isSynced = 0,
  }) : _data = {
          'id': id,
          'name': name,
          'lat': lat,
          'lng': lng,
          'created_at': createdAt.toIso8601String(),
          'is_synced': isSynced,
        };

  Client._fromRawMap(Map<String, dynamic> map)
      : _data = {
          'id': map['id']?.toString() ?? '',
          'name': map['name']?.toString() ?? 'Anonyme',
          'lat': (map['lat'] as num?)?.toDouble(),
          'lng': (map['lng'] as num?)?.toDouble(),
          'created_at': map['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
          'is_synced': (map['is_synced'] as num?)?.toInt() ?? 0,
        };

  /// Factory pour désérialiser depuis Supabase / SQLite / JSON
  factory Client.fromMap(Map<String, dynamic> map) {
    if (map is Client) return map;
    return Client._fromRawMap(map);
  }

  String get id => (_data['id'] ?? '').toString();
  String get name => (_data['name'] ?? 'Anonyme').toString();
  double? get lat => (_data['lat'] as num?)?.toDouble();
  double? get lng => (_data['lng'] as num?)?.toDouble();
  int get isSynced => (_data['is_synced'] as num?)?.toInt() ?? 0;

  DateTime get createdAt {
    final raw = _data['created_at']?.toString();
    return raw != null ? DateTime.tryParse(raw) ?? DateTime.now() : DateTime.now();
  }

  /// Sérialisation pour SQLite / Supabase
  Map<String, dynamic> toMap({bool includeSyncFlag = true}) {
    final map = Map<String, dynamic>.from(_data);
    if (!includeSyncFlag) {
      map.remove('is_synced');
    }
    return map;
  }

  @override
  dynamic operator [](Object? key) => _data[key];

  @override
  void operator []=(String key, dynamic value) {
    _data[key] = value;
  }

  @override
  void clear() => _data.clear();

  @override
  Iterable<String> get keys => _data.keys;

  @override
  dynamic remove(Object? key) => _data.remove(key);

  @override
  String toString() =>
      'Client(id: $id, name: $name, lat: $lat, lng: $lng, created_at: ${_data['created_at']}, is_synced: $isSynced)';
}

/// Extension sur [Map<String, dynamic>] permettant d'utiliser `.name`, `.id`,
/// `.initials`, `.formattedTime`, `.lat`, `.lng` même sur des Maps brutes
/// injectées dans les tests (ex: Step 3.2 Widget Test).
extension ClientMapExtension on Map<String, dynamic> {
  String get id => (this['id'] ?? '').toString();
  String get name => (this['name'] ?? 'Anonyme').toString();
  double? get lat => (this['lat'] as num?)?.toDouble();
  double? get lng => (this['lng'] as num?)?.toDouble();
  int get isSynced => (this['is_synced'] as num?)?.toInt() ?? 0;

  DateTime get createdAt {
    final raw = this['created_at']?.toString();
    return raw != null ? DateTime.tryParse(raw) ?? DateTime.now() : DateTime.now();
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get formattedTime {
    final dt = createdAt;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get formattedLocation {
    final latitude = lat;
    final longitude = lng;
    if (latitude == null || longitude == null) {
      return '📍 Location not captured';
    }
    return '📍 ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}
