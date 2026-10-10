# 🔐 Activer l'authentification anonyme Firebase (pour sécuriser Firestore)

> **But** : permettre à l'application de se connecter à Firestore via une **session
> anonyme** Firebase, afin de pouvoir durcir les règles de sécurité (accès réservé aux
> sessions authentifiées) **sans casser la synchronisation cloud**.
>
> Durée : **~2 minutes**. Aucune ligne de commande (sauf la dernière étape, optionnelle).

---

## Pourquoi cette étape ?

Aujourd'hui, la base Firestore est en règles de **développement** (accès ouvert à tous).
C'est pratique en phase de test, mais **dangereux en production** : n'importe qui pourrait
lire/écrire vos données.

Pour la sécuriser, la bonne pratique est d'exiger une **authentification**. Comme
l'application possède sa **propre** authentification métier (comptes internes), on utilise
une **session Firebase anonyme** : automatique, invisible pour l'utilisateur, mais elle
fournit le jeton sécurisé requis par les règles de production.

> ⚠️ **Important** : il faut activer l'auth anonyme **AVANT** de déployer les règles
> strictes. Sinon l'application perdrait l'accès à Firestore.

---

## Étape par étape

### 1. Ouvrir la console Firebase
Allez sur **https://console.firebase.google.com** et sélectionnez le projet
**`gorex-concierge`**.

### 2. Ouvrir Authentication
Dans le menu de gauche → **Build** → **Authentication**
(ou cliquez sur la tuile **Authentication** au centre de l'écran).

### 3. Démarrer
Cliquez sur le bouton **« Commencer »** (Get started).
> Si Authentication est déjà activé, passez directement à l'étape 4.

### 4. Onglet « Sign-in method »
Cliquez sur l'onglet **Sign-in method** (Méthodes de connexion) en haut.

### 5. Activer « Anonyme »
1. Dans la liste des fournisseurs, cliquez sur **Anonyme** (Anonymous)
2. Basculez le commutateur **Activer** (Enable) sur **ON** 🟢
3. Cliquez sur **Enregistrer** (Save)

C'est tout ! ✅ L'auth anonyme est maintenant disponible pour l'application.

### 6. (Optionnel) Vérifier
Toujours dans Authentication, onglet **Users** (Utilisateurs) : vous verrez les
sessions anonymes apparaître **une fois l'application utilisée** (elles ont un UID mais
pas d'e-mail).

---

## 7. Déployer les règles Firestore de production

Une fois l'étape 5 faite, revenez ici et lancez :

```bash
cd /home/user/flutter_app/deploy/firebase
python3 set_production_rules.py
```

Résultat attendu :
```
✅ Ruleset créé : projects/gorex-concierge/rulesets/…
✅ Règles PRODUCTION déployées sur cloud.firestore
🔒 Accès désormais réservé aux sessions authentifiées (Firebase Auth).
```

Les règles déployées seront :
```
match /{document=**} {
  allow read, write: if request.auth != null;
}
```

---

## 🩺 Dépannage

| Problème | Solution |
|---|---|
| Bouton « Commencer » absent | Authentication est déjà activé → passez à l'onglet **Sign-in method** |
| « Anonyme » grisé / non proposé | Vérifiez que vous êtes **Propriétaire** ou **Éditeur** du projet |
| Après déploiement, plus de synchro | L'app n'a pas pu ouvrir de session anonyme → vérifiez l'étape 5, puis relancez l'app |
| Erreur `403` / `PERMISSION_DENIED` | Vous n'avez pas les droits sur le projet → connectez-vous avec le compte propriétaire |

---

## Ce qui se passera dans l'application (déjà codé)

- Au démarrage, `FirebaseBootstrap.init()` appelle `FirebaseAuthService.ensureSignedIn()`
  qui ouvre une **session anonyme** (invisible).
- En cas d'échec (hors-ligne, auth non activée), l'app **bascule en mode local** sans planter.
- La synchro cloud et le temps réel continuent de fonctionner, désormais sous règles strictes.

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
