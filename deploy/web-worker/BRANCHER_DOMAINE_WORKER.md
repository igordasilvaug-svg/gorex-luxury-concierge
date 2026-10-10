# Brancher `gorex-luxury-concierge.eu` sur le site (Worker)

> **État au moment de ce guide**
> - ✅ Zone Cloudflare `gorex-luxury-concierge.eu` **ACTIVE** (serveurs de noms `nucum` / `tanner`)
> - ✅ Site déployé et **en ligne** : `https://gorex-luxury-concierge.smoggy-shock.workers.dev` (HTTP 200)
> - ⏳ Domaine **pas encore attaché** → `https://gorex-luxury-concierge.eu` ne répond pas encore
> - Compte Cloudflare : **Smoggy Shock**

Il ne reste **qu'une seule opération** à faire, depuis le tableau de bord Cloudflare.
Durée : ~2 minutes. Aucun code, aucun terminal.

---

## 🎯 Objectif

Faire en sorte que **`https://gorex-luxury-concierge.eu`** affiche l'application
(au lieu de l'URL technique `...smoggy-shock.workers.dev`).

---

## 📋 Étape par étape (clic par clic)

### 1. Ouvrir le projet Worker
1. Connectez-vous à **https://dash.cloudflare.com**
2. Dans le menu de gauche, cliquez sur **Workers & Pages**
3. Cliquez sur le projet nommé **`gorex-luxury-concierge`**

### 2. Aller dans l'onglet « Domains » / « Domaines »
4. En haut de la page du projet, cliquez sur l'onglet **Settings** (Paramètres)
5. Dans la liste, cliquez sur **Domains & Routes** (Domaines et routes)
   > Sur certaines versions de l'interface, l'onglet s'appelle directement **Domains** / **Domaines** en haut de page.

### 3. Ajouter le domaine personnalisé
6. Cliquez sur le bouton **Add** (Ajouter) → choisissez **Custom domain** (Domaine personnalisé)
7. Saisissez exactement :
   ```
   gorex-luxury-concierge.eu
   ```
8. Cliquez sur **Add domain** (Ajouter le domaine)

### 4. Attendre l'activation
9. Cloudflare crée **automatiquement** l'enregistrement DNS (CNAME) et le **certificat SSL**.
10. Le statut passe de *Initializing* → **Active** (généralement **< 1 minute**).
    - Si le statut reste *Initializing*, patientez 2–3 minutes et rechargez la page.

### 5. (Recommandé) Ajouter aussi `www`
11. Répétez les étapes 6–8 avec :
    ```
    www.gorex-luxury-concierge.eu
    ```
    > Vous pouvez aussi créer une **Redirect Rule** pour rediriger `www` → domaine racine
    > (Rules → Redirect Rules → Create rule), mais ajouter le domaine à part est plus simple.

---

## ✅ Vérification

Après l'étape 4 (statut **Active**), ouvrez un onglet et allez sur :

**https://gorex-luxury-concierge.eu**

Vous devez voir l'application **GOREX LUXURY CONCIERGE**.
Le cadenas 🔒 (HTTPS) doit être vert.

En ligne de commande (optionnel) :
```bash
curl -sI https://gorex-luxury-concierge.eu/ | grep -iE "http/|strict-transport|content-security"
```
Résultat attendu : `HTTP/2 200` + en-têtes `strict-transport-security` et `content-security-policy`.

---

## 🩺 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| « Zone introuvable » / « Aucune zone ne correspond » | Le domaine n'est pas encore une zone de **ce** compte | Vérifiez que la zone `gorex-luxury-concierge.eu` est bien sur le compte *Smoggy Shock* (sélecteur de compte en haut à gauche) |
| Le domaine reste en *Initializing* > 5 min | Enregistrements DNS préexistants en conflit | Cloudflare → onglet **DNS** → supprimez un éventuel enregistrement A/CNAME en conflit sur `@` ou `www`, puis réessayez |
| Page blanche | Cache navigateur | Faites **Ctrl+Shift+R** (rechargement forcé) |
| Erreur de certificat | Certificat pas encore émis | Attendez 2–3 min ; vérifiez SSL/TLS → Edge Certificates |

---

## ℹ️ Bon à savoir

- L'URL technique `...smoggy-shock.workers.dev` **reste valable** en parallèle du domaine.
- Une fois le domaine attaché, toutes les pages légales et la page de téléchargement
  Android fonctionnent automatiquement, par ex. :
  - `https://gorex-luxury-concierge.eu/privacy.html`
  - `https://gorex-luxury-concierge.eu/download`
- Le certificat SSL est **gratuit et renouvelé automatiquement** par Cloudflare.

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
