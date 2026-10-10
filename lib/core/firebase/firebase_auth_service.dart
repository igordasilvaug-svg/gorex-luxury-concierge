// GOREX LUXURY CONCIERGE — Authentification Firebase (anonyme) pour le cloud.
//
// L'application possède sa PROPRE authentification métier (comptes utilisateurs
// internes gérés dans l'état applicatif). Firebase Auth en mode ANONYME est
// utilisé UNIQUEMENT pour obtenir un jeton sécurisé permettant l'accès Firestore
// sous des règles de production (`request.auth != null`), sans exposer les
// données publiquement.
//
// Totalement défensif : ne lève jamais d'exception ; en cas d'échec l'application
// continue en mode local.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthService {
  FirebaseAuthService._();

  static bool _signedIn = false;
  static String? _uid;
  static bool _attempted = false;

  /// Vrai si une session Firebase (anonyme) est active.
  static bool get signedIn => _signedIn;

  /// Identifiant Firebase de la session (diagnostic).
  static String? get uid => _uid;

  /// Établit une session anonyme (idempotente). Retourne `true` si un jeton
  /// est disponible. N'échoue jamais bruyamment.
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
      if (kDebugMode) {
        debugPrint('[Auth] session anonyme établie : $_uid');
      }
      return _signedIn;
    } catch (e) {
      _signedIn = false;
      if (kDebugMode) {
        debugPrint('[Auth] anonyme indisponible (mode local) : $e');
      }
      return false;
    }
  }
}
