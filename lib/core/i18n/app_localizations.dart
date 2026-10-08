/// GOREX LUXURY CONCIERGE — Localisation légère (FR / NL / EN).
///
/// Approche volontairement simple et sans dépendance : une table de
/// traductions par langue et une méthode `tr(lang, key)`. Le français est
/// la langue de référence ; toute clé manquante retombe sur le français.
///
/// Pour étendre la couverture linguistique, il suffit d'ajouter des clés
/// dans les trois cartes ci-dessous. Les écrans lisent la langue active via
/// `AppState.language` (persistée) et appellent `L10n.tr(...)`.
library;

class L10n {
  L10n._();

  /// Langues supportées (codes ISO 639-1).
  static const List<String> supported = ['fr', 'nl', 'en'];

  /// Nom natif de chaque langue (affiché dans le sélecteur).
  static const Map<String, String> languageNames = {
    'fr': 'Français',
    'nl': 'Nederlands',
    'en': 'English',
  };

  /// Drapeau / indicatif visuel (Belgique pour FR et NL, RU pour EN).
  static const Map<String, String> flags = {
    'fr': '🇧🇪',
    'nl': '🇧🇪',
    'en': '🇬🇧',
  };

  /// Libellés de langue au format « FR », « NL », « EN ».
  static const Map<String, String> shortLabels = {
    'fr': 'FR',
    'nl': 'NL',
    'en': 'EN',
  };

  static bool isSupported(String code) => supported.contains(code);

  /// Traduit une clé pour la langue donnée.
  /// Repli : langue → français → clé brute.
  static String tr(String lang, String key) {
    final table = _data[lang] ?? _data['fr']!;
    return table[key] ?? _data['fr']![key] ?? key;
  }

  /// Nom lisible d'une langue (ex. « Nederlands »).
  static String name(String code) => languageNames[code] ?? code;

  static const Map<String, Map<String, String>> _data = {
    'fr': _fr,
    'nl': _nl,
    'en': _en,
  };

  // ───────────────────────────── FRANÇAIS ─────────────────────────────
  static const Map<String, String> _fr = {
    // Navigation (back-office & client)
    'nav.dashboard': 'Tableau de bord',
    'nav.requests': 'Demandes',
    'nav.services': 'Services',
    'nav.itineraries': 'Itinéraires',
    'nav.bookings': 'Réservations',
    'nav.providers': 'Prestataires',
    'nav.clients': 'Clients',
    'nav.finance': 'Finance',
    'nav.accounting': 'Comptabilité',
    'nav.company_settings': 'Paramètres société',
    'nav.peppol': 'Access Point Peppol',
    'nav.reminders': 'Relances automatiques',
    'nav.crm': 'CRM',
    'nav.agenda': 'Agenda',
    'nav.communication': 'Communication',
    'nav.team': 'Équipe',
    'nav.access': 'Accès personnel',
    'nav.subscriptions': 'Abonnements',
    'nav.guide': 'Guide d\'utilisation',
    'nav.legal': 'Mentions légales',
    'nav.privacy': 'Confidentialité',
    'nav.about': 'À propos',
    // Connexion
    'login.secure_access': 'ACCÈS SÉCURISÉ',
    'login.subtitle':
        'Portail confidentiel réservé aux membres et à l\'équipe.',
    'login.email': 'ADRESSE E-MAIL',
    'login.password': 'MOT DE PASSE',
    'login.signin': 'Se connecter',
    'login.checking': 'Vérification...',
    'login.invalid': 'Identifiants invalides. Veuillez réessayer.',
    'login.demo_accounts': 'COMPTES DE DÉMONSTRATION',
    'login.guide': 'Guide d\'utilisation',
    'login.legal': 'Mentions légales',
    'login.about': 'À propos',
    // Commun
    'common.logout': 'Déconnexion',
    'common.close': 'Fermer',
    'common.language': 'Langue',
    // À propos
    'about.eyebrow': 'À PROPOS',
    'about.title': 'L\'excellence discrète',
    'about.intro':
        'GOREX LUXURY CONCIERGE est la signature de Gorex Group, maison belge '
            'dédiée à la conciergerie d\'exception et à l\'assistance exécutive. '
            'Nous accompagnons une clientèle privée et des dirigeants exigeants '
            'en Belgique et à l\'international.',
    'about.pillars_title': 'Nos cinq piliers',
    'about.pillar.concierge': 'Conciergerie de luxe',
    'about.pillar.executive': 'Assistance exécutive',
    'about.pillar.travel': 'Voyage',
    'about.pillar.lifestyle': 'Art de vivre',
    'about.pillar.security': 'Sécurité',
    'about.values_title': 'Nos engagements',
    'about.value.discretion': 'Discrétion',
    'about.value.discretion_body':
        'La confidentialité est absolue. Chaque demande est traitée avec la '
            'plus stricte réserve.',
    'about.value.access': 'Accès',
    'about.value.access_body':
        'Un réseau privilégié d\'adresses, de partenaires et de privilèges '
            'normalement inaccessibles.',
    'about.value.excellence': 'Excellence',
    'about.value.excellence_body':
        'Un service sur mesure, réactif et irréprochable, du premier contact '
            'à l\'exécution.',
    'about.contact_title': 'Nous contacter',
    'about.legal_title': 'Informations légales',
    'about.version': 'Version',
    // Hub légal
    'legal.hub_eyebrow': 'INFORMATIONS LÉGALES',
    'legal.hub_title': 'Transparence et conformité',
    'legal.privacy': 'Politique de confidentialité',
    'legal.privacy_sub':
        'Traitement des données personnelles (RGPD), finalités, durées de '
            'conservation et vos droits.',
    'legal.terms': 'Conditions Générales de Vente',
    'legal.terms_sub':
        'Prestations, prix et TVA, paiement, annulation, responsabilité et '
            'règlement des litiges.',
    'legal.notice': 'Mentions légales',
    'legal.notice_sub':
        'Éditeur, hébergeur, propriété intellectuelle, responsabilité et '
            'juridiction compétente.',
    'legal.cookies': 'Politique cookies',
    'legal.cookies_sub':
        'Cookies et stockage local utilisés. Aucun traceur publicitaire tiers.',
  };

  // ───────────────────────────── NEDERLANDS ─────────────────────────────
  static const Map<String, String> _nl = {
    'nav.dashboard': 'Dashboard',
    'nav.requests': 'Aanvragen',
    'nav.services': 'Diensten',
    'nav.itineraries': 'Routes',
    'nav.bookings': 'Boekingen',
    'nav.providers': 'Leveranciers',
    'nav.clients': 'Klanten',
    'nav.finance': 'Financiën',
    'nav.accounting': 'Boekhouding',
    'nav.company_settings': 'Bedrijfsinstellingen',
    'nav.peppol': 'Peppol Access Point',
    'nav.reminders': 'Automatische herinneringen',
    'nav.crm': 'CRM',
    'nav.agenda': 'Agenda',
    'nav.communication': 'Communicatie',
    'nav.team': 'Team',
    'nav.access': 'Personeelstoegang',
    'nav.subscriptions': 'Abonnementen',
    'nav.guide': 'Gebruikershandleiding',
    'nav.legal': 'Juridische informatie',
    'nav.privacy': 'Privacy',
    'nav.about': 'Over ons',
    'login.secure_access': 'BEVEILIGDE TOEGANG',
    'login.subtitle': 'Vertrouwelijk portaal voor leden en team.',
    'login.email': 'E-MAILADRES',
    'login.password': 'WACHTWOORD',
    'login.signin': 'Inloggen',
    'login.checking': 'Controleren...',
    'login.invalid': 'Ongeldige inloggegevens. Probeer opnieuw.',
    'login.demo_accounts': 'DEMO-ACCOUNTS',
    'login.guide': 'Gebruikershandleiding',
    'login.legal': 'Juridische informatie',
    'login.about': 'Over ons',
    'common.logout': 'Afmelden',
    'common.close': 'Sluiten',
    'common.language': 'Taal',
    'about.eyebrow': 'OVER ONS',
    'about.title': 'Discrete excellentie',
    'about.intro':
        'GOREX LUXURY CONCIERGE is de signatuur van Gorex Group, een Belgisch '
            'huis gewijd aan uitzonderlijke conciërge en executive assistance. '
            'Wij begeleiden een privécliënteel en veeleisende leiders in België '
            'en internationaal.',
    'about.pillars_title': 'Onze vijf pijlers',
    'about.pillar.concierge': 'Luxe conciërge',
    'about.pillar.executive': 'Executive assistance',
    'about.pillar.travel': 'Reizen',
    'about.pillar.lifestyle': 'Levensstijl',
    'about.pillar.security': 'Beveiliging',
    'about.values_title': 'Onze engagementen',
    'about.value.discretion': 'Discretie',
    'about.value.discretion_body':
        'Vertrouwelijkheid is absoluut. Elke aanvraag wordt met de grootste '
            'terughoudendheid behandeld.',
    'about.value.access': 'Toegang',
    'about.value.access_body':
        'Een bevoorrecht netwerk van adressen, partners en privileges die '
            'normaal ontoegankelijk zijn.',
    'about.value.excellence': 'Excellentie',
    'about.value.excellence_body':
        'Een dienst op maat, responsief en onberispelijk, van het eerste '
            'contact tot de uitvoering.',
    'about.contact_title': 'Contacteer ons',
    'about.legal_title': 'Juridische informatie',
    'about.version': 'Versie',
    'legal.hub_eyebrow': 'JURIDISCHE INFORMATIE',
    'legal.hub_title': 'Transparantie en conformiteit',
    'legal.privacy': 'Privacybeleid',
    'legal.privacy_sub':
        'Verwerking van persoonsgegevens (AVG), doeleinden, bewaartermijnen '
            'en uw rechten.',
    'legal.terms': 'Algemene Verkoopvoorwaarden',
    'legal.terms_sub':
        'Diensten, prijzen en btw, betaling, annulering, aansprakelijkheid en '
            'geschillenbeslechting.',
    'legal.notice': 'Juridische informatie',
    'legal.notice_sub':
        'Uitgever, hosting, intellectuele eigendom, aansprakelijkheid en '
            'bevoegde rechtbank.',
    'legal.cookies': 'Cookiebeleid',
    'legal.cookies_sub':
        'Gebruikte cookies en lokale opslag. Geen tracking door derden.',
  };

  // ───────────────────────────── ENGLISH ─────────────────────────────
  static const Map<String, String> _en = {
    'nav.dashboard': 'Dashboard',
    'nav.requests': 'Requests',
    'nav.services': 'Services',
    'nav.itineraries': 'Itineraries',
    'nav.bookings': 'Bookings',
    'nav.providers': 'Providers',
    'nav.clients': 'Clients',
    'nav.finance': 'Finance',
    'nav.accounting': 'Accounting',
    'nav.company_settings': 'Company settings',
    'nav.peppol': 'Peppol Access Point',
    'nav.reminders': 'Automatic reminders',
    'nav.crm': 'CRM',
    'nav.agenda': 'Agenda',
    'nav.communication': 'Communication',
    'nav.team': 'Team',
    'nav.access': 'Staff access',
    'nav.subscriptions': 'Subscriptions',
    'nav.guide': 'User guide',
    'nav.legal': 'Legal notice',
    'nav.privacy': 'Privacy',
    'nav.about': 'About',
    'login.secure_access': 'SECURE ACCESS',
    'login.subtitle': 'Confidential portal for members and staff.',
    'login.email': 'EMAIL ADDRESS',
    'login.password': 'PASSWORD',
    'login.signin': 'Sign in',
    'login.checking': 'Checking...',
    'login.invalid': 'Invalid credentials. Please try again.',
    'login.demo_accounts': 'DEMO ACCOUNTS',
    'login.guide': 'User guide',
    'login.legal': 'Legal notice',
    'login.about': 'About',
    'common.logout': 'Log out',
    'common.close': 'Close',
    'common.language': 'Language',
    'about.eyebrow': 'ABOUT',
    'about.title': 'Discreet excellence',
    'about.intro':
        'GOREX LUXURY CONCIERGE is the signature of Gorex Group, a Belgian '
            'house devoted to exceptional concierge and executive assistance. '
            'We serve a private clientele and demanding executives in Belgium '
            'and internationally.',
    'about.pillars_title': 'Our five pillars',
    'about.pillar.concierge': 'Luxury concierge',
    'about.pillar.executive': 'Executive assistance',
    'about.pillar.travel': 'Travel',
    'about.pillar.lifestyle': 'Lifestyle',
    'about.pillar.security': 'Security',
    'about.values_title': 'Our commitments',
    'about.value.discretion': 'Discretion',
    'about.value.discretion_body':
        'Confidentiality is absolute. Every request is handled with the '
            'strictest reserve.',
    'about.value.access': 'Access',
    'about.value.access_body':
        'A privileged network of addresses, partners and privileges normally '
            'out of reach.',
    'about.value.excellence': 'Excellence',
    'about.value.excellence_body':
        'A tailor-made, responsive and flawless service, from first contact '
            'to delivery.',
    'about.contact_title': 'Contact us',
    'about.legal_title': 'Legal information',
    'about.version': 'Version',
    'legal.hub_eyebrow': 'LEGAL INFORMATION',
    'legal.hub_title': 'Transparency and compliance',
    'legal.privacy': 'Privacy policy',
    'legal.privacy_sub':
        'Processing of personal data (GDPR), purposes, retention periods and '
            'your rights.',
    'legal.terms': 'General Terms of Sale',
    'legal.terms_sub':
        'Services, prices and VAT, payment, cancellation, liability and '
            'dispute resolution.',
    'legal.notice': 'Legal notice',
    'legal.notice_sub':
        'Publisher, hosting, intellectual property, liability and competent '
            'jurisdiction.',
    'legal.cookies': 'Cookie policy',
    'legal.cookies_sub':
        'Cookies and local storage used. No third-party advertising trackers.',
  };
}
