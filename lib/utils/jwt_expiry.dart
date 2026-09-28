import 'dart:convert';

/// The `exp` claim of a JWT, read without checking the signature: only the server can say a token
/// is genuine, the app only needs to know whether it is already over. Null when unreadable.
DateTime? jwtExpiry(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;

  try {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final exp = payload is Map ? payload['exp'] : null;

    return exp is num ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000) : null;
  } catch (_) {
    return null;
  }
}

/// A stored token worth resuming with: readable, and not about to run out - a minute of margin,
/// so the first screen's calls do not meet an expiry the splash screen just waved through.
bool isJwtUsable(String jwt, {DateTime? now}) {
  final expiry = jwtExpiry(jwt);

  return expiry != null && expiry.isAfter((now ?? DateTime.now()).add(const Duration(minutes: 1)));
}
