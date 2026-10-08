<div align="center">

# GOREX LUXURY CONCIERGE

**Luxury Concierge · Executive Assistance · Travel · Lifestyle · Security**

*Discretion. Access. Excellence.*

![Flutter](https://img.shields.io/badge/Flutter-3.35.4-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9.2-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-3DDC84?logo=android&logoColor=white)
![Tests](https://img.shields.io/badge/tests-112%20passed-success)
![License](https://img.shields.io/badge/license-Proprietary-C6A15B)

</div>

---

## Présentation

Plateforme de conciergerie d'exception éditée par **Gorex Group** (Belgique). L'application réunit la gestion des demandes clients, l'assistance exécutive, la facturation conforme (TVA belge, Peppol), la comptabilité et la conformité RGPD — dans une identité visuelle sobre : noir, blanc, champagne discret, anthracite.

- **Package Android** : `com.gorexconcierge.luxury`
- **Version** : 1.0.0 (versionCode 1)

## Application en ligne

| Ressource | URL |
|---|---|
| Application web | https://gorex-luxury-concierge.delightful-bag-624.workers.dev |
| Politique de confidentialité (RGPD) | https://gorex-luxury-concierge.delightful-bag-624.workers.dev/privacy.html |

## Fonctionnalités

### Conciergerie & opérations
- Tableau de bord direction, CRM clients, demandes, réservations, agenda
- Suivi des prestations et assignation du personnel
- Gestion des accès personnel (CRUD, rôles, permissions)

### Facturation (conforme Belgique)
- Validation **BCE / TVA** (modulo-97), normalisation des identifiants
- Régimes TVA : autoliquidation (art. 51 §2.4 CTVA), exonération intracommunautaire (art. 39bis CTVA), hors champ
- **Communication structurée** OGM/VCS (mod 97)
- **Peppol** : génération UBL 2.1 (Peppol BIS Billing 3.0 / EN 16931), envoi via Storecove, suivi asynchrone (polling + webhook)
- Export PDF des factures

### Comptabilité
- **Rapprochement bancaire** automatique (scoring : OGM, référence, montant, nom)
- **Relances de factures** impayées (escalade 7 / 21 / 45 jours) + moteur de relances planifiées
- **Export comptable** CSV (format belge `;`, décimales `,`)

### Conformité
- Politique de confidentialité **RGPD** (écran in-app + page web publique)
- Charte de confidentialité intégrée à l'identité visuelle

## Stack technique

| Domaine | Technologie |
|---|---|
| Framework | Flutter 3.35.4 / Dart 3.9.2 |
| État | Provider 6.1.5+1 (`AppState extends ChangeNotifier`) |
| Persistance | shared_preferences 2.5.3 (JSON `gorex_state_v1`) |
| Localisation | flutter_localizations + intl (`fr_BE`) |
| PDF / Impression | pdf 3.11.1 + printing 5.13.4 |
| Réseau | http 1.5.0, url_launcher 6.3.1 |
| UI | Material Design 3 (thème sombre), design system maison |

## Structure du projet

```
lib/
├── core/          # services (billing, accounting, peppol, export…)
├── data/          # seed & données de démonstration
├── models/        # modèles de domaine (finance, company, peppol…)
├── screens/       # écrans (shell, finance, client, legal, settings…)
├── state/         # AppState (état central)
├── widgets/       # composants réutilisables (design system)
└── main.dart
```

## Démarrage

```bash
flutter pub get
flutter run                      # dev
flutter build web --release      # web
flutter build apk --release      # Android (signé)
flutter build appbundle --release
```

## Qualité

```bash
flutter analyze     # → No issues found
flutter test        # → 112/112 tests
```

## Déploiement web

Voir [`deploy/web-worker/README.md`](deploy/web-worker/README.md) (Cloudflare Workers + Assets).

---

<div align="center">
<sub>© Gorex Group — GOREX LUXURY CONCIERGE. Tous droits réservés.</sub>
</div>
