#!/usr/bin/env python3
"""
GOREX GROUP — Déploiement des règles Firestore par rôle.

Déploie `firestore.rules` (règles de production avec contrôle d'accès par rôle) :
  • personnel authentifié : accès métier ;
  • administrateur (CEO) : gestion des comptes ;
  • audit_log : append-only ;
  • tout accès requiert une session authentifiée.

Usage :
    python3 deploy_firestore_rules.py            # déploie
    python3 deploy_firestore_rules.py --show     # affiche sans déployer
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
RULES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "firestore.rules")


def find_admin_key():
    for pattern in CANDIDATE_KEYS:
        for path in sorted(glob.glob(pattern)):
            if os.path.isfile(path):
                return path
    return None


def get_access_token(key_path):
    from google.oauth2 import service_account
    import google.auth.transport.requests as gt
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
        print(e.read().decode()[:900])
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--show", action="store_true")
    args = ap.parse_args()

    with open(RULES_FILE) as fh:
        rules = fh.read()

    print("=" * 64)
    print("  GOREX GROUP — Règles Firestore par rôle")
    print("=" * 64)
    if args.show:
        print(rules)
        return

    key_path = find_admin_key()
    if not key_path:
        print("❌ Clé Admin SDK introuvable.")
        sys.exit(1)
    project_id = project_id_from_key(key_path)
    print(f"\n✅ Projet : {project_id}")
    print(f"✅ Fichier: {RULES_FILE}")
    token = get_access_token(key_path)

    base = f"https://firebaserules.googleapis.com/v1/projects/{project_id}"
    ruleset = api("POST", f"{base}/rulesets", token,
                  {"source": {"files": [{"name": "firestore.rules", "content": rules}]}})
    print(f"✅ Ruleset créé : {ruleset['name']}")

    api("PATCH", f"{base}/releases/cloud.firestore", token,
        {"release": {"name": f"projects/{project_id}/releases/cloud.firestore",
                     "rulesetName": ruleset["name"]}})
    print("✅ Règles PAR RÔLE déployées sur cloud.firestore")


if __name__ == "__main__":
    main()
