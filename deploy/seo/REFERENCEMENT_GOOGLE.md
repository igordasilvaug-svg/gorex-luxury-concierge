# 🔎 Référencement Google — GOREX LUXURY CONCIERGE

Comment faire apparaître **Gorex Luxury Concierge** sur Google, et comment
**garder l'accès** aux statistiques.

---

## 1. Ce qui est déjà en place (fait automatiquement)

| Élément | Fichier | Rôle |
|---|---|---|
| `robots.txt` | `https://gorex-luxury-concierge.eu/robots.txt` | Autorise l'indexation + indique le sitemap |
| `sitemap.xml` | `https://gorex-luxury-concierge.eu/sitemap.xml` | Liste des 7 pages à indexer |
| Balise `canonical` | toutes les pages | Évite le contenu dupliqué |
| Données structurées | `index.html` (JSON-LD `Organization` + `WebSite`) | Google comprend : nom, adresse, contact, services |
| Contenu indexable | `index.html` (`<noscript>`) | Texte visible par les robots (l'app Flutter est un canvas) |
| Open Graph / Twitter | `index.html` | Aperçu propre lors d'un partage (WhatsApp, LinkedIn…) |
| En-têtes de sécurité | Worker Cloudflare | CSP, HSTS (bon signal de qualité) |

> Ces éléments sont **déjà déployés** et vérifiés en ligne.

---

## 2. Le plus important : Google Search Console (votre accès)

C'est **l'outil officiel et gratuit** de Google. Il vous donne :
- la confirmation que Google connaît votre site ;
- les **requêtes** que les gens tapent pour vous trouver ;
- le nombre de clics / impressions ;
- les erreurs éventuelles.

### 2.1 Créer votre accès (5 minutes)

1. Allez sur **https://search.google.com/search-console**
2. Connectez-vous avec **votre compte Google** (celui de Gorex).
3. Cliquez sur **« Ajouter une propriété »**.
4. Choisissez **« Préfixe d'URL »** et collez :
   `https://gorex-luxury-concierge.eu/`
5. Google demande de **vérifier** que le site est bien à vous. **Deux méthodes :**

   **Méthode A — Balise HTML (la plus simple ici)**
   - Google vous affiche une balise du type :
     `<meta name="google-site-verification" content="XXXXXXXX">`
   - **Copiez-la** et envoyez-la-moi : je l'ajoute au site et je redéploie.
   - Puis cliquez sur **« Vérifier »** dans Google.

   **Méthode B — DNS (si vous préférez)**
   - Google fournit un enregistrement **TXT**.
   - Ajoutez-le dans **Cloudflare → DNS → Add record → TXT** sur `@`.
   - Puis cliquez sur **« Vérifier »**.

6. Une fois vérifié : dans le menu, ouvrez **« Sitemaps »** → saisissez
   `sitemap.xml` → **Envoyer**.

### 2.2 Suivre les résultats

- **Performances** (menu de gauche) : requêtes, clics, position moyenne.
- Les premiers résultats apparaissent généralement en **quelques jours à
  quelques semaines** (Google doit explorer le site).

---

## 3. Le référencement naturel prend du temps

Un site **neuf** met en général **2 à 8 semaines** avant d'apparaître sur son
nom exact, et **plusieurs mois** pour des mots-clés concurrentiels
(« conciergerie de luxe Bruxelles »). C'est normal.

### Accélérer (optionnel)
- **Google Business Profile** (ex-Google My Business) : créez la fiche
  « Gorex Group » (adresse Bruxelles, téléphone, site web) —
  https://www.google.com/business/ . C'est **le levier n°1** pour une entreprise
  locale belge.
- **Annuaires / presse** : quelques liens entrants (backlinks) accélèrent la
  reconnaissance.
- **Réseaux sociaux** : un lien vers le site depuis LinkedIn/Instagram aide Google.

---

## 4. Publicité (résultat immédiat, optionnel)

Si vous voulez apparaître **tout en haut immédiatement** (bloc « Sponsorisé ») :
- **Google Ads** : https://ads.google.com
- Vous payez au clic sur des mots comme « conciergerie de luxe Bruxelles ».

> Le référencement **naturel** (gratuit, section 2) reste la base : il travaille
> pour vous 24h/24 sans coût par clic.

---

## 5. Checklist

- [x] `robots.txt` en ligne
- [x] `sitemap.xml` en ligne
- [x] `canonical` sur toutes les pages
- [x] Données structurées (Organization / WebSite)
- [x] Contenu indexable (`<noscript>`)
- [ ] **Vous** : créer la propriété dans Google Search Console
- [ ] **Vous → moi** : m'envoyer la balise `google-site-verification`
- [ ] (Recommandé) Créer la fiche Google Business Profile

---

## 6. Vérifications techniques (pour référence)

```bash
# robots.txt
curl -s https://gorex-luxury-concierge.eu/robots.txt

# sitemap.xml
curl -s https://gorex-luxury-concierge.eu/sitemap.xml

# canonical + données structurées
curl -s https://gorex-luxury-concierge.eu/ | grep -E "canonical|ld\\+json"

# Test de données enrichies Google
# https://search.google.com/test/rich-results
```

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
