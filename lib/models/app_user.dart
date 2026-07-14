/// Mirrors the `user:read` serialization group exposed by GET /api/me on the moncampus backend
/// (see App\Entity\User's ApiResource attribute) - only the fields that group exposes exist here.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.roles,
    this.email,
    this.firstname,
    this.lastname,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        username: json['username'] as String,
        email: json['email'] as String?,
        firstname: json['firstname'] as String?,
        lastname: json['lastname'] as String?,
        roles: (json['roles'] as List<dynamic>? ?? const [])
            .map((role) => role as String)
            .toList(),
      );

  final int id;
  final String username;
  final String? email;
  final String? firstname;
  final String? lastname;
  final List<String> roles;

  /// French convention: "NOM Prénom" (surname upper-cased, first name as-is) - falls back to the
  /// login when LDAP hasn't supplied a name at all (see App\Security\LdapUserMapper on the API
  /// side, which leaves firstname/lastname null if givenName/sn are unset in the directory).
  String get greetingName {
    final parts = <String>[
      if (lastname != null && lastname!.isNotEmpty) lastname!.toUpperCase(),
      if (firstname != null && firstname!.isNotEmpty) firstname!,
    ];

    return parts.isNotEmpty ? parts.join(' ') : username;
  }

  String get initials {
    final first = (firstname?.isNotEmpty ?? false) ? firstname![0] : '';
    final last = (lastname?.isNotEmpty ?? false) ? lastname![0] : '';
    final combined = '$first$last'.toUpperCase();

    return combined.isNotEmpty ? combined : username[0].toUpperCase();
  }
}
