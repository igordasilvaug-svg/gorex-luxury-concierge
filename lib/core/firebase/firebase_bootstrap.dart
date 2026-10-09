// GOREX LUXURY CONCIERGE — Amorçage Firebase défensif.
//
// Initialise Firebase si possible ; en cas d'échec (hors-ligne, plateforme non
// configurée, tests unitaires), l'application bascule proprement en mode LOCAL
// sans jamais planter. Le résultat est exposé via [FirebaseBootstrap.available].

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;
  static bool _available = false;
  static String? _error;

  /// Vrai si Firebase est initialisé et utilisable (Firestore accessible).
  static bool get available => _available;

  /// Message d'erreur éventuel (diagnostic).
  static String? get error => _error;

  /// Initialise Firebase de manière idempotente et défensive.
  ///
  /// Ne lève jamais d'exception : retourne simplement [available] = false en cas
  /// de problème afin que l'application continue en mode local.
  static Future<bool> init() async {
    if (_initialized) return _available;
    _initialized = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _available = true;
      if (kDebugMode) {
        debugPrint('[Firebase] initialisé — projet gorex-concierge');
      }
    } catch (e) {
      _available = false;
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('[Firebase] indisponible, mode local activé : $e');
      }
    }
    return _available;
  }
}
