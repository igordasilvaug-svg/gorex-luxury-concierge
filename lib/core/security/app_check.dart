// GOREX LUXURY CONCIERGE — Firebase App Check.
//
// App Check atteste que la requête provient bien de l'application légitime et
// non d'un script qui rejouerait la clé API publique. Une fois les services
// passés en mode « Appliqué » dans la console Firebase, toute requête dépourvue
// de jeton valide est refusée (401), y compris avec la bonne clé API.
//
// ── POINT CRUCIAL POUR CETTE APPLICATION ────────────────────────────────
// L'application n'utilise PAS le SDK Firebase pour l'authentification ni pour
// Firestore : elle appelle directement `identitytoolkit.googleapis.com` et
// `firestore.googleapis.com` avec la clé API (voir RestAuthService), pour être
// robuste sur Safari. Or App Check n'ajoute automatiquement l'en-tête QUE pour
// les appels passant par le SDK. Sans l'injection manuelle réalisée ici via
// [FirebaseAppCheckHeaders], activer le mode « Appliqué » couperait la
// connexion et toutes les lectures pour l'ensemble des utilisateurs.
//
// ── ACTIVATION ─────────────────────────────────────────────────────────
// L'attestation n'est activée que si une clé de site reCAPTCHA est fournie via
// `--dart-define=RECAPTCHA_SITE_KEY=...`. Sans cette clé, [WebAppCheck.token]
// retourne `null` et l'application fonctionne exactement comme avant : aucune
// requête supplémentaire, aucun en-tête ajouté. Cela permet de livrer le code
// avant que la clé n'existe, sans risque de régression.

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Clé de site reCAPTCHA (Enterprise / Fraud Defense), fournie au build.
///
/// Vide tant que la clé n'a pas été créée dans la console Google Cloud puis
/// passée au build :
///   flutter build web --release --dart-define=RECAPTCHA_SITE_KEY=6Lc...
const String _recaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_SITE_KEY',
  defaultValue: '',
);

class WebAppCheck {
  WebAppCheck._();

  static bool _activated = false;
  static String? _lastError;

  /// Vrai si une clé est configurée ET que l'activation a réussi.
  static bool get enabled => _activated;

  /// Dernière erreur d'attestation (diagnostic, jamais affichée telle quelle).
  static String? get lastError => _lastError;

  /// Vrai si une clé de site a été fournie au build.
  static bool get configured => _recaptchaSiteKey.isNotEmpty;

  /// Active App Check de façon défensive.
  ///
  /// Ne lève jamais d'exception : en cas d'échec, l'application continue de
  /// fonctionner sans jeton. C'est volontaire — une panne d'attestation ne doit
  /// pas empêcher un client d'accéder à son espace.
  static Future<void> activate() async {
    if (_activated || !configured) return;
    try {
      await FirebaseAppCheck.instance.activate(
        // Fournisseur Enterprise (nom actuel : Google Cloud Fraud Defense).
        // Il correspond aux clés « score-based » créées dans la console
        // Cloud, invisibles pour l'utilisateur.
        webProvider: ReCaptchaEnterpriseProvider(_recaptchaSiteKey),
        // Attestation désactivée sur les autres plateformes : l'application
        // cible le web. Android/iOS utiliseraient Play Integrity / App Attest.
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      _activated = true;
      if (kDebugMode) {
        debugPrint('[AppCheck] attestation web activée');
      }
    } catch (e) {
      _activated = false;
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('[AppCheck] activation impossible, mode sans jeton : $e');
      }
    }
  }

  /// Récupère un jeton d'attestation, ou `null` si App Check est inactif.
  ///
  /// Le SDK renouvelle le jeton tout seul (toutes les ~30 min). On ne force
  /// jamais le rafraîchissement : cela créerait une évaluation reCAPTCHA
  /// supplémentaire à chaque appel, facturée au-delà du quota gratuit.
  static Future<String?> token() async {
    if (!_activated) return null;
    try {
      return await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) debugPrint('[AppCheck] jeton indisponible : $e');
      return null;
    }
  }
}

/// Construit les en-têtes HTTP des appels REST, jeton App Check inclus.
///
/// Regroupé ici pour qu'il n'existe qu'UN seul endroit à corriger si Google
/// change le nom de l'en-tête : il est aujourd'hui `X-Firebase-AppCheck`.
class FirebaseAppCheckHeaders {
  FirebaseAppCheckHeaders._();

  /// En-tête attendu par les API Google pour l'attestation d'application.
  static const String headerName = 'X-Firebase-AppCheck';

  /// Complète [base] avec le jeton d'attestation s'il est disponible.
  ///
  /// Si App Check est inactif, [base] est retourné inchangé : le comportement
  /// est alors strictement identique à celui d'avant l'introduction du jeton.
  static Future<Map<String, String>> withToken(
    Map<String, String> base,
  ) async {
    final t = await WebAppCheck.token();
    if (t == null || t.isEmpty) return base;
    return {...base, headerName: t};
  }
}
