import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;

  /// Stream of auth state changes for widgets that want to react declaratively.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  AppAuthProvider() {
    // Keep auth persistence explicit where supported (web).
    if (kIsWeb) {
      try {
        _auth.setPersistence(Persistence.LOCAL);
      } catch (_) {}
    }

    // Notify listeners whenever the underlying Firebase user changes.
    _auth.userChanges().listen((_) => notifyListeners());
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }
}
