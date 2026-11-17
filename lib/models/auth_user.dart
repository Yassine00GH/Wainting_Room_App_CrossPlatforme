enum UserRole {
  admin,
  client,
}

class AuthUser {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String tel;
  final String motDePasse;
  final UserRole role;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.tel,
    required this.motDePasse,
    required this.role,
    required this.createdAt,
  });

  String get fullName => '$prenom $nom'.trim();

  bool get isAdmin => role == UserRole.admin;
  bool get isClient => role == UserRole.client;

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email.trim().toLowerCase(),
      'tel': tel,
      'mot_de_passe': motDePasse,
      'role': role.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toLocalMap() => toSupabaseMap();

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    final rawRole = (map['role'] ?? 'client').toString().toLowerCase();
    final role = rawRole == 'admin' ? UserRole.admin : UserRole.client;

    return AuthUser(
      id: (map['id'] ?? '').toString(),
      nom: (map['nom'] ?? '').toString(),
      prenom: (map['prenom'] ?? '').toString(),
      email: (map['email'] ?? '').toString().trim().toLowerCase(),
      tel: (map['tel'] ?? '').toString(),
      motDePasse: (map['mot_de_passe'] ?? '').toString(),
      role: role,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
