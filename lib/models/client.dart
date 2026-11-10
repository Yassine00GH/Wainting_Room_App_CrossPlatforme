import 'sync_status.dart';

class Client {
  final String id;
  final String name;
  final double? lat;
  final double? lng;
  final double? locationAccuracy;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  const Client({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.locationAccuracy,
    required this.createdAt,
    this.syncStatus = SyncStatus.synced,
  });

  bool get hasLocation => lat != null && lng != null;

  String get locationText {
    if (!hasLocation) {
      return 'Location not captured';
    }
    return '${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}';
  }

  /// Initiales du client pour l'avatar UI moderne
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Format de l'heure d'arrivée (HH:mm)
  String get formattedTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Serialization for Supabase (Business data only)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'location_accuracy_m': locationAccuracy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Serialization for SQLite (Includes local synchronization status)
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'location_accuracy_m': locationAccuracy,
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Client.fromSupabaseMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'].toString(),
      name: map['name'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      locationAccuracy: (map['location_accuracy_m'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: SyncStatus.synced,
    );
  }

  factory Client.fromLocalMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      name: map['name'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      locationAccuracy: (map['location_accuracy_m'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (status) => status.name == map['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }

  /// Compatibilité avec l'ancien fromMap
  factory Client.fromMap(Map<String, dynamic> map) {
    if (map.containsKey('sync_status')) {
      return Client.fromLocalMap(map);
    }
    return Client.fromSupabaseMap(map);
  }

  /// Accès par opérateur indexé pour compatibilité des tests
  dynamic operator [](String key) {
    switch (key) {
      case 'id':
        return id;
      case 'name':
        return name;
      case 'lat':
        return lat;
      case 'lng':
        return lng;
      case 'location_accuracy_m':
        return locationAccuracy;
      case 'created_at':
        return createdAt.toIso8601String();
      case 'sync_status':
        return syncStatus.name;
      default:
        return null;
    }
  }

  Client copyWith({
    String? id,
    String? name,
    double? lat,
    double? lng,
    double? locationAccuracy,
    DateTime? createdAt,
    SyncStatus? syncStatus,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Client &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Client(id: $id, name: $name, lat: $lat, lng: $lng, syncStatus: $syncStatus)';
}
