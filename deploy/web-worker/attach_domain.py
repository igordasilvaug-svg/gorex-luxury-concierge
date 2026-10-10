#!/usr/bin/env python3
"""
Attache le domaine gorex-luxury-concierge.eu au Worker Cloudflare
`gorex-luxury-concierge`, via l'API Cloudflare.

Utilisation :
    export CLOUDFLARE_API_TOKEN="votre_jeton"
    python3 attach_domain.py

Le jeton doit avoir les permissions :
    - Zone : Zone : Read           (pour retrouver la zone)
    - Compte : Workers Scripts : Edit  (pour attacher le domaine personnalisé)

Le script est idempotent : s'il est relancé, il détecte le domaine déjà attaché.
"""

import json
import os
import sys
import urllib.request
import urllib.error

API = "https://api.cloudflare.com/client/v4"
HOSTNAME = "gorex-luxury-concierge.eu"
WORKER = "gorex-luxury-concierge"
ENVIRONMENT = "production"


def call(method, path, token, body=None):
    url = f"{API}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read().decode())
        except Exception:
            return {"success": False, "errors": [{"message": f"HTTP {e.code}"}]}


def main():
    token = os.environ.get("CLOUDFLARE_API_TOKEN", "").strip()
    if not token:
        print("❌ CLOUDFLARE_API_TOKEN manquant.")
        print("   export CLOUDFLARE_API_TOKEN=\"votre_jeton\"")
        sys.exit(1)

    print("1) Vérification du jeton…")
    v = call("GET", "/user/tokens/verify", token)
    if not v.get("success"):
        print("❌ Jeton invalide :", v.get("errors"))
        sys.exit(1)
    print("   ✅ Jeton valide — statut :", v["result"].get("status"))

    print("2) Recherche du compte…")
    acc = call("GET", "/accounts", token)
    if not acc.get("success") or not acc.get("result"):
        print("❌ Impossible de lister les comptes :", acc.get("errors"))
        sys.exit(1)
    accounts = acc["result"]
    for a in accounts:
        print(f"   • {a['name']}  (id {a['id']})")
    account_id = accounts[0]["id"]
    print(f"   → compte utilisé : {accounts[0]['name']}")

    print(f"3) Recherche de la zone {HOSTNAME}…")
    z = call("GET", f"/zones?name={HOSTNAME}", token)
    if not z.get("success") or not z.get("result"):
        print("❌ Zone introuvable. La zone doit être ajoutée à CE compte Cloudflare.")
        print("   Erreurs :", z.get("errors"))
        sys.exit(1)
    zone = z["result"][0]
    zone_id = zone["id"]
    print(f"   ✅ Zone trouvée : {zone['name']}  (id {zone_id}, statut {zone['status']})")

    print(f"4) Vérification du Worker « {WORKER} »…")
    w = call("GET", f"/accounts/{account_id}/workers/scripts/{WORKER}", token)
    if not w.get("success"):
        print("   ⚠️ Worker non listé (permission ?). On tente quand même l'attachement.")

    print(f"5) Attachement du domaine personnalisé {HOSTNAME}…")
    body = {
        "zone_id": zone_id,
        "hostname": HOSTNAME,
        "service": WORKER,
        "environment": ENVIRONMENT,
    }
    r = call("PUT", f"/accounts/{account_id}/workers/domains", token, body)
    if not r.get("success"):
        errs = r.get("errors", [])
        # Cas déjà attaché
        if any("already" in str(e).lower() for e in errs):
            print("   ℹ️ Le domaine semble déjà attaché.")
        else:
            print("❌ Échec de l'attachement :", errs)
            sys.exit(1)
    else:
        print("   ✅ Domaine attaché !")
        res = r.get("result", {})
        print(f"      id={res.get('id')} | statut={res.get('status')}")

    print("6) Relecture de la liste des domaines du Worker…")
    lst = call("GET", f"/accounts/{account_id}/workers/domains", token)
    if lst.get("success"):
        for d in lst["result"]:
            if d.get("service") == WORKER:
                print(f"   • {d.get('hostname')} → statut {d.get('status')}")

    print("\n✅ Terminé. Le certificat TLS peut prendre 1 à 3 minutes.")
    print(f"   Test : curl -sI https://{HOSTNAME}/")


if __name__ == "__main__":
    main()
