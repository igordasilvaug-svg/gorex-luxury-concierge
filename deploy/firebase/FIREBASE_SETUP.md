# 🔥 Backend Firebase — Guide d'activation

> **Objectif** : brancher GOREX LUXURY CONCIERGE sur un backend **Firebase
> Firestore** (base de données cloud), avec synchronisation temps réel et
> comptes multi-appareils.
>
> **Statut actuel** : l'application fonctionne **100 % en local**
> (`shared_preferences`). Le backend n'est **pas** encore activé car
> l'environnement de développement ne contient **aucune clé Firebase**.
> Ce guide décrit exactement ce qu'il faut fournir pour l'activer.

---

## 1. Pourquoi l'activation n'est pas automatique

Pour connecter une application Flutter à Firebase, **deux fichiers de
configuration** sont obligatoires et **propres à votre projet Firebase**.
Ils ne peuvent pas être générés à votre place : ils proviennent de la console
Firebase et contiennent des identifiants liés à votre compte.

| Fichier | Rôle | Où le récupérer |
|---|---|---|
| `google-services.json` | Config **Android** (ID client, API key, project id…) | Console Firebase → ⚙️ *Paramètres du projet* → onglet **Général** → *Vos applications* → Android |
| `firebase-admin-sdk.json` | Config **serveur** (Admin SDK) pour créer les collections et données | Console Firebase → ⚙️ *Paramètres du projet* → onglet **Comptes de service** → **Générer une nouvelle clé privée** (choisir **Python**) |

> ⚠️ **Prérequis** : créer d'abord la base **Firestore Database** dans la console
> (menu *Build* → *Firestore Database* → **Créer une base de données**).
> Sans elle, la création de collections échouera.

---

## 2. Ce qu'il faut fournir

Déposez ces deux fichiers dans l'onglet **Firebase** de l'interface (ou
transmettez-les) :

1. **`google-services.json`** — pour l'intégration Android/Web.
2. **`firebase-admin-sdk.json`** — pour l'initialisation du schéma et des données.

Un identifiant de **projet Firebase** (ex. `gorex-concierge`) suffit en
complément.

---

## 3. Procédure d'activation (ce que je ferai dès réception)

Une fois les deux fichiers disponibles, l'activation se fait en quelques étapes
automatisées :

### a) Dépendances Flutter (versions verrouillées)

```yaml
dependencies:
  firebase_core: 3.6.0
  cloud_firestore: 5.4.3
  firebase_storage: 12.3.2
  firebase_messaging: 15.1.3
  firebase_analytics: 11.3.3
```

### b) Cohérence du nom de package (Android)

Le `package_name` de `google-services.json` **doit** correspondre à
`applicationId` :

- `android/app/build.gradle.kts` → `applicationId`
- `android/app/src/main/AndroidManifest.xml` → `package`
- `MainActivity.kt` → package + arborescence `android/app/src/main/kotlin/<pkg>/`
- Valeur attendue : **`com.gorexconcierge.luxury`**

### c) Multi-plateforme (Web + Android)

Création d'un fichier `firebase_options.dart` (Web + Android) et mise à jour de
`main.dart` pour utiliser `DefaultFirebaseOptions.currentPlatform`.
*Sans cette étape, la plateforme Web échoue avec
« No Firebase App '[DEFAULT]' has been created ».*

### d) Schéma Firestore proposé

| Collection | Champs principaux |
|---|---|
| `clients` | nom, e-mail, téléphone, tier, TVA/BCE, actif, créé_le |
| `requests` | client_id, domaine, sous-service, titre, urgence, budget, statut, responsable |
| `providers` | nom, catégorie, contact, note, actif |
| `bookings` | demande_id, prestataire_id, date, montant, commission, statut |
| `itineraries` | client_id, titre, étapes[], dates, statut |
| `finance_docs` | référence, type, client, HT/TVA/TTC, statut, Peppol, échéance |
| `expenses` | libellé, catégorie, montant, date |
| `conversations` | participants[], messages[], dernier_message |
| `appointments` | propriétaire_id, titre, début, fin, lieu |
| `audit_log` | horodatage, acteur, rôle, action, cible, détail |
| `users` | nom, e-mail, rôle, actif, dernier_login |

### e) Données d'exemple

Génération automatique de **10 enregistrements réalistes** par collection, avec
des types **cohérents** (jamais de `null` là où l'app attend une chaîne, dates
en `Timestamp`, montants en `number`).

### f) Règles de sécurité Firestore

Configuration de règles adaptées (lecture/écriture contrôlée par rôle en
production, ou mode développement permissif pour les tests).

### g) Couche d'accès Flutter

Un service `FirestoreService` remplacera la persistance locale par des requêtes
Firestore — **sans casser** l'architecture existante (`AppState` reste le point
d'entrée, chaque mutation passe déjà par une méthode dédiée).

---

## 4. Recommandations (ordre des priorités)

1. **Fournir les 2 clés** → j'active le backend et crée le schéma + données.
2. **Réclamer le Worker Cloudflare** (voir `../web-worker/CLOUDFLARE_CLAIM_GUIDE.md`)
   → rend l'URL web **permanente** (actuellement temporaire).
3. **Attacher `concierge.gorex.be`** → domaine final.

---

## 5. Points d'attention (retour d'expérience)

- **Index composites** : les requêtes `where(...).orderBy(...)` exigent des index.
  Le code privilégie les requêtes simples + tri en mémoire (pas d'index requis).
- **Types de données** : toujours vérifier le type réel côté Firestore avant de
  créer un modèle Dart (éviter `type 'Null' is not a subtype of type 'String'`).
- **Chargement auto** : les écrans chargent leurs données dans `initState()` via
  `addPostFrameCallback`, avec états *chargement / erreur / vide* explicites.

---

*Document préparé pour Gorex Group — GOREX LUXURY CONCIERGE v1.0.0*
