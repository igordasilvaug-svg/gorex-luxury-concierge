// GOREX GROUP — Authentification Firebase (e-mail / mot de passe réel).
//
// Ce service gère :
//   • la connexion par e-mail + mot de passe (comptes professionnels & clients) ;
//   • la déconnexion ;
//   • le changement de mot de passe (avec ré-authentification sécurisée) ;
//   • l'envoi du lien de réinitialisation.
//
// Il reste TOTALEMENT DÉFENSIF : en l'absence de Firebase (tests, hors-ligne),
// l'application retombe sur l'authentification locale (AppState.authenticate).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Résultat d'une tentative de connexion Firebase.
class FirebaseSignInResult {
  const FirebaseSignInResult({required this.ok, this.uid, this.error});
  final bool ok;
  final String? uid;
  final String? error;

  static const unavailable = FirebaseSignInResult(
    ok: false,
    error: 'FIREBASE_UNAVAILABLE',
  );
}

class FirebaseAuthService {
  FirebaseAuthService._();

  static bool _signedIn = false;
  static String? _uid;
  static bool _attempted = false;

  /// Vrai si une session Firebase est active (anonyme ou nominative).
  static bool get signedIn => _signedIn;

  /// Identifiant Firebase de la session (diagnostic).
  static String? get uid => _uid;

  /// Vrai si l'utilisateur courant est connecté par e-mail/mot de passe
  /// (par opposition à une session anonyme technique).
  static bool get isNamedUser {
    try {
      final u = FirebaseAuth.instance.currentUser;
      return u != null && u.email != null && !u.isAnonymous;
    } catch (_) {
      return false;
    }
  }

  static String? get currentEmail {
    try {
      return FirebaseAuth.instance.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  /// Établit une session anonyme technique (idempotente).
  /// Utilisée uniquement pour accéder à Firestore avant toute connexion.
  static Future<bool> ensureSignedIn() async {
    if (_attempted && _signedIn) return true;
    _attempted = true;
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) {
        _signedIn = true;
        _uid = auth.currentUser!.uid;
        return true;
      }
      final cred = await auth.signInAnonymously();
      _signedIn = cred.user != null;
      _uid = cred.user?.uid;
      return _signedIn;
    } catch (e) {
      _signedIn = false;
      if (kDebugMode) debugPrint('[Auth] anonyme indisponible : $e');
      return false;
    }
  }

  /// Connexion nominative par e-mail + mot de passe.
  static Future<FirebaseSignInResult> signIn(
    String email,
    String password,
  ) async {
    try {
      final auth = FirebaseAuth.instance;
      // Déconnecte toute session anonyme technique avant la connexion nominative.
      if (auth.currentUser != null && auth.currentUser!.isAnonymous) {
        await auth.signOut();
      }
      final cred = await auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      _signedIn = cred.user != null;
      _uid = cred.user?.uid;
      return FirebaseSignInResult(ok: true, uid: _uid);
    } on FirebaseAuthException catch (e) {
      _signedIn = false;
      return FirebaseSignInResult(ok: false, error: _messageFor(e));
    } catch (e) {
      return FirebaseSignInResult.unavailable;
    }
  }

  /// Ré-authentifie l'utilisateur courant (requis avant changement sensible).
  static Future<bool> reauthenticate(String currentPassword) async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null || u.email == null) return false;
      final cred = EmailAuthProvider.credential(
        email: u.email!,
        password: currentPassword,
      );
      await u.reauthenticateWithCredential(cred);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] ré-auth échouée : $e');
      return false;
    }
  }

  /// Met à jour le mot de passe de l'utilisateur courant.
  static Future<bool> updatePassword(String newPassword) async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return false;
      await u.updatePassword(newPassword);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] changement mot de passe échoué : $e');
      return false;
    }
  }

  /// Envoie un lien de réinitialisation de mot de passe.
  static Future<bool> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim().toLowerCase(),
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] reset échoué : $e');
      return false;
    }
  }

  /// Déconnecte la session courante.
  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    _signedIn = false;
    _uid = null;
  }

  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'EMAIL_NOT_FOUND';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'WRONG_PASSWORD';
      case 'invalid-email':
        return 'INVALID_EMAIL';
      case 'user-disabled':
        return 'USER_DISABLED';
      case 'too-many-requests':
        return 'TOO_MANY_REQUESTS';
      case 'operation-not-allowed':
        return 'OPERATION_NOT_ALLOWED';
      default:
        return e.code.toUpperCase();
    }
  }
}
