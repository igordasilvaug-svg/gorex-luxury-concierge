# ✅ Récapitulatif — Finalisation GOREX LUXURY CONCIERGE

Trois chantiers de mise en production. Statut détaillé et actions restantes.

---

## A. Sous-domaine `www` (Cloudflare)

Le domaine racine `https://gorex-luxury-concierge.eu` **fonctionne** (HTTP 200).
Pour que `www.gorex-luxury-concierge.eu` fonctionne aussi, faire les **2 étapes** :

### 1. Enregistrement DNS
Zone `gorex-luxury-concierge.eu` → **DNS** → **Enregistrements** → **+ Ajouter** :

| Champ | Valeur |
|---|---|
| **Type** | `CNAME` |
| **Nom** | `www` |
| **Cible** | `gorex-luxury-concierge.eu` |
| **Proxy** | 🟠 **Proxied** |

### 2. Route Worker (ou Domaine personnalisé)
**Workers & Pages** → `gorex-luxury-concierge` → **Paramètres** → **Domaines et routes** :
- **Option 1 (route)** : **+ Ajouter une route** → `www.gorex-luxury-concierge.eu/*` → Worker `gorex-luxury-concierge`
- **Option 2 (domaine)** : **+ Ajouter un domaine** → `www.gorex-luxury-concierge.eu`

### 3. (Recommandé) Redirection `www` → racine
**Rules → Redirect Rules → Create rule** : rediriger `www.gorex-luxury-concierge.eu/*`
vers `https://gorex-luxury-concierge.eu/$1` (301). Évite le contenu dupliqué SEO.

### Vérification
```bash
curl -sI https://www.gorex-luxury-concierge.eu/ | grep -iE "http/|location"
```

---

## B. Build Android signé (Play Store) — ✅ FAIT

| Fichier | Taille | Signé |
|---|---|---|
| `build/app/outputs/bundle/release/app-release.aab` | 48,0 Mo | ✅ |
| `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | 22,2 Mo | ✅ |
| `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` | 20,4 Mo | ✅ |
| `build/app/outputs/flutter-apk/app-x86_64-release.apk` | 23,3 Mo | ✅ |

- **Version** : `1.0.0+1`
- **Package** : `com.gorexconcierge.luxury`
- **Keystore** : `android/release-key.jks` (alias `release`, DN `CN=Flutter App, O=GenSpark`)
- **Build** : `--dart-define=PRODUCTION=true` (comptes de démonstration masqués)
- **Page `/download`** : morceaux APK régénérés (arm64 6, armeabi 6, x86_64 7) + `manifest.json`
  (SHA-256 recalculés). Tous les morceaux < 5 Mo (limite Cloudflare).

### Publier sur Google Play
1. **Play Console** → votre application → **Production** → **Créer une release**
2. **Téléverser** `app-release.aab`
3. Compléter la fiche (voir `deploy/play-store/FICHE_GOOGLE_PLAY.md`) :
   - Site web : `https://gorex-luxury-concierge.eu`
   - Politique de confidentialité : `https://gorex-luxury-concierge.eu/privacy.html`
4. Renseigner la **Data Safety** (RGPD), les captures d'écran, l'icône (512×512).
5. Envoyer pour **examen**.

> ⚠️ Le keystore `release-key.jks` et `key.properties` doivent être **sauvegardés**
> en lieu sûr : sans eux, impossible de publier des mises à jour de l'application.

### Mise à jour de la page `/download`
La page publique `/download` sert les APK découpés en morceaux < 5 Mo.
Après un nouveau build, relancer :
```bash
cd /home/user/flutter_app && ./build_release.sh --skip-tests
```
(ou régénérer le manifeste + les morceaux comme documenté dans `build_release.sh`).

---

## C. Règles Firestore de production — ✅ FAIT

### État
- **Authentification anonyme Firebase activée** (console, fournisseur « Anonyme » ON).
- **Règles de production déployées** :
  ```
  match /{document=**} {
    allow read, write: if request.auth != null;
  }
  ```
  Release : `projects/gorex-concierge/releases/cloud.firestore`
  Ruleset : `projects/gorex-concierge/rulesets/89132cf0-b33a-4638-a46d-0167fb9b61d9`
- **Vérifié** : accès **sans** auth → `403` (refusé) ; accès **avec** jeton anonyme → autorisé.
- Côté application : `firebase_auth: 5.3.1` + session anonyme automatique
  (`lib/core/firebase/firebase_auth_service.dart`), établie dans `FirebaseBootstrap.init()`.

### ⚠️ Conséquence : redéployer le web
L'ancien build **en ligne** (sans `firebase_auth`) reçoit désormais `403` sur Firestore
→ la synchro cloud bascule en mode local. Il faut **redéployer le nouveau build**
(staging, avec `firebase_auth`) — voir la section **D** ci-dessous.

### Régénérer / redéployer les règles
```bash
cd /home/user/flutter_app/deploy/firebase
python3 set_production_rules.py        # règles PROD (auth requise)
python3 set_firestore_security_rules.py # revenir aux règles dev (si besoin)
```

---

## D. Déployer la nouvelle version du site (Cloudflare) — ✅ FAIT

**Déployé le 11 octobre 2026** sur le compte *Smoggy Shock*
(compte `057bea67e583635360b8686e985dd036`).

| Élément | Résultat |
|---|---|
| Worker | `gorex-luxury-concierge` — version `22b34312-7718-4a8c-b014-73fb70433715` |
| Assets | 64 fichiers (build avec `firebase_auth`) |
| Site | `https://gorex-luxury-concierge.eu/` → **HTTP 200** |
| Build en ligne | contient `signInAnonymously` ✅ (nouveau build) |
| En-têtes sécurité | CSP, HSTS, nosniff, frame-ancestors ✅ |
| Firestore sans auth | **403** (règles PRODUCTION actives) |
| Firestore avec auth anonyme | **200** lecture + écriture ✅ |

### Pour redéployer plus tard
```bash
cd /home/user/flutter_app/deploy/web-worker
CLOUDFLARE_API_TOKEN="<jeton>" CLOUDFLARE_ACCOUNT_ID="057bea67e583635360b8686e985dd036" ./deploy_web.sh
```
Créer un jeton : voir **`deploy/web-worker/CREER_JETON_API_CLOUDFLARE.md`**.

### Vérification
```bash
curl -s -o /dev/null -w "%{http_code}\n" https://gorex-luxury-concierge.eu/
curl -s https://gorex-luxury-concierge.eu/main.dart.js | grep -c signInAnonymously
```

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
