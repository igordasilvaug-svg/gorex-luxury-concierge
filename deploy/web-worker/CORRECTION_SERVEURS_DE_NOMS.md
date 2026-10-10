# 🔴 CORRECTION URGENTE — Serveurs de noms (NS) à corriger chez Combell

**Domaine** : `gorex-luxury-concierge.eu`
**Date du diagnostic** : 2026-10-10
**Statut** : ❌ Zone Cloudflare bloquée en « En attente » — **cause identifiée**

---

## 🎯 Le problème en une phrase

Vous avez saisi chez **Combell** les **mauvais** serveurs de noms :
`aria.ns.cloudflare.com` / `dan.ns.cloudflare.com`

Alors que Cloudflare **vous a attribué** pour ce domaine :
`nucum.ns.cloudflare.com` / `tanner.ns.cloudflare.com`

👉 Résultat : le registre `.eu` envoie le trafic vers des serveurs Cloudflare qui **ne connaissent pas votre domaine** → ils répondent `REFUSED` → la zone ne s'activera **jamais**.

---

## 🔬 Preuve technique (diagnostic DNS réel)

| Vérification | Résultat |
|---|---|
| Résolution `gorex-luxury-concierge.eu` | `Status 2` — **REFUSED / lame delegation** |
| Serveurs qui répondent REFUSED | `108.162.192.68`, `172.64.32.68`, `173.245.59.108`, `173.245.58.68`, `108.162.193.108`, `172.64.33.108` |
| Ces IP correspondent à | **`aria.ns.cloudflare.com`** (108.162.192.68 / 172.64.32.68 / 173.245.58.68) et **`dan.ns.cloudflare.com`** (108.162.193.108 / 172.64.33.108 / 173.245.59.108) |
| IP de `nucum.ns.cloudflare.com` (les BONNES) | `162.159.38.145`, `108.162.194.145`, `172.64.34.145` |
| IP de `tanner.ns.cloudflare.com` (les BONNES) | `108.162.195.97`, `172.64.35.97`, `162.159.44.97` |

➡️ Le registre interroge bien `aria` et `dan` (donc Combell a bien enregistré votre saisie), **mais Cloudflare répond REFUSED** car votre zone n'est pas hébergée sur `aria`/`dan`.

---

## ✅ La solution (5 minutes)

### Étape 1 — Relever les BONS serveurs de noms sur Cloudflare

1. Allez sur **https://dash.cloudflare.com**
2. Cliquez sur votre domaine **`gorex-luxury-concierge.eu`**
3. Menu de gauche → **Vue d'ensemble** (Overview)
4. Cherchez le bloc **« Serveurs de noms Cloudflare »** — vous y verrez les 2 serveurs **exacts** attribués.

**D'après votre capture, ils sont :**

```
nucum.ns.cloudflare.com
tanner.ns.cloudflare.com
```

> ⚠️ Copiez-les **exactement** (au caractère près). Ne recopiez jamais ceux de la doc Cloudflare générique : ils sont **uniques à votre compte + votre domaine**.

### Étape 2 — Corriger chez Combell

1. Allez sur **https://my.combell.com** → **Mes produits** → **Noms de domaine**
2. Cliquez sur **`gorex-luxury-concierge.eu`**
3. Onglet **Serveurs de noms**
4. **Remplacez** la liste actuelle :
   - ❌ Supprimez : `aria.ns.cloudflare.com`
   - ❌ Supprimez : `dan.ns.cloudflare.com`
   - ✅ Ajoutez : `nucum.ns.cloudflare.com`
   - ✅ Ajoutez : `tanner.ns.cloudflare.com`
5. Cliquez sur **Enregistrer les modifications**
6. Attendez la confirmation verte : *« Les modifications apportées aux serveurs de noms ont été prises en compte »*

### Étape 3 — Vérifier dans Cloudflare

1. Retournez sur **Cloudflare** → **Vue d'ensemble** de votre domaine
2. Cliquez sur **« Vérifier les serveurs de noms maintenant »**
3. Sous **1 à 2 h**, la zone doit passer de **« En attente »** à **« Active »** ✅

---

## ⏱️ Délai à prévoir

| Étape | Délai |
|---|---|
| Combell → registre `.eu` (EURid) | 15 min à 2 h |
| Propagation DNS mondiale | jusqu'à 24–36 h (souvent < 2 h) |
| Cloudflare détecte et active la zone | automatique (polling) ou manuel via le bouton |

> 💡 Combell indique « jusqu'à 24 h » mais pour un `.eu` (EURid) c'est en général **beaucoup plus rapide**.

---

## 🔍 Comment vérifier vous-même que c'est propagé

Ouvrez dans votre navigateur :

```
https://dns.google/resolve?name=gorex-luxury-concierge.eu&type=NS
```

- **Avant** : `"Status":2` + `REFUSED` → ❌ pas encore bon
- **Après** : `"Status":0` + `"Answer"` contenant `nucum.ns.cloudflare.com` et `tanner.ns.cloudflare.com` → ✅ c'est bon !

---

## ❌ Erreurs à ne PAS refaire

| ❌ Ne faites pas | Pourquoi |
|---|---|
| Saisir `aria` / `dan` | Ce sont des NS Cloudflare **d'un autre contexte**, ils refusent votre domaine |
| Saisir les NS de la documentation Cloudflare | Chaque zone a ses propres NS, uniques |
| Resaisir plusieurs fois chez Combell | Inutile, ça ne fait que retarder |
| Activer DNSSEC chez Combell | À **désactiver** tant que la zone n'est pas active sur Cloudflare |

---

## 🚀 Et après ? (rappel)

Une fois la zone **Active** :

1. **Cloudflare** → **Workers & Pages** → **`gorex-luxury-concierge`** → onglet **Domaines** (ou *Paramètres → Domaines et itinéraires*)
2. **Ajouter** → **Domaine personnalisé** → `gorex-luxury-concierge.eu`
3. Cloudflare crée automatiquement l'enregistrement DNS + le certificat SSL ✅
4. Testez :
   ```bash
   curl -sI https://gorex-luxury-concierge.eu/
   ```
   → doit renvoyer **HTTP/2 200** + en-têtes de sécurité.

---

*Guide généré automatiquement suite au diagnostic DNS du 2026-10-10.*
