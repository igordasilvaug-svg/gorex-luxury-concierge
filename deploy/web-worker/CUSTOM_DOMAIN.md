# Domaine personnalisé — GOREX LUXURY CONCIERGE

Ce guide décrit comment attacher un domaine personnalisé (par ex. `concierge.gorex.be`)
au Worker Cloudflare `gorex-luxury-concierge` qui sert l'application Flutter Web.

> **Prérequis** : posséder un compte Cloudflare et un nom de domaine dont la zone DNS
> est gérée par Cloudflare (nameservers Cloudflare actifs).

---

## Option A — Domaine personnalisé via le tableau de bord (recommandé)

1. Se connecter à https://dash.cloudflare.com
2. **Workers & Pages** → sélectionner le projet `gorex-luxury-concierge`
3. Onglet **Settings** → **Domains & Routes** → **Add** → **Custom domain**
4. Saisir le domaine, par ex. `concierge.gorex.be`
5. Cloudflare crée automatiquement l'enregistrement DNS (CNAME) et provisionne le
   certificat TLS. Attendre l'état **Active** (généralement < 1 minute).
6. (Optionnel) Ajouter aussi `www` ou `app.gorex.be`.

## Option B — Route personnalisée (zone du même compte)

Si le domaine est sur le même compte Cloudflare, on peut utiliser une **route** :

```toml
# wrangler.toml
routes = [
  { pattern = "concierge.gorex.be/*", zone_name = "gorex.be" }
]
```

Puis redéployer :

```bash
cd deploy/web-worker
npx wrangler deploy
```

---

## Option C — Déploiement en ligne de commande (CLI)

```bash
# Attacher le domaine au Worker (après authentification wrangler)
npx wrangler domains add concierge.gorex.be \
  --service gorex-luxury-concierge
```

---

## Enregistrements DNS requis

| Type  | Nom (host)          | Contenu / Cible                                   | Proxy |
|-------|---------------------|---------------------------------------------------|-------|
| CNAME | `concierge`         | `gorex-luxury-concierge.<compte>.workers.dev`     | 🟠 Proxied |
| CNAME | `app` (optionnel)   | idem                                              | 🟠 Proxied |

> Avec un domaine personnalisé, l'option **Proxied (orange)** est **obligatoire** :
> elle est nécessaire pour l'application des en-têtes de sécurité, du cache et du TLS
> géré par Cloudflare.

---

## Vérification après mise en service

```bash
# La page doit répondre 200 avec les en-têtes de sécurité
curl -sI https://concierge.gorex.be/ | grep -iE "strict-transport|content-security"

# Toutes les pages légales doivent répondre 200
for p in "" privacy.html legal.html terms.html cookies.html legal-hub.html; do
  curl -s -o /dev/null -w "$p -> %{http_code}\n" "https://concierge.gorex.be/$p"
done
```

---

## Rappel — URL permanente du Worker

Tant qu'aucun domaine personnalisé n'est attaché, l'application reste accessible via
l'URL `*.workers.dev` générée par Cloudflare. Pour **pérenniser** cette URL (au lieu de
la version temporaire), utilisez le **lien de réclamation (claim)** fourni par
`wrangler deploy --temporary` : il transfère le projet dans votre propre compte Cloudflare.
