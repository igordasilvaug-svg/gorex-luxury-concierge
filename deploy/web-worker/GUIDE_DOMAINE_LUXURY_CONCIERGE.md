# 🌐 Héberger GOREX LUXURY CONCIERGE sur `gorex-luxury-concierge.eu` / `.com`

> **Objectif** : acheter le domaine, l'ajouter à Cloudflare, puis l'attacher au
> Worker `gorex-luxury-concierge` — pour que le site soit accessible sur
> **`https://gorex-luxury-concierge.eu`** (ou `.com`).
>
> ✅ **Disponibilité vérifiée le 09/10/2026** : les deux domaines sont **LIBRES**.

---

## 0. Disponibilité (vérifiée)

| Domaine | État | Recommandation |
|---|---|---|
| **`gorex-luxury-concierge.eu`** | ✅ **DISPONIBLE** | ⭐ **Recommandé** (audience européenne, Belgique) |
| **`gorex-luxury-concierge.com`** | ✅ **DISPONIBLE** | ⭐ Recommandé (portée internationale) |
| `gorex-luxury-concierge.be` | ✅ Disponible | (optionnel, ancrage belge) |
| `gorexconcierge.eu` | ✅ Disponible | (variante plus courte) |
| `gorexconcierge.com` | ✅ Disponible | (variante plus courte) |

> 💡 **Conseil** : prenez le **`.eu`** et le **`.com`** si le budget le permet
> (~12–15 €/an chacun) — cela protège votre marque et couvre l'Europe + le monde.

---

## 1. Enregistrer le domaine (Étape 1)

Choisissez un bureau d'enregistrement (registrar) :

| Registrar | Points forts | Idéal pour |
|---|---|---|
| **Combell** | 🇧🇪 Belge, support FR/NL, très fiable | Entreprise belge |
| **OVHcloud** | 🇪🇺 Européen, tarifs compétitifs | Bon rapport qualité/prix |
| **Gandi** | 🇫🇷 Interface simple, e-mail inclus | Facilité |
| **Namecheap / Porkbun** | 🌍 International, .com à bas prix | .com pas cher |

### Procédure (exemple générique)
1. Aller sur le site du registrar → **Rechercher un nom de domaine**
2. Saisir **`gorex-luxury-concierge.eu`** (et/ou **`.com`**)
3. Ajouter au panier → **Commander**
4. Renseigner les coordonnées du propriétaire :
   - Société : **Gorex Group**
   - E-mail : **concierge@gorex.com**
   - Adresse : (adresse de la société en Belgique)
5. Payer (~12–15 €/an)
6. ✅ Le domaine est à vous **immédiatement**

> ⚠️ **Après l'achat, ne configurez PAS tout de suite le DNS du registrar** :
> l'étape suivante (Cloudflare) va vous donner les nameservers à utiliser.

---

## 2. Ajouter le domaine à Cloudflare (Étape 2 — gratuit)

1. Tableau de bord Cloudflare → bouton **« Ajouter un site »** (*Add a site*)
2. Saisir : `gorex-luxury-concierge.eu`
3. Choisir le plan **Free** (gratuit)
4. Cloudflare scanne le domaine puis affiche **2 nameservers**, par exemple :
   ```
   aria.ns.cloudflare.com
   dan.ns.cloudflare.com
   ```
   *(les vôtres seront différents — notez-les)*

---

## 3. Pointer les nameservers chez le registrar (Étape 3)

Retournez chez votre registrar, dans la section **DNS / Nameservers** du domaine,
et remplacez les nameservers par ceux fournis par Cloudflare :

| Type | Valeur |
|---|---|
| Nameserver 1 | `xxx.ns.cloudflare.com` ← fourni par Cloudflare |
| Nameserver 2 | `yyy.ns.cloudflare.com` ← fourni par Cloudflare |

- **Délai de propagation** : quelques minutes à quelques heures (max 24 h)
- Cloudflare envoie un **e-mail** quand la zone passe **Active**
- Vous pouvez suivre l'état dans le tableau de bord (badge **« En attente » → « Active »**)

---

## 4. Attacher le domaine au Worker (Étape 4)

Une fois la zone **Active** :

1. **Workers & Pages** → `gorex-luxury-concierge`
2. Onglet **Domaines** (*Domains*)
3. **Ajouter** → **Domaine personnalisé** (*Custom domain*)
4. Saisir : `gorex-luxury-concierge.eu`
5. Cliquer **Ajouter le domaine**

✅ Cloudflare crée automatiquement :
- l'enregistrement **CNAME** (DNS)
- le **certificat TLS** (HTTPS)

Statut **Active** en général **< 1 minute**.

> 🔁 Pour le `.com` : répétez l'étape 4 avec `gorex-luxury-concierge.com`
> (après avoir aussi ajouté `gorex-luxury-concierge.com` comme site Cloudflare).

---

## 5. Vérifier (Étape 5)

```bash
# En-têtes de sécurité présents ?
curl -sI https://gorex-luxury-concierge.eu/ | grep -iE "strict-transport|content-security"

# Toutes les pages répondent 200 ?
for p in "" download privacy.html legal.html terms.html cookies.html about.html legal-hub.html; do
  curl -s -o /dev/null -w "$p -> %{http_code}\n" "https://gorex-luxury-concierge.eu/$p"
done
```

**Attendu** : `200` partout + `strict-transport-security` + `content-security-policy`.

---

## 6. Enregistrements DNS (créés automatiquement)

| Type | Nom (host) | Cible | Proxy |
|---|---|---|---|
| CNAME | `@` (racine) | `gorex-luxury-concierge.<compte>.workers.dev` | 🟠 Proxied |
| CNAME | `www` (optionnel) | idem | 🟠 Proxied |

> ⚠️ Le proxy **doit rester orange (Proxied)** : indispensable pour les en-têtes
> de sécurité, le cache et le TLS géré par Cloudflare.

**Sous-domaines utiles (optionnels) :**

| Type | Nom | Usage |
|---|---|---|
| CNAME | `app` | `app.gorex-luxury-concierge.eu` |
| CNAME | `download` | page de téléchargement APK dédiée |

---

## 7. Mettre à jour les références

Après activation, remplacer l'URL `*.workers.dev` par le domaine final dans :

- la **fiche Google Play** (`deploy/play-store/FICHE_GOOGLE_PLAY.md`) —
  politique de confidentialité + site web ;
- le **README** du projet ;
- les **signatures e-mail** et documents commerciaux.

---

## 8. Alternative : attacher via CLI (Wrangler)

Si vous préférez la ligne de commande (compte Cloudflare connecté) :

```bash
# 1) Attacher le domaine au Worker
cd /home/user/gorex_web_worker
npx wrangler@4 domains add gorex-luxury-concierge.eu \
  --service gorex-luxury-concierge

# 2) Ou via une route (zone du même compte) — éditer wrangler.toml :
#    routes = [
#      { pattern = "gorex-luxury-concierge.eu/*", zone_name = "gorex-luxury-concierge.eu" }
#    ]
#    puis : npx wrangler deploy
```

---

## 9. Récapitulatif

| Étape | Action | Durée | Coût |
|---|---|---|---|
| 1 | Acheter `gorex-luxury-concierge.eu` (+ `.com`) | 5 min | ~12–15 €/an |
| 2 | Ajouter le domaine à Cloudflare | 2 min | Gratuit |
| 3 | Pointer les nameservers chez le registrar | 5 min + propagation | Gratuit |
| 4 | Attacher le domaine au Worker | 1 min | Gratuit |
| 5 | Vérifier | 1 min | Gratuit |

**Total : ~15 minutes d'action → site pro sur votre propre domaine.** 🎉

---

## 10. En attendant : le site est DÉJÀ en ligne

| Élément | Valeur |
|---|---|
| Worker | `gorex-luxury-concierge` |
| URL actuelle | `https://gorex-luxury-concierge.smoggy-shock.workers.dev` |
| Statut | ✅ en ligne (toutes les pages 200, HTTPS, en-têtes de sécurité) |

Vous pouvez **déjà publier sur le Play Store** avec l'URL `workers.dev`, puis
basculer vers `gorex-luxury-concierge.eu` une fois le domaine actif.

---

*Guide préparé pour Gorex Group — GOREX LUXURY CONCIERGE v1.0.0*
