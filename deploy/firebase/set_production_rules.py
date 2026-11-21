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
# ─────────────────────────────────────────────────────────────────────────────
# SCRIPT DÉSARMÉ — NE PAS RÉUTILISER TEL QUEL.
#
# Ce script publiait un jeu de règles codé en dur :
#
#     match /{document=**} { allow read, write: if request.auth != null; }
#
# Appliqué sur `gorex-concierge`, il aurait accordé à N'IMPORTE QUEL compte
# connecté — y compris un client tout juste inscrit et jamais validé — la
# lecture et l'écriture de TOUTE la base : dossiers clients, journal d'audit,
# fiches du personnel. Aucun contrôle par rôle, aucune restriction de champ.
#
# Les règles réelles — refus par défaut, contrôle par rôle, validation des
# inscriptions client — vivent dans `deploy/firebase/firestore.rules` et sont
# publiées par `deploy_firestore_rules.py`, qui lit ce fichier.
#
# Ce script refuse donc désormais de s'exécuter.
# ─────────────────────────────────────────────────────────────────────────────
_ARCHIVED_WARNING = (
    "Jeu de regles historiquement contenu dans ce script :\n"
    "    match /{document=**} { allow read, write: if request.auth != null; }\n"
    "Il accordait a tout compte connecte l'acces total a la base.\n"
    "Il n'est plus jamais deploye."
)


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
    parser.parse_args()

    print("=" * 64)
    print("  GOREX — Règles Firestore PRODUCTION")
    print("=" * 64)
    print()
    print("⚠️  SCRIPT DÉSARMÉ — AUCUN DÉPLOIEMENT EFFECTUÉ.")
    print()
    print(_ARCHIVED_WARNING)
    print()
    print("Le déploiement des règles passe exclusivement par :")
    print("    deploy/firebase/deploy_firestore_rules.py")
    print("qui publie le contenu de :")
    print("    deploy/firebase/firestore.rules")
    print()
    print("Pour consulter les règles réellement en production :")
    print("    python3 deploy/firebase/deploy_firestore_rules.py --show")
    sys.exit(1)


if __name__ == "__main__":
    main()
