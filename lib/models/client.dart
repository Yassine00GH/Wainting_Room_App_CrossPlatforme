/// Modèle de données pour un client dans la salle d'attente
class Client {
  final String id;
  final String name;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  /// Factory pour désérialiser depuis Supabase / JSON
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Anonyme',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Sérialisation pour l'insertion Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
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

  @override
  String toString() => 'Client(id: $id, name: $name, created_at: $createdAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Client &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
