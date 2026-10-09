# Réclamation Cloudflare & mise en ligne permanente — GOREX LUXURY CONCIERGE

> Objectif : transformer l'URL **temporaire** du Worker en URL **permanente** rattachée à
> votre propre compte Cloudflare, puis **attacher le domaine personnalisé** `concierge.gorex.be`.

---

## Pourquoi réclamer ?

Le déploiement a été fait en mode **temporaire** (`wrangler deploy --temporary`). L'URL
`*.workers.dev` fonctionne **immédiatement** mais reste **temporaire** (elle peut expirer).
La **réclamation (claim)** transfère le Worker dans **votre compte Cloudflare**, ce qui :

- ✅ rend l'URL **permanente** ;
- ✅ permet d'**attacher un domaine personnalisé** (`concierge.gorex.be`) ;
- ✅ donne accès au tableau de bord Cloudflare (statistiques, logs, cache, règles).

**Vous n'avez PAS besoin de compte préalable** : la réclamation vous permet d'en créer un
gratuitement en quelques minutes.

---

## ÉTAPE 1 — Ouvrir le lien de réclamation

Le lien de réclamation est de la forme :

```
https://dash.cloudflare.com/claim-preview?claimToken=<JETON>
```

**Lien du dernier déploiement (valable ~60 min) :**

```
https://dash.cloudflare.com/claim-preview?claimToken=9G80XlhdF5iwKCAvFmWXUcvxN2aaTmI3HaeaHogR6tE
```

> ⚠️ **URL temporaire du dernier déploiement** (peut expirer) :
> `https://gorex-luxury-concierge.internal-promotion.workers.dev`

> 📌 **Le jeton change à chaque déploiement** et **expire** (fenêtre limitée).
> Le jeton du dernier déploiement vous est fourni dans la conversation.
> Si le lien a expiré, il suffit de **redéployer** pour en générer un nouveau (voir Étape 5).

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
7. L'URL `https://gorex-luxury-concierge.<votre-sous-domaine>.workers.dev` est maintenant
   **permanente**. Testez-la : la page de connexion GOREX doit s'afficher.

## ÉTAPE 4 — Attacher le domaine personnalisé `concierge.gorex.be`

> Prérequis : la zone DNS `gorex.be` doit être gérée par Cloudflare
> (nameservers Cloudflare actifs). Si `gorex.be` est géré ailleurs, vous pouvez d'abord
> ajouter le domaine à Cloudflare (gratuit) et changer les nameservers chez votre registrar.

**Méthode tableau de bord (recommandée) :**

8. **Workers & Pages** → `gorex-luxury-concierge` → onglet **Settings**.
9. **Domains & Routes** → **Add** → **Custom domain**.
10. Saisir : `concierge.gorex.be` → **Add domain**.
11. Cloudflare crée le **CNAME** et le **certificat TLS** automatiquement.
    Attendre l'état **Active** (≈ 1 minute).
12. (Optionnel) Ajouter `app.gorex.be` et `www.gorex.be` de la même façon.

**Vérification DNS :**

| Type  | Nom (host)  | Cible                                            | Proxy |
|-------|-------------|--------------------------------------------------|-------|
| CNAME | `concierge` | `gorex-luxury-concierge.<compte>.workers.dev`   | 🟠 Proxied |

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
curl -sI https://concierge.gorex.be/ | grep -iE "strict-transport|content-security"

# Pages principales (toutes doivent répondre 200)
for p in "" download privacy.html legal.html terms.html cookies.html legal-hub.html about.html; do
  curl -s -o /dev/null -w "$p -> %{http_code}\n" "https://concierge.gorex.be/$p"
done
```

**Attendu :** `200` partout, `strict-transport-security` et `content-security-policy` présents.

---

## ÉTAPE 7 — Mettre à jour les URL de référence

Après activation du domaine, remplacer l'URL `*.workers.dev` par `https://concierge.gorex.be`
dans :

- la **fiche Google Play** (politique de confidentialité, site web) — voir `../play-store/FICHE_GOOGLE_PLAY.md` ;
- le fichier `manifest.json` de l'app si nécessaire ;
- les signatures d'e-mail / documents commerciaux.

---

## Récapitulatif — URLs

| État | URL |
|---|---|
| Temporaire (avant réclamation) | `https://gorex-luxury-concierge.internal-promotion.workers.dev` |
| Permanente (après réclamation) | `https://gorex-luxury-concierge.<compte>.workers.dev` |
| Domaine final | `https://concierge.gorex.be` |

---

*Guide préparé pour Gorex Group — GOREX LUXURY CONCIERGE v1.0.0*
