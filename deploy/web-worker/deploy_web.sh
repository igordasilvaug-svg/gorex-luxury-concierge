#!/usr/bin/env bash
#
# GOREX LUXURY CONCIERGE — Déploiement du site web sur Cloudflare.
#
# Prérequis : un jeton API Cloudflare (voir CREER_JETON_API_CLOUDFLARE.md).
#
# Usage :
#   CLOUDFLARE_API_TOKEN="xxx" ./deploy_web.sh
#
# Le script :
#   1. vérifie que le staging est prêt ;
#   2. déploie via wrangler sur VOTRE compte (gorex-luxury-concierge.eu) ;
#   3. vérifie que le site répond.
# ---------------------------------------------------------------------------
set -euo pipefail

WORKER_DIR="/home/user/gorex_web_worker"
STAGE_DIR="/home/user/gorex_web_stage"
HOST="gorex-luxury-concierge.eu"

c()  { printf "\033[1;33m%s\033[0m\n" "$*"; }
ok() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
die(){ printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

# ── 0. Jeton ────────────────────────────────────────────────────────────────
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "❌ Jeton manquant."
  echo "   Usage : CLOUDFLARE_API_TOKEN=\"votre_jeton\" ./deploy_web.sh"
  echo "   Créer un jeton : voir deploy/web-worker/CREER_JETON_API_CLOUDFLARE.md"
  exit 1
fi

# ── 1. Vérifs staging ───────────────────────────────────────────────────────
c "[1/3] Vérification du staging…"
[ -f "$STAGE_DIR/index.html" ] || die "Staging incomplet (index.html manquant)."
[ -f "$STAGE_DIR/main.dart.js" ] || die "Staging incomplet (main.dart.js manquant)."
grep -q "signInAnonymously" "$STAGE_DIR/main.dart.js" \
  && ok "Build avec authentification Firebase (firebase_auth présent)" \
  || echo "  ⚠️ firebase_auth non détecté dans le build (la synchro cloud pourrait échouer)"
ok "Staging prêt ($(find "$STAGE_DIR" -type f | wc -l) fichiers)"

# ── 2. Déploiement ──────────────────────────────────────────────────────────
c "[2/3] Déploiement sur Cloudflare…"
cd "$WORKER_DIR"
npx wrangler@4 deploy 2>&1 | tail -15

# ── 3. Vérification ─────────────────────────────────────────────────────────
c "[3/3] Vérification…"
sleep 5
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 20 "https://$HOST/" 2>/dev/null || echo "000")
if [ "$CODE" = "200" ]; then
  ok "Site en ligne : https://$HOST/ (HTTP 200)"
else
  echo "  ⚠️ Réponse HTTP $CODE — vérifiez dans quelques instants (propagation)."
fi
echo
ok "Déploiement terminé."
