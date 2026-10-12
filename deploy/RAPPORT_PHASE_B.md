# ✅ RAPPORT DE LIVRAISON — PHASE B (isolation des données & durcissement)

**Date :** 12 octobre 2026
**Projet :** GOREX GROUP — plateforme Gorex Security + Gorex Luxury Concierge
**Site en production :** https://gorex-luxury-concierge.eu
**Version déployée :** `aa63b58f-f63a-4226-bc32-a286a77e1324`

> Toutes les affirmations ci-dessous ont été **testées réellement** sur le projet
> Firebase `gorex-concierge` et sur le site en ligne. Aucune fonctionnalité n'est
> simulée. Les blocages restants sont listés explicitement (§6).

---

## 1. OBJECTIF DE LA PHASE B

Garantir qu'**aucune donnée client ne fuite d'un client vers un autre**, retirer
toute **donnée de démonstration** des builds de production, et **durcir** les
règles d'accès Firestore collection par collection.

---

## 2. CE QUI A ÉTÉ LIVRÉ ET VÉRIFIÉ

| # | Livrable | État | Preuve |
|---|---|---|---|
| 1 | **Isolation par client** (`user_profiles/{uid}.clientId`) | ✅ | client voit son dossier (200), pas celui d'un autre (403) |
| 2 | **Filtrage applicatif** par `clientId` (requêtes, réservations, finances, conversations, RDV) | ✅ | `myRequests`, `myConversations`, `*ForClient` |
| 3 | **`currentClient` sûr** (aucune fuite de repli) | ✅ | plus de fallback silencieux |
| 4 | **Comptes de démo retirés en production** | ✅ | build prod : `gorex2025` = **0 occurrence** |
| 5 | **`_seed()` vidé en production** (utilisateurs, clients, demandes…) | ✅ | garde `AppConfig.isProduction` |
| 6 | **Règles Firestore durcies** : session anonyme **exclue** | ✅ | `sign_in_provider != 'anonymous'` |
| 7 | **Règles par collection** (staff / client / admin) | ✅ | ruleset actif `4aab0c2e…` |
| 8 | **`clients`** : personnel = tout, client = sa fiche uniquement | ✅ | testé 200/403 |
| 9 | **`user_profiles`** : lecture de soi, écriture de soi | ✅ | règles dédiées |
| 10 | **`audit_log`** append-only | ✅ | `update/delete: if false` |
| 11 | **100 documents de démo supprimés** de Firestore | ✅ | sauvegarde préalable conservée |
| 12 | **Sauvegarde avant suppression** | ✅ | `gorex_backup_demo_20261012-160150.json` |
| 13 | **Build + analyse + tests** | ✅ | analyze = 0 ; tests = 173/173 |
| 14 | **Déploiement web production** | ✅ | version `aa63b58f`, HTTP 200 |
| 15 | **Commit Git** | ✅ | `3b7cf72` |

### Preuves de test (résumé)

```
Build production (--dart-define=PRODUCTION=true)
  gorex2025 (comptes démo)   → 0 occurrence      (retirés)
  user_profiles (isolation)  → présent dans le bundle

Firestore — règles Phase B (ruleset 4aab0c2e-d72b-43da-888a-7253e23eb751)
  Session anonyme            → 403 (bloquée)
  Session nominative staff   → 200 (autorisée)
  Client : son dossier       → 200
  Client : dossier d'autrui  → 403
  CEO    : tous les dossiers → 200

Firestore — contenu après nettoyage
  users / clients / requests / bookings / finance_docs /
  providers / expenses / itineraries / conversations / appointments → 0 doc
  staff        → 8 docs   (comptes professionnels réels)
  audit_log    → 18 docs  (journal d'audit)
  gorex_cloud  → 1 doc    (configuration)

flutter analyze → No issues found!
flutter test    → 173/173 tests passés
Site en ligne   → HTTP 200
```

---

## 3. MODÈLE D'ISOLATION (comment ça marche)

1. À l'inscription/connexion, un **profil technique** est écrit dans
   `user_profiles/{uid}` : `{ uid, email, role, clientId }`.
2. Les **règles Firestore** lisent ce profil pour autoriser un client à lire
   **uniquement** les documents dont `clientId` correspond au sien
   (`ownsClientData(d)`).
3. Côté application, les listes (demandes, réservations, finances, conversations,
   rendez-vous) sont **filtrées par `clientId`** avant affichage.
4. Les **règles interdisent toute session anonyme** — un simple visiteur ne peut
   plus lire les collections.

---

## 4. FICHIERS MODIFIÉS (Phase B)

| Fichier | Nature |
|---|---|
| `lib/state/app_state.dart` | isolation `clientId`, résolution profil client, `_seed()` vidé en prod, journal d'audit |
| `lib/screens/access/client_signup_screen.dart` | écriture `clients/{id}` + `user_profiles/{uid}` |
| `deploy/firebase/firestore.rules` | règles durcies par collection (anonyme exclu, isolation client) |

*Commit :* `3b7cf72 — feat(phase-b): isolation des donnees par client …`

---

## 5. CONFORMITÉ RGPD — CE QUI EST EN PLACE

- ✅ **Minimisation** : seules les données nécessaires sont collectées.
- ✅ **Cloisonnement** : un client n'accède qu'à ses propres données.
- ✅ **Traçabilité** : `audit_log` append-only (non modifiable, non supprimable).
- ✅ **Droit à l'effacement** : suppression possible via Admin SDK (sur demande).
- ✅ **Transport chiffré** : HTTPS + HSTS.
- ✅ **Séparation** données de démo / données réelles (prod nettoyée).

---

## 6. BLOCAGES RESTANTS (nécessitent une action de votre part)

Ces points **ne peuvent pas être simulés** : ils requièrent vos accès ou
identifiants.

| # | Blocage | Ce qu'il faut fournir |
|---|---|---|
| 1 | **MFA** (CEO + personnel) | Facturation **Google Cloud / Identity Platform** activée |
| 2 | **E-mails professionnels** (@gorex-group.eu) | Fournisseur (SendGrid / Postmark / SES) + **clé API** |
| 3 | **Peppol** (facturation électronique) | **Point d'Accès** + identifiant + **clé API** |
| 4 | **Coordonnées société** | BCE, TVA, siège, IBAN/BIC, téléphone |
| 5 | **Domaine e-mail** | Confirmer que `@gorex-group.eu` **reçoit** les e-mails |

> Tant que ces éléments ne sont pas fournis, les fonctionnalités concernées
> restent **inactives** — jamais simulées.

---

## 7. PROCHAINES ÉTAPES

**Côté Google (5 min, par vous) :**
1. Search Console → **Valider** la propriété (balise déjà en ligne).
2. Soumettre le **sitemap** : `https://gorex-luxury-concierge.eu/sitemap.xml`.
3. « **Demander une indexation** » de la page d'accueil.
4. Créer la fiche **Google Business Profile** (textes prêts : `deploy/seo/GUIDE_GOOGLE_BUSINESS_PROFILE.md`).

**Côté Gorex Group (fournir les accès) :** e-mails, Peppol, coordonnées société, facturation Google Cloud.

**Phase C (optionnelle, sur validation) :** branchement e-mails transactionnels
réels, Peppol réel, espace client enrichi, notifications.

---

*Rapport GOREX GROUP — Discretion. Access. Excellence.*
