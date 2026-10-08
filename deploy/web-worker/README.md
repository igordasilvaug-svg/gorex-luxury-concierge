# GOREX LUXURY CONCIERGE — Déploiement Web (Cloudflare Workers + Assets)

## URL publique
- Application : https://gorex-luxury-concierge.delightful-bag-624.workers.dev
- Confidentialité : https://gorex-luxury-concierge.delightful-bag-624.workers.dev/privacy.html

> ⚠️ L'URL `*.workers.dev` dépend du compte Cloudflare utilisé. En mode
> « temporary » (`--temporary`), un nouveau compte preview est créé à chaque
> déploiement et l'URL change. Pour une URL **stable et permanente**, réclamez
> le compte (claim token) ou attachez un domaine personnalisé (voir plus bas).

## En-têtes de sécurité appliqués (worker.js)
| En-tête | Valeur |
|---|---|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` |
| `Content-Security-Policy` | `default-src 'self'` + `gstatic` (CanvasKit) + `wasm-unsafe-eval` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | caméra/micro/géoloc/paiement… désactivés |
| `X-XSS-Protection` | `1; mode=block` |
| `frame-ancestors` | `'self'` (anti-clickjacking) |

CSP détaillée :
```
default-src 'self';
script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com;
style-src 'self' 'unsafe-inline';
img-src 'self' data: blob:;
font-src 'self' data:;
connect-src 'self' https://www.gstatic.com;
worker-src 'self' blob:;
frame-ancestors 'self';
base-uri 'self';
form-action 'self';
object-src 'none';
upgrade-insecure-requests
```

## Procédure de (re)déploiement
```bash
# 1) Build web
cd /home/user/flutter_app && flutter build web --release

# 2) Staging allégé (retrait des canvaskit.wasm > 5 Mo, servis via CDN gstatic)
rm -rf /home/user/gorex_web_stage
cp -r build/web /home/user/gorex_web_stage
rm -f /home/user/gorex_web_stage/canvaskit/*.wasm \
      /home/user/gorex_web_stage/canvaskit/*.symbols \
      /home/user/gorex_web_stage/canvaskit/chromium/*.wasm \
      /home/user/gorex_web_stage/canvaskit/chromium/*.symbols

# 3) Déployer
cd /home/user/gorex_web_worker && npx wrangler deploy --temporary
```

## Notes techniques
- **Limite Cloudflare** : 5 Mo / fichier → les `.wasm` CanvasKit sont exclus
  (Flutter les charge depuis `https://www.gstatic.com/flutter-canvaskit/`).
- `html_handling = "none"` + `not_found_handling = "single-page-application"`
  préservent `privacy.html` et le routage SPA.
- Cache : `index.html` jamais mis en cache ; assets versionnés 1 an (`immutable`).

## 🔒 Domaine personnalisé (URL permanente)

### Option 1 — Réclamer le compte preview (gratuit)
1. Au moment du `wrangler deploy --temporary`, un **claim URL** s'affiche
   (valable 60 min) : `https://dash.cloudflare.com/claim-preview?claimToken=…`
2. Ouvrez-le, créez/connectez un compte Cloudflare gratuit.
3. Le Worker est alors conservé et l'URL `*.workers.dev` devient permanente.

### Option 2 — Domaine personnalisé (ex. `app.gorex.be`)
1. Possédez un domaine (ex. chez votre registrar) et un compte Cloudflare.
2. `wrangler login` (ou `CLOUDFLARE_API_TOKEN`).
3. Dans `wrangler.toml`, ajoutez :
   ```toml
   [[routes]]
   pattern = "app.gorex.be"
   custom_domain = true
   ```
4. `npx wrangler deploy` → Cloudflare crée l'enregistrement DNS + le certificat
   TLS automatiquement.

### Option 3 — Cloudflare Pages (alternative)
```bash
npx wrangler pages deploy /home/user/gorex_web_stage --project-name gorex-concierge
```
