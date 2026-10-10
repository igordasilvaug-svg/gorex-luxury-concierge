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

## C. Règles Firestore de production — ⚠️ Action console requise

### Situation
- L'application possède sa **propre authentification métier** (comptes internes).
- La synchro cloud utilise Firestore **sans** Firebase Authentication.
- Pour restreindre Firestore aux seules sessions authentifiées, il faut activer
  **Firebase Authentication**, ce qui **exige la console Firebase** (mes permissions
  API sont insuffisantes : `403`, et Identity Platform requiert la facturation).

### Ce qui a été préparé (côté application)
- `firebase_auth: 5.3.1` ajouté.
- `lib/core/firebase/firebase_auth_service.dart` : session **anonyme** automatique.
- `FirebaseBootstrap.init()` établit la session anonyme au démarrage (défensif).
- `deploy/firebase/set_production_rules.py` : déploie les règles **PROD**
  (`allow read, write: if request.auth != null`).

### Procédure (2 minutes, dans la console)
1. **https://console.firebase.google.com** → projet **gorex-concierge**
2. **Build → Authentication → Commencer**
3. Onglet **Sign-in method** → **Anonyme** → **Activer** → Enregistrer
4. Puis déployer les règles :
   ```bash
   cd /home/user/flutter_app/deploy/firebase
   python3 set_production_rules.py
   ```

> ⚠️ **NE PAS** déployer les règles PROD **avant** d'activer l'auth anonyme,
> sinon l'application ne pourra plus lire/écrire Firestore (perte de synchro).

### En attendant
Les règles actuelles (**développement, accès ouvert**) restent en place et
fonctionnelles. Le site étant public, il est **recommandé** d'activer l'auth
anonyme + les règles PROD dès que possible.

---

## D. Déployer la nouvelle version du site (Cloudflare)

Le build web (avec `firebase_auth`) et la page `/download` (nouveaux APK) sont
prêts dans le staging `/home/user/gorex_web_stage`, mais **le déploiement nécessite
une authentification Cloudflare** (jeton API ou `wrangler login`).

### Méthode 1 — Jeton API (recommandé)
1. Créez un jeton : voir **`deploy/web-worker/CREER_JETON_API_CLOUDFLARE.md`**
   (permissions : *Account → Workers Scripts → Edit*).
2. Déployez :
   ```bash
   cd /home/user/gorex_web_worker
   CLOUDFLARE_API_TOKEN="<votre_jeton>" npx wrangler@4 deploy
   ```

### Méthode 2 — `wrangler login`
```bash
cd /home/user/gorex_web_worker
npx wrangler@4 login        # ouvre le navigateur
npx wrangler@4 deploy
```

### Vérification
```bash
curl -sI https://gorex-luxury-concierge.eu/download | grep -iE "http/"
curl -s  https://gorex-luxury-concierge.eu/download/manifest.json | head
```

> ℹ️ Le staging est déjà synchronisé (`build/web` → `gorex_web_stage`), les `.wasm`
> CanvasKit retirés (servis via le CDN gstatic) et les APK découpés. Il ne reste
> que la commande `wrangler deploy`.

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
