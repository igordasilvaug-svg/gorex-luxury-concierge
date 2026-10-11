# 🧪 Compte de démonstration — Revue Google Play

> À fournir à Google dans **Play Console → Contenu de l'application → Accès à l'application**
> (obligatoire car l'application est à **accès restreint / sur invitation**).
>
> Sans identifiants de test valides, Google **rejette** la publication.

---

## Identifiants à communiquer à Google

| Champ | Valeur |
|---|---|
| **Nom d'utilisateur / E-mail** | `ceo@gorex.com` |
| **Mot de passe** | `gorex2025` |
| **Instructions** | « Ouvrez l'application, saisissez l'e-mail et le mot de passe ci-dessus sur l'écran de connexion, puis appuyez sur *Se connecter*. Le compte donne un accès complet (tableau de bord direction). » |

> Ce compte **existe** dans les données de l'application (rôle *CEO*) et fonctionne
> sur une installation neuve (aucune donnée requise au préalable).

---

## Autres comptes disponibles (facultatif)

Tous partagent le mot de passe **`gorex2025`** :

| E-mail | Rôle |
|---|---|
| `ceo@gorex.com` | CEO (accès complet) — **recommandé pour la revue** |
| `manager@gorex.com` | Luxury Concierge Manager |
| `senior@gorex.com` | Senior Concierge |
| `travel@gorex.com` | Travel Manager |
| `security@gorex.com` | Security Coordinator |
| `finance@gorex.com` | Finance Director |
| `client@gorex.com` | Client VIP (PRIVATE) |
| `eleanor@gorex.com` | Client VIP (ELITE) |

---

## Notes importantes

- **Build production** : dans l'AAB publié, les **boutons de démo** (remplissage rapide)
  sont **masqués** (flag `--dart-define=PRODUCTION=true`). Les identifiants doivent donc
  être **saisis manuellement** — c'est normal et attendu par Google.
- Le mot de passe `gorex2025` peut être **changé** dans l'application après connexion.
- Pour une sécurité renforcée en production réelle, prévoyez de **réinitialiser** ces
  comptes de démonstration après la phase de test (ou de les désactiver).

---

## Rappel — où renseigner dans Play Console

**Play Console → votre app → Contenu de l'application → Accès à l'application** :
- Sélectionnez **« Toutes les fonctionnalités sont restreintes »**
- Ajoutez les **identifiants** (e-mail + mot de passe) + les instructions ci-dessus

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
