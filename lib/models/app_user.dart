/// Mirrors the `user:read` serialization group exposed by GET /api/me on the moncampus backend
/// (see App\Entity\User's ApiResource attribute) - only the fields that group exposes exist here,
/// plus [features], which App\Serializer\UserFeaturesNormalizer appends to the same response.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.roles,
    this.email,
    this.firstname,
    this.lastname,
    this.contactEmail,
    this.contactEmailVerified = false,
    this.features = const {},
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        username: json['username'] as String,
        email: json['email'] as String?,
        firstname: json['firstname'] as String?,
        lastname: json['lastname'] as String?,
        contactEmail: json['contactEmail'] as String?,
        contactEmailVerified: json['contactEmailVerified'] as bool? ?? false,
        roles: (json['roles'] as List<dynamic>? ?? const [])
            .map((role) => role as String)
            .toList(),
        features: ((json['features'] as Map<String, dynamic>?) ?? const {})
            .map((key, value) => MapEntry(key, value == true)),
      );

  final int id;
  final String username;
  final String? email;
  final String? firstname;
  final String? lastname;
  final List<String> roles;

  /// What this establishment runs, resolved for this account
  /// (moncampus design/validated/feature-access.md §10.1): every key of the catalogue, with `true`
  /// or `false`. Re-read on every call to GET /api/me, which the shell makes at startup and on
  /// every return to the foreground - so a feature switched off on the web reaches the app on its
  /// next breath rather than at its next login.
  ///
  /// **It is not a permission and it never grants one.** The backend guards each endpoint on its
  /// own and answers 404; this only stops the app from drawing a door that would slam. An empty map
  /// - an older backend, a response that lost the field - therefore has to mean "show everything",
  /// which is what [has] does: hiding the whole app because a key is missing would be the worse
  /// failure by far.
  final Map<String, bool> features;

  /// Whether [key] is switched on for this account. Unknown keys read as `true` - see [features].
  bool has(String key) => features[key] ?? true;

  /// Local-only address (App\Entity\User::$contactEmail on the backend) - distinct from [email],
  /// the LDAP-synced directory address. Drives the 3-state machine on ProfileScreen: null =
  /// missing, set+!verified = pending, set+verified = verified.
  final String? contactEmail;
  final bool contactEmailVerified;

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
