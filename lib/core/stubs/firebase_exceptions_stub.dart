/// Minimal stub types so the app can compile without Firebase.
/// Replace/remove once Firebase is reintroduced.

class FirebaseException implements Exception {
  final String plugin;
  final String? message;
  final String? code;

  FirebaseException({this.plugin = 'stub', this.message, this.code});

  @override
  String toString() => 'FirebaseException($code): $message';
}

class FirebaseAuthException extends FirebaseException {
  FirebaseAuthException({String? message, String? code})
      : super(plugin: 'firebase_auth', message: message, code: code);
}
