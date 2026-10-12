#!/usr/bin/env python3
"""
GOREX GROUP — Provisionnement des comptes professionnels (Phase A).

Crée réellement les comptes dans Firebase Authentication (projet gorex-concierge) :
  • mot de passe robuste et unique par compte (20+ caractères, aléatoire crypto) ;
  • e-mail vérifié, custom claims `role` (contrôle d'accès côté règles Firestore) ;
  • fiche Firestore `staff/{uid}` avec rôle, service, drapeau mustChangePassword.

⚠️ Les mots de passe ne sont JAMAIS écrits dans le dépôt : ils sont générés en
   mémoire puis exportés dans un fichier confidentiel HORS du projet
   (/home/user/secure_delivery/), à transmettre hors ligne puis à supprimer.

Usage :
  python3 provision_staff_accounts.py            # crée / met à jour
  python3 provision_staff_accounts.py --dry-run  # simulation, n'écrit rien
  python3 provision_staff_accounts.py --domain gorex-group.eu
"""
from __future__ import annotations

import argparse
import json
import os
import secrets
import string
import sys
from datetime import datetime, timezone

try:
    import firebase_admin
    from firebase_admin import credentials, auth, firestore
except ImportError:
    print("❌ firebase-admin requis (pip install firebase-admin==7.1.0)")
    sys.exit(1)

ADMIN_SDK = "/opt/flutter/firebase-admin-sdk.json"
OUT_DIR = "/home/user/secure_delivery"

# ── Comptes professionnels ────────────────────────────────────────────────────
# (local-part, rôle interne, libellé, service)
STAFF = [
    ("ceo",              "ceo",                "CEO / Administrateur",  "Direction"),
    ("conciergemanager", "conciergeManager",   "Concierge Manager",     "Conciergerie"),
    ("seniorconcierge",  "seniorConcierge",    "Senior Concierge",      "Conciergerie"),
    ("concierge",        "concierge",          "Concierge",             "Conciergerie"),
    ("travelmanager",    "travelManager",      "Travel Manager",        "Travel"),
    ("lifestylemanager", "lifestyleManager",   "Lifestyle Manager",     "Lifestyle"),
    ("security",         "securityCoordinator","Security Coordinator",  "Security"),
    ("finance",          "finance",            "Finance",               "Finance"),
]

ALPHABET = string.ascii_letters + string.digits + "!@#$%^&*()-_=+"


def gen_password(n: int = 22) -> str:
    """Mot de passe robuste garantissant les 4 catégories de caractères."""
    while True:
        pwd = "".join(secrets.choice(ALPHABET) for _ in range(n))
        if (any(c.islower() for c in pwd) and any(c.isupper() for c in pwd)
                and any(c.isdigit() for c in pwd)
                and any(c in "!@#$%^&*()-_=+" for c in pwd)):
            return pwd


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--domain", default="gorex-group.eu",
                    help="Domaine e-mail des comptes (défaut: gorex-group.eu)")
    ap.add_argument("--dry-run", action="store_true",
                    help="Simulation : aucune écriture dans Firebase")
    args = ap.parse_args()

    cred = credentials.Certificate(ADMIN_SDK)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    print(f"Projet     : {cred.project_id}")
    print(f"Domaine    : @{args.domain}")
    print(f"Mode       : {'DRY-RUN (aucune écriture)' if args.dry_run else 'RÉEL'}")
    print("=" * 68)

    results = []
    for local, role, label, dept in STAFF:
        email = f"{local}@{args.domain}"
        password = gen_password(22)
        uid = None
        status = ""

        if not args.dry_run:
            try:
                existing = None
                try:
                    existing = auth.get_user_by_email(email)
                except auth.UserNotFoundError:
                    existing = None

                if existing:
                    auth.update_user(
                        existing.uid,
                        password=password,
                        email_verified=True,
                        display_name=label,
                        disabled=False,
                    )
                    uid = existing.uid
                    status = "mis à jour"
                else:
                    u = auth.create_user(
                        email=email,
                        password=password,
                        email_verified=True,
                        display_name=label,
                    )
                    uid = u.uid
                    status = "créé"

                # Custom claims : rôle lisible par les règles Firestore.
                auth.set_custom_user_claims(uid, {"role": role, "dept": dept})

                # Fiche Firestore (sans mot de passe !).
                db.collection("staff").document(uid).set({
                    "uid": uid,
                    "email": email,
                    "displayName": label,
                    "role": role,
                    "department": dept,
                    "active": True,
                    "mustChangePassword": True,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                }, merge=True)

                # Journal d'audit.
                db.collection("audit_log").add({
                    "type": "staff_account_provisioned",
                    "actor": "admin-sdk",
                    "subject": email,
                    "role": role,
                    "at": firestore.SERVER_TIMESTAMP,
                })
            except Exception as e:
                status = f"ERREUR: {str(e)[:120]}"

        results.append({
            "email": email, "role": role, "label": label, "department": dept,
            "password": password, "uid": uid, "status": status or "simulé",
        })
        print(f"  {'✓' if uid or args.dry_run else '✗'} {email:38s} {role:20s} {status}")

    # ── Export confidentiel HORS dépôt ────────────────────────────────────────
    if not args.dry_run:
        os.makedirs(OUT_DIR, exist_ok=True)
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        path = os.path.join(OUT_DIR, f"gorex_identifiants_{stamp}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump({
                "projet": cred.project_id,
                "genere_le": datetime.now(timezone.utc).isoformat(),
                "avertissement": ("CONFIDENTIEL — À TRANSMETTRE HORS LIGNE. "
                                  "Chaque collaborateur DOIT changer son mot de passe "
                                  "à la 1re connexion. Supprimer ce fichier après diffusion."),
                "comptes": [{k: r[k] for k in ("email", "role", "label", "department", "password", "uid")}
                            for r in results],
            }, f, ensure_ascii=False, indent=2)
        os.chmod(path, 0o600)
        print("=" * 68)
        print(f"🔐 Fichier d'identifiants (confidentiel) : {path}")
        print("   → hors du dépôt, permissions 600, à supprimer après diffusion.")

    print("=" * 68)
    print(f"Terminé : {len(results)} comptes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
