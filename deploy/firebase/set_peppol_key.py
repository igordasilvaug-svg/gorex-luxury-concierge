#!/usr/bin/env python3
"""
GOREX GROUP — Activation de l'Access Point Peppol.

Finalise la configuration de facturation électronique UNE FOIS la clé d'API
obtenue auprès du fournisseur (Access Point agréé).

Ce que fait ce script, dans cet ordre :

  1. Demande la clé en saisie MASQUÉE (getpass) — jamais en argument, jamais
     dans l'historique du shell, jamais affichée.
  2. EXIGE l'identifiant NUMÉRIQUE de l'entité légale Gorex chez le
     fournisseur (transmis par `--legal-entity-id`).
  3. TESTE réellement `GET /legal_entities/{id}` avec la clé. Pas de test
     simulé : soit le fournisseur accepte, soit il refuse.
  4. Écrit le secret dans `company_secrets/gorex-group` — collection lisible
     du SEUL rôle finance. Jamais dans `company/gorex-group`, qui est public.
  5. N'active la transmission (`enabled: true`) QUE si le test a réussi.

Sans clé valide, le script n'écrit RIEN : pas de configuration à moitié faite.

POURQUOI L'IDENTIFIANT D'ENTITÉ AVANT LE TEST :
    Le 22/11/2026, l'API a été mesurée depuis ce réseau :
        GET /legal_entities          -> 404 (sans ET avec clé) : n'existe pas
        GET /legal_entities/{id}     -> 401 (sans ET avec clé) : existe
        POST /document_submissions   -> 401 (sans ET avec clé) : existe
    Il n'existe donc AUCUNE route permettant de LISTER les entités. On ne peut
    tester que sur une entité précise : cet identifiant doit être lu dans le
    tableau de bord du fournisseur AVANT de lancer ce script.

Usage :
    python3 set_peppol_key.py --legal-entity-id 12345            # procédure
    python3 set_peppol_key.py --legal-entity-id 12345 --dry-run  # teste sans écrire
    python3 set_peppol_key.py --base-url https://api.storecove.com/api/v2 \\
                              --legal-entity-id 12345
"""
from __future__ import annotations

import argparse
import getpass
import glob
import json
import sys
import urllib.error
import urllib.request

COMPANY_DOC = "gorex-group"
PROJECT_HINT = "gorex-concierge"

# URL de l'API de l'Access Point. Storecove est le fournisseur câblé dans
# `lib/core/billing/peppol_service.dart` (chemins /legal_entities et
# /document_submissions). Un autre fournisseur impose d'adapter ce service.
PROVIDERS = {"storecove": "https://api.storecove.com/api/v2"}

CANDIDATE_KEYS = [
    "/opt/flutter/firebase-admin-sdk.json",
    "/opt/flutter/*adminsdk*.json",
    "/opt/flutter/*admin-sdk*.json",
    "./firebase-admin-sdk.json",
]


# ─────────────────────────── sortie lisible ───────────────────────────
def ok(m: str) -> None:
    print(f"\033[92mOK   {m}\033[0m")


def err(m: str) -> None:
    print(f"\033[91mECHEC {m}\033[0m")


def warn(m: str) -> None:
    print(f"\033[93mATTENTION  {m}\033[0m")


def info(m: str) -> None:
    print(f"   {m}")


def titre(m: str) -> None:
    print(f"\n\033[1m{m}\033[0m")
    print("-" * 68)


# ─────────────────────────────── Firestore ───────────────────────────────
def get_db():
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        err("firebase-admin absent. Installez : pip install firebase-admin==7.1.0")
        sys.exit(1)

    path = None
    for pattern in CANDIDATE_KEYS:
        found = sorted(glob.glob(pattern))
        if found:
            path = found[0]
            break
    if not path:
        err("Clé de service Firebase introuvable (/opt/flutter/firebase-admin-sdk.json).")
        sys.exit(1)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(path))
    return firestore.client()


# ─────────────────────── test réel du fournisseur ───────────────────────
def probe_provider(base_url: str, api_key: str, legal_entity_id: int, timeout: int = 20):
    """Interroge réellement l'Access Point. Retourne (succès, message, entité).

    On appelle `GET /legal_entities/{id}` : la seule route de lecture existante
    (mesurée le 22/11/2026 — `/legal_entities` renvoie 404 même avec une clé
    valide). L'appel ne crée aucune facture et ne transmet aucun document.
    """
    url = f"{base_url.rstrip('/')}/legal_entities/{legal_entity_id}"
    req = urllib.request.Request(
        url,
        headers={"Accept": "application/json", "Authorization": f"Bearer {api_key}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8", "replace")
        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            return True, "Réponse acceptée (HTTP 200, corps non JSON).", {}
        entity = data if isinstance(data, dict) else {}
        check = entity.get("peppol_identifier") or entity.get("peppol_id")
        if check:
            return True, f"Connexion acceptée. Entité {legal_entity_id} — Peppol : {check}", entity
        return True, f"Connexion acceptée. Entité {legal_entity_id} accessible.", entity
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:300]
        if e.code == 401:
            return False, f"Clé refusée par l'Access Point (HTTP 401). {detail}", {}
        if e.code == 403:
            return (
                False,
                f"Clé acceptée mais aucun accès à l'entité {legal_entity_id} "
                f"(HTTP 403). Vérifiez l'identifiant. {detail}",
                {},
            )
        if e.code == 404:
            return (
                False,
                f"Entité légale {legal_entity_id} introuvable chez ce fournisseur "
                f"(HTTP 404). Vérifiez l'identifiant, ou l'URL de base. {detail}",
                {},
            )
        return False, f"Erreur HTTP {e.code}. {detail}", {}
    except urllib.error.URLError as e:
        return False, f"Réseau injoignable : {e.reason}", {}
    except Exception as e:
        return False, f"Échec : {e}", {}


# ──────────────────────────────── principal ──────────────────────────────
def main() -> int:
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--provider", choices=sorted(PROVIDERS), default="storecove")
    ap.add_argument("--base-url", help="URL de base de l'API (remplace --provider)")
    ap.add_argument(
        "--legal-entity-id",
        required=True,
        help="Identifiant NUMERIQUE de l'entite Gorex chez le fournisseur "
        "(obligatoire : aucune route ne permet de lister les entites)",
    )
    ap.add_argument(
        "--sender-peppol-id",
        default="0208:1009679037",
        help="Identifiant Peppol emetteur (defaut : celui enregistre chez Peppol)",
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Teste la cle mais n'ecrit RIEN dans Firestore",
    )
    args = ap.parse_args()

    base_url = args.base_url or PROVIDERS[args.provider]

    titre("GOREX GROUP — Activation de l'Access Point Peppol")
    info(f"Projet Firestore vise : {PROJECT_HINT}")
    info(f"URL de l'Access Point : {base_url}")
    info(f"Identifiant emetteur  : {args.sender_peppol_id}")
    if args.dry_run:
        warn("MODE A BLANC : aucune ecriture ne sera faite.")

    # ── 1. Identifiant d'entité (AVANT le test : voir docstring) ─────────
    titre("1/4 — Entite legale Gorex chez le fournisseur")
    legal_id = args.legal_entity_id.strip()
    if not legal_id.isdigit():
        err(
            f"« {args.legal_entity_id} » n'est pas un nombre entier.\n"
            "   L'API attend un identifiant numerique, pas un nom ni un numero\n"
            "   d'entreprise. Lisez-le dans le tableau de bord du fournisseur."
        )
        return 3
    entity_id = int(legal_id)
    ok(f"Identifiant d'entite retenu : {entity_id}")

    # ── 2. Saisie masquée ───────────────────────────────────────────────
    titre("2/4 — Cle d'API du fournisseur")
    info("Saisie masquee : la cle n'apparait ni a l'ecran ni dans l'historique.")
    key = getpass.getpass("   Cle d'API : ").strip()
    if not key:
        err("Aucune cle saisie. Rien n'a ete modifie.")
        return 1
    if len(key) < 16:
        warn(f"Cle tres courte ({len(key)} caracteres) — verifiez la copie.")
    info(f"Longueur de la cle : {len(key)} caracteres.")

    # ── 3. Test réel ────────────────────────────────────────────────────
    titre("3/4 — Test reel contre l'Access Point")
    info(f"Appel : GET /legal_entities/{entity_id} (aucun document transmis)")
    success, message, entity = probe_provider(base_url, key, entity_id)
    if not success:
        err(message)
        print()
        warn("RIEN n'a ete enregistre. Corrigez la cle, l'identifiant ou l'URL.")
        return 2
    ok(message)
    if entity:
        name = entity.get("name") or entity.get("legal_name")
        if name:
            info(f"Entite : {name}")
        if entity.get("city") or entity.get("country"):
            info(f"Localisation : {entity.get('city', '—')} / {entity.get('country', '—')}")

    # ── 4. Écriture ─────────────────────────────────────────────────────
    titre("4/4 — Enregistrement")
    enabled = True  # le test vient de réussir ET l'identifiant est numérique

    payload_public = {
        "apiBaseUrl": base_url,
        "senderPeppolId": args.sender_peppol_id,
        "senderLegalEntityId": str(entity_id),
        "enabled": enabled,
        # Pas de webhook : aucun serveur ne l'ecoute (site statique, POST 405).
        "webhookUrl": "",
    }

    if args.dry_run:
        warn("MODE A BLANC — rien n'est ecrit.")
        info(f"Aurait ete ecrit dans company_secrets/{COMPANY_DOC} : apiKey (masquee)")
        info(f"Aurait ete ecrit dans company/{COMPANY_DOC} : {payload_public}")
        return 0

    db = get_db()
    try:
        db.collection("company_secrets").document(COMPANY_DOC).set(
            {"peppol": {"apiKey": key}}, merge=True
        )
        ok(f"Secret ecrit dans company_secrets/{COMPANY_DOC} (role finance uniquement).")
    except Exception as e:
        err(f"Ecriture du secret impossible : {e}")
        return 4

    try:
        db.collection("company").document(COMPANY_DOC).set(
            {"peppol": payload_public}, merge=True
        )
        ok(f"Configuration publique ecrite dans company/{COMPANY_DOC}.")
    except Exception as e:
        err(f"Ecriture de la configuration impossible : {e}")
        return 5

    ok("Transmission Peppol ACTIVEE.")
    info("Verification : application -> Finance -> Parametres Peppol.")
    print()
    info("Prochaine etape : creez une facture pour un client professionnel et")
    info("utilisez « TRANSMETTRE VIA PEPPOL ». Le statut ne passera a « Envoye »")
    info("qu'apres une reponse reelle du fournisseur.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
