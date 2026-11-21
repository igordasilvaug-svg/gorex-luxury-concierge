#!/usr/bin/env bash
# Lanceur des tests de règles Firestore.
#
# ── POURQUOI CE SCRIPT EXISTE ──────────────────────────────────────────────
# L'émulateur Firestore REFUSE un fichier de règles situé hors de son dossier
# projet (« ../firestore.rules is outside of project directory »). La
# contournement précédent consistait à copier les règles à la main dans un
# autre dossier (/home/user/rules_lab). Résultat constaté : la copie a divergé
# du fichier versionné, et un émulateur a tourné pendant des heures avec des
# règles périmées — les tests « passaient » sans rien prouver du fichier qui
# est réellement publié.
#
# Ce script recopie SYSTÉMATIQUEMENT la source versionnée avant chaque
# exécution. La copie ne peut donc plus être en avance ou en retard sur elle.
#
# USAGE :  ./run_rules_tests.sh
# Sortie : 0 si tous les tests passent, non nul sinon.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SRC="$HERE/../firestore.rules"
LAB="${RULES_LAB:-/home/user/rules_lab}"
PORT="${FIRESTORE_EMULATOR_PORT:-8080}"
PROJECT="gorex-concierge-lab"

if [[ ! -f "$RULES_SRC" ]]; then
  echo "ERREUR : règles introuvables : $RULES_SRC" >&2
  exit 1
fi

mkdir -p "$LAB"

# La copie est refaite à chaque exécution : aucune dérive possible.
cp "$RULES_SRC" "$LAB/firestore.rules"
echo "Règles copiées depuis $RULES_SRC ($(wc -l < "$LAB/firestore.rules") lignes)"

cat > "$LAB/firebase.json" <<JSON
{
  "firestore": { "rules": "firestore.rules" },
  "emulators": {
    "firestore": { "host": "127.0.0.1", "port": $PORT },
    "ui": { "enabled": false }
  }
}
JSON

# Dépendances : on réutilise celles du lab si elles existent déjà.
if [[ ! -d "$LAB/node_modules" ]]; then
  echo "Installation des dépendances de test dans $LAB…"
  ( cd "$LAB" && npm install --no-fund --no-audit \
      @firebase/rules-unit-testing@^3.0.4 firebase@^10.14.1 firebase-tools@^13.29.1 ) || {
    echo "ERREUR : installation impossible" >&2
    exit 1
  }
fi

# Libère le port si un émulateur oublié l'occupe encore.
if lsof -ti:$PORT >/dev/null 2>&1; then
  echo "Port $PORT occupé : arrêt de l'émulateur précédent."
  lsof -ti:$PORT | xargs -r kill -9 2>/dev/null
  sleep 2
fi

LOG="$(mktemp)"
( cd "$LAB" && PATH="$LAB/node_modules/.bin:$PATH" \
    firebase emulators:start --only firestore --project "$PROJECT" \
    > "$LOG" 2>&1 ) &
EMU_PID=$!

cleanup() {
  kill "$EMU_PID" 2>/dev/null
  lsof -ti:$PORT 2>/dev/null | xargs -r kill -9 2>/dev/null
}
trap cleanup EXIT

# Attente active : l'émulateur met ~10-20 s à démarrer.
for _ in $(seq 1 60); do
  if grep -q "All emulators ready" "$LOG" 2>/dev/null; then break; fi
  if grep -qE "^Error|Could not start" "$LOG" 2>/dev/null; then
    echo "Échec du démarrage de l'émulateur :" >&2
    tail -20 "$LOG" >&2
    exit 1
  fi
  sleep 1
done

if ! grep -q "All emulators ready" "$LOG" 2>/dev/null; then
  echo "L'émulateur n'a pas démarré dans le délai imparti :" >&2
  tail -20 "$LOG" >&2
  exit 1
fi

echo "Émulateur prêt. Exécution des tests…"
echo "────────────────────────────────────────────────────────────────"
( cd "$LAB" && cp "$HERE/rules.test.js" ./rules.test.js \
    && GOREX_RULES_PATH="$LAB/firestore.rules" node ./rules.test.js )
RC=$?
echo "────────────────────────────────────────────────────────────────"
exit $RC
