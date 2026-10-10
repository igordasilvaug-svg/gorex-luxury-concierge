# Diagnostic & correction — domaine `gorex-luxury-concierge.eu` (erreur 530 / 1016)

## Symptôme observé

| Test | Résultat |
|---|---|
| DNS apex `A` / `AAAA` / `CNAME` | **vide** (aucun enregistrement résolvable) |
| `https://gorex-luxury-concierge.eu` forcé sur IP Cloudflare | **HTTP 530** → erreur Cloudflare **1016 « Origin DNS error »** |
| `https://gorex-luxury-concierge.smoggy-shock.workers.dev` | ✅ **HTTP 200** (site OK) |
| Zone DNS (NS) | ✅ `nucum` / `tanner` (active) |

## Cause

Des **enregistrements DNS en conflit** sur le même nom `gorex-luxury-concierge.eu`,
créés par des tentatives successives :

1. une **Route** Worker (crée un enregistrement de type `Worker`) ;
2. un **CNAME manuel** vers `...workers.dev` ;
3. un **Domaine personnalisé** (type « Production »).

Cloudflare proxifie bien le domaine mais ne peut pas résoudre l'origine → **530 / 1016**.

## Correction — remise à zéro propre

### A. Nettoyer les enregistrements DNS
1. Zone `gorex-luxury-concierge.eu` → onglet **DNS** → **Enregistrements**
2. **Supprimer** tout enregistrement nommé `gorex-luxury-concierge.eu`
   (CNAME **et** Worker s'il existe) → état vide.

### B. Nettoyer les attachements Worker
3. **Workers & Pages** → `gorex-luxury-concierge` → **Settings** → **Domains & Routes**
4. **Supprimer** toute entrée existante pour `gorex-luxury-concierge.eu`
   (Route **et** Domaine personnalisé).

### C. Rattacher UN SEUL Domaine personnalisé
5. **Settings → Domains & Routes → Add → Custom domain**
6. Saisir `gorex-luxury-concierge.eu` → **Add domain**
7. Cloudflare crée **lui-même** l'enregistrement correct **et** le certificat SSL.
8. Attendre le statut **Active** (1–3 min).

## Vérification

```bash
curl -sI https://gorex-luxury-concierge.eu/ | grep -iE "http/|strict-transport|content-security"
```

Attendu : `HTTP/2 200` + `strict-transport-security` + `content-security-policy`.

## Solution de repli (si le Domaine personnalisé échoue encore)

N'utiliser **QUE** un CNAME manuel, **sans** Route ni Domaine personnalisé :

| Type | Nom | Contenu | Proxy |
|---|---|---|---|
| CNAME | `@` | `gorex-luxury-concierge.smoggy-shock.workers.dev` | 🟠 Proxied |

---

*Guide GOREX LUXURY CONCIERGE — Discretion. Access. Excellence.*
