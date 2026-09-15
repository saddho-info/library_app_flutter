class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.publisherId,
    this.libraryId,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String? publisherId;
  final String? libraryId;

  String get displayName => '$firstName $lastName';

  bool get isLibraryRole =>
      role == 'SUPER_ADMIN' ||
      role == 'LIBRARY_ADMIN' ||
      role == 'LIBRARY_STAFF';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      role: json['role'] as String,
      publisherId: json['publisherId'] as String?,
      libraryId: json['libraryId'] as String?,
    );
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AuthUser user;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
