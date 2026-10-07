# GOREX LUXURY CONCIERGE — Déploiement Web (Cloudflare Workers + Assets)

## URL publique
- Application : https://gorex-luxury-concierge.omniscient-magpie-1dc.workers.dev
- Confidentialité : https://gorex-luxury-concierge.omniscient-magpie-1dc.workers.dev/privacy.html

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

## Notes
- Limite Cloudflare : 5 Mo / fichier (d'où l'exclusion des .wasm canvaskit).
- Flutter charge canvaskit depuis https://www.gstatic.com/flutter-canvaskit/ par défaut.
- `html_handling = "none"` + `not_found_handling = "single-page-application"` pour préserver privacy.html et le routing SPA.
- Le compte "temporary" doit être réclamé (claim token, 60 min) pour une permanence au-delà de la fenêtre preview, ou utiliser un compte Cloudflare personnel.
