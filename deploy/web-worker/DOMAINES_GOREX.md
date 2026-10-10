# 🌐 Domaines — État & marche à suivre

> ✅ **DÉCISION (09/10/2026)** : le domaine retenu est
> **`gorex-luxury-concierge.eu`** (et/ou `.com`) — **les deux sont disponibles**.
> 👉 **Marche à suivre complète** :
> [`GUIDE_DOMAINE_LUXURY_CONCIERGE.md`](GUIDE_DOMAINE_LUXURY_CONCIERGE.md).

---

# 🌐 (Annexe) Domaines gorex.be / gorex.com — Diagnostic initial

> **Contexte** : pour attacher `concierge.gorex.be` au Worker Cloudflare
> `gorex-luxury-concierge`, le domaine **`gorex.be` doit d'abord exister** et
> être **géré par Cloudflare** (zone ajoutée au compte).
>
> ❌ **Problème rencontré** : le message Cloudflare
> *« Aucune zone ne correspond à concierge.gorex.be »* apparaît car
> **le domaine `gorex.be` n'est pas encore enregistré**.

---

## 1. Diagnostic (vérifié le 09/10/2026)

| Domaine | État DNS | Détail |
|---|---|---|
| **`gorex.be`** | ❌ **NON ENREGISTRÉ** | Réponse DNS Belgium : `AVAILABLE` (disponible à l'achat) |
| **`gorex.com`** | ⚠️ Enregistré, mais **pas par Gorex Group** | Nameservers `ns1.atom.com` / `ns2.atom.com` → place de marché de domaines (domaine mis en vente/parké) |

**Conséquence** : on ne peut **pas** ajouter `concierge.gorex.be` (ni
`concierge.gorex.com`) à Cloudflare tant que le domaine racine n'est pas
**possédé** puis **ajouté** à Cloudflare.

> ✅ **Bonne nouvelle** : `gorex.be` est **disponible** — il peut être
> enregistré dès maintenant pour ~10–15 €/an.

---

## 2. Marche à suivre pour activer `concierge.gorex.be`

### Étape 1 — Enregistrer le domaine `gorex.be`
Chez un bureau d'enregistrement (registrar) accrédité **.be** (DNS Belgium) :

| Registrar | Remarque |
|---|---|
| **Combell** | 🇧🇪 Belge, support FR/NL — recommandé |
| **OVHcloud** | 🇧🇪/🇫🇷, tarifs compétitifs |
| **Gandi** | Interface simple, FR |
| **Namecheap / Porkbun** | International, support .be |

- Coût : ~10–15 €/an
- Durée d'activation : immédiate (minutes)
- Aucune condition de résidence requise pour le .be

### Étape 2 — Ajouter `gorex.be` à Cloudflare (gratuit)
1. Tableau de bord Cloudflare → **Ajouter un site** (*Add a site*)
2. Saisir `gorex.be` → choisir le plan **Free**
3. Cloudflare affiche **2 nameservers** (ex. `xxx.ns.cloudflare.com`)

### Étape 3 — Pointer les nameservers chez le registrar
Chez votre registrar (Combell/OVH/Gandi…), remplacez les nameservers par ceux
fournis par Cloudflare.

| Type | Valeur |
|---|---|
| Nameserver 1 | `xxx.ns.cloudflare.com` (fourni par Cloudflare) |
| Nameserver 2 | `yyy.ns.cloudflare.com` (fourni par Cloudflare) |

- Délai de propagation : **quelques minutes à quelques heures** (max 24 h)
- Cloudflare envoie un e-mail quand la zone est **Active**

### Étape 4 — Attacher `concierge.gorex.be` au Worker
Une fois la zone **Active** :
1. **Workers & Pages** → `gorex-luxury-concierge` → onglet **Domaines**
2. **Ajouter** → **Domaine personnalisé** → saisir `concierge.gorex.be`
3. ✅ Cloudflare crée le **CNAME** + le **certificat HTTPS** automatiquement
   (statut **Active** en < 1 minute)

### Étape 5 — Vérifier
```bash
curl -sI https://concierge.gorex.be/ | grep -iE "strict-transport|content-security"
for p in "" download privacy.html legal.html terms.html cookies.html about.html; do
  curl -s -o /dev/null -w "$p -> %{http_code}\n" "https://concierge.gorex.be/$p"
done
```

---

## 3. Options intermédiaires (en attendant)

| Option | URL | Remarque |
|---|---|---|
| **A. Utiliser l'URL actuelle** | `https://gorex-luxury-concierge.<compte>.workers.dev` | ✅ Fonctionne **maintenant**, aucune action requise |
| **B. Domaine alternatif possédé** | `concierge.<votre-domaine>` | Si Gorex Group possède un autre domaine, l'ajouter à Cloudflare |
| **C. Racheter `gorex.com`** | `concierge.gorex.com` | ⚠️ `gorex.com` semble mis en vente par un tiers (coût élevé) |

> 💡 **Recommandation** : enregistrer `gorex.be` (disponible, faible coût) →
> c'est l'option la plus propre et la moins chère pour une entreprise belge.

---

## 4. Rappel — le site est déjà en ligne

| Élément | Valeur |
|---|---|
| Worker | `gorex-luxury-concierge` |
| URL actuelle | `https://gorex-luxury-concierge.smoggy-shock.workers.dev` |
| Statut | ✅ en ligne (pages 200, en-têtes de sécurité actifs) |

Le domaine personnalisé est **cosmétique** : il rend l'URL plus professionnelle,
mais le site fonctionne déjà parfaitement sans lui.

---

*Document préparé pour Gorex Group — GOREX LUXURY CONCIERGE v1.0.0*
