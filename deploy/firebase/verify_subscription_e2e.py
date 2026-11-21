#!/usr/bin/env python3
"""GOREX — Vérification bout-en-bout du circuit d'abonnement en PRODUCTION.

──────────────────────────────────────────────────────────────────────────────
POURQUOI CE SCRIPT EXISTE
──────────────────────────────────────────────────────────────────────────────
Les tests de règles tournent sur l'émulateur. L'émulateur a prouvé qu'il ne
suffisait pas : il répondait « autorisé » à une écriture que le VRAI Firestore
refusait (403). Cause : l'application écrit ses dates en ISO 8601 et
l'encodeur REST les convertit en `timestampValue`, alors que la règle exigeait
`is string`. L'émulateur recevait une vraie chaîne JS, la production un
timestamp.

Ce script comble ce trou : il s'adresse au VRAI Firestore, avec un VRAI compte
et la charge utile EXACTE de l'application. Il vérifie ce qui doit réussir ET
ce qui doit être refusé.

──────────────────────────────────────────────────────────────────────────────
CE QU'IL FAIT, DANS L'ORDRE
──────────────────────────────────────────────────────────────────────────────
 1. compte l'état avant (pour prouver le nettoyage) ;
 2. crée un compte Firebase Auth jetable + fiche client + profil ;
 3. se connecte par l'API REST, comme le fait l'application ;
 4. lit la grille tarifaire ;
 5. dépose une demande d'abonnement avec la charge utile réelle ;
 6. tente les écritures INTERDITES (statut auto-attribué, dossier d'autrui) ;
 7. signe un mandat SEPA comme le débiteur le ferait ;
 8. relit pour prouver la persistance ;
 9. SUPPRIME TOUT et vérifie que l'état est revenu à l'identique.

──────────────────────────────────────────────────────────────────────────────
LA CLÉ API N'EST PAS ÉCRITE ICI
──────────────────────────────────────────────────────────────────────────────
Elle est LUE dans `lib/core/firebase/firebase_options.dart`, source unique de
vérité. Une première version la recopiait à la main : une faute de frappe
(« L » au lieu de « hL ») a produit « API key not valid » et m'a fait chercher
pendant plusieurs essais une restriction Firebase qui n'existait pas. On ne
recopie pas un secret à la main quand un fichier le contient déjà.

USAGE
    python3 deploy/firebase/verify_subscription_e2e.py
Sortie : 0 si tout passe, 2 sinon.
"""
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OPTIONS_DART = os.path.join(ROOT, "lib", "core", "firebase", "firebase_options.dart")
ADMIN_KEY = "/opt/flutter/firebase-admin-sdk.json"

PROJECT = "gorex-concierge"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
IDENT = "https://identitytoolkit.googleapis.com/v1/accounts"

ok_count = 0
ko_count = 0
created = {"uid": None, "client": None, "profile": None, "subs": [], "mands": [],
           "finance_uid": None, "finance_staff": None}


def say(label, success, detail=""):
    global ok_count, ko_count
    if success:
        ok_count += 1
    else:
        ko_count += 1
    print(f"{'PASS' if success else 'FAIL'}  {label}"
          + (f"  -> {detail}" if detail and not success else ""))


def read_web_api_key():
    """Extrait la clé Web depuis la source Dart — aucune recopie manuelle."""
    src = open(OPTIONS_DART, encoding="utf-8").read()
    block = re.search(r"static const FirebaseOptions web = FirebaseOptions\((.*?)\);",
                      src, re.S)
    if not block:
        sys.exit("ERREUR : bloc `web` introuvable dans firebase_options.dart")
    m = re.search(r"apiKey:\s*'([^']+)'", block.group(1))
    if not m:
        sys.exit("ERREUR : apiKey introuvable dans le bloc `web`")
    key = m.group(1)
    # Même contrôle que dans l'application : format d'une clé API Google.
    if not re.fullmatch(r"AIza[0-9A-Za-z_-]{35}", key):
        sys.exit(f"ERREUR : clé API de forme inattendue ({len(key)} caractères)")
    return key


def req(url, method="GET", body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            payload = json.loads(e.read() or b"{}")
        except Exception:
            payload = {}
        return e.code, payload


def main():
    if not os.path.exists(ADMIN_KEY):
        sys.exit(f"ERREUR : clé d'administration absente : {ADMIN_KEY}")

    api_key = read_web_api_key()
    print(f"Clé API lue depuis firebase_options.dart : {api_key[:10]}… "
          f"({len(api_key)} caractères)")
    print()

    from firebase_admin import auth as fb_auth, initialize_app, credentials as fb_creds, firestore

    cred = fb_creds.Certificate(ADMIN_KEY)
    try:
        initialize_app(cred, {"projectId": PROJECT})
    except ValueError:
        pass  # application déjà initialisée dans ce processus
    db = firestore.client()

    def counts():
        return {c: len(list(db.collection(c).limit(500).stream()))
                for c in ["clients", "subscriptions", "sepa_mandates", "user_profiles", "staff"]}

    stamp = datetime.datetime.now().strftime("%H%M%S")
    email = f"e2e.abonnement.{stamp}@example.invalid"
    password = f"Grx-E2E-{stamp}!abonnement"

    before = counts()
    print("État AVANT :", before)
    print()

    try:
        # ── 1. Compte et fiches ──────────────────────────────────────────
        user = fb_auth.create_user(email=email, password=password, email_verified=True)
        created["uid"] = user.uid
        say("1. compte Firebase Auth créé", True)

        cid = "e2ecli" + stamp
        db.collection("clients").document(cid).set({
            "id": cid, "code": "GRX-E2E-" + stamp, "fullName": "Client E2E",
            "email": email, "phone": "+32470000000", "language": "fr",
            "country": "Belgique", "city": "Bruxelles",
            "subscriptionTierId": "", "approvalStatus": "approved", "active": True,
        })
        created["client"] = cid
        db.collection("user_profiles").document(user.uid).set({
            "uid": user.uid, "email": email, "role": "vipClient", "clientId": cid,
        })
        created["profile"] = user.uid
        say("2. fiche client + profil créés", True)

        # ── 2. Connexion comme l'application ─────────────────────────────
        st, res = req(f"{IDENT}:signInWithPassword?key={api_key}", "POST",
                      {"email": email, "password": password, "returnSecureToken": True})
        token = res.get("idToken")
        say("3. connexion client (REST, comme l'application)",
            st == 200 and bool(token),
            f"HTTP {st} {res.get('error', {}).get('message', '')}")
        if not token:
            raise SystemExit("connexion impossible : le reste ne prouverait rien")

        # ── 3. Grille tarifaire ──────────────────────────────────────────
        st, res = req(f"{FS}/subscription_tiers?pageSize=50", token=token)
        tiers = res.get("documents", [])
        say("4. le client LIT la grille tarifaire", st == 200 and len(tiers) >= 1,
            f"HTTP {st} docs={len(tiers)}")

        # ── 4. Charge utile EXACTE de l'application ──────────────────────
        # Même encodage que `_encodeValue` : null -> nullValue, date ISO ->
        # timestampValue. C'est précisément ce que l'émulateur ne reproduisait
        # pas, et qui a masqué un 403 réel.
        now = datetime.datetime.now(datetime.timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

        sub_id = "sub_e2e_" + stamp
        sub_doc = {"fields": {
            "id": {"stringValue": sub_id},
            "clientId": {"stringValue": cid},
            "clientEmail": {"stringValue": email},
            "tierId": {"stringValue": "tier_essential"},
            "tierName": {"stringValue": "GOREX ESSENTIAL"},
            "cycle": {"stringValue": "annual"},
            "amount": {"doubleValue": 4800},
            "status": {"stringValue": "requested"},
            "requestedAt": {"timestampValue": now},
            "decidedAt": {"nullValue": None},
            "decidedBy": {"nullValue": None},
            "activatedAt": {"nullValue": None},
            "note": {"nullValue": None},
        }}
        st, res = req(f"{FS}/subscriptions/{sub_id}", "PATCH", sub_doc, token=token)
        created["subs"].append(sub_id)
        say("5. le client DÉPOSE une demande (charge utile réelle, nuls compris)",
            st == 200, f"HTTP {st} {str(res)[:180]}")

        # ── 5. Barrières de sécurité ─────────────────────────────────────
        sid2 = "sub_e2e_active_" + stamp
        bad = json.loads(json.dumps(sub_doc))
        bad["fields"]["id"] = {"stringValue": sid2}
        bad["fields"]["status"] = {"stringValue": "active"}
        st, _ = req(f"{FS}/subscriptions/{sid2}", "PATCH", bad, token=token)
        created["subs"].append(sid2)
        say("6. statut `active` écrit par le client -> REFUSÉ", st == 403,
            f"HTTP {st} (attendu 403)")

        sid3 = "sub_e2e_other_" + stamp
        bad2 = json.loads(json.dumps(sub_doc))
        bad2["fields"]["id"] = {"stringValue": sid3}
        bad2["fields"]["clientId"] = {"stringValue": "autre-dossier"}
        st, _ = req(f"{FS}/subscriptions/{sid3}", "PATCH", bad2, token=token)
        created["subs"].append(sid3)
        say("7. abonnement sur un AUTRE dossier -> REFUSÉ", st == 403,
            f"HTTP {st} (attendu 403)")

        # ── 6. Mandat SEPA signé par le débiteur ─────────────────────────
        mid = "mand_e2e_" + stamp
        mand_doc = {"fields": {
            "id": {"stringValue": mid},
            "clientId": {"stringValue": cid},
            "clientName": {"stringValue": "Client E2E"},
            "mandateReference": {"stringValue": "GRX-ABO-2026-9" + stamp},
            "iban": {"stringValue": "BE68539007547034"},
            "bic": {"nullValue": None},
            "accountHolder": {"stringValue": "Client E2E"},
            "type": {"stringValue": "core"},
            "status": {"stringValue": "active"},
            "signatureDate": {"timestampValue": now},
            "createdAt": {"timestampValue": now},
            "cancelledAt": {"nullValue": None},
            "lastUsedAt": {"nullValue": None},
            "preNotificationDays": {"integerValue": "14"},
            "notes": {"stringValue": "Signé par le client (vérification e2e)."},
        }}
        st, res = req(f"{FS}/sepa_mandates/{mid}", "PATCH", mand_doc, token=token)
        created["mands"].append(mid)
        say("8. le client SIGNE son mandat SEPA (dates en timestamp)", st == 200,
            f"HTTP {st} {str(res)[:180]}")

        mid2 = "mand_e2e_other_" + stamp
        bad3 = json.loads(json.dumps(mand_doc))
        bad3["fields"]["id"] = {"stringValue": mid2}
        bad3["fields"]["clientId"] = {"stringValue": "autre-dossier"}
        st, _ = req(f"{FS}/sepa_mandates/{mid2}", "PATCH", bad3, token=token)
        created["mands"].append(mid2)
        say("9. mandat sur le dossier d'autrui -> REFUSÉ", st == 403,
            f"HTTP {st} (attendu 403)")

        # ── 7. Persistance et cloisonnement ──────────────────────────────
        st, res = req(f"{FS}/subscriptions/{sub_id}", token=token)
        got = res.get("fields", {}).get("status", {}).get("stringValue")
        say("10. le client RELIT sa demande (persistance)",
            st == 200 and got == "requested", f"HTTP {st} status={got}")

        st, res = req(f"{FS}/subscriptions?pageSize=100", token=token)
        say("11. lecture de collection refusée (cloisonnement)", st == 403,
            f"HTTP {st} (attendu 403, docs={len(res.get('documents', []))})")

        # ── 8. L'AUTRE CÔTÉ DU CIRCUIT : DÉCISION ET ACTIVATION ──────────
        # Jusqu'ici seule la moitié « client » était prouvée. Si la finance ne
        # pouvait pas décider ni activer, le circuit serait bloqué au milieu :
        # le client aurait déposé une demande que personne ne pourrait traiter.
        fin_email = f"e2e.finance.{stamp}@example.invalid"
        fin_user = fb_auth.create_user(
            email=fin_email, password=password, email_verified=True)
        created["finance_uid"] = fin_user.uid
        db.collection("user_profiles").document(fin_user.uid).set({
            "uid": fin_user.uid, "email": fin_email, "role": "finance",
            "clientId": "",
        })
        fin_staff_id = "e2efin" + stamp
        db.collection("staff").document(fin_staff_id).set({
            "id": fin_staff_id, "uid": fin_user.uid, "email": fin_email,
            "fullName": "Finance E2E", "role": "finance", "active": True,
        })
        created["finance_staff"] = fin_staff_id

        st, res = req(f"{IDENT}:signInWithPassword?key={api_key}", "POST",
                      {"email": fin_email, "password": password,
                       "returnSecureToken": True})
        fin_token = res.get("idToken")
        say("12. connexion du compte finance", st == 200 and bool(fin_token),
            f"HTTP {st} {res.get('error', {}).get('message', '')}")

        if fin_token:
            # Décision : acceptation. `updateMask` limite l'écriture aux seuls
            # champs modifiés, comme le fait l'application.
            st, res = req(
                f"{FS}/subscriptions/{sub_id}"
                "?updateMask.fieldPaths=status&updateMask.fieldPaths=decidedBy"
                "&updateMask.fieldPaths=decidedAt",
                "PATCH",
                {"fields": {
                    "status": {"stringValue": "approved"},
                    "decidedBy": {"stringValue": fin_email},
                    "decidedAt": {"timestampValue": now},
                }}, token=fin_token)
            say("13. la finance ACCEPTE la demande", st == 200,
                f"HTTP {st} {str(res)[:180]}")

            st, res = req(
                f"{FS}/subscriptions/{sub_id}"
                "?updateMask.fieldPaths=status&updateMask.fieldPaths=activatedAt",
                "PATCH",
                {"fields": {
                    "status": {"stringValue": "active"},
                    "activatedAt": {"timestampValue": now},
                }}, token=fin_token)
            say("14. la finance ACTIVE l'abonnement", st == 200,
                f"HTTP {st} {str(res)[:180]}")

            # Relecture par le CLIENT : il doit voir son contrat actif.
            st, res = req(f"{FS}/subscriptions/{sub_id}", token=token)
            got = res.get("fields", {}).get("status", {}).get("stringValue")
            say("15. le client VOIT son contrat actif", st == 200 and got == "active",
                f"HTTP {st} status={got}")

            # Et il ne peut toujours pas le modifier lui-même.
            st, _ = req(
                f"{FS}/subscriptions/{sub_id}?updateMask.fieldPaths=status",
                "PATCH", {"fields": {"status": {"stringValue": "ended"}}},
                token=token)
            say("16. le client ne peut pas CLORE son contrat lui-même", st == 403,
                f"HTTP {st} (attendu 403)")

            # Un client ne doit pas pouvoir décider à la place de la finance.
            st, _ = req(
                f"{FS}/user_profiles/{fin_user.uid}", token=token)
            say("17. le client ne lit pas le profil de la finance", st == 403,
                f"HTTP {st} (attendu 403)")

    finally:
        # ── Nettoyage intégral ───────────────────────────────────────────
        print()
        for s in created["subs"]:
            try:
                db.collection("subscriptions").document(s).delete()
            except Exception:
                pass
        for m in created["mands"]:
            try:
                db.collection("sepa_mandates").document(m).delete()
            except Exception:
                pass
        if created["finance_staff"]:
            try:
                db.collection("staff").document(created["finance_staff"]).delete()
            except Exception:
                pass
        if created["finance_uid"]:
            try:
                db.collection("user_profiles").document(created["finance_uid"]).delete()
            except Exception:
                pass
            try:
                fb_auth.delete_user(created["finance_uid"])
            except Exception:
                pass
        if created["profile"]:
            try:
                db.collection("user_profiles").document(created["profile"]).delete()
            except Exception:
                pass
        if created["client"]:
            try:
                db.collection("clients").document(created["client"]).delete()
            except Exception:
                pass
        if created["uid"]:
            try:
                fb_auth.delete_user(created["uid"])
            except Exception:
                pass

        after = counts()
        print("État APRÈS :", after)
        say("18. aucune donnée de test ne subsiste", after == before,
            f"avant={before} après={after}")

    print()
    print(f"{ok_count}/{ok_count + ko_count} vérifications réussies")
    return 0 if ko_count == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
