# Politique de confidentialité — GOREX LUXURY CONCIERGE

Page publique RGPD hébergeable sur Cloudflare Workers/Pages (assets statiques).

## Déploiement
```bash
cd deploy/privacy-worker
npx wrangler deploy            # compte Cloudflare authentifié
# ou, sans compte :
npx wrangler deploy --temporary
```

## Fichiers
- `index.html` — page publique (autonome, aucune dépendance externe)
- `worker.js` — sert index.html sur `/`, `/index.html` et `/privacy`
- `wrangler.toml` — configuration Worker + assets

## Mise à jour du contenu
Modifier `index.html` (ou `lib/screens/legal/privacy_policy_screen.dart` pour
la version in-app), puis redéployer. Incrémenter la version dans l'en-tête.
