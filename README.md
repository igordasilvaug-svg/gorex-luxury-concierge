<div align="center">

# GOREX LUXURY CONCIERGE

**Luxury Concierge · Executive Assistance · Travel · Lifestyle · Security**

*Discretion. Access. Excellence.*

![Flutter](https://img.shields.io/badge/Flutter-3.35.4-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9.2-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-3DDC84?logo=android&logoColor=white)
![Tests](https://img.shields.io/badge/tests-157%20passed-success)
![License](https://img.shields.io/badge/license-Proprietary-C6A15B)

</div>

---

## Présentation

Plateforme de conciergerie d'exception éditée par **Gorex Group** (Belgique). L'application réunit la gestion des demandes clients, l'assistance exécutive, la facturation conforme (TVA belge, Peppol), la comptabilité et la conformité RGPD — dans une identité visuelle sobre : noir, blanc, champagne discret, anthracite.

- **Package Android** : `com.gorexconcierge.luxury`
- **Version** : 1.0.0 (versionCode 1)

## Application en ligne

| Ressource | URL |
|---|---|
| Application web | https://gorex-luxury-concierge.calico-wormhole.workers.dev |
| Téléchargement Android (APK) | https://gorex-luxury-concierge.calico-wormhole.workers.dev/download |
| Informations légales (hub) | .../legal-hub.html |
| Mentions légales | .../legal.html |
| CGV | .../terms.html |
| Politique cookies | .../cookies.html |
| Politique de confidentialité (RGPD) | .../privacy.html |

> **Domaine cible** : `concierge.gorex.be` (à attacher après réclamation du Worker).
> L'URL `*.workers.dev` est **temporaire** tant que le Worker n'est pas réclamé — voir la
> [section Publication](#publication) ci-dessous.

> Sécurité : l'ensemble des pages (y compris `.html`) est servi avec des en-têtes stricts
> (CSP, HSTS, `X-Content-Type-Options: nosniff`, Referrer-Policy, Permissions-Policy).

## Fonctionnalités

### Conciergerie & opérations
- Tableau de bord direction, CRM clients, demandes, réservations, agenda
- Suivi des prestations et assignation du personnel
- Gestion des accès personnel (CRUD, rôles, permissions)

### Facturation (conforme Belgique)
- Validation **BCE / TVA** (modulo-97), normalisation des identifiants
- Régimes TVA : autoliquidation (art. 51 §2.4 CTVA), exonération intracommunautaire (art. 39bis CTVA), hors champ
- **Communication structurée** OGM/VCS (mod 97)
- **Peppol** : génération UBL 2.1 (Peppol BIS Billing 3.0 / EN 16931), envoi via Storecove, suivi asynchrone (polling + webhook)
- Export PDF des factures

### Comptabilité
- **Rapprochement bancaire** automatique (scoring : OGM, référence, montant, nom)
- **Relances de factures** impayées (escalade 7 / 21 / 45 jours) + moteur de relances planifiées
- **Export comptable** CSV (format belge `;`, décimales `,`)

### Conformité
- Politique de confidentialité **RGPD** (écran in-app + page web publique)
- Charte de confidentialité intégrée à l'identité visuelle

### Sécurité & données
- **Journal d'audit** : traçabilité horodatée des actions sensibles (connexions,
  mots de passe, escalades sécurité, opérations Peppol, rapprochements…) avec
  recherche, filtre par rôle et **export CSV + PDF** (rapport confidentiel).
  Borné à 300 entrées.
- **Tableau de bord sécurité** : activité sur 14 jours (histogramme), répartition
  par catégorie d'actions, indicateurs clés et liste des événements sensibles
  (échecs, suppressions, escalades).
- **Sauvegarde & restauration** : export JSON complet des données (clients,
  demandes, finances, agenda, journal d'audit…) et restauration transactionnelle
  (rollback automatique en cas de sauvegarde invalide). 100 % local, aucune
  donnée transmise à un tiers.

## Stack technique

| Domaine | Technologie |
|---|---|
| Framework | Flutter 3.35.4 / Dart 3.9.2 |
| État | Provider 6.1.5+1 (`AppState extends ChangeNotifier`) |
| Persistance | shared_preferences 2.5.3 (JSON `gorex_state_v1`) |
| Localisation | flutter_localizations + intl (`fr_BE`) |
| PDF / Impression | pdf 3.11.1 + printing 5.13.4 |
| Réseau | http 1.5.0, url_launcher 6.3.1 |
| UI | Material Design 3 (thème sombre), design system maison |

## Structure du projet

```
lib/
├── core/          # services (billing, accounting, peppol, export…)
├── data/          # seed & données de démonstration
├── models/        # modèles de domaine (finance, company, peppol…)
├── screens/       # écrans (shell, finance, client, legal, settings…)
├── state/         # AppState (état central)
├── widgets/       # composants réutilisables (design system)
└── main.dart
```

## Démarrage

```bash
flutter pub get
flutter run                      # dev
flutter build web --release      # web (mode démo : comptes visibles)
flutter build appbundle --release --dart-define=PRODUCTION=true   # Play Store
```

> **Flag `PRODUCTION`** : `--dart-define=PRODUCTION=true` masque les comptes de
> démonstration sur l'écran de connexion (voir `lib/core/app_config.dart`).

## Qualité

```bash
flutter analyze     # → No issues found
flutter test        # → 157/157 tests
```

## Publication

### 1. Build release (tout-en-un)

```bash
./build_release.sh                 # analyse + tests + AAB + APK + web + staging + découpage
./build_release.sh --skip-tests    # sans la suite de tests
./build_release.sh --deploy        # + déploiement Cloudflare (wrangler --temporary)
```

Le script produit :

| Artefact | Emplacement |
|---|---|
| **AAB** (Play Store, démo masquée) | `build/app/outputs/bundle/release/app-release.aab` |
| **APK** par ABI | `build/app/outputs/flutter-apk/app-{arm64-v8a,armeabi-v7a,x86_64}-release.apk` |
| **Staging Worker** (web + `/download`) | `/home/user/gorex_web_stage` |

### 2. Fiche Google Play

Tout le dossier de publication (descriptions **FR / NL / EN**, classification, sécurité des
Données, captures 1080×1920, icône 512, bannière 1024×500) se trouve dans
[`deploy/play-store/`](deploy/play-store/) :

- 📄 [`FICHE_GOOGLE_PLAY.md`](deploy/play-store/FICHE_GOOGLE_PLAY.md) — fiche complète
- 🖼️ `icon_512.png`, `feature_graphic_1024x500.png`, `screenshots/01…08` + `screenshots/extras/`
- 🎨 `screenshots/marketing/` — visuels avec cadres et accroches

### 3. Réclamation Cloudflare & domaine personnalisé

L'URL `*.workers.dev` est **temporaire**. Pour la rendre permanente et attacher
`concierge.gorex.be`, suivre :

- 📄 [`deploy/web-worker/CLOUDFLARE_CLAIM_GUIDE.md`](deploy/web-worker/CLOUDFLARE_CLAIM_GUIDE.md) — réclamation pas-à-pas
- 📄 [`deploy/web-worker/CUSTOM_DOMAIN.md`](deploy/web-worker/CUSTOM_DOMAIN.md) — domaine personnalisé

### 4. Téléchargement Android public

La page **`/download`** distribue les APK signés. Comme un APK dépasse la limite Cloudflare
de **5 Mo/fichier**, chaque APK est **découpé en morceaux < 4 Mo** (`download/parts/*.partNN`)
et **réassemblé dans le navigateur** (`web/download.js`) avec **vérification SHA-256** avant
enregistrement du `.apk`.

### 5. Backend Firebase (optionnel)

L'application fonctionne **100 % en local** par défaut. Pour activer un backend cloud
Firestore (synchronisation multi-appareils), il suffit de fournir **deux clés Firebase**.
Tout est préparé :

- 📄 [`deploy/firebase/FIREBASE_SETUP.md`](deploy/firebase/FIREBASE_SETUP.md) — guide d'activation
- 🐍 [`deploy/firebase/create_backend_services.py`](deploy/firebase/create_backend_services.py) — script d'initialisation (11 collections × 10 documents, prêt à l'emploi)

## Déploiement web

Voir [`deploy/web-worker/README.md`](deploy/web-worker/README.md) (Cloudflare Workers + Assets).

---

<div align="center">
<sub>© Gorex Group — GOREX LUXURY CONCIERGE. Tous droits réservés.</sub>
</div>
