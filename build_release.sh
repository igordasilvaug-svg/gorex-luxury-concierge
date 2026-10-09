#!/usr/bin/env bash
#
# GOREX LUXURY CONCIERGE — Script de build « release »
# ---------------------------------------------------------------------------
# Génère en une seule commande :
#   1. l'AAB de production (comptes de démonstration MASQUÉS) pour Google Play ;
#   2. les APK signés séparés par ABI (arm64-v8a, armeabi-v7a, x86_64) ;
#   3. le bundle Flutter Web + le dossier de staging du Worker Cloudflare ;
#   4. la page de téléchargement public : découpage des APK en morceaux < 5 Mo
#      + régénération du manifeste (tailles + empreintes SHA-256).
#
# Usage :
#   ./build_release.sh                 # tout (analyse + tests + AAB + APK + web)
#   ./build_release.sh --skip-tests    # sans la suite de tests
#   ./build_release.sh --skip-web      # sans le build web / staging
#   ./build_release.sh --deploy        # déploie aussi sur Cloudflare (wrangler)
#   ./build_release.sh --no-prod-web   # web en mode démo (comptes visibles)
#
# Prérequis : Flutter 3.35.4 / Dart 3.9.2, Android SDK, python3, split, sha256sum.
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Chemins ─────────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_WEB="$PROJECT_DIR/build/web"
APK_DIR="$PROJECT_DIR/build/app/outputs/flutter-apk"
AAB_DIR="$PROJECT_DIR/build/app/outputs/bundle/release"
STAGE_DIR="${GOREX_STAGE_DIR:-/home/user/gorex_web_stage}"
WORKER_DIR="${GOREX_WORKER_DIR:-/home/user/gorex_web_worker}"

# Taille maximale par morceau (limite Cloudflare = 5 Mo/fichier ; marge de sécurité)
PART_BYTES=4000000

# ── Options ─────────────────────────────────────────────────────────────────
SKIP_TESTS=0; SKIP_WEB=0; DEPLOY=0; PROD_WEB=1
for arg in "$@"; do
  case "$arg" in
    --skip-tests) SKIP_TESTS=1 ;;
    --skip-web)   SKIP_WEB=1 ;;
    --deploy)     DEPLOY=1 ;;
    --no-prod-web) PROD_WEB=0 ;;
    *) echo "Option inconnue : $arg" >&2; exit 2 ;;
  esac
done

# ── Utilitaires ─────────────────────────────────────────────────────────────
c() { printf "\033[1;33m%s\033[0m\n" "$*"; }   # titre (or)
ok() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
die() { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

cd "$PROJECT_DIR"

# Version (depuis pubspec.yaml)
VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//')"
c "GOREX LUXURY CONCIERGE — build release (version $VERSION)"

# ── 1. Dépendances ──────────────────────────────────────────────────────────
c "[1/6] Résolution des dépendances…"
flutter pub get >/dev/null
ok "flutter pub get"

# ── 2. Analyse statique ─────────────────────────────────────────────────────
c "[2/6] Analyse statique…"
if ! flutter analyze; then die "flutter analyze a signalé des erreurs"; fi
ok "Analyse propre"

# ── 3. Tests ────────────────────────────────────────────────────────────────
if [ "$SKIP_TESTS" -eq 0 ]; then
  c "[3/6] Tests…"
  flutter test >/dev/null || die "Échec des tests"
  ok "Tests passés"
else
  c "[3/6] Tests ignorés (--skip-tests)"
fi

# ── 4. AAB de production (comptes de démo masqués) ──────────────────────────
c "[4/6] Build AAB de production (PRODUCTION=true)…"
flutter build appbundle --release --dart-define=PRODUCTION=true >/dev/null
ok "AAB : $AAB_DIR/app-release.aab ($(du -h "$AAB_DIR/app-release.aab" | cut -f1))"

# ── 5. APK séparés par ABI ──────────────────────────────────────────────────
c "[5/6] Build des APK (split-per-abi)…"
flutter build apk --release --split-per-abi --dart-define=PRODUCTION=true >/dev/null
ok "APK générés dans $APK_DIR"

# ── 6. Web + staging + page de téléchargement ───────────────────────────────
if [ "$SKIP_WEB" -eq 0 ]; then
  c "[6/6] Build Web + staging Cloudflare + découpage APK…"

  # 6a. Build web (démo par défaut : les comptes restent visibles pour la
  #     connexion, faute de backend d'authentification réel).
  if [ "$PROD_WEB" -eq 1 ]; then
    flutter build web --release --dart-define=PRODUCTION=true >/dev/null
    ok "Web build (PRODUCTION)"
  else
    flutter build web --release >/dev/null
    ok "Web build (démo)"
  fi

  # 6b. Synchroniser build/web -> stage (sans écraser download/)
  mkdir -p "$STAGE_DIR"
  # Vider le staging SAUF le dossier download/ (conservé puis régénéré en 6c)
  find "$STAGE_DIR" -mindepth 1 -maxdepth 1 ! -name 'download' -exec rm -rf {} +
  cp -a "$BUILD_WEB/." "$STAGE_DIR/"
  # Retirer les artefacts lourds inutiles au runtime web
  find "$STAGE_DIR" -name '*.wasm' -delete 2>/dev/null || true
  find "$STAGE_DIR" -name '*.symbols' -delete 2>/dev/null || true
  ok "Staging synchronisé : $STAGE_DIR"

  # 6c. Découper les APK + régénérer le manifeste
  PARTS_DIR="$STAGE_DIR/download/parts"
  rm -rf "$PARTS_DIR"; mkdir -p "$PARTS_DIR"
  cp "$PROJECT_DIR/web/download.html" "$STAGE_DIR/download.html"
  cp "$PROJECT_DIR/web/download.js"   "$STAGE_DIR/download.js"

  declare -A ABI_LABEL=( [arm64-v8a]="ARM 64 bits (v8a)" [armeabi-v7a]="ARM 32 bits (v7a)" [x86_64]="x86_64" )
  declare -A ABI_RECO=( [arm64-v8a]=true [armeabi-v7a]=false [x86_64]=false )
  declare -A ABI_FILE=( [arm64-v8a]="gorex-concierge-arm64-v8a.apk" [armeabi-v7a]="gorex-concierge-armeabi-v7a.apk" [x86_64]="gorex-concierge-x86_64.apk" )

  for abi in arm64-v8a armeabi-v7a x86_64; do
    src="$APK_DIR/app-${abi}-release.apk"
    [ -f "$src" ] || die "APK manquant : $src"
    out="${ABI_FILE[$abi]}"
    cp "$src" "$PARTS_DIR/$out"
    split -b "$PART_BYTES" -d -a 2 "$PARTS_DIR/$out" "$PARTS_DIR/$out.part"
    rm -f "$PARTS_DIR/$out"   # on ne garde que les morceaux
    ok "Découpé : $out ($(ls "$PARTS_DIR/$out.part"* | wc -l) morceaux)"
  done

  # 6d. Manifeste JSON (tailles + SHA-256)
  python3 - "$PARTS_DIR" "$VERSION" <<'PY'
import json, os, sys, glob, hashlib
parts_dir, version = sys.argv[1], sys.argv[2]
meta = {
  "arm64-v8a":  ("ARM 64 bits (v8a)", True,  "gorex-concierge-arm64-v8a.apk"),
  "armeabi-v7a":("ARM 32 bits (v7a)", False, "gorex-concierge-armeabi-v7a.apk"),
  "x86_64":     ("x86_64",            False, "gorex-concierge-x86_64.apk"),
}
files = {}
for abi,(label,reco,fname) in meta.items():
    parts = sorted(glob.glob(os.path.join(parts_dir, fname + ".part*")))
    h = hashlib.sha256(); size = 0
    for p in parts:
        with open(p,'rb') as fh:
            for chunk in iter(lambda: fh.read(1<<20), b''):
                h.update(chunk); size += len(chunk)
    files[abi] = {
        "label": label, "recommended": reco, "filename": fname,
        "size": size, "sha256": h.hexdigest(),
        "parts": [os.path.basename(p) for p in parts],
        "part_count": len(parts),
    }
manifest = {"version": version, "package": "com.gorexconcierge.luxury",
            "min_sdk": 24, "files": files}
with open(os.path.join(parts_dir, "..", "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
print("  manifeste :", os.path.join(parts_dir, "..", "manifest.json"))
PY
  ok "Manifeste régénéré"

  # 6e. (Optionnel) déploiement Cloudflare
  if [ "$DEPLOY" -eq 1 ]; then
    c "Déploiement Cloudflare (wrangler)…"
    ( cd "$WORKER_DIR" && npx wrangler@4 deploy --temporary )
    ok "Déployé"
  fi
else
  c "[6/6] Web/staging ignorés (--skip-web)"
fi

# ── Résumé ──────────────────────────────────────────────────────────────────
echo
c "════════════════════════ RÉSUMÉ ════════════════════════"
printf "  Version        : %s\n" "$VERSION"
printf "  AAB (Play)     : %s\n" "$AAB_DIR/app-release.aab"
printf "  APK            : %s/app-{arm64-v8a,armeabi-v7a,x86_64}-release.apk\n" "$APK_DIR"
[ "$SKIP_WEB" -eq 0 ] && printf "  Staging Worker : %s\n" "$STAGE_DIR"
echo
ok "Build terminé."
echo
echo "  ➜ Publier l'AAB  : Play Console → Production → Téléverser"
echo "  ➜ Déployer le web : cd $WORKER_DIR && npx wrangler@4 deploy --temporary"
echo
