import 'package:firebase_auth/firebase_auth.dart';

/// Wraps [FirebaseAuth] with a single, app-wide anonymous sign-in.
///
/// We use anonymous auth so every device has a stable `uid` that can own
/// its notes in Firestore, without changing the existing AppsPro/BDApps
/// subscription flow that gates the UI.
///
/// **Firebase Console prerequisite:** Authentication → Sign-in method →
/// "Anonymous" must be enabled, otherwise [signInAnonymously] will throw
/// `firebase_auth/undefined` with a message pointing there.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// The current user, or `null` if no anonymous sign-in has completed yet.
  User? get currentUser => _auth.currentUser;

  /// Convenience: the current uid, or `null` if not signed in.
  String? get currentUid => _auth.currentUser?.uid;

  /// Ensures we have an authenticated user. If a previous session is still
  /// valid, returns it immediately. Otherwise signs in anonymously.
  ///
  /// Safe to call multiple times — FirebaseAuth caches the signed-in user.
  Future<User> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing;
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  /// Signs out and clears the local anonymous session. Used by tests
  /// and (in the future) a "switch user" action.
  Future<void> signOut() => _auth.signOut();
}
