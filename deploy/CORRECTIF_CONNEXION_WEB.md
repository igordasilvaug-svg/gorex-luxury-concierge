# 🔧 CORRECTIF — Connexion web (« Identifiants invalides »)

**Date :** 13 octobre 2026
**Symptôme :** sur https://gorex-luxury-concierge.eu, la connexion avec les
identifiants professionnels affichait « Identifiants invalides » alors que les
comptes fonctionnaient côté serveur.

## Diagnostic (reproduit dans un vrai navigateur)

1. **Build web périmé** — le `main.dart.js` déployé **ne contenait pas**
   `firebase_auth_web` (module d'authentification Web de Firebase). Le registrant
   de plugins web était incomplet : seuls `firebase_core_web` et
   `cloud_firestore_web` étaient enregistrés, **pas `firebase_auth_web`**.
   → Sans ce module, `signInWithEmailAndPassword` échouait en silence et
   l'application basculait sur le repli local (« Identifiants invalides »).

2. **CSP bloquante** — le SDK Firebase Web injecte un court **script inline**
   pour charger le SDK modulaire depuis `gstatic.com`. La
   `Content-Security-Policy` du Worker bloquait ces scripts
   (`firebase_core`, `firebase_auth`, `firebase_firestore`).
   → Firebase ne s'initialisait jamais (`firebasejs` absent du trafic réseau).

## Correctifs appliqués

### 1. Build propre (régénère le registrant web)
```bash
cd /home/user/flutter_app
flutter clean && flutter pub get
flutter build web --release --dart-define=PRODUCTION=true
```
→ Le registrant inclut désormais `FirebaseAuthWeb.registerWith(registrar)`.

### 2. CSP — autorisation par empreinte SHA-256 (sans `unsafe-inline`)
Dans `deploy/web-worker/worker.js`, directive `script-src` :
```
'sha256-lxybZtu/9pEo9t2cXF8OdVCueZV6paBpNEQpBgqbYWA='
'sha256-Kd6jrSJ+A8S4mbnMXfLL0WXdMJ02uYTrwrdvhPTpDug='
'sha256-JAe3kXNkLbcxHg2ubdnFd1ozxf8byMAcYA7B4I7gV5I='
```
Ces 3 empreintes correspondent aux 3 scripts inline injectés par FlutterFire
pour charger `firebase-app.js`, `firebase-auth.js`, `firebase-firestore.js`.

> ⚠️ **Si la version du SDK Firebase JS change** (actuellement `11.9.1`),
> recalculer ces empreintes (les erreurs CSP du navigateur les fournissent
> directement) et mettre à jour la CSP.

## Preuve (test navigateur réel, compte CEO)

```
firebase-firestore.js (gstatic)            → 200
accounts:signInWithPassword                → 200  (localId = CEO)
firestore Listen/Write channels            → 200
Écran obtenu : « Première connexion » (définition du mot de passe) ✅
```

## Versions déployées
- Build web : `main.dart.js` avec `firebase_auth_web` ✅
- Worker : version `cc11ec73-77c1-467c-aa69-0e22de6cc0de` ✅
