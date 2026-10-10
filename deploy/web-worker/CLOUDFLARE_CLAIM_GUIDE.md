# Réclamation Cloudflare & mise en ligne permanente — GOREX LUXURY CONCIERGE

> ✅ **RÉCLAMATION EFFECTUÉE.** Le Worker a été réclamé dans le compte Cloudflare
> **« Smoggy Shock »** ; l'URL `*.workers.dev` est désormais **permanente**.
> L'étape restante — **attacher le domaine `gorex-luxury-concierge.eu`** — est décrite
> dans **`BRANCHER_DOMAINE_WORKER.md`**.

---

## Pourquoi réclamer ?

Le déploiement initial a été fait en mode **temporaire** (`wrangler deploy --temporary`).
L'URL `*.workers.dev` fonctionne **immédiatement** mais reste **temporaire** (elle peut expirer).
La **réclamation (claim)** transfère le Worker dans **votre compte Cloudflare**, ce qui :

- ✅ rend l'URL **permanente** ;
- ✅ permet d'**attacher un domaine personnalisé** (`gorex-luxury-concierge.eu`) ;
- ✅ donne accès au tableau de bord Cloudflare (statistiques, logs, cache, règles).

---

## ÉTAPE 1 — Ouvrir le lien de réclamation

Le lien de réclamation est de la forme :

```
https://dash.cloudflare.com/claim-preview?claimToken=<JETON>
```

> ⚠️ **Le jeton expire après ~60 minutes** et **change à chaque déploiement**.
> Si le lien a expiré, **redéployez** pour en générer un nouveau (voir Étape 5).

1. Ouvrez le lien dans votre navigateur.
2. Vous verrez un aperçu du Worker `gorex-luxury-concierge`.

## ÉTAPE 2 — Se connecter / créer un compte Cloudflare

3. Cliquez sur **« Claim / Réclamer »** (ou *Sign in*).
4. Connectez-vous à votre compte Cloudflare **OU** créez-en un gratuit :
   - E-mail professionnel : `concierge@gorex.com`
   - Mot de passe fort + validation e-mail.
5. Autorisez la réclamation. Le Worker est **copié dans votre compte**.

## ÉTAPE 3 — Vérifier la nouvelle URL permanente

6. Dans le tableau de bord : **Workers & Pages** → `gorex-luxury-concierge`.
7. L'URL `https://gorex-luxury-concierge.<compte>.workers.dev` est maintenant
   **permanente**. Testez-la : la page de connexion GOREX doit s'afficher.
   ➡️ Compte actuel : `https://gorex-luxury-concierge.smoggy-shock.workers.dev`

## ÉTAPE 4 — Attacher le domaine personnalisé `gorex-luxury-concierge.eu`

> **Prérequis** : la zone DNS `gorex-luxury-concierge.eu` doit être gérée par Cloudflare
> (serveurs de noms `nucum` / `tanner` actifs) — ✅ c'est le cas.
>
> 📘 **Procédure détaillée (clic par clic) : voir [`BRANCHER_DOMAINE_WORKER.md`](BRANCHER_DOMAINE_WORKER.md).**

**Méthode tableau de bord (recommandée) :**

8. **Workers & Pages** → `gorex-luxury-concierge` → onglet **Settings**.
9. **Domains & Routes** → **Add** → **Custom domain**.
10. Saisir : `gorex-luxury-concierge.eu` → **Add domain**.
11. Cloudflare crée le **CNAME** et le **certificat TLS** automatiquement.
    Attendre l'état **Active** (≈ 1 minute).
12. (Optionnel) Ajouter `www.gorex-luxury-concierge.eu` de la même façon.

**Vérification DNS :**

| Type  | Nom (host)   | Cible                                              | Proxy |
|-------|--------------|----------------------------------------------------|-------|
| CNAME | `@` (racine) | `gorex-luxury-concierge.smoggy-shock.workers.dev`  | 🟠 Proxied |

> ⚠️ Le proxy **doit rester orange (Proxied)** : indispensable pour les en-têtes de
> sécurité, le cache et le TLS géré par Cloudflare.

## ÉTAPE 5 — (Si le jeton a expiré) Regénérer un lien de réclamation

Depuis le sandbox de développement :

```bash
cd /home/user/gorex_web_worker
npx wrangler@4 deploy --temporary
```

La commande réaffiche un **nouveau lien de réclamation** avec un jeton frais.
Le déploiement actuel est **idempotent** : le contenu du site ne change pas.

---

## ÉTAPE 6 — Vérifier après mise en service

```bash
# En-têtes de sécurité présents
curl -sI https://gorex-luxury-concierge.eu/ | grep -iE "strict-transport|content-security"

# Pages principales (toutes doivent répondre 200)
for p in "" download privacy.html legal.html terms.html cookies.html legal-hub.html about.html; do
  curl -s -o /dev/null -w "$p -> %{http_code}\n" "https://gorex-luxury-concierge.eu/$p"
done
```

**Attendu :** `200` partout, `strict-transport-security` et `content-security-policy` présents.

---

## ÉTAPE 7 — Mettre à jour les URL de référence

Après activation du domaine, remplacer l'URL `*.workers.dev` par `https://gorex-luxury-concierge.eu`
dans :

- la **fiche Google Play** (politique de confidentialité, site web) — voir `../play-store/FICHE_GOOGLE_PLAY.md` ;
- le fichier `manifest.json` de l'app si nécessaire ;
- les signatures d'e-mail / documents commerciaux.

---

## Récapitulatif — URLs

| État | URL |
|---|---|
| Permanente (compte réclamé) | `https://gorex-luxury-concierge.smoggy-shock.workers.dev` |
| Domaine final | `https://gorex-luxury-concierge.eu` |

---

*Guide préparé pour Gorex Group — GOREX LUXURY CONCIERGE v1.0.0*
