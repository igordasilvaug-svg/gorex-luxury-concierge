# 🚀 Publier GOREX LUXURY CONCIERGE sur Google Play — pas à pas

> **But** : publier l'application Android (AAB signé) sur le Google Play Store.
>
> Fichier à téléverser : **`build/app/outputs/bundle/release/app-release.aab`** (48 Mo)
> Contenu de la fiche : **`deploy/play-store/FICHE_GOOGLE_PLAY.md`**
> Ressources prêtes : `icon_512.png`, `feature_graphic_1024x500.png`, `screenshots/01…08`

---

## ⏱️ Vue d'ensemble

1. Créer un **compte développeur** Google Play (frais **uniques 25 $**)
2. Créer l'**application** dans la Play Console
3. Remplir la **fiche** (textes, images)
4. Renseigner **Sécurité des données** (RGPD) + **Classification du contenu**
5. **Téléverser l'AAB** et créer la **release**
6. Envoyer pour **examen** (24–72 h)

---

## 1. Créer le compte développeur

1. Allez sur **https://play.google.com/console**
2. Connectez-vous avec un compte Google (idéalement `concierge@gorex.com`)
3. Choisissez **Type de compte** : **Organisation** (société Gorex Group)
   - Nom de l'organisation : `Gorex Group`
   - Fournissez les infos de vérification (SIRET/BCE, adresse, D-U-N-S éventuel)
4. Réglez les **frais d'inscription uniques : 25 $**
5. Attendez la **validation du compte** (souvent < 48 h, parfois quelques jours pour une organisation)

> ⚠️ La vérification « Organisation » peut demander un **numéro D-U-N-S**. Anticipez-le.

---

## 2. Créer l'application

1. Play Console → **Toutes les applications** → **Créer une application**
2. Renseignez :
   - **Nom** : `GOREX LUXURY CONCIERGE`
   - **Langue par défaut** : Français (fr-FR)
   - **Type** : Application · **Gratuit** (accès sur invitation)
   - Acceptez les déclarations (règles, export US)
3. Cliquez sur **Créer**

---

## 3. Fiche du Play Store

Menu **Présence → Fiche principale** (et les fiches localisées FR/NL/EN).
Copiez les contenus depuis **`deploy/play-store/FICHE_GOOGLE_PLAY.md`** :

| Élément | Contenu |
|---|---|
| **Nom** (30) | `GOREX LUXURY CONCIERGE` |
| **Description courte** (80) | `Conciergerie de luxe, assistance exécutive, voyages, lifestyle et sécurité.` |
| **Description complète** (4000) | voir la fiche |
| **Icône** | `icon_512.png` (512×512) |
| **Image de présentation** | `feature_graphic_1024x500.png` |
| **Captures d'écran** | `screenshots/01…08` (min. 2, idéalement 4+) |
| **Site web** | `https://gorex-luxury-concierge.eu` |
| **E-mail** | `concierge@gorex.com` |
| **Politique de confidentialité** | `https://gorex-luxury-concierge.eu/privacy.html` |

---

## 4. Déclarations obligatoires

### a) Sécurité des données (Data safety)
Menu **Contenu de l'application → Sécurité des données**.
- Collecte de données : décrivez ce que l'app collecte (comptes, identifiants) — voir fiche
- Chiffrement en transit : **Oui** (HTTPS/Cloudflare + Firestore)
- L'utilisateur peut demander la suppression : **Oui** (`concierge@gorex.com`)

### b) Classification du contenu
Menu **Contenu de l'application → Classification du contenu** → remplissez le questionnaire.

### c) Publicité / Accès à l'application
- App **sans publicité**
- **Accès restreint** (invitation) : fournissez un **compte de démonstration** pour la revue
  → indiquez un login/mot de passe de test dans **« Accès à l'application »**

### d) Autres déclarations
- **Politique de confidentialité** (obligatoire) : URL ci-dessus
- **Public cible** et **modèle d'application**

---

## 5. Téléverser l'AAB et créer la release

1. Menu **Production → Créer une release**
2. Si demandé, activez **Play App Signing** (recommandé — Google conserve la clé de signature)
3. **Téléversez** `app-release.aab`
4. **Notes de version** (ex.) :
   ```
   Première version de GOREX LUXURY CONCIERGE.
   Discretion. Access. Excellence.
   ```
5. Cliquez sur **Examiner la release → Démarrer le déploiement**

> 💡 Pour tester d'abord sans publier : utilisez **Test interne** (déploiement en minutes).

---

## 6. Examen et publication

- Google examine l'app : **24 à 72 h** (parfois plus pour un premier lancement)
- Statut visible dans **Publishing overview**
- Une fois approuvée → **publiée** automatiquement sur le Play Store

---

## 🔑 Points de vigilance

| Point | Détail |
|---|---|
| **Keystore** | `android/release-key.jks` + `key.properties` → **sauvegardez-les** ! Sans eux, pas de mises à jour. |
| **Version** | Pour une nouvelle release, incrémentez `version:` dans `pubspec.yaml` (ex. `1.0.1+2`) puis rebuild. |
| **Compte de test** | Fournissez un accès de démo pour la revue (obligatoire si l'app est restreinte). |
| **D-U-N-S** | Souvent requis pour un compte **Organisation**. |
| **URL légales** | Doivent être **publiques et accessibles** (✅ elles le sont). |

---

## 🛠️ Reconstruire un AAB (nouvelle version)

```bash
cd /home/user/flutter_app
# 1. Incrémenter la version dans pubspec.yaml (ex. 1.0.1+2)
# 2. Reconstruire
flutter build appbundle --release --dart-define=PRODUCTION=true
# → build/app/outputs/bundle/release/app-release.aab
```

Ou tout-en-un :
```bash
./build_release.sh --skip-tests
```

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
