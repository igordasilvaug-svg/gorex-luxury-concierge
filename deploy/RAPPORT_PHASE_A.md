# ✅ RAPPORT DE LIVRAISON — PHASE A (authentification réelle)

**Date :** 12 octobre 2026
**Projet :** GOREX GROUP — plateforme Gorex Security + Gorex Luxury Concierge
**Site en production :** https://gorex-luxury-concierge.eu

> Toutes les affirmations ci-dessous ont été **testées réellement**. Aucune
> fonctionnalité n'est simulée. Les blocages sont listés explicitement.

---

## 1. CE QUI A ÉTÉ LIVRÉ ET VÉRIFIÉ

| # | Livrable | État | Preuve |
|---|---|---|---|
| 1 | **Auth e-mail / mot de passe activée** | ✅ | `signIn.email.enabled = true` |
| 2 | **8 comptes professionnels créés** dans Firebase | ✅ | 8/8 connexions réussies |
| 3 | **Mots de passe robustes uniques** (22 car., aléatoire crypto) | ✅ | générés, jamais en clair |
| 4 | **Custom claims `role`** par compte | ✅ | `{role: ceo, dept: Direction}`… |
| 5 | **Fiches Firestore `staff/{uid}`** | ✅ | 8 fiches, `mustChangePassword: true` |
| 6 | **Journal d'audit** des provisions/connexions | ✅ | `audit_log` alimenté |
| 7 | **Connexion réelle** dans l'application | ✅ | `signInWithEmailAndPassword` en ligne |
| 8 | **Réinitialisation de mot de passe** | ✅ | endpoint opérationnel |
| 9 | **Changement forcé** à la 1ʳᵉ connexion | ✅ | `mustChangePassword` + écran dédié |
| 10 | **Règles Firestore par rôle** | ✅ | anonyme → 403 ; nominatif → 200 |
| 11 | **Audit append-only** (non modifiable) | ✅ | `update/delete: if false` |
| 12 | **Inscription client** (e-mail + vérification) | ✅ | `createUserWithEmailAndPassword` en ligne |
| 13 | **Déploiement web** | ✅ | version `65baf32d`, HTTP 200 |

### Preuves de test (résumé)
```
8/8 connexions Firebase réussies
Firestore sans auth        → 403  (bloqué)
Firestore session anonyme  → 403  (bloqué — règles renforcées)
Firestore session nominative → 200 (autorisé)
flutter analyze            → No issues found!
flutter test               → 173/173 tests passés
```

---

## 2. COMPTES PROFESSIONNELS (réellement créés)

| Rôle | Adresse |
|---|---|
| CEO / Administrateur | `ceo@gorex-group.eu` |
| Concierge Manager | `conciergemanager@gorex-group.eu` |
| Senior Concierge | `seniorconcierge@gorex-group.eu` |
| Concierge | `concierge@gorex-group.eu` |
| Travel Manager | `travelmanager@gorex-group.eu` |
| Lifestyle Manager | `lifestylemanager@gorex-group.eu` |
| Security Coordinator | `security@gorex-group.eu` |
| Finance | `finance@gorex-group.eu` |

> Les **mots de passe** sont dans le **fichier confidentiel** livré séparément
> (§5). Ils ne figurent **ni ici, ni dans le code, ni sur le site**.

---

## 3. SÉCURITÉ — CE QUI EST ACTIF

- ✅ Sessions **nominatives obligatoires** (l'ancien accès anonyme est bloqué).
- ✅ **Gestion des comptes réservée au CEO** (`staff`/`users` en écriture admin).
- ✅ **Auto-promotion impossible** (un utilisateur ne peut modifier son rôle).
- ✅ **Journal d'audit append-only** (ni modification, ni suppression).
- ✅ **Mots de passe hachés** par Firebase Auth (SCRYPT + sel) — jamais en clair.
- ✅ HTTPS + HSTS + CSP sur le site.
- ✅ Réinitialisation sécurisée par lien (expiration automatique).

---

## 4. PROCÉDURE DE GESTION DES UTILISATEURS (CEO)

| Action | Comment |
|---|---|
| **Créer un compte** | `python3 deploy/firebase/provision_staff_accounts.py` (liste `STAFF` en tête de fichier) |
| **Réinitialiser un mot de passe** | Firebase Console → Authentication → utilisateur → *Reset password*, ou lien « Mot de passe oublié » |
| **Désactiver un départ** | Firebase Console → Authentication → *Disable account* (+ révocation des sessions) |
| **Révoquer les sessions actives** | Admin SDK `auth.revoke_refresh_tokens(uid)` |
| **Consulter le journal d'audit** | Console → Firestore → collection `audit_log` |

---

## 5. REMISE SÉCURISÉE DES IDENTIFIANTS

- Fichier confidentiel : `gorex_identifiants_<date>.json` (hors dépôt, permissions `600`).
- **Lien de téléchargement :** https://www.genspark.ai/api/files/s/zD4b0hQr
  → **à télécharger, transmettre hors ligne, puis supprimer.**
- Chaque collaborateur **doit changer** son mot de passe à la 1ʳᵉ connexion.

---

## 6. INTÉGRATIONS QUI RESTENT À CONNECTER (avec vos identifiants)

| Intégration | Ce qu'il faut fournir | État |
|---|---|---|
| **MFA** (CEO + pro) | Facturation Google Cloud activée | ⚠️ Bloqué (plan payant) |
| **E-mails pro** (@gorex-group.eu) | Fournisseur (SendGrid/Postmark/SES) + clé API | ⚠️ À connecter |
| **Peppol** | Point d'Accès + identifiant + clé API | ⚠️ À connecter |
| **Coordonnées société** | BCE, TVA, siège, IBAN/BIC, téléphone | ⚠️ À fournir |
| **Notifications SMS** (option) | Fournisseur SMS | ⚠️ Optionnel |

---

## 7. BLOCAGES EMPÊCHANT LA MISE EN PRODUCTION COMPLÈTE

1. **Domaine e-mail** : confirmer que `@gorex-group.eu` **reçoit** des e-mails
   (sinon les liens de vérification / réinitialisation n'arrivent pas).
2. **Données société** manquantes (facturation).
3. **Peppol** : Point d'Accès non connecté (envoi réel impossible).
4. **MFA** : facturation Google Cloud requise.

---

## 8. PHASE B (à venir, sur validation)

- Isolation fine **par client** (chaque client ne voit que ses dossiers).
- Suppression des **données de démonstration** résiduelles.
- Branchement **e-mails transactionnels** et **Peppol**.
- Durcissement par collection des règles Firestore.

---

*Rapport GOREX GROUP — Discretion. Access. Excellence.*
