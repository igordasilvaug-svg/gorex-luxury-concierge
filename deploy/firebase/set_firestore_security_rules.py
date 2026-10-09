#!/usr/bin/env python3
"""
GOREX LUXURY CONCIERGE — Déploiement des règles de sécurité Firestore.

Déploie un jeu de règles adapté au DÉVELOPPEMENT (lecture/écriture ouvertes),
via l'API Firebase Rules (firebaserules.googleapis.com), en utilisant la clé
Admin SDK du projet.

⚠️  RÈGLES DE DÉVELOPPEMENT UNIQUEMENT — à durcir avant mise en production
    (voir la section "Durcissement" en bas du script et deploy/firebase/FIREBASE_SETUP.md).

Usage :
    python3 set_firestore_security_rules.py            # déploie les règles dev
    python3 set_firestore_security_rules.py --show     # affiche sans déployer
"""

import argparse
import glob
import json
import os
import sys
import urllib.request
import urllib.error

CANDIDATE_KEYS = [
    "/opt/flutter/firebase-admin-sdk.json",
    "/opt/flutter/*adminsdk*.json",
    "/opt/flutter/*admin-sdk*.json",
    "./firebase-admin-sdk.json",
]

SCOPES = ["https://www.googleapis.com/auth/cloud-platform"]

# --- Règles de DÉVELOPPEMENT (accès ouvert) -------------------------------
DEV_RULES = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ⚠️ DÉVELOPPEMENT : accès ouvert. À restreindre en production.
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
"""

# --- Règles PRODUCTION recommandées (décommenter après intégration Auth) --
PROD_RULES = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Utilisateurs authentifiés uniquement
    match /{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
"""


def find_admin_key():
    for pattern in CANDIDATE_KEYS:
        for path in sorted(glob.glob(pattern)):
            if os.path.isfile(path):
                return path
    return None


def get_access_token(key_path):
    try:
        from google.oauth2 import service_account
        import google.auth.transport.requests as gt
    except ImportError:
        print("❌ google-auth non disponible. → pip install google-auth")
        sys.exit(1)

    creds = service_account.Credentials.from_service_account_file(key_path, scopes=SCOPES)
    creds.refresh(gt.Request())
    return creds.token


def project_id_from_key(key_path):
    with open(key_path) as fh:
        return json.load(fh)["project_id"]


def api(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        print(f"❌ HTTP {e.code} on {method} {url}")
        print(e.read().decode()[:800])
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--show", action="store_true", help="Affiche les règles sans déployer")
    args = parser.parse_args()

    print("=" * 64)
    print("  GOREX — Règles de sécurité Firestore")
    print("=" * 64)

    if args.show:
        print("\n--- Règles de développement ---")
        print(DEV_RULES)
        print("--- Règles de production (référence) ---")
        print(PROD_RULES)
        return

    key_path = find_admin_key()
    if not key_path:
        print("❌ Clé Admin SDK introuvable.")
        sys.exit(1)

    project_id = project_id_from_key(key_path)
    print(f"\n✅ Projet : {project_id}")
    print(f"✅ Clé    : {key_path}")

    token = get_access_token(key_path)
    print("✅ Jeton OAuth obtenu")

    base = f"https://firebaserules.googleapis.com/v1/projects/{project_id}"

    # 1) Créer un ruleset
    ruleset = api("POST", f"{base}/rulesets", token, {
        "source": {"files": [{"name": "firestore.rules", "content": DEV_RULES}]}
    })
    ruleset_name = ruleset["name"]
    print(f"✅ Ruleset créé : {ruleset_name}")

    # 2) Mettre à jour la release cloud.firestore
    release_name = f"projects/{project_id}/releases/cloud.firestore"
    api("PATCH", f"{base}/releases/cloud.firestore", token, {
        "release": {"name": release_name, "rulesetName": ruleset_name}
    })
    print("✅ Règles de développement déployées sur cloud.firestore")

    print("\n⚠️  Rappel : règles ouvertes = DÉVELOPPEMENT uniquement.")
    print("   Passez aux règles PROD (dans ce script) avant la mise en production.")


if __name__ == "__main__":
    main()
