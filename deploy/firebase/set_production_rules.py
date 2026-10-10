#!/usr/bin/env python3
"""
GOREX LUXURY CONCIERGE — Déploiement des règles de sécurité Firestore PRODUCTION.

Déploie un jeu de règles restreignant l'accès aux seules sessions authentifiées
(Firebase Auth — session anonyme côté application). Aucun accès public.

- Lecture / écriture : uniquement si `request.auth != null`.
- Le document d'état `gorex_cloud/state` est également protégé.

Usage :
    python3 set_production_rules.py           # déploie les règles PROD
    python3 set_production_rules.py --show    # affiche sans déployer
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

# --- Règles PRODUCTION ----------------------------------------------------
PROD_RULES = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Toute la base : accessible uniquement aux sessions authentifiées.
    // L'application ouvre une session Firebase anonyme (firebase_auth) au
    // démarrage ; le backend Admin SDK conserve l'accès complet côté serveur.
    match /{document=**} {
      allow read, write: if request.auth != null;
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
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()

    print("=" * 64)
    print("  GOREX — Règles Firestore PRODUCTION")
    print("=" * 64)

    if args.show:
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

    ruleset = api("POST", f"{base}/rulesets", token, {
        "source": {"files": [{"name": "firestore.rules", "content": PROD_RULES}]}
    })
    ruleset_name = ruleset["name"]
    print(f"✅ Ruleset créé : {ruleset_name}")

    release_name = f"projects/{project_id}/releases/cloud.firestore"
    api("PATCH", f"{base}/releases/cloud.firestore", token, {
        "release": {"name": release_name, "rulesetName": ruleset_name}
    })
    print("✅ Règles PRODUCTION déployées sur cloud.firestore")
    print("\n🔒 Accès désormais réservé aux sessions authentifiées (Firebase Auth).")


if __name__ == "__main__":
    main()
