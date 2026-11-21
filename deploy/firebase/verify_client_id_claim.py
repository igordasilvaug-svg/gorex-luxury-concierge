#!/usr/bin/env python3
"""Verifie EN PRODUCTION la fermeture de la faille `clientId`.

FAILLE : la creation de `user_profiles/{uid}` exigeait seulement que `clientId`
soit une chaine. Un compte fraichement cree pouvait donc se rattacher au
dossier d'un AUTRE client, puis lire ses contrats, mandats SEPA et demandes.

Ce script prouve les deux cotes en production, avec de vrais comptes :
  - l'attaque est REFUSEE (403) ;
  - l'inscription LEGITIME fonctionne toujours (200), y compris avec
    email_verified = false (l'etat reel d'un compte qui vient de s'inscrire).

Il nettoie tout a la fin.
"""
import json, re, sys, time, urllib.error, urllib.request
from firebase_admin import auth as fb_auth, initialize_app, credentials as fb_creds, firestore

ROOT = "/home/user/flutter_app"
KEY_SRC = f"{ROOT}/lib/core/firebase/firebase_options.dart"
ADMIN = "/opt/flutter/firebase-admin-sdk.json"
PROJECT = "gorex-concierge"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
IDENT = "https://identitytoolkit.googleapis.com/v1/accounts"

ok = ko = 0
def say(label, success, detail=""):
    global ok, ko
    ok, ko = (ok + 1, ko) if success else (ok, ko + 1)
    print(f"{'PASS' if success else 'FAIL'}  {label}" + (f"  -> {detail}" if not success else ""))

def api_key():
    src = open(KEY_SRC, encoding="utf-8").read()
    block = re.search(r"FirebaseOptions web = FirebaseOptions\((.*?)\);", src, re.S).group(1)
    k = re.search(r"apiKey:\s*'([^']+)'", block).group(1)
    assert re.fullmatch(r"AIza[0-9A-Za-z_-]{35}", k), "cle API de forme inattendue"
    return k

def req(url, method="GET", body=None, token=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Content-Type", "application/json")
    if token: r.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(r) as x: return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")

KEY = api_key()
try: initialize_app(fb_creds.Certificate(ADMIN), {"projectId": PROJECT})
except ValueError: pass
db = firestore.client()

stamp = time.strftime("%H%M%S")
victim_email = f"sib.verite.{stamp}@example.invalid"
attacker_email = f"sib.attaque.{stamp}@example.invalid"
own_email = f"sib.propre.{stamp}@example.invalid"
pw = f"Grx-Sib-{stamp}!test1"
victim_id = "victim" + stamp
own_id = "own" + stamp
created = []

try:
    # Dossier d'une VICTIME (approuve : c'est le plus interessant a voler).
    db.collection("clients").document(victim_id).set({
        "id": victim_id, "code": "GRX-SIB-" + stamp, "fullName": "Client Victime",
        "email": victim_email, "phone": "+3247000009", "language": "fr",
        "approvalStatus": "approved", "active": True,
    })
    created.append(("clients", victim_id))

    # Compte ATTAQUANT.
    att = fb_auth.create_user(email=attacker_email, password=pw, email_verified=True)
    created.append(("auth", att.uid))

    # Compte LEGITIME + son propre dossier (meme e-mail).
    legit = fb_auth.create_user(email=own_email, password=pw, email_verified=True)
    created.append(("auth", legit.uid))
    db.collection("clients").document(own_id).set({
        "id": own_id, "code": "GRX-SIBP-" + stamp, "fullName": "Client Propre",
        "email": own_email, "phone": "+3247000010", "language": "fr",
        "approvalStatus": "pending", "active": True,
    })
    created.append(("clients", own_id))

    st, res = req(f"{IDENT}:signInWithPassword?key={KEY}", "POST",
                  {"email": attacker_email, "password": pw, "returnSecureToken": True})
    att_token = res.get("idToken")
    say("1. connexion de l'attaquant", st == 200 and bool(att_token), f"HTTP {st}")

    st, res = req(f"{IDENT}:signInWithPassword?key={KEY}", "POST",
                  {"email": own_email, "password": pw, "returnSecureToken": True})
    own_token = res.get("idToken")
    say("2. connexion du titulaire legitime", st == 200 and bool(own_token), f"HTTP {st}")

    # ATTAQUE : se rattacher au dossier de la victime.
    st, res = req(f"{FS}/user_profiles/{att.uid}", "PATCH", {"fields": {
        "uid": {"stringValue": att.uid},
        "email": {"stringValue": attacker_email},
        "role": {"stringValue": "vipClient"},
        "clientId": {"stringValue": victim_id},
    }}, token=att_token)
    say("3. ATTAQUE : se rattacher au dossier d'autrui -> REFUSEE", st == 403, f"HTTP {st}")

    # Verification : le profil ne doit PAS avoir ete cree.
    st2, _ = req(f"{FS}/user_profiles/{att.uid}", token=att_token)
    say("4. aucun profil d'attaque n'a ete cree", st2 == 404 or st2 == 403, f"HTTP {st2}")

    # INSCRIPTION LEGITIME : son propre dossier.
    st, res = req(f"{FS}/user_profiles/{legit.uid}", "PATCH", {"fields": {
        "uid": {"stringValue": legit.uid},
        "email": {"stringValue": own_email},
        "role": {"stringValue": "vipClient"},
        "clientId": {"stringValue": own_id},
    }}, token=own_token)
    say("5. INSCRIPTION LEGITIME (son propre dossier) -> AUTORISEE", st == 200, f"HTTP {st}")
    created.append(("user_profiles", legit.uid))

    # L'inscription reelle se fait avec email_verified = false.
    fb_auth.update_user(legit.uid, email_verified=False)
    legit2 = fb_auth.create_user(email=f"sib.nvx.{stamp}@example.invalid", password=pw,
                                 email_verified=False)
    created.append(("auth", legit2.uid))
    nv_id = "nvx" + stamp
    db.collection("clients").document(nv_id).set({
        "id": nv_id, "code": "GRX-SIBN-" + stamp, "fullName": "Nouveau Venu",
        "email": f"sib.nvx.{stamp}@example.invalid", "phone": "+3247000011",
        "language": "fr", "approvalStatus": "pending", "active": True,
    })
    created.append(("clients", nv_id))
    st, res = req(f"{IDENT}:signInWithPassword?key={KEY}", "POST",
                  {"email": f"sib.nvx.{stamp}@example.invalid", "password": pw,
                   "returnSecureToken": True})
    nv_token = res.get("idToken")
    st, res = req(f"{FS}/user_profiles/{legit2.uid}", "PATCH", {"fields": {
        "uid": {"stringValue": legit2.uid},
        "email": {"stringValue": f"sib.nvx.{stamp}@example.invalid"},
        "role": {"stringValue": "vipClient"},
        "clientId": {"stringValue": nv_id},
    }}, token=nv_token)
    say("6. inscription reelle (email_verified=false) -> AUTORISEE", st == 200, f"HTTP {st}")
    if st == 200: created.append(("user_profiles", legit2.uid))

    # Le dossier inexistant est refuse.
    st, res = req(f"{FS}/user_profiles/{legit.uid}", "PATCH", {"fields": {
        "uid": {"stringValue": legit.uid},
        "email": {"stringValue": own_email},
        "role": {"stringValue": "vipClient"},
        "clientId": {"stringValue": "dossier-inexistant-" + stamp},
    }}, token=own_token)
    say("7. dossier inexistant -> REFUSE", st == 403, f"HTTP {st}")

finally:
    for kind, ident in reversed(created):
        try:
            if kind == "auth": fb_auth.delete_user(ident)
            else: db.collection(kind).document(ident).delete()
        except Exception as e:
            print("  nettoyage impossible :", kind, ident, e)
    print("\nEtat final :", {c: len(list(db.collection(c).limit(500).stream()))
          for c in ["clients", "user_profiles", "staff", "subscriptions", "sepa_mandates"]})

print(f"\n{ok}/{ok+ko} verifications reussies.")
sys.exit(0 if ko == 0 else 2)
