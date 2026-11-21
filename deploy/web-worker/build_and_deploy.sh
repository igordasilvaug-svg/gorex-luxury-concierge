#!/usr/bin/env bash
# GOREX — build + correctifs web + déploiement Cloudflare.
set -e
STAGE=/home/user/gorex_web_stage
FLUT=/home/user/flutter_app
OVR=/home/user/gorex_web_worker/assets_overrides

# ── ATTESTATION D'APPLICATION (App Check / reCAPTCHA) : DÉSACTIVÉE ───────
#
# Elle était active avec la clé de site ci-dessous. Elle est désormais vide,
# et voici la MESURE qui a motivé ce choix, pas une préférence :
#
#   Une requête envoyée SANS en-tête `X-Firebase-AppCheck`, directement sur
#   identitytoolkit.googleapis.com avec la clé API publique, répond
#   `HTTP 400 INVALID_LOGIN_CREDENTIALS` — c'est-à-dire qu'elle est traitée
#   normalement, jusqu'à la vérification du mot de passe. Si App Check était
#   réellement appliqué, elle aurait été refusée AVANT, avec une erreur
#   d'attestation. Il en va de même pour firestore.googleapis.com, qui répond
#   403 « Missing or insufficient permissions » (nos règles de sécurité),
#   et non un refus d'attestation.
#
# Autrement dit : l'attestation n'est pas imposée côté serveur. Dans cet état,
# la clé ne protège RIEN, mais elle produit à chaque session un échange de
# jeton refusé (403 sur `exchangeRecaptchaEnterpriseToken`) : du bruit, une
# requête réseau inutile et des événements d'erreur dans la console.
#
# Ce que cela change en sécurité : RIEN de mesurable. La protection réelle de
# cette application est assurée par les règles Firestore (vérifiées par 66
# tests) et par Firebase Auth, pas par une attestation non appliquée.
#
# ── COMMENT LA RÉACTIVER PROPREMENT (si elle devient nécessaire) ─────────
#  1. Dans la console Firebase → App Check, enregistrer l'application web
#     avec la clé reCAPTCHA Enterprise, PUIS passer les services en mode
#     « Appliqué » (Firestore et Authentication). Sans cette dernière étape,
#     on ne fait que réintroduire le bruit.
#  2. Exporter la clé au déploiement :
#       RECAPTCHA_SITE_KEY=6Lc... ./build_and_deploy.sh
#  3. Vérifier immédiatement que la connexion fonctionne toujours : le code
#     injecte l'en-tête manuellement (lib/core/security/app_check.dart), car
#     l'application n'utilise pas le SDK Firebase pour l'authentification.
#
# Vide par défaut = aucun script reCAPTCHA chargé, aucune requête de jeton.
RECAPTCHA_SITE_KEY="${RECAPTCHA_SITE_KEY-}"

if [ -n "$RECAPTCHA_SITE_KEY" ]; then
  echo "→ Build Flutter web… (App Check: activé)"
else
  echo "→ Build Flutter web… (App Check: désactivé — clé absente)"
fi
cd "$FLUT" && flutter build web --release \
  --dart-define=PRODUCTION=true \
  --dart-define=RECAPTCHA_SITE_KEY="$RECAPTCHA_SITE_KEY" \
  --pwa-strategy=none

echo "→ Synchronisation du staging (download/ préservé)…"
find "$STAGE" -mindepth 1 -maxdepth 1 ! -name download -exec rm -rf {} +
cp -r "$FLUT/build/web/." "$STAGE/"

echo "→ Correctifs : kill-switch SW + bootstrap sans service worker…"
cp "$OVR/flutter_service_worker.js" "$STAGE/flutter_service_worker.js"
python3 - << 'PY'
import re
p="/home/user/gorex_web_stage/flutter_bootstrap.js"
s=open(p,encoding="utf-8").read()
s=re.sub(r'serviceWorkerSettings:\s*\{[^}]*\}', 'serviceWorkerSettings: null', s)
open(p,"w",encoding="utf-8").write(s)
PY


echo "→ Finalisation : nom de bundle empreinté (anti-cache Safari)…"
python3 "$OVR/finalize_web.py" "$STAGE"

echo "→ Déploiement Cloudflare…"
cd /home/user/gorex_web_worker

# ── LE JETON N'EST PLUS ECRIT DANS CE FICHIER ───────────────────────────
# Il y figurait en clair. Un jeton d'API Cloudflare permet de modifier ou de
# supprimer le Worker, les DNS et les regles : sa place n'est pas dans un
# script, meme non versionne, ou il finit par etre copie, filtre dans un
# historique de shell ou colle dans un ticket.
#
# Il est desormais lu depuis un fichier d'environnement aux droits restreints
# (600), absent du depot. Ordre de recherche :
#   1. $CLOUDFLARE_API_TOKEN deja exporte ;
#   2. ~/.gorex_cloudflare.env (source).
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  ENV_FILE="${HOME}/.gorex_cloudflare.env"
  if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$ENV_FILE"
  fi
fi

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "ERREUR : CLOUDFLARE_API_TOKEN absent." >&2
  echo "  Creez ${HOME}/.gorex_cloudflare.env contenant :" >&2
  echo "    CLOUDFLARE_API_TOKEN=votre_jeton" >&2
  echo "  puis : chmod 600 ${HOME}/.gorex_cloudflare.env" >&2
  echo "  (ou exportez la variable dans l'environnement)" >&2
  exit 1
fi

CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" npx wrangler@4 deploy
