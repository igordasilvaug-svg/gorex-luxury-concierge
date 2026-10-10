# 🌐 Héberger GOREX LUXURY CONCIERGE sur `gorex-luxury-concierge.eu` / `.com`

> **Registrar retenu : COM BELL 🇧🇪** — guide pas à pas, clic par clic.
>
> **Objectif** : acheter le domaine chez Combell, l'ajouter à Cloudflare, puis
> l'attacher au Worker `gorex-luxury-concierge` — pour que le site soit
> accessible sur **`https://gorex-luxury-concierge.eu`** (ou `.com`).
>
> ✅ **Disponibilité vérifiée le 09/10/2026** : les deux domaines sont **LIBRES**.

---

## 0. Disponibilité & tarifs Combell (vérifiés)

| Domaine | État | Prix d'enregistrement (Combell) |
|---|---|---|
| **`gorex-luxury-concierge.eu`** | ✅ **DISPONIBLE** | **9,99 €/an** (promo, au lieu de 46,99 €) |
| **`gorex-luxury-concierge.com`** | ✅ **DISPONIBLE** | ~12–15 €/an |
| `gorex-luxury-concierge.be` | ✅ Disponible | 9,99 €/an |
| `gorexconcierge.eu` | ✅ Disponible | 9,99 €/an |

> 💡 **Conseil** : prenez le **`.eu`** (9,99 €/an) et le **`.com`** si le budget
> le permet — cela protège votre marque et couvre l'Europe **et** le monde.
> **Inclus gratuitement chez Combell** : e-mail, redirection, sous-domaines
> illimités, assistance 24/7 en français.

---

## 1. Acheter le domaine chez Combell (Étape 1)

### 1.1 — Créer un compte Combell
1. Aller sur **https://www.combell.com/fr/noms-de-domaine**
2. Cliquer sur **« Se connecter »** (en haut à droite) → **« Créer un compte »**
3. Renseigner :
   - Nom / Société : **Gorex Group**
   - E-mail : **concierge@gorex.com**
   - Adresse : (adresse de la société en Belgique)
   - Mot de passe
4. Valider (un e-mail de confirmation peut être envoyé)

### 1.2 — Rechercher et commander le domaine
1. Dans le champ de recherche, taper : **`gorex-luxury-concierge.eu`**
2. Cliquer sur **« Rechercher »** → le domaine apparaît **disponible**
3. Cliquer sur **« Ajouter au panier »** (ajouter aussi le `.com` si souhaité)
4. Cliquer sur **« Commander »**
5. Choisir la durée (1 an minimum) → **passer à la caisse**
6. Renseigner les données du **propriétaire** (titulaire) :
   - Type : **Société** → Nom : **Gorex Group**
   - E-mail : **concierge@gorex.com**
7. Payer (carte bancaire / Bancontact / virement)
8. ✅ Le domaine est **à vous immédiatement**

> ℹ️ **Parking gratuit** : tant que le domaine n'est pas relié à un site,
> Combell affiche une page d'attente — c'est normal.

> ⚠️ **Ne configurez PAS encore le DNS chez Combell** : l'étape suivante
> (Cloudflare) va vous donner les **nameservers** à utiliser.

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

## 3. Pointer les nameservers chez Combell (Étape 3)

### 3.1 — Se connecter au panneau de contrôle Combell
1. Aller sur **https://my.combell.com/fr** et se connecter

### 3.2 — Modifier les nameservers (procédure officielle Combell)
1. Menu **« Mes produits »** → **« Noms de domaine »**
2. Cliquer sur **`gorex-luxury-concierge.eu`** → **« Gérer le nom de domaine »**
3. Dans le menu de gauche, cliquer sur **« Nameservers »** (Serveurs de noms)
4. Sélectionner **« Autres serveurs de noms »** (*Other name servers*)
5. Saisir les **2 nameservers fournis par Cloudflare**, par exemple :
   ```
   aria.ns.cloudflare.com
   dan.ns.cloudflare.com
   ```
   *(⚠️ utilisez les VÔTRES, affichés par Cloudflare à l'étape 2)*
6. Cliquer sur **« Enregistrer les serveurs de noms »** (*Save name servers*)

> ⏱️ **Délai** : Combell indique **jusqu'à 36 h** pour l'activation complète
> (en pratique, souvent 15 min à 2 h). Cloudflare envoie un **e-mail** quand la
> zone passe **Active**.

> ⚠️ **Attention Combell** : modifier les nameservers **désactive** la gestion DNS
> interne de Combell — c'est **exactement** ce qu'on veut (c'est Cloudflare qui
> gérera le DNS). Vous pourrez revenir en arrière à tout moment.

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
| 1 | Acheter `gorex-luxury-concierge.eu` chez **Combell** (+ `.com`) | 5 min | 9,99 €/an |
| 2 | Ajouter le domaine à Cloudflare | 2 min | Gratuit |
| 3 | Pointer les nameservers **chez Combell** | 5 min + propagation | Gratuit |
| 4 | Attacher le domaine au Worker | 1 min | Gratuit |
| 5 | Vérifier | 1 min | Gratuit |

**Total : ~15 minutes d'action → site pro sur votre propre domaine.** 🎉

---

## 9bis. Dépannage Combell

| Problème | Solution |
|---|---|
| **Le domaine affiche une page d'attente** | Normal : « parking » Combell tant que le site n'est pas relié |
| **La zone Cloudflare reste « En attente »** | Vérifier que les 2 nameservers sont bien **exacts** (sans faute de frappe) chez Combell → patience jusqu'à 36 h |
| **Je ne trouve pas « Nameservers »** | Mes produits → Noms de domaine → *Gérer le nom de domaine* → menu gauche « Nameservers » |
| **J'ai perdu la gestion DNS Combell** | Normal après changement de nameservers — c'est Cloudflare qui gère désormais |
| **Besoin d'aide Combell** | Support gratuit **24/7** : **0800-8-5678** ou chat sur combell.com |
| **Le domaine est en « premium »** | Choisir une variante (ex. `gorexconcierge.eu`) — vérifier le prix affiché |

---

## 9ter. Aide-mémoire — liens Combell

| Ressource | Lien |
|---|---|
| Rechercher / acheter un domaine | https://www.combell.com/fr/noms-de-domaine |
| Page .eu dédiée | https://www.combell.com/fr/noms-de-domaine/eu-enregistrement-nom-de-domaine |
| Panneau de contrôle (connexion) | https://my.combell.com/fr |
| Modifier les nameservers (aide) | https://www.combell.com/en/help/kb/how-can-i-update-the-name-servers-of-a-domain/ |
| Support gratuit 24/7 | **0800-8-5678** |

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
