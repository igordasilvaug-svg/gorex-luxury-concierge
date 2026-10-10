# GOREX LUXURY CONCIERGE — Déploiement Web (Cloudflare Workers + Assets)

## URL publique
- Application (technique) : https://gorex-luxury-concierge.smoggy-shock.workers.dev
- Domaine final (à attacher) : https://gorex-luxury-concierge.eu
- Confidentialité : https://gorex-luxury-concierge.smoggy-shock.workers.dev/privacy.html

> ✅ Le compte Cloudflare a été **réclamé** (compte *Smoggy Shock*) : l'URL
> `*.workers.dev` est désormais **permanente**.
> ➡️ Pour brancher le domaine final, suivez **`BRANCHER_DOMAINE_WORKER.md`**.

## En-têtes de sécurité appliqués (worker.js)
| En-tête | Valeur |
|---|---|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` |
| `Content-Security-Policy` | `default-src 'self'` + `gstatic` (CanvasKit) + Firestore + `wasm-unsafe-eval` |
| `X-Content-Type-Options` | `nosniff` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | caméra/micro/géoloc/paiement… désactivés |
| `X-XSS-Protection` | `1; mode=block` |
| `frame-ancestors` | `'self'` (anti-clickjacking) |

CSP détaillée :
```
default-src 'self';
script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com https://apis.google.com;
style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
img-src 'self' data: blob:;
font-src 'self' data: https://fonts.gstatic.com;
connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com
            https://firestore.googleapis.com https://*.googleapis.com
            https://*.firebaseio.com wss://*.firebaseio.com https://*.cloudfunctions.net;
worker-src 'self' blob:;
frame-src 'self' https://*.firebaseapp.com https://accounts.google.com;
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

# 3) Déployer (sur le compte réclamé : npx wrangler deploy ; en preview : --temporary)
cd /home/user/gorex_web_worker && npx wrangler deploy
```

## Notes techniques
- **Limite Cloudflare** : 5 Mo / fichier → les `.wasm` CanvasKit sont exclus
  (Flutter les charge depuis `https://www.gstatic.com/flutter-canvaskit/`).
- `html_handling = "none"` + `not_found_handling = "single-page-application"`
  préservent `privacy.html` et le routage SPA.
- Cache : `index.html` jamais mis en cache ; assets versionnés 1 an (`immutable`).

## 🔒 Domaine personnalisé — `gorex-luxury-concierge.eu`

➡️ **Procédure complète et à jour : voir `BRANCHER_DOMAINE_WORKER.md`.**

Résumé (tableau de bord) :
1. https://dash.cloudflare.com → **Workers & Pages** → projet `gorex-luxury-concierge`
2. **Settings → Domains & Routes → Add → Custom domain**
3. Saisir `gorex-luxury-concierge.eu` → **Add domain**
4. Attendre le statut **Active** (< 1 min) → l'enregistrement DNS et le certificat TLS sont créés automatiquement.

### Alternative CLI (nécessite un jeton API avec droits Workers)
```bash
cd /home/user/gorex_web_worker
npx wrangler deploy   # avec [[routes]] custom_domain dans wrangler.toml
```

### Option — Cloudflare Pages (alternative)
```bash
npx wrangler pages deploy /home/user/gorex_web_stage --project-name gorex-concierge
```
