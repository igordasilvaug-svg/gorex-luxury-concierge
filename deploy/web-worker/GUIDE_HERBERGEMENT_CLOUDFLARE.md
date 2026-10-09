# ☁️ Héberger GOREX LUXURY CONCIERGE sur Cloudflare — Guide complet

> **But** : mettre en ligne l'application web GOREX LUXURY CONCIERGE sur
> **Cloudflare Workers + Assets**, obtenir une **URL permanente**, puis la
> rattacher au domaine **`concierge.gorex.be`**.
>
> Deux méthodes sont proposées :
> - **Méthode A — Réclamation (claim)** : la plus simple, sans outil à installer.
> - **Méthode B — Wrangler CLI** : pour les mises à jour automatisées / récurrentes.

---

## 0. État actuel (dernier déploiement)

| Élément | Valeur |
|---|---|
| Worker | `gorex-luxury-concierge` |
| URL temporaire | `https://gorex-luxury-concierge.determined-pint.workers.dev` |
| Statut | ✅ en ligne (toutes les pages 200, en-têtes de sécurité actifs) |
| Lien de réclamation | `https://dash.cloudflare.com/claim-preview?claimToken=lYkaQV1dswlfWTT_vrPR-VCowilcXsPcV6cvrU-iU5U` |
| Validité du lien | **~60 minutes** (régénérable — voir §4) |

> ⚠️ Tant que le Worker n'est **pas réclamé**, l'URL `*.workers.dev` est
> **temporaire** : elle peut expirer. La **réclamation** la rend **permanente**.

---

## Méthode A — Réclamation (claim) puis domaine

### Étape 1 — Ouvrir le lien de réclamation
Ouvrez dans votre navigateur :

```
https://dash.cloudflare.com/claim-preview?claimToken=lYkaQV1dswlfWTT_vrPR-VCowilcXsPcV6cvrU-iU5U
```

### Étape 2 — Créer / connecter un compte Cloudflare
1. Cliquez sur **Claim / Réclamer**.
2. Connectez-vous **ou** créez un compte gratuit :
   - E-mail : `concierge@gorex.com`
   - Mot de passe fort, puis validation de l'e-mail.
3. Autorisez la réclamation → le Worker est **copié dans votre compte**.

### Étape 3 — Vérifier l'URL permanente
- Tableau de bord → **Workers & Pages** → `gorex-luxury-concierge`
- L'URL `https://gorex-luxury-concierge.<votre-sous-domaine>.workers.dev`
  est désormais **permanente**. Testez : la page de connexion GOREX s'affiche.

### Étape 4 — Attacher `concierge.gorex.be`

> **Prérequis** : la zone `gorex.be` doit être gérée par Cloudflare
> (nameservers Cloudflare actifs). Si le domaine est ailleurs, ajoutez-le à
> Cloudflare (gratuit) et changez les nameservers chez votre registrar.

1. **Workers & Pages** → `gorex-luxury-concierge` → onglet **Settings**
2. **Domains & Routes** → **Add** → **Custom domain**
3. Saisir `concierge.gorex.be` → **Add domain**
4. Cloudflare crée le **CNAME** + le **certificat TLS** automatiquement.
   Attendre l'état **Active** (< 1 min en général).

**Enregistrement DNS créé :**

| Type | Nom | Cible | Proxy |
|---|---|---|---|
| CNAME | `concierge` | `gorex-luxury-concierge.<compte>.workers.dev` | 🟠 Proxied |

> ⚠️ Le proxy **doit rester orange (Proxied)** : nécessaire pour les en-têtes
> de sécurité, le cache et le TLS géré par Cloudflare.

### Étape 5 — Vérifier
```bash
curl -sI https://concierge.gorex.be/ | grep -iE "strict-transport|content-security"
for p in "" download privacy.html legal.html terms.html cookies.html legal-hub.html about.html; do
  curl -s -o /dev/null -w "$p -> %{http_code}\n" "https://concierge.gorex.be/$p"
done
```
**Attendu :** `200` partout, `strict-transport-security` + `content-security-policy` présents.

---

## Méthode B — Wrangler CLI (mises à jour)

### Prérequis
- Node.js ≥ 18 (déjà présent dans le sandbox)
- Compte Cloudflare

### Étape 1 — Se connecter
```bash
cd /home/user/gorex_web_worker
npx wrangler@4 login
```
Une page s'ouvre : autorisez l'accès. (Sinon, créez un **API Token** :
*My Profile → API Tokens → Create Token → Edit Cloudflare Workers*.)

### Étape 2 — Construire et préparer le site
```bash
# Build Flutter Web (production : masque les comptes démo)
cd /home/user/flutter_app
flutter build web --release --dart-define=PRODUCTION=true

# Rafraîchir le dossier de staging servi par le Worker
rm -rf /home/user/gorex_web_stage
cp -r build/web /home/user/gorex_web_stage
# (Optionnel) retirer les .wasm CanvasKit > 5 Mo (servis via le CDN gstatic)
rm -f /home/user/gorex_web_stage/canvaskit/*.wasm \
      /home/user/gorex_web_stage/canvaskit/chromium/*.wasm
```

### Étape 3 — Déployer
```bash
cd /home/user/gorex_web_worker
npx wrangler@4 deploy           # compte connecté → URL permanente
# ou, sans compte :
npx wrangler@4 deploy --temporary   # URL temporaire + lien de réclamation
```

### Étape 4 — Domaine personnalisé via CLI
```bash
# Option 1 : route (zone du même compte)
#   éditer wrangler.toml :
#   routes = [ { pattern = "concierge.gorex.be/*", zone_name = "gorex.be" } ]
#   puis : npx wrangler deploy
#
# Option 2 : Custom Domain (recommandé pour un sous-domaine)
npx wrangler domains add concierge.gorex.be --service gorex-luxury-concierge
```

---

## 3. Structure du projet de déploiement

```
/home/user/gorex_web_worker/
├── worker.js          # Worker : en-têtes de sécurité + routage SPA + /download
├── wrangler.toml      # Configuration (name, assets, compatibility_date)
└── .wrangler/         # Cache local (ignoré)
```

`wrangler.toml` :
```toml
name = "gorex-luxury-concierge"
compatibility_date = "2025-01-01"
main = "worker.js"

[assets]
directory = "/home/user/gorex_web_stage"
binding = "ASSETS"
html_handling = "none"
not_found_handling = "single-page-application"
run_worker_first = true
```

### En-têtes de sécurité appliqués (`worker.js`)
| En-tête | Valeur |
|---|---|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` |
| `Content-Security-Policy` | `default-src 'self'` + gstatic (CanvasKit) + **Firestore** + `wasm-unsafe-eval` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | caméra/micro/géoloc/paiement… désactivés |
| `X-XSS-Protection` | `1; mode=block` |
| `frame-ancestors` | `'self'` (anti-clickjacking) |

> 🔥 **Firestore** : la CSP autorise `https://firestore.googleapis.com`,
> `https://*.googleapis.com` et `wss://*.firebaseio.com` en `connect-src`,
> afin que la synchronisation cloud temps réel fonctionne **une fois déployé**.

---

## 4. Régénérer un lien de réclamation (s'il a expiré)

Le jeton **expire après ~60 min**. Pour en générer un nouveau :

```bash
cd /home/user/gorex_web_worker
npx wrangler@4 deploy --temporary
```

La sortie affiche un nouveau **Claim URL** :
```
Temporary account ready:
    Claim within: 59 minutes
    Claim URL: https://dash.cloudflare.com/claim-preview?claimToken=<NOUVEAU_JETON>
```
Le contenu du site **ne change pas** (déploiement idempotent).

---

## 5. Mettre à jour l'application (nouvelle version)

```bash
cd /home/user/flutter_app
flutter build web --release --dart-define=PRODUCTION=true
rm -rf /home/user/gorex_web_stage
cp -r build/web /home/user/gorex_web_stage
cd /home/user/gorex_web_worker && npx wrangler@4 deploy
```

---

## 6. Distribution Android (page `/download`)

La page publique **`/download`** distribue les APK signés. Comme un APK dépasse
la limite **5 Mo/fichier** de Cloudflare, chaque APK est **découpé** en morceaux
`< 4 Mo` (`/download/parts/*.partNN`) et **réassemblé dans le navigateur**
(`download.js`) avec **vérification SHA-256**.

**Alternative** (fichiers > 5 Mo ou CDN dédié) : héberger les APK sur
**Cloudflare R2**, **GitHub Releases** ou **S3**, et pointer la page `/download`
vers ces URL.

---

## 7. Résumé des URLs

| État | URL |
|---|---|
| Temporaire (avant réclamation) | `https://gorex-luxury-concierge.determined-pint.workers.dev` |
| Permanente (après réclamation) | `https://gorex-luxury-concierge.<compte>.workers.dev` |
| Domaine final | `https://concierge.gorex.be` |

---

*Guide préparé pour Gorex Group — GOREX LUXURY CONCIERGE v1.0.0*
