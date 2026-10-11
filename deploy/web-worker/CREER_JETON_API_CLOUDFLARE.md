# 🔑 Créer un jeton API Cloudflare — pour déployer le site

Ce guide vous fait créer un **jeton API** (30 secondes). Une fois le jeton créé,
je pourrai **déployer automatiquement** le site `gorex-luxury-concierge.eu` sur
votre compte via le script [`deploy_web.sh`](deploy_web.sh) (commande
`npx wrangler@4 deploy`).

> ⚠️ **Pourquoi vous et pas moi ?** Un jeton API s'obtient uniquement depuis une
> session connectée à **votre** compte Cloudflare (mot de passe + 2FA). C'est une
> protection : personne d'autre ne peut générer un accès à votre compte.
> Vous seul pouvez créer le jeton, puis me le confier pour exécuter l'attachement.

---

## Étape 1 — Ouvrir la page des jetons

1. Connectez-vous à **https://dash.cloudflare.com**
2. En **haut à droite**, cliquez sur l'**icône de profil** (ou « My Profile »)
3. Dans le menu de gauche, cliquez sur **API Tokens**
4. Cliquez sur **Create Token** (Créer un jeton)

## Étape 2 — Choisir « Create Custom Token »

5. Faites défiler jusqu'à la section **Custom token** (jeton personnalisé)
6. Cliquez sur **Get started** (Commencer) à droite de « Create Custom Token »

## Étape 3 — Configurer les permissions

7. **Token name** (Nom du jeton) : `Gorex - deploiement site`
8. **Permissions** — ajoutez **deux** lignes :

| Ressource (Resource) | Niveau (Level) |
|---|---|
| **Account** → **Workers Scripts** | **Edit** |
| **Zone** → **Zone** | **Read** |

   - Cliquez sur **+ Add more** pour ajouter la 2ᵉ ligne si besoin.

9. **Account Resources** (Ressources de compte) :
   - **Include** → sélectionnez votre compte **« Smoggy Shock »**

10. **Zone Resources** (Ressources de zone) :
    - **Include** → **Specific zone** → **`gorex-luxury-concierge.eu`**

11. **Client IP Address Filtering** : laissez vide (ou votre IP si vous préférez)
12. **TTL** (durée de vie) : choisissez une **date d'expiration proche**
    (ex. *1 jour*) — c'est plus sûr ; le jeton ne servira qu'une fois.

## Étape 4 — Créer et copier

13. Cliquez sur **Continue to summary** (Continuer vers le résumé)
14. Vérifiez le résumé, puis cliquez sur **Create Token**
15. **Copiez le jeton** affiché (il ne sera **plus jamais** réaffiché) :
    - Il ressemble à : `a1b2C3d4E5f6...` (longue chaîne aléatoire)

## Étape 5 — Me le transmettre

Collez le jeton dans votre prochain message. Je lancerai alors :

```bash
cd /home/user/flutter_app/deploy/web-worker
CLOUDFLARE_API_TOKEN="<votre_jeton>" ./deploy_web.sh
```

Le script va automatiquement :
1. ✅ vérifier que le build contient bien l'authentification Firebase ;
2. ✅ **déployer le site** sur votre compte (`npx wrangler@4 deploy`) ;
3. ✅ **vérifier que le site répond** en HTTP 200 ;
4. ✅ afficher le statut final.

> Le jeton est utilisé **une seule fois** puis peut être révoqué immédiatement.

---

## 🔒 Sécurité — bon à savoir

- Un jeton à **portée limitée** (Workers Scripts Edit + Zone Read) ne peut **pas**
  supprimer votre compte ni accéder à votre facturation.
- Donnez-lui une **expiration courte** (1 jour) : après l'opération, il devient inutile.
- Après l'attachement, vous pouvez **révoquer** le jeton :
  *My Profile → API Tokens → `Gorex - deploiement site` → ... → Delete / Roll*.
- **Alternative sans jeton** : vous pouvez aussi le faire vous-même en 4 clics
  (voir [`BRANCHER_DOMAINE_WORKER.md`](BRANCHER_DOMAINE_WORKER.md)) — c'est la
  méthode la plus sûre si vous préférez ne partager aucun secret.

---

## 🩺 Dépannage du jeton

| Message | Cause | Solution |
|---|---|---|
| `Invalid API Token` | Jeton mal copié ou révoqué | Re-créez le jeton (Étape 1) et copiez-le en entier |
| `Zone introuvable` | La zone n'est pas sur le compte visé | Vérifiez que `gorex-luxury-concierge.eu` est bien sur le compte *Smoggy Shock* |
| `Authentication error` sur Workers | Permission manquante | Ajoutez **Account → Workers Scripts → Edit** |
| `already exists` | Domaine déjà attaché | C'est bon signe : le domaine est en place ✅ |

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
