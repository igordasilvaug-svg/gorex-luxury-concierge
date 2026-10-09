#!/usr/bin/env python3
"""
GOREX LUXURY CONCIERGE — Initialisation du backend Firestore.

Ce script est PRÊT À L'EMPLOI : il ne s'exécute utilement qu'une fois les
clés Firebase fournies. Il :

  1. localise la clé Admin SDK (firebase-admin-sdk.json) ;
  2. initialise firebase_admin ;
  3. détecte si une base Firestore existe déjà ;
  4. crée les collections du schéma GOREX avec 10 enregistrements réalistes ;
  5. affiche la synthèse et les règles de sécurité recommandées.

Usage :
    pip install firebase-admin==7.1.0
    python3 create_backend_services.py
    python3 create_backend_services.py --dry-run   # simulation, sans écriture
"""

import argparse
import glob
import os
import sys
from datetime import datetime, timedelta, timezone

CANDIDATE_KEYS = [
    "/opt/flutter/firebase-admin-sdk.json",
    "/opt/flutter/*adminsdk*.json",
    "/opt/flutter/*admin-sdk*.json",
    "./firebase-admin-sdk.json",
    "./serviceAccountKey.json",
]


def find_admin_key():
    for pattern in CANDIDATE_KEYS:
        for path in sorted(glob.glob(pattern)):
            if os.path.isfile(path):
                return path
    return None


def now():
    return datetime.now(timezone.utc)


def build_dataset():
    """Retourne {collection: [documents]} — 10 enregistrements par collection."""
    ts = now()
    first_names = [
        "Dimitri", "Isabelle", "Marc", "Sofia", "Alexandre",
        "Nadia", "Julien", "Camille", "Rachid", "Elena",
    ]
    last_names = [
        "Kalashov", "Vermeulen", "Dubois", "Rossi", "De Vries",
        "Peeters", "Lambert", "Moreau", "Benali", "Novak",
    ]
    cities = [
        "Bruxelles", "Anvers", "Gand", "Liège", "Namur",
        "Charleroi", "Bruges", "Louvain", "Mons", "Ostende",
    ]

    clients = []
    for i in range(10):
        clients.append({
            "id": f"cli_{i+1:03d}",
            "name": f"{first_names[i]} {last_names[i]}",
            "email": f"{first_names[i].lower()}.{last_names[i].lower().replace(' ', '')}@example.be",
            "phone": f"+32 4{70 + i} {10 + i:02d} {20 + i:02d} {30 + i:02d}",
            "city": cities[i],
            "tier": ["PRIVATE", "ELITE", "CORPORATE"][i % 3],
            "vat_number": f"BE0{100 + i}.{200 + i}.{300 + i}",
            "active": True,
            "is_business": i % 3 == 0,
            "created_at": ts - timedelta(days=30 * (i + 1)),
        })

    domains = ["concierge", "executive", "travel", "lifestyle", "security"]
    urgencies = ["standard", "prioritaire", "urgent", "critique"]
    statuses = ["nouveau", "en_revue", "en_cours", "en_attente", "confirme", "termine"]
    requests = []
    for i in range(10):
        requests.append({
            "id": f"req_{i+1:03d}",
            "reference": f"GRX-REQ-2025-{i+1:04d}",
            "client_id": clients[i]["id"],
            "client_name": clients[i]["name"],
            "domain": domains[i % len(domains)],
            "sub_service": "Réservation sur mesure",
            "title": f"Prestation {domains[i % len(domains)]} — {cities[i]}",
            "description": "Demande de prestation haut de gamme, traitement confidentiel.",
            "urgency": urgencies[i % len(urgencies)],
            "status": statuses[i % len(statuses)],
            "budget": 1500.0 + i * 850.0,
            "location": cities[i],
            "responsible_name": f"{first_names[(i+3) % 10]} {last_names[(i+3) % 10]}",
            "created_at": ts - timedelta(days=7 * (i + 1)),
        })

    provider_names = [
        "Hôtel Ritz Bruxelles", "Jet Privé Benelux", "Chauffeurs Deluxe",
        "Traiteur Royal", "Sécurité Elite Group", "Spa Thermal Anvers",
        "Galeries Privées", "Conciergerie Littoral", "Vignobles & Cie",
        "Atelier Horlogerie",
    ]
    categories = ["hôtellerie", "transport", "sécurité", "gastronomie", "bien-être"]
    providers = []
    for i in range(10):
        providers.append({
            "id": f"pro_{i+1:03d}",
            "name": provider_names[i],
            "category": categories[i % len(categories)],
            "contact_email": f"contact@{provider_names[i].lower().replace(' ', '').replace('é', 'e')[:12]}.be",
            "phone": f"+32 2 {500 + i} {10 + i:02d} {20 + i:02d}",
            "city": cities[i],
            "rating": round(4.0 + (i % 10) * 0.1, 1),
            "active": True,
            "created_at": ts - timedelta(days=45 * (i + 1)),
        })

    bookings = []
    for i in range(10):
        amount = 1200.0 + i * 600.0
        bookings.append({
            "id": f"bok_{i+1:03d}",
            "reference": f"GRX-BOK-2025-{i+1:04d}",
            "request_id": requests[i]["id"],
            "provider_id": providers[i]["id"],
            "provider_name": providers[i]["name"],
            "client_name": clients[i]["name"],
            "date": ts + timedelta(days=5 * (i + 1)),
            "amount": amount,
            "commission": round(amount * 0.15, 2),
            "status": statuses[i % len(statuses)],
            "created_at": ts - timedelta(days=3 * (i + 1)),
        })

    itineraries = []
    for i in range(10):
        itineraries.append({
            "id": f"iti_{i+1:03d}",
            "reference": f"GRX-ITI-2025-{i+1:04d}",
            "client_id": clients[i]["id"],
            "client_name": clients[i]["name"],
            "title": f"Voyage {cities[i]} → Genève",
            "steps": [
                {"order": 1, "label": "Départ Bruxelles", "city": "Bruxelles"},
                {"order": 2, "label": "Vol privé", "city": "Genève"},
                {"order": 3, "label": "Hôtel 5★", "city": "Genève"},
            ],
            "start_date": ts + timedelta(days=10 * (i + 1)),
            "status": statuses[i % len(statuses)],
            "created_at": ts - timedelta(days=2 * (i + 1)),
        })

    finance_docs = []
    for i in range(10):
        ht = 1000.0 + i * 500.0
        tax = round(ht * 0.21, 2)
        finance_docs.append({
            "id": f"fin_{i+1:03d}",
            "reference": f"GRX-INV-2025-{i+1:04d}",
            "type": "invoice",
            "client_id": clients[i]["id"],
            "client_name": clients[i]["name"],
            "date": ts - timedelta(days=15 * (i + 1)),
            "due_date": ts + timedelta(days=15),
            "subtotal": ht,
            "tax_percent": 21.0,
            "tax_amount": tax,
            "total": round(ht + tax, 2),
            "amount_paid": 0.0,
            "status": ["draft", "sent", "paid", "overdue"][i % 4],
            "peppol_status": ["not_applicable", "pending", "delivered"][i % 3],
        })

    expenses = []
    for i in range(10):
        expenses.append({
            "id": f"exp_{i+1:03d}",
            "label": f"Frais {categories[i % len(categories)]}",
            "category": categories[i % len(categories)],
            "amount": 150.0 + i * 120.0,
            "date": ts - timedelta(days=5 * (i + 1)),
        })

    conversations = []
    for i in range(10):
        conversations.append({
            "id": f"cnv_{i+1:03d}",
            "client_id": clients[i]["id"],
            "client_name": clients[i]["name"],
            "subject": f"Suivi prestation {i+1}",
            "messages": [
                {"from": clients[i]["name"], "text": "Bonjour, où en est ma demande ?", "at": ts - timedelta(hours=5)},
                {"from": "Concierge", "text": "Bonjour, votre demande est en cours de traitement.", "at": ts - timedelta(hours=3)},
            ],
            "last_message_at": ts - timedelta(hours=3),
        })

    appointments = []
    for i in range(10):
        appointments.append({
            "id": f"apt_{i+1:03d}",
            "owner_id": f"usr_{i+1:03d}",
            "title": f"Rendez-vous client — {clients[i]['name']}",
            "start": ts + timedelta(days=i + 1, hours=10),
            "end": ts + timedelta(days=i + 1, hours=11),
            "location": cities[i],
            "created_at": ts - timedelta(days=i + 1),
        })

    users = []
    for i in range(10):
        users.append({
            "id": f"usr_{i+1:03d}",
            "full_name": f"{first_names[i]} {last_names[i]}",
            "email": f"user{i+1}@gorex.com",
            "role": ["ceo", "concierge_manager", "concierge", "travel_manager", "security", "finance"][i % 6],
            "active": True,
            "last_login": ts - timedelta(days=i),
        })

    audit_log = []
    actions = ["Connexion", "Création demande", "Changement statut", "Peppol distribué",
               "Rapprochement auto", "Escalade sécurité", "Mise à jour client"]
    for i in range(10):
        audit_log.append({
            "id": f"aud_{i+1:03d}",
            "timestamp": ts - timedelta(hours=i * 6),
            "actor": f"{first_names[i]} {last_names[i]}",
            "actor_role": users[i]["role"],
            "action": actions[i % len(actions)],
            "target": clients[i]["name"],
            "detail": "Action enregistrée automatiquement.",
        })

    return {
        "clients": clients,
        "requests": requests,
        "providers": providers,
        "bookings": bookings,
        "itineraries": itineraries,
        "finance_docs": finance_docs,
        "expenses": expenses,
        "conversations": conversations,
        "appointments": appointments,
        "users": users,
        "audit_log": audit_log,
    }


def main():
    parser = argparse.ArgumentParser(description="Init backend Firestore GOREX")
    parser.add_argument("--dry-run", action="store_true", help="Simulation sans écriture")
    args = parser.parse_args()

    print("=" * 64)
    print("  GOREX LUXURY CONCIERGE — Initialisation backend Firestore")
    print("=" * 64)

    key_path = find_admin_key()
    if not key_path:
        print("\n❌ Aucune clé Admin SDK trouvée.")
        print("   Fichiers attendus dans /opt/flutter/ :")
        print("     - firebase-admin-sdk.json  (ou *adminsdk*.json)")
        print("\n📖 Voir deploy/firebase/FIREBASE_SETUP.md pour la marche à suivre.")
        sys.exit(1)

    print(f"\n✅ Clé Admin SDK : {key_path}")

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError:
        print("\n❌ firebase-admin non installé.")
        print("   → pip install firebase-admin==7.1.0")
        sys.exit(1)

    cred = credentials.Certificate(key_path)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ firebase_admin initialisé")

    # Détection de la base (nom de sonde valide, non réservé)
    try:
        db.collection("gorex_probe").limit(1).get()
        print("✅ Base Firestore accessible")
    except Exception as e:  # noqa: BLE001
        print(f"\n❌ Firestore inaccessible : {e}")
        print("   → Créez d'abord la base dans la console Firebase :")
        print("     Build → Firestore Database → Créer une base de données")
        sys.exit(1)

    dataset = build_dataset()
    print(f"\n📦 Schéma : {len(dataset)} collections")

    for name, docs in dataset.items():
        print(f"\n→ {name} ({len(docs)} documents)")
        if args.dry_run:
            print("   [dry-run] ignoré")
            continue
        for doc in docs:
            db.collection(name).document(doc["id"]).set(doc)
        print("   ✅ écrit")

    print("\n" + "=" * 64)
    if args.dry_run:
        print("  SIMULATION terminée (aucune écriture).")
    else:
        print("  ✅ Backend initialisé avec succès.")
    print("=" * 64)
    print("\nRègles de sécurité recommandées (console Firestore → Règles) :")
    print("""
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
""")


if __name__ == "__main__":
    main()
