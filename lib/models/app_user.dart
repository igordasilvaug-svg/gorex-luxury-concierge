import 'enums.dart';

/// Utilisateur de la plateforme (équipe ou client VIP)
class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String password;
  final UserRole role;
  final String? title;
  final String? phone;
  final String? avatarInitials;
  final String? clientId; // si l'utilisateur est un client VIP
  final bool active;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    this.title,
    this.phone,
    this.avatarInitials,
    this.clientId,
    this.active = true,
  });

  String get initials {
    if (avatarInitials != null && avatarInitials!.isNotEmpty) {
      return avatarInitials!;
    }
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'password': password,
    'role': role.name,
    'title': title,
    'phone': phone,
    'avatarInitials': avatarInitials,
    'clientId': clientId,
    'active': active,
  };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    id: m['id'] as String,
    fullName: m['fullName'] as String,
    email: m['email'] as String,
    password: m['password'] as String? ?? '',
    role: UserRole.fromName(m['role'] as String),
    title: m['title'] as String?,
    phone: m['phone'] as String?,
    avatarInitials: m['avatarInitials'] as String?,
    clientId: m['clientId'] as String?,
    active: m['active'] as bool? ?? true,
  );
}
