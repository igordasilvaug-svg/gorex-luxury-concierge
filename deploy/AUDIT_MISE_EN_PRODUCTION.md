# 📋 AUDIT & PLAN DE MISE EN PRODUCTION — GOREX GROUP

**Date :** 12 octobre 2026
**Périmètre :** plateforme Gorex Security + Gorex Luxury Concierge
**Environnement examiné :** projet Flutter `flutter_app`, Firebase `gorex-concierge`,
site `https://gorex-luxury-concierge.eu` (Cloudflare Worker).

> ⚠️ **Principe appliqué** : aucune fausse réussite. Ce document distingue ce qui a
> été **réellement testé et fonctionne** de ce qui est **bloqué** et de ce qui
> **nécessite une information de votre part**.

---

## 1. ÉTAT DES LIEUX (existant préservé)

L'application existante est **déjà riche** : 86 fichiers Dart, une architecture
par rôles, et un socle cloud. Rien n'a été supprimé.

| Domaine | Existant |
|---|---|
| Rôles | `CEO`, `Concierge Manager`, `Senior Concierge`, `Concierge`, `Travel Manager`, `Lifestyle Manager`, `Security Coordinator`, `Finance`, `Client VIP` |
| Modèles | clients, demandes de service, facturation (finance), Peppol (config + UBL), abonnements, agenda/CRM, itinéraires, fournisseurs, documents, communication, audit |
| Écrans | dashboard, clients, demandes, finance, sécurité, réservations, fournisseurs, abonnements, agenda, documents, équipe, paramètres, sauvegarde, audit, légal, accès |
| Cloud | Firebase Firestore (12 collections), auth anonyme, service de synchronisation |
| Billing | `vat_service` (TVA), `peppol_ubl_generator`, `peppol_service`, `reconciliation_service`, `accounting_export_service`, `reminder_service` |
| Audit | `audit_insights`, `audit_export_service`, journal `audit_log` |

**Conclusion** : le socle métier existe. Le travail de mise en production consiste à
**brancher une authentification réelle**, **remplacer les données de démo**, et
**connecter les services externes**.

---

## 2. VÉRIFIÉ — FONCTIONNE RÉELLEMENT (tests effectués)

| # | Fonction | Statut | Preuve |
|---|---|---|---|
| 1 | Admin SDK Firebase | ✅ | `firebase-admin 7.1.0`, projet `gorex-concierge` |
| 2 | Auth **e-mail / mot de passe** | ✅ **activée par moi** | `signIn.email.enabled: true` (était désactivée → `OPERATION_NOT_ALLOWED`) |
| 3 | **Création de comptes** par l'Admin | ✅ | compte créé + connexion `idToken` OK |
| 4 | **Connexion** e-mail/mot de passe | ✅ | `accounts:signInWithPassword` → `idToken` |
| 5 | Domaine autorisé | ✅ | `gorex-luxury-concierge.eu` + `www` ajoutés |
| 6 | **Réinitialisation** de mot de passe | ✅ | endpoint `sendOobCode` opérationnel |
| 7 | Firestore (12 collections) | ✅ | lecture confirmée |
| 8 | Site HTTPS + sécurité | ✅ | `gorex-luxury-concierge.eu`, CSP/HSTS, HTTP 200 |
| 9 | Support `mustChangePassword` | ✅ | champ présent dans le modèle `AppUser` |

---

## 3. BLOQUÉ — nécessite une action de VOTRE part

### 3.1 MFA (authentification multifacteur) — ⚠️ BLOQUÉ
- **Constat** : `mfaConfig` absent. Le MFA TOTP/SMS exige **Identity Platform**
  (Google Cloud), qui requiert un **compte de facturation Google Cloud activé**.
- **Ce qu'il me faut** : que vous activiez la facturation sur le projet Google
  Cloud `gorex-concierge`, puis je configure le MFA pour le CEO et les comptes pro.
- **Sans cela** : MFA **impossible** aujourd'hui. Je ne le simulerai pas.

### 3.2 E-mails transactionnels (vérification, reset, notifications) — ⚠️ LIMITÉ
- Firebase Auth envoie déjà les e-mails de **reset** via l'expéditeur par défaut
  (`noreply@gorex-concierge.firebaseapp.com`) — fonctionnel mais non professionnel.
- Pour des e-mails **@gorex-group.eu** (vérification, notifications, devis),
  il faut un **fournisseur** (SendGrid, Postmark, Amazon SES…) + **clé API**.
- **Ce qu'il me faut** : le choix du fournisseur et sa clé API.

### 3.3 Peppol (facturation B2B belge) — ⚠️ BLOQUÉ
- La **génération UBL** est prête dans le code. Mais l'**envoi réel via Peppol**
  exige un **Point d'Accès Peppol certifié** (ex. Billit, Storecove, Unifiedpost…)
  avec un **identifiant Peppol** (n° d'entreprise belge `0208:...`) et un abonnement.
- **Ce qu'il me faut** : le fournisseur Peppol choisi + identifiant + clé API.
- **Sans cela** : Peppol **non transmissible**. Je ne simulerai pas d'envoi.

### 3.4 Coordonnées officielles de l'entreprise — ⚠️ MANQUANT
Je ne dois **pas inventer** ces informations. À fournir :
- Dénomination légale exacte (ex. « Gorex Group SA » ?) + forme juridique
- **N° d'entreprise (BCE/KBO)** belge
- **N° de TVA** (BE 0xxx.xxx.xxx)
- **Siège social** réel (rue, n°, code postal, ville, pays)
- **IBAN / BIC** du compte professionnel
- Numéro de téléphone réel, e-mail officiel
- Identifiant Peppol (si déjà existant)

### 3.5 Nom de domaine e-mail professionnel — ⚠️ À CONFIRMER
- Le cahier des charges indique des adresses **@gorex-group.eu**.
- Le site actuel est sur **gorex-luxury-concierge.eu** et le contact historique est
  **concierge@gorex.com**.
- **Question** : quel domaine e-mail est officiel ? (`gorex-group.eu` ?)
  Les adresses des comptes pro dépendent de cette réponse.

### 3.6 SMS / notifications temps réel — ⚠️ OPTIONNEL
- Notifications push : Firebase Cloud Messaging (gratuit, activable).
- SMS : nécessite un fournisseur (Twilio…) + crédits.

---

## 4. PLAN DE MISE EN PRODUCTION PROPOSÉ

### Phase A — Authentification réelle (réalisable maintenant) ✅
1. Migration des comptes **professionnels** vers Firebase Auth (vrais mots de passe hachés).
2. Comptes créés par **Admin SDK** avec **mot de passe aléatoire robuste** (jamais en clair).
3. `mustChangePassword = true` → **changement forcé à la 1ʳᵉ connexion**.
4. **Réinitialisation** sécurisée (déjà opérationnelle).
5. **Journal d'audit** des connexions et actions sensibles (table `audit_log` existante).
6. **Désactivation / révocation** d'un compte (Admin SDK `update_user` / `revoke_tokens`).
7. Écran d'inscription **client** (e-mail réel + vérification) sur le site.
8. Remise des identifiants par **procédure sécurisée** (voir §5).

### Phase B — Données réelles (réalisable) ✅
9. Suppression des données de **démonstration** (users `user1@…`, clients fictifs).
10. Règles Firestore **par rôle** (accès aux seules données de son service).
11. Structuration : `users`, `clients`, `requests`, `security_missions`, `invoices`, `audit_log`.

### Phase C — Services externes (dépend de vos identifiants) ⚠️
12. E-mails transactionnels (fournisseur + clé).
13. Peppol (Point d'Accès + identifiant).
14. MFA (facturation Google Cloud).
15. Données société + coordonnées bancaires.

### Phase D — Recette & production ✅
16. Tests par rôle (restrictions d'accès).
17. Tests demandes / notifications / factures.
18. Déploiement (Cloudflare Worker + APK/AAB).

---

## 5. PROCÉDURE DE MOTS DE PASSE (sécurisée, réelle)

**Méthode retenue (conforme aux bonnes pratiques) :**

1. **Génération** : mots de passe aléatoires de **20+ caractères** (majuscules,
   minuscules, chiffres, symboles), **uniques par compte**.
2. **Stockage** : hachés par **Firebase Auth** (algorithme SCRYPT, sel unique) —
   **jamais** en clair dans le code, la base ou une page web.
3. **Remise initiale** : les identifiants sont **générés dans un fichier local**
   que **vous** téléchargez et transmettez **hors ligne** (jamais par e-mail en clair).
4. **Première connexion** : `mustChangePassword = true` → le collaborateur **doit**
   définir son propre mot de passe.
5. **Révocation** : désactivation immédiate + `revokeRefreshTokens` (sessions actives coupées).
6. **Réinitialisation** : lien Firebase Auth sécurisé (expiration automatique).

> Je **générerai** les mots de passe et les **créerai** réellement dans Firebase,
> puis je vous remettrai un **fichier confidentiel** à supprimer après diffusion.
> Je n'afficherai **aucun** mot de passe en clair dans le chat ni sur le site.

---

## 6. CE QU'IL ME MANQUE POUR FINALISER (récapitulatif)

| # | Élément requis | Pour quoi |
|---|---|---|
| 1 | Domaine e-mail officiel (`gorex-group.eu` ?) | Adresses des comptes pro |
| 2 | Données société (BCE, TVA, siège, IBAN) | Facturation |
| 3 | Fournisseur e-mail + clé API | E-mails transactionnels |
| 4 | Fournisseur Peppol + identifiant + clé | Facturation B2B |
| 5 | Facturation Google Cloud activée | MFA |
| 6 | (Optionnel) Fournisseur SMS | Notifications SMS |

---

## 7. RÉPONSES AUX EXIGENCES

| Exigence | Réalisable ? | Note |
|---|---|---|
| Comptes pro distincts | ✅ Oui | Phase A |
| Mots de passe robustes, uniques | ✅ Oui | Générés + hachés |
| Changement forcé 1ʳᵉ connexion | ✅ Oui | `mustChangePassword` |
| MFA | ⚠️ Bloqué | Facturation Google Cloud |
| Journal d'audit | ✅ Oui | table `audit_log` |
| Droits par rôle | ✅ Oui | Phase B (règles Firestore) |
| Espace client + inscription | ✅ Oui | Phase A |
| Conciergerie (demandes, statuts, refs) | ✅ Existant à brancher | Phase B |
| Gorex Security (missions, planning CP 317) | ✅ Cadre existant | Phase B |
| Facturation + Peppol | ⚠️ Partiel | Peppol = Point d'Accès externe |
| Base persistante réelle | ✅ Oui | Firestore |
| RGPD | ✅ Oui | Pages légales déjà en ligne |
| HTTPS | ✅ Oui | Déjà actif |

---

*Rapport GOREX GROUP — Discretion. Access. Excellence.*
