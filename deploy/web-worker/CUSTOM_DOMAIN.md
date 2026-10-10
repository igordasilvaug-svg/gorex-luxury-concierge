# Domaine personnalisé — GOREX LUXURY CONCIERGE

Ce guide décrit comment attacher le domaine personnalisé **`gorex-luxury-concierge.eu`**
au Worker Cloudflare `gorex-luxury-concierge` qui sert l'application Flutter Web.

> **Prérequis** : posséder un compte Cloudflare et un nom de domaine dont la zone DNS
> est gérée par Cloudflare (serveurs de noms `nucum` / `tanner` actifs).
>
> ➡️ Procédure détaillée et à jour : voir **`BRANCHER_DOMAINE_WORKER.md`**.

---

## Option A — Domaine personnalisé via le tableau de bord (recommandé)

1. Se connecter à https://dash.cloudflare.com
2. **Workers & Pages** → sélectionner le projet `gorex-luxury-concierge`
3. Onglet **Settings** → **Domains & Routes** → **Add** → **Custom domain**
4. Saisir le domaine : `gorex-luxury-concierge.eu`
5. Cloudflare crée automatiquement l'enregistrement DNS (CNAME) et provisionne le
   certificat TLS. Attendre l'état **Active** (généralement < 1 minute).
6. (Optionnel) Ajouter aussi `www.gorex-luxury-concierge.eu`.

## Option B — Route personnalisée (zone du même compte)

Si le domaine est sur le même compte Cloudflare, on peut utiliser une **route** :

```toml
# wrangler.toml
routes = [
  { pattern = "gorex-luxury-concierge.eu/*", zone_name = "gorex-luxury-concierge.eu" }
]
```

Puis redéployer :

```bash
cd /home/user/gorex_web_worker
npx wrangler deploy
```

---

## Option C — Déploiement en ligne de commande (CLI)

```bash
# Attacher le domaine au Worker (après authentification wrangler)
npx wrangler domains add gorex-luxury-concierge.eu \
  --service gorex-luxury-concierge
```

---

## Enregistrements DNS requis

| Type  | Nom (host)      | Contenu / Cible                                    | Proxy |
|-------|-----------------|----------------------------------------------------|-------|
| CNAME | `@` (racine)    | `gorex-luxury-concierge.smoggy-shock.workers.dev`  | 🟠 Proxied |
| CNAME | `www` (option)  | idem                                               | 🟠 Proxied |

> Avec un domaine personnalisé, l'option **Proxied (orange)** est **obligatoire** :
> elle est nécessaire pour l'application des en-têtes de sécurité, du cache et du TLS
> géré par Cloudflare.

---

## Vérification après mise en service

```bash
# La page doit répondre 200 avec les en-têtes de sécurité
curl -sI https://gorex-luxury-concierge.eu/ | grep -iE "strict-transport|content-security"

# Toutes les pages légales doivent répondre 200
for p in "" privacy.html legal.html terms.html cookies.html legal-hub.html; do
  curl -s -o /dev/null -w "$p -> %{http_code}\n" "https://gorex-luxury-concierge.eu/$p"
done
```

---

## Rappel — URL permanente du Worker

Le compte Cloudflare a été **réclamé** (compte *Smoggy Shock*) : l'URL `*.workers.dev`
est désormais **permanente** et reste accessible en parallèle du domaine final.

**URL actuelle du Worker** : `https://gorex-luxury-concierge.smoggy-shock.workers.dev`

---

## Page de téléchargement Android (publique)

L'application expose une page de téléchargement publique : **`/download`**
(ex. `https://gorex-luxury-concierge.eu/download`).

- Trois variantes d'APK signés sont proposées (arm64-v8a *recommandé*, armeabi-v7a, x86_64).
- Comme un APK dépasse la limite Cloudflare de 5 Mo par fichier, chaque APK est **découpé
  en morceaux < 5 Mo** (`/download/parts/*.partNN`) et **réassemblé automatiquement dans le
  navigateur** par `download.js`, avec **vérification de l'empreinte SHA-256** avant
  enregistrement du fichier `.apk`.
- Le manifeste (`/download/manifest.json`) décrit tailles, découpages et empreintes.

### Mise à jour des APK (nouvelle version)

```bash
# 1. Reconstruire les APK séparés par ABI
cd /home/user/flutter_app
flutter build apk --release --split-per-abi

# 2. Régénérer les morceaux + le manifeste dans le dossier d'assets du Worker,
#    puis redéployer :
cd /home/user/gorex_web_worker && npx wrangler deploy
```

> **Alternative sans découpage** : héberger les APK sur un stockage objet
> (R2, S3, GitHub Releases…) et pointer les liens de la page `/download` vers ces URL
> — utile pour des fichiers de plus de 5 Mo ou une distribution via un CDN dédié.
