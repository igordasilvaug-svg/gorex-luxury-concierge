// GOREX LUXURY CONCIERGE — Attestation d'application : l'invariant à tenir.
//
// ── POURQUOI CE TEST EXISTE ───────────────────────────────────────────────
// L'attestation (App Check / reCAPTCHA) a été DÉSACTIVÉE en production après
// une mesure, pas par confort :
//
//   Une requête envoyée sans en-tête `X-Firebase-AppCheck` sur
//   identitytoolkit.googleapis.com répond `400 INVALID_LOGIN_CREDENTIALS`,
//   donc elle est traitée normalement. Si App Check était appliqué côté
//   serveur, elle serait refusée AVANT la vérification du mot de passe.
//
// L'attestation n'étant pas imposée, la clé ne protégeait rien et produisait
// seulement un échange de jeton refusé (403) à chaque session.
//
// Ce test ne verrouille pas « la clé doit être absente » — c'est une décision
// d'exploitation. Il verrouille ce qui doit rester vrai DANS TOUS LES CAS :
// si aucune clé n'est compilée, l'application ne doit émettre AUCUNE requête
// d'attestation et n'ajouter AUCUN en-tête. Une régression ici casserait la
// connexion ou réintroduirait le bruit de console.

import 'package:flutter_test/flutter_test.dart';

import 'package:gorex_concierge/core/security/app_check.dart';

void main() {
  group('Attestation d\'application', () {
    test('sans clé de site, l\'attestation se déclare inactive', () {
      if (WebAppCheck.configured) {
        // Une clé a été fournie au build : cet état est décrit plus bas.
        return;
      }
      expect(WebAppCheck.configured, isFalse);
      expect(WebAppCheck.enabled, isFalse);
    });

    test('sans clé, aucun jeton n\'est demandé', () async {
      if (WebAppCheck.configured) return;
      // `token()` doit répondre `null` SANS appel réseau : c'est ce qui
      // garantit qu'aucune requête `exchangeRecaptchaEnterpriseToken` n'est
      // émise, donc aucun 403 dans la console.
      expect(await WebAppCheck.token(), isNull);
    });

    test('sans jeton, les en-têtes d\'appel sont rendus inchangés', () async {
      if (WebAppCheck.configured) return;
      final base = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer abc',
      };
      final out = await FirebaseAppCheckHeaders.withToken(base);
      // Aucun en-tête d'attestation ne doit apparaître.
      expect(out.containsKey(FirebaseAppCheckHeaders.headerName), isFalse);
      // Et surtout : les en-têtes existants ne doivent pas être perdus ou
      // remplacés — le mode sans attestation doit être STRICTEMENT identique
      // au comportement d'avant son introduction.
      expect(out, equals(base));
    });

    test('le nom d\'en-tête attendu par Google n\'a pas dérivé', () {
      // Un seul endroit à corriger si Google renomme l'en-tête. S'il changeait
      // de façon inaperçue, l'attestation échouerait silencieusement : le
      // serveur lirait un en-tête absent et l'application croirait l'avoir
      // envoyé.
      expect(FirebaseAppCheckHeaders.headerName, 'X-Firebase-AppCheck');
    });
  });
}
