import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_localizations.dart';
import '../core/app_config.dart';
import '../core/security/password_policy.dart';
import '../core/firebase/firebase_auth_service.dart';
import '../core/firebase/rest_auth_service.dart';
import '../core/firebase/firestore_service.dart';
import '../core/billing/peppol_service.dart';
import '../core/billing/subscription_policy.dart';
import '../core/billing/peppol_ubl_generator.dart';
import '../core/billing/reconciliation_service.dart';
import '../core/billing/reminder_service.dart';
import '../core/billing/sepa_pain008_generator.dart';
import '../core/billing/sepa_validator.dart';
import '../core/billing/vat_service.dart';
import '../data/seed_data.dart';
import '../data/seed_operations.dart';
import '../models/app_user.dart';
import '../models/client.dart';
import '../models/company_profile.dart';
import '../models/sepa_mandate.dart';
import '../models/subscription.dart';
import '../models/communication.dart';
import '../models/crm_agenda.dart';
import '../models/enums.dart';
import '../models/finance.dart';
import '../models/itinerary.dart';
import '../models/peppol_config.dart';
import '../models/provider_booking.dart';
import '../models/reminder_config.dart';
import '../models/service_request.dart';
import '../models/subscription_tier.dart';

/// Erreur de persistance côté serveur.
///
/// Levée lorsqu'une modification a été appliquée à l'écran mais que la
/// sauvegarde serveur a échoué. L'appelant DOIT en informer l'utilisateur :
/// sans cela, une saisie semblerait enregistrée alors qu'elle serait perdue
/// au rechargement suivant.
class CloudWriteException implements Exception {
  const CloudWriteException(this.what);
  final String what;

  @override
  String toString() =>
      '$what : la sauvegarde sur le serveur a échoué. '
      'La modification n\'a pas été conservée.';
}

/// Tentative d'utiliser un service alors que le dossier client n'est pas
/// validé par le personnel (ou a été refusé).
///
/// Exception distincte de [CloudWriteException] : ici la connexion et le
/// serveur fonctionnent, c'est l'ACCÈS qui n'est pas ouvert. Le message est
/// destiné à être affiché tel quel à la personne.
class ClientNotApprovedException implements Exception {
  const ClientNotApprovedException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// État applicatif central — persistance locale (shared_preferences JSON)
/// Architecture API-ready : chaque mutation passe par une méthode dédiée
/// qui pourra être remplacée par un appel HTTP.
class AppState extends ChangeNotifier {
  static const _storageKey = 'gorex_state_v1';

  /// Version du schéma des données locales.
  ///
  /// Incrémentée à chaque changement incompatible. Une donnée locale d'une
  /// version antérieure est PURGÉE au démarrage : les anciennes versions de
  /// démonstration avaient laissé des exemples fictifs (clients, demandes,
  /// réservations, finances) dans le stockage des navigateurs.
  static const int _dataVersion = 2;

  /// Clé de stockage de la version des données.
  static const _versionKey = 'gorex_data_version';

  /// Instance SharedPreferences conservée après [init] (évite les accès async
  /// répétés lors des écritures successives).
  SharedPreferences? _cachedPrefs;

  AppUser? currentUser;

  /// Message de diagnostic de la dernière tentative de connexion (null = aucune
  /// erreur). Permet d'afficher une cause précise à l'utilisateur au lieu du
  /// générique « identifiants invalides » (aide au support).
  String? lastAuthError;

  /// Raison du changement de mot de passe imposé, lorsque la session vient
  /// d'être ouverte. `'weak-password'` signale un mot de passe trop faible
  /// détecté à la connexion : l'écran de changement doit alors expliquer
  /// pourquoi il s'affiche, plutôt que de parler de « première connexion ».
  String? mustChangeReason;

  /// Un essai de réinitialisation par lien e-mail a-t-il déjà été consommé ?
  ///
  /// Un `oobCode` est à usage unique : recharger la page après un changement
  /// réussi renverrait « code déjà utilisé » alors que l'opération a réussi.
  /// L'écran de réinitialisation lit puis efface ce drapeau pour éviter ce
  /// faux message d'échec.
  bool resetAttempted = false;

  /// Efface le drapeau d'essai de réinitialisation.
  void consumeResetAttempt() => resetAttempted = false;

  /// Jeton de session obtenu via l'API REST (repli sans SDK JavaScript).
  /// Conservé pour permettre le changement de mot de passe en cours de session.
  String? restIdToken;

  /// Identifiant Firebase de la session REST.
  String? restUid;

  /// Coordonnées officielles de l'émetteur (Gorex Group) — facturation.
  CompanyProfile company = const CompanyProfile();

  /// Configuration de l'Access Point Peppol (facturation électronique).
  PeppolConfig peppol = const PeppolConfig();

  /// Configuration du moteur de relance automatique des impayés.
  ReminderConfig reminderConfig = const ReminderConfig();

  /// Langue active de l'interface (code ISO 639-1 : fr, nl, en).
  /// Persistée pour conserver le choix de l'utilisateur entre les sessions.
  String language = 'fr';

  List<AppUser> users = [];
  List<Client> clients = [];
  List<ServiceRequest> requests = [];
  List<Provider> providers = [];
  List<Booking> bookings = [];
  List<Itinerary> itineraries = [];
  List<FinanceDocument> financeDocs = [];
  List<Expense> expenses = [];

  /// Relevé bancaire importé (transactions à rapprocher des factures).
  List<BankTransaction> bankTransactions = [];
  List<Conversation> conversations = [];
  List<Appointment> appointments = [];
  List<Prospect> prospects = [];
  List<SubscriptionTier> tiers = [];

  /// Demandes et contrats d'abonnement.
  ///
  /// Distincts de `Client.subscriptionTierId` : ce dernier dit quelle formule
  /// est APPLIQUÉE au dossier, celui-ci porte le CONTRAT (demande, décision,
  /// date d'effet, montant convenu). Un abonnement n'est facturable qu'à
  /// l'état `active`, c'est-à-dire après acceptation ET signature du mandat.
  List<Subscription> subscriptions = [];

  List<AuditEntry> auditLog = [];

  bool _ready = false;
  bool get ready => _ready;

  // ─────────────────────────── INIT ───────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    final storedVersion = prefs.getInt(_versionKey);

    // ── PURGE UNIQUE DES DONNÉES HÉRITÉES ──────────────────────────────
    // Les versions précédentes (démonstration) ont persisté des exemples
    // fictifs dans le navigateur. Si la donnée locale provient d'une version
    // antérieure, elle est supprimée définitivement, une seule fois.
    if (storedVersion != _dataVersion) {
      await prefs.remove(_storageKey);
      await prefs.setInt(_versionKey, _dataVersion);
      if (kDebugMode) {
        debugPrint(
          '[State] Données locales v${storedVersion ?? 0} purgées '
          '(schéma courant : v$_dataVersion).',
        );
      }
    }

    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _hydrate(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        if (kDebugMode) debugPrint('State hydrate failed: $e');
        _seed();
      }
    } else {
      _seed();
    }

    // En production, on récupère les comptes réels d'équipe depuis Firestore
    // dès qu'une session authentifiée existe (voir `_afterSignIn`). Sans jeton
    // valide, Firestore refuse la lecture : on n'affiche donc aucun compte
    // plutôt que des exemples inventés.
    if (AppConfig.isProduction && restIdToken != null) {
      await loadTeamFromCloud();
      await loadOperationalFromCloud();
      await loadProvidersFromCloud();
      await loadCompanyFromCloud();
      await loadPeppolSecretFromCloud();
      await loadTiersFromCloud();
    }

    // Mandats et prélèvements SEPA : stockage séparé de l'état principal
    // (les coordonnées bancaires ne doivent pas figurer dans le document
    // d'état partagé).
    await loadSepa();
    // Les mandats vivent aussi dans Firestore : on récupère ceux saisis
    // depuis un autre appareil.
    await syncSepaFromCloud();
    // Les abonnements aussi (règle « un client ne lit que SON contrat »).
    await syncSubscriptionsFromCloud();

    _ready = true;
    notifyListeners();
  }

  /// Charge la liste réelle des comptes d'équipe depuis Firestore (`staff`).
  ///
  /// Alimente les onglets « Équipe » et « Accès personnel » avec les comptes
  /// réellement existants. Aucune donnée n'est inventée : si la lecture
  /// échoue (session absente, droits, réseau), la liste reste vide.
  ///
  /// Deux voies de lecture, dans cet ordre :
  ///   1. API REST Firestore — fonctionne même quand le SDK est bloqué
  ///      (cas constaté sur Safari) ;
  ///   2. SDK Firestore — secours.
  Future<void> loadTeamFromCloud() async {
    // 403 CORRIGÉ. `staff` est réservé au personnel par les règles Firestore.
    // Un client connecté qui appelait cette méthode recevait un 403 à chaque
    // connexion (erreur visible en console). L'équipe ne le concerne pas :
    // on ne demande plus rien.
    if (!isStaff) return;

    final token = restIdToken;
    var rows = <Map<String, dynamic>>[];

    if (token != null && token.isNotEmpty) {
      rows = await RestAuthService.fetchCollection('staff', token, limit: 100);
    }
    if (rows.isEmpty && FirestoreService.available) {
      try {
        rows = await FirestoreService.fetchCollection('staff', limit: 100);
      } catch (e) {
        if (kDebugMode) debugPrint('[State] équipe (SDK) : $e');
      }
    }
    if (rows.isEmpty) return;

    final loaded = <AppUser>[];
    for (final r in rows) {
      final p = _profileFromStaff(r);
      if (p == null) continue;
      // Le mot de passe n'est JAMAIS rapatrié côté navigateur.
      loaded.add(p.copyWith(password: '', mustChangePassword: false));
    }
    if (loaded.isEmpty) return;

    // La base fait foi : la liste affichée est exactement celle de Firestore.
    // Aucune fiche locale antérieure n'est conservée, pour qu'une entrée
    // supprimée côté serveur disparaisse aussi de l'interface.
    users = loaded
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

    // Ré-aligne la session courante sur la fiche fraîche.
    // Le NOM et le TÉLÉPHONE doivent aussi être repris : sans cela, une valeur
    // enregistrée lors d'une session précédente n'était jamais réaffichée
    // (champ vide à l'écran alors que la base la contenait).
    final email = currentUser?.email.toLowerCase();
    if (email != null) {
      for (final fresh in loaded) {
        if (fresh.email.toLowerCase() == email) {
          currentUser = currentUser!.copyWith(
            fullName: fresh.fullName,
            phone: fresh.phone,
            role: fresh.role,
            title: fresh.title,
            active: fresh.active,
          );
          break;
        }
      }
    }

    await _persist();
    notifyListeners();
  }

  void _seed() {
    // En PRODUCTION : AUCUNE donnée de démonstration, dans AUCUNE collection.
    // Les données réelles proviennent exclusivement de Firestore (profils
    // d'équipe, clients, dossiers saisis par les utilisateurs).
    // En développement : jeu de démonstration pour le prototypage.
    if (AppConfig.isProduction) {
      users = [];
      clients = [];
      requests = [];
      providers = [];
      bookings = [];
      itineraries = [];
      financeDocs = [];
      expenses = [];
      bankTransactions = [];
      conversations = [];
      appointments = [];
      prospects = [];
      // La grille d'abonnements commerciale est rétablie : c'est l'offre
      // publique de Gorex Group, et non un jeu de démonstration.
      // Elle reste entièrement modifiable depuis l'écran Abonnements.
      tiers = SeedData.tiers();
      auditLog = [
        AuditEntry(
          id: 'aud_0',
          timestamp: DateTime.now(),
          actor: 'Système',
          actorRole: 'System',
          action: 'Initialisation plateforme',
          target: 'GOREX GROUP',
        ),
      ];
      _persist();
      return;
    }
    users = SeedData.users();
    clients = SeedData.clients();
    tiers = SeedData.tiers();
    requests = SeedOperations.requests();
    providers = SeedOperations.providers();
    bookings = SeedOperations.bookings();
    itineraries = SeedOperations.itineraries();
    financeDocs = SeedOperations.financeDocs();
    expenses = SeedOperations.expenses();
    bankTransactions = SeedOperations.bankTransactions();
    conversations = SeedOperations.conversations();
    appointments = SeedOperations.appointments();
    prospects = SeedOperations.prospects();
    auditLog = [
      AuditEntry(
        id: 'aud_0',
        timestamp: DateTime.now(),
        actor: 'Système',
        actorRole: 'System',
        action: 'Initialisation plateforme',
        target: 'GOREX LUXURY CONCIERGE',
      ),
    ];
    _persist();
  }

  void _hydrate(Map<String, dynamic> m) {
    if (m['company'] != null) {
      company = CompanyProfile.fromMap(
        Map<String, dynamic>.from(m['company'] as Map),
      );
    }
    if (m['peppol'] != null) {
      peppol = PeppolConfig.fromMap(
        Map<String, dynamic>.from(m['peppol'] as Map),
      );
    }
    if (m['reminderConfig'] != null) {
      reminderConfig = ReminderConfig.fromMap(
        Map<String, dynamic>.from(m['reminderConfig'] as Map),
      );
    }
    final lang = m['language'] as String?;
    if (lang != null && lang.isNotEmpty) language = lang;
    users = _mapList(m['users'], AppUser.fromMap);
    clients = _mapList(m['clients'], Client.fromMap);
    tiers = _mapList(m['tiers'], SubscriptionTier.fromMap);
    subscriptions = _mapList(m['subscriptions'], Subscription.fromMap);
    // ── MIGRATION CIBLÉE UNIQUEMENT ─────────────────────────────────────
    // Une version intermédiaire avait vidé la grille d'abonnements. Les
    // navigateurs l'ayant déjà chargée conservent `tiers: []` en mémoire :
    // on rétablit donc l'offre commerciale SANS toucher aux autres données
    // (clients, dossiers, finances…) qui pourraient être réelles.
    // Si la grille a été personnalisée en base, elle n'est pas touchée.
    if (AppConfig.isProduction && tiers.isEmpty) {
      tiers = SeedData.tiers();
    }
    requests = _mapList(m['requests'], ServiceRequest.fromMap);
    providers = _mapList(m['providers'], Provider.fromMap);
    bookings = _mapList(m['bookings'], Booking.fromMap);
    itineraries = _mapList(m['itineraries'], Itinerary.fromMap);
    financeDocs = _mapList(m['financeDocs'], FinanceDocument.fromMap);
    expenses = _mapList(m['expenses'], Expense.fromMap);
    bankTransactions = _mapList(m['bankTransactions'], BankTransaction.fromMap);
    conversations = _mapList(m['conversations'], Conversation.fromMap);
    appointments = _mapList(m['appointments'], Appointment.fromMap);
    prospects = _mapList(m['prospects'], Prospect.fromMap);
    auditLog = _mapList(m['auditLog'], AuditEntry.fromMap);
    // ⚠️ En production, une liste vide est un état NORMAL (démarrage à zéro) :
    // il ne faut surtout pas relancer le jeu de démonstration. L'ancien test
    // `users.isEmpty || clients.isEmpty` recréait les exemples fictifs à chaque
    // chargement puisqu'aucun client n'existe avant la première saisie.
    if (!AppConfig.isProduction && (users.isEmpty || clients.isEmpty)) _seed();
  }

  List<T> _mapList<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      v == null
      ? <T>[]
      : (v as List).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();

  // ═══════════════════════════════════════════════════════════════════════
  // PERSISTANCE SERVEUR
  //
  // Toute modification métier doit être écrite dans Firestore, et pas
  // seulement dans le stockage local du navigateur. Sans cela, une saisie
  // disparaît dès que l'utilisateur change d'appareil ou vide son cache.
  //
  // Voie principale : API REST Firestore (fonctionne même quand le SDK est
  // bloqué, cas constaté sur Safari). Repli : SDK. Le code HTTP est
  // remonté à l'appelant, qui décide d'informer l'utilisateur.
  // ═══════════════════════════════════════════════════════════════════════

  /// Identifiant fixe du document Firestore contenant les réglages société.
  ///
  /// Constant et non dérivé du numéro d'entreprise : ce dernier est un champ
  /// modifiable (et encore un placeholder), il ne peut pas servir de clé.
  static const String _companyDocId = 'gorex-group';

  /// Résultat de la dernière écriture serveur (diagnostic).
  String? lastCloudError;

  /// Écrit (ou met à jour partiellement) un document Firestore.
  ///
  /// [collection] et [docId] désignent le document cible ; [data] ne contient
  /// que les champs à modifier (mise à jour partielle par `updateMask`).
  /// Retourne `true` si le serveur a confirmé l'écriture.
  Future<bool> _pushToCloud(
    String collection,
    Map<String, dynamic> data, {
    String? docId,
  }) async {
    // Hors production, la persistance locale suffit au prototypage.
    if (!AppConfig.isProduction) return true;
    if (data.isEmpty) return true;

    final token = restIdToken;
    final id = docId ?? restUid;
    if (token == null || token.isEmpty || id == null || id.isEmpty) {
      lastCloudError = 'session absente';
      return false;
    }

    final path = '$collection/$id';
    final code = await RestAuthService.updateDocument(path, token, data);
    if (code == 200) {
      lastCloudError = null;
      return true;
    }

    // Repli SDK si la requête n'a pas abouti pour une raison réseau.
    if (code == 0 && FirestoreService.available) {
      try {
        await FirestoreService.updateDocument(collection, id, data);
        lastCloudError = null;
        return true;
      } catch (_) {}
    }
    lastCloudError = 'HTTP $code';
    if (kDebugMode) debugPrint('[Cloud] écriture $path refusée : HTTP $code');
    return false;
  }

  /// Sérialise un utilisateur pour le stockage local SANS son mot de passe.
  ///
  /// ── POURQUOI CE RETRAIT EST NÉCESSAIRE ────────────────────────────────
  /// L'état applicatif complet est écrit dans le stockage local du navigateur
  /// (`localStorage`) via `shared_preferences`. En y laissant le champ
  /// `password`, le mot de passe du compte — y compris celui d'un vrai
  /// utilisateur après un changement — se retrouvait EN CLAIR dans un
  /// espace lisible par tout script de la page et par quiconque accède à la
  /// machine. C'est exactement ce que proscrit la règle « aucun mot de passe
  /// en clair ».
  ///
  /// En production, l'authentification passe par Firebase : le mot de passe
  /// n'est jamais nécessaire côté application. Il ne reste donc en mémoire
  /// que pour les comptes de démonstration hors production.
  Map<String, dynamic> _userMapForStorage(AppUser u) {
    final m = u.toMap();
    m['password'] = '';
    return m;
  }

  Future<void> _persist() async {    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'company': company.toMap(),
        'peppol': peppol.toMap(),
        'reminderConfig': reminderConfig.toMap(),
        'language': language,
        'users': users.map(_userMapForStorage).toList(),
        'clients': clients.map((e) => e.toMap()).toList(),
        'tiers': tiers.map((e) => e.toMap()).toList(),
        'subscriptions': subscriptions.map((e) => e.toMap()).toList(),
        'requests': requests.map((e) => e.toMap()).toList(),
        'providers': providers.map((e) => e.toMap()).toList(),
        'bookings': bookings.map((e) => e.toMap()).toList(),
        'itineraries': itineraries.map((e) => e.toMap()).toList(),
        'financeDocs': financeDocs.map((e) => e.toMap()).toList(),
        'expenses': expenses.map((e) => e.toMap()).toList(),
        'bankTransactions': bankTransactions.map((e) => e.toMap()).toList(),
        'conversations': conversations.map((e) => e.toMap()).toList(),
        'appointments': appointments.map((e) => e.toMap()).toList(),
        'prospects': prospects.map((e) => e.toMap()).toList(),
        'auditLog': auditLog.map((e) => e.toMap()).toList(),
      }),
    );
  }

  Future<void> resetDemo() async {
    _seed();
    currentUser = null;
    notifyListeners();
  }

  // ─────────────────────── SAUVEGARDE / RESTAURATION ───────────────────────
  /// Sérialise l'intégralité des données persistées (hors session courante).
  Map<String, dynamic> exportState() => {
    'schema': 1,
    'app': 'GOREX LUXURY CONCIERGE',
    'exportedAt': DateTime.now().toIso8601String(),
    'company': company.toMap(),
    'peppol': peppol.toMap(),
    'reminderConfig': reminderConfig.toMap(),
    'language': language,
    'users': users.map((e) => e.toMap()).toList(),
    'clients': clients.map((e) => e.toMap()).toList(),
    'tiers': tiers.map((e) => e.toMap()).toList(),
    // Les abonnements sont inclus dans la sauvegarde, mais la source de
    // verite reste la collection `subscriptions` (chaque client ne lit que
    // la sienne). Cette copie sert uniquement au stockage local et aux
    // sauvegardes, jamais aux decisions de facturation.
    'subscriptions': subscriptions.map((e) => e.toMap()).toList(),
    'requests': requests.map((e) => e.toMap()).toList(),
    'providers': providers.map((e) => e.toMap()).toList(),
    'bookings': bookings.map((e) => e.toMap()).toList(),
    'itineraries': itineraries.map((e) => e.toMap()).toList(),
    'financeDocs': financeDocs.map((e) => e.toMap()).toList(),
    'expenses': expenses.map((e) => e.toMap()).toList(),
    'bankTransactions': bankTransactions.map((e) => e.toMap()).toList(),
    'conversations': conversations.map((e) => e.toMap()).toList(),
    'appointments': appointments.map((e) => e.toMap()).toList(),
    'prospects': prospects.map((e) => e.toMap()).toList(),
    'auditLog': auditLog.map((e) => e.toMap()).toList(),
  };

  /// Sérialise l'état sous forme de chaîne JSON lisible (sauvegarde fichier).
  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(exportState());

  /// Indicateurs résumés des données actuelles (affichage sauvegarde).
  Map<String, int> get dataCounts => {
    'clients': clients.length,
    'requests': requests.length,
    'providers': providers.length,
    'bookings': bookings.length,
    'itineraries': itineraries.length,
    'financeDocs': financeDocs.length,
    'expenses': expenses.length,
    'users': users.length,
    'auditLog': auditLog.length,
  };

  /// Restaure les données à partir d'une sauvegarde JSON.
  ///
  /// [rawJson] peut être la chaîne JSON complète ou directement la carte
  /// d'état. La session courante est clôturée pour éviter toute incohérence
  /// d'identifiants après remplacement des données. La méthode conserve une
  /// copie des données précédentes et restaure l'état antérieur en cas
  /// d'erreur de lecture (transaction tout-ou-rien).
  Future<void> importJson(String rawJson) async {
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('JSON invalide.');
    }
    await _applyImport(parsed);
  }

  /// Variante acceptant directement une carte d'état (tests / appel interne).
  ///
  /// [closeSession] = false conserve la session courante (utilisé par la
  /// synchronisation temps réel, pour ne pas déconnecter l'utilisateur à chaque
  /// mise à jour distante).
  Future<void> importMap(
    Map<String, dynamic> data, {
    bool closeSession = true,
  }) => _applyImport(data, closeSession: closeSession);

  Future<void> _applyImport(
    Map<String, dynamic> data, {
    bool closeSession = true,
  }) async {
    // Validation stricte AVANT toute mutation d'état : la sauvegarde doit
    // contenir des utilisateurs et des clients non vides.
    final usersRaw = data['users'];
    final clientsRaw = data['clients'];
    if (usersRaw is! List ||
        clientsRaw is! List ||
        usersRaw.isEmpty ||
        clientsRaw.isEmpty) {
      throw const FormatException(
        'Sauvegarde invalide ou vide : utilisateurs/clients manquants.',
      );
    }

    // Copie de sécurité de l'état courant.
    final snapshot = exportState();
    final previousUser = currentUser;

    try {
      // Repartir d'une base vierge pour ne pas conserver d'éléments résiduels
      // absents de la sauvegarde.
      _clearData();
      _hydrate(data);
      if (closeSession) {
        currentUser = null; // session close → reconnexion requise
      } else if (previousUser != null) {
        // Conserver la session : ré-aligner l'objet sur les nouvelles données.
        final idx = users.indexWhere((u) => u.id == previousUser.id);
        currentUser = idx >= 0 ? users[idx] : null;
      }
      log(
        'Restauration sauvegarde',
        'Données locales',
        detail:
            '${dataCounts['clients']} clients · ${dataCounts['requests']} demandes',
      );
      await _persist();
      notifyListeners();
    } catch (e) {
      // Rollback : on restaure l'état antérieur et la session.
      _clearData();
      _hydrate(snapshot);
      currentUser = previousUser;
      await _persist();
      notifyListeners();
      throw FormatException('Restauration échouée : $e');
    }
  }

  /// Vide tous les jeux de données (utilisé avant import / restauration).
  void _clearData() {
    users = [];
    clients = [];
    requests = [];
    providers = [];
    bookings = [];
    itineraries = [];
    financeDocs = [];
    expenses = [];
    bankTransactions = [];
    conversations = [];
    appointments = [];
    prospects = [];
    tiers = [];
    auditLog = [];
  }

  /// Efface toutes les données locales et réinitialise l'application.
  Future<void> wipeAll() async {
    _clearData();
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  // ─────────────────────── SYNCHRONISATION CLOUD (Firestore) ───────────────────────
  /// Vrai si le backend Cloud (Firestore) est initialisé et exploitable.
  bool get cloudAvailable => FirestoreService.available;

  /// Date de la dernière synchronisation cloud réussie (session courante).
  DateTime? lastCloudSync;

  /// Pousse l'intégralité de l'état local vers Firestore.
  /// Retourne la date d'écriture. Lève [CloudException] en cas d'échec.
  Future<DateTime> pushToCloud() async {
    final at = await FirestoreService.pushState(exportState());
    lastCloudSync = at;
    log('Synchronisation cloud', 'Envoi', detail: 'État complet transmis');
    await _persist();
    notifyListeners();
    return at;
  }

  /// Récupère l'état précédemment poussé depuis Firestore et l'applique.
  /// Retourne la date de synchronisation, ou null si aucune donnée cloud.
  Future<DateTime?> pullFromCloud() async {
    final remote = await FirestoreService.pullState();
    if (remote == null) return null;
    await _applyImport(remote.payload);
    lastCloudSync = remote.syncedAt;
    notifyListeners();
    return remote.syncedAt;
  }

  /// Nombre de documents par collection du backend GOREX (diagnostic).
  Future<Map<String, int>> cloudCollectionCounts() =>
      FirestoreService.collectionCounts();

  // ── Synchronisation TEMPS RÉEL ──
  StreamSubscription<({Map<String, dynamic> payload, DateTime syncedAt})>?
  _cloudSub;
  bool _liveSync = false;
  DateTime? lastRemoteUpdate;

  /// Vrai si l'abonnement temps réel Firestore est actif.
  bool get liveSyncEnabled => _liveSync;

  /// Démarre l'écoute temps réel du document cloud.
  ///
  /// À chaque mise à jour distante, l'état local est réaligné (la session
  /// courante est conservée). Les écritures déclenchées localement par cette
  /// synchronisation sont ignorées grâce à [_applyingRemote] (anti-boucle).
  bool startLiveSync() {
    if (!FirestoreService.available) return false;
    if (_liveSync) return true;
    _liveSync = true;
    _cloudSub = FirestoreService.watchState().listen(
      (event) async {
        if (_applyingRemote) return;
        if (event.payload.isEmpty) return;
        _applyingRemote = true;
        try {
          final before = lastRemoteUpdate;
          if (before != null && !event.syncedAt.isAfter(before)) return;
          await importMap(event.payload, closeSession: false);
          lastRemoteUpdate = event.syncedAt;
        } catch (e) {
          if (kDebugMode) debugPrint('[Cloud] apply remote failed: $e');
        } finally {
          _applyingRemote = false;
        }
      },
      onError: (e) {
        if (kDebugMode) debugPrint('[Cloud] live stream error: $e');
      },
    );
    notifyListeners();
    return true;
  }

  /// Arrête l'écoute temps réel.
  Future<void> stopLiveSync() async {
    await _cloudSub?.cancel();
    _cloudSub = null;
    _liveSync = false;
    notifyListeners();
  }

  /// Anti-boucle : vrai pendant l'application d'une mise à jour distante.
  bool _applyingRemote = false;

  @override
  void dispose() {
    _cloudSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────── AUTH ───────────────────────────
  /// Authentification de repli (locale). Conservée pour les tests unitaires et
  /// le mode hors-ligne. En production, la connexion passe par [signInWithFirebase].
  AppUser? authenticate(String email, String password) {
    final e = email.trim().toLowerCase();
    for (var i = 0; i < users.length; i++) {
      final u = users[i];
      // Refus explicite si aucun mot de passe n'est connu localement : sans
      // cette garde, un enregistrement dont le mot de passe a été vidé (car
      // il n'est plus persisté) pourrait être ouvert avec une saisie vide.
      if (u.password.isEmpty) continue;
      if (u.email.toLowerCase() == e && u.password == password && u.active) {
        final updated = u.copyWith(lastLogin: DateTime.now());
        users[i] = updated;
        currentUser = updated;
        log('Connexion', updated.email);
        _persist();
        notifyListeners();
        return updated;
      }
    }
    return null;
  }

  /// Connexion RÉELLE via Firebase Auth (e-mail / mot de passe).
  ///
  /// Retourne `true` si la connexion réussit. L'utilisateur métier est ensuite
  /// résolu depuis Firestore (`staff/{uid}` puis `users` par e-mail).
  /// En l'absence de Firebase (tests, hors-ligne), retombe sur le repli local.
  Future<bool> signInWithFirebase(String email, String password) async {
    // Message de diagnostic précis de la dernière tentative (affiché à l'écran).
    lastAuthError = null;
    final e = email.trim().toLowerCase();
    // Assainissement : on retire tout espace (copier-coller, clavier mobile).
    final pwd = password.replaceAll(RegExp(r'\s'), '');

    // ═══════════════════════════════════════════════════════════════════════
    // ÉTAPE 1 — VOIE PRINCIPALE : API REST officielle Google/Firebase.
    //
    // Aucun SDK JavaScript, aucun script tiers, aucun pré-vol CORS : c'est la
    // voie la plus robuste et elle fonctionne sur Safari (macOS / iOS) comme
    // sur Chrome, Firefox, Edge et sur Android.
    // ═══════════════════════════════════════════════════════════════════════
    final rest = await _signInViaRest(e, pwd);
    if (rest != null) return rest; // true = connecté, false = refus définitif.

    // ═══════════════════════════════════════════════════════════════════════
    // ÉTAPE 2 — SECOURS : SDK Firebase (si le réseau REST est injoignable).
    // ═══════════════════════════════════════════════════════════════════════
    FirebaseSignInResult res;
    try {
      res = await FirebaseAuthService.signIn(e, pwd);
    } catch (_) {
      res = FirebaseSignInResult.unavailable;
    }

    // SDK totalement indisponible → dernier repli local (hors production).
    if (res.error == 'FIREBASE_UNAVAILABLE' && !res.ok) {
      final local = authenticate(email, password);
      if (local != null) {
        await _logAudit('Connexion', local.email, detail: 'mode local');
        return true;
      }
      lastAuthError ??=
          'Service de connexion indisponible. Vérifiez votre connexion internet.';
      return false;
    }

    if (!res.ok) {
      lastAuthError = _authMessage(res.error);
      return false;
    }

    // Résolution du profil métier : personnel (staff) puis client.
    AppUser? profile;
    final uid = res.uid;
    if (uid != null) {
      try {
        final rows = await FirestoreService.fetchCollection(
          'staff',
          limit: 100,
        );
        for (final r in rows) {
          if (r['uid'] == uid || r['id'] == uid) {
            profile = _profileFromStaff(r);
            break;
          }
        }
      } catch (_) {}
    }
    // Pas du personnel → tentative de résolution en tant que client.
    if (profile == null) {
      try {
        final rows = await FirestoreService.fetchCollection(
          'clients',
          limit: 300,
        );
        for (final r in rows) {
          final re = (r['email'] as String?)?.toLowerCase();
          if (re != null && re == e) {
            profile = _profileFromClientRow(r);
            _upsertClientFromRow(r);
            break;
          }
        }
      } catch (_) {}
    }
    // Repli local : UNIQUEMENT hors production (comptes de démonstration).
    if (profile == null && AppConfig.showDemoAccounts) {
      profile = _localUserByEmail(e);
    }

    if (profile == null) {
      // Compte Firebase valide mais sans profil métier : accès refusé.
      await FirebaseAuthService.signOut();
      await _logAudit('Connexion refusée', e, detail: 'profil introuvable');
      lastAuthError =
          'Ce compte n\'est pas habilité à accéder au portail. Contactez l\'administrateur.';
      return false;
    }

    // Le profil d'identité (`user_profiles/{uid}`) est créé UNE FOIS, au
    // moment de l'inscription, avec son rôle et son `clientId`. Il ne doit
    // JAMAIS être réécrit par le navigateur : le rôle est une donnée
    // d'autorisation, et si le client pouvait la modifier il pourrait
    // s'attribuer les droits du CEO.
    //
    // On ne maintient donc que les clés inoffensives (uid, e-mail), et
    // uniquement pour un compte client : les fiches du personnel sont gérées
    // par la direction.
    if (uid != null && profile.role == UserRole.vipClient) {
      try {
        await FirestoreService.updateDocument('user_profiles', uid, {
          'uid': uid,
          'email': e,
        });
      } catch (_) {}
    }

    currentUser = profile.copyWith(lastLogin: DateTime.now());
    await _persist();
    await _logAudit('Connexion', e, detail: 'firebase');
    await loadTeamFromCloud();
    await loadOperationalFromCloud();
    await loadProvidersFromCloud();
    await loadCompanyFromCloud();
    await loadPeppolSecretFromCloud();
    await loadTiersFromCloud();
    await syncSubscriptionsFromCloud();
    await syncSepaFromCloud();
    notifyListeners();
    return true;
  }

  /// Connexion via les API REST officielles (sans SDK JavaScript).
  ///
  /// VOIE PRINCIPALE sur le Web. Retourne :
  ///   • `true`  → connexion réussie, [currentUser] renseigné ;
  ///   • `false` → refus définitif (identifiants invalides, compte non habilité) :
  ///               le message est déjà positionné dans [lastAuthError] ;
  ///   • `null`  → réseau REST injoignable : l'appelant enchaîne sur le SDK.
  Future<bool?> _signInViaRest(String email, String password) async {
    final r = await RestAuthService.signIn(email, password);

    if (!r.ok) {
      // Panne réseau / réponse inexploitable → on laisse sa chance au SDK.
      if (r.error == 'NETWORK' || r.error == 'UNKNOWN') return null;
      // Erreur d'identifiants : message précis, inutile d'insister.
      lastAuthError = _authMessage(r.error);
      return false;
    }

    return _openRestSession(email, r.uid, r.idToken, password: password);
  }

  /// Connexion via un code de réinitialisation de mot de passe.
  ///
  /// Utilisée par l'écran de réinitialisation : la personne n'a plus à saisir
  /// son mot de passe une seconde fois, puisque `accounts:resetPassword`
  /// retourne directement un jeton de connexion.
  ///
  /// Le compte est CONSERVÉ : mêmes `uid`, mêmes dossiers, même rôle.
  /// Si l'adresse ne correspond à aucune fiche métier, la session n'est pas
  /// ouverte et le message explique de contacter l'administrateur — le mot de
  /// passe reste néanmoins modifié côté Firebase.
  Future<bool?> signInAfterPasswordReset(
    String oobCode,
    String newPassword,
  ) async {
    resetAttempted = true;
    final r = await RestAuthService.resetPassword(oobCode, newPassword);
    if (!r.ok) {
      if (r.error == 'NETWORK' || r.error == 'UNKNOWN') return null;
      if (r.error == 'EXPIRED_OOB_CODE') {
        lastAuthError =
            'Ce lien a expiré. Demandez un nouveau lien de réinitialisation.';
        return false;
      }
      if (r.error == 'INVALID_OOB_CODE') {
        lastAuthError =
            'Ce lien n\'est plus valide (déjà utilisé ou incomplet). '
            'Demandez un nouveau lien de réinitialisation.';
        return false;
      }
      if (r.error == 'WEAK_PASSWORD') {
        lastAuthError =
            'Mot de passe refusé : 12 caractères minimum, avec majuscule, '
            'minuscule, chiffre et symbole.';
        return false;
      }
      lastAuthError = 'La réinitialisation a échoué. Réessayez dans un instant.';
      return false;
    }

    final email = r.email ?? '';
    await _logAudit(
      'Mot de passe réinitialisé',
      email,
      detail: 'lien e-mail',
    );
    final opened = await _openRestSession(email, r.uid, r.idToken);
    if (opened == true) {
      // Mot de passe choisi par la personne elle-même : la contrainte de
      // changement à la première connexion n'a plus lieu d'être.
      final u = currentUser;
      if (u != null && u.mustChangePassword) {
        final uid = restUid;
        final token = restIdToken;
        if (uid != null && token != null) {
          await RestAuthService.clearMustChangePassword(uid, token);
          currentUser = u.copyWith(mustChangePassword: false);
          final i = users.indexWhere((e) => e.id == u.id);
          if (i >= 0) users[i] = currentUser!;
          await _persist();
          notifyListeners();
        }
      }
    }
    return opened;
  }

  /// Ouvre la session applicative à partir d'un jeton Firebase déjà obtenu.
  ///
  /// Extraite pour être partagée par la connexion classique et par la
  /// réinitialisation de mot de passe : les deux doivent charger le profil
  /// métier, le jeton REST et les données cloud de façon IDENTIQUE.
  Future<bool?> _openRestSession(
    String email,
    String? uid,
    String? token, {
    String? password,
  }) async {
    if (uid == null || token == null || token.isEmpty) return null;

    // Nouvelle session = nouveau bilan. Sans ce nettoyage, une fiche signalée
    // lors d'une connexion précédente resterait affichée indéfiniment. Le
    // nettoyage est ici, et non dans `loadOperationalFromCloud`, parce que
    // `_upsertClientFromRow` s'exécute AVANT cette synchronisation : effacer
    // plus tard détruirait justement l'erreur de connexion qu'on veut garder.
    _clientDecodeErrors.clear();

    // Résolution du profil métier : personnel (`staff`) puis client (`clients`).
    AppUser? profile;

    // ── ÉTAPE PRÉALABLE : le profil d'identité (404/403 CORRIGÉS) ────────
    //
    // DÉFAUT CORRIGÉ. La résolution commençait par sonder `staff/{uid}`, puis
    // `staff` par e-mail. Pour un CLIENT — c'est-à-dire l'immense majorité des
    // comptes — ces deux appels échouaient : 404 sur un document inexistant,
    // 403 sur une collection réservée au personnel. Deux erreurs rouges dans
    // la console à chaque connexion, pour un cas parfaitement normal.
    //
    // `user_profiles/{uid}` est lisible par son propre titulaire (règle :
    // `request.auth.uid == uid || isStaff()`). Une seule lecture, autorisée,
    // donne le rôle ET le dossier. On ne sonde plus au hasard.
    //
    // Repli conservé : les comptes plus anciens peuvent ne pas avoir de
    // `user_profiles`. Dans ce cas seulement, l'ancienne résolution s'applique.
    String? roleFromProfile;
    String? clientIdFromProfile;
    try {
      final own = await RestAuthService.fetchDocument(
        'user_profiles/$uid',
        token,
      );
      if (own != null) {
        roleFromProfile = own['role'] as String?;
        clientIdFromProfile = own['clientId'] as String?;
      }
    } catch (_) {
      // Lecture impossible : on retombera sur la résolution historique.
    }

    // Client : le profil d'identité suffit, on lit directement sa fiche.
    if (roleFromProfile == UserRole.vipClient.name) {
      final clientFetch = await RestAuthService.findClientByEmail(email, token);
      final clientRow = clientFetch.data;
      if (clientRow != null) {
        profile = _profileFromClientRow(clientRow);
        _upsertClientFromRow(clientRow);
      }
      if (profile == null && clientIdFromProfile != null &&
          clientIdFromProfile.isNotEmpty) {
        // Repli : la fiche est peut-être indexée sous un autre e-mail.
        final direct = await RestAuthService.fetchDocument(
          'clients/$clientIdFromProfile',
          token,
        );
        if (direct != null) {
          profile = _profileFromClientRow(direct);
          _upsertClientFromRow(direct);
        }
      }
    }

    if (profile == null && roleFromProfile == null) {
      // Compte sans profil d'identité : résolution historique (personnel).
      final staffFetch = await RestAuthService.fetchStaffProfile(uid, token);
      var row = staffFetch.data;
      if (row == null) {
        final byEmail = await RestAuthService.findStaffByEmail(email, token);
        row = byEmail.data;
      }
      if (row != null) profile = _profileFromStaff(row);
    } else if (profile == null && roleFromProfile != UserRole.vipClient.name) {
      // Profil d'identité indiquant un rôle de personnel : on charge sa fiche.
      final staffFetch = await RestAuthService.fetchStaffProfile(uid, token);
      var row = staffFetch.data;
      if (row == null) {
        final byEmail = await RestAuthService.findStaffByEmail(email, token);
        row = byEmail.data;
      }
      if (row != null) profile = _profileFromStaff(row);
    }

    // Repli local : UNIQUEMENT hors production (comptes de démonstration).
    if (profile == null && AppConfig.showDemoAccounts) {
      profile = _localUserByEmail(email);
    }

    if (profile == null) {
      await _logAudit('Connexion refusée', email, detail: 'profil introuvable');
      lastAuthError =
          'Ce compte n\'est pas habilité à accéder au portail. '
          'Contactez l\'administrateur.';
      return false;
    }

    // ── CONTRÔLE DE ROBUSTESSE DU MOT DE PASSE ──────────────────────────
    // Firebase n'applique aucune longueur minimale : un compte dont le mot de
    // passe a été défini sur la page générique de réinitialisation peut très
    // bien n'avoir que six caractères. Cette vérification est faite ICI, à la
    // connexion, car c'est le seul endroit où le mot de passe est disponible
    // en clair. Un mot de passe faible ne bloque pas l'accès (la personne
    // resterait sinon enfermée dehors) : il ouvre la session puis impose le
    // choix d'un mot de passe conforme, exactement comme à la première
    // connexion. La fiche Firestore n'est pas modifiée : le drapeau est local,
    // ce qui évite d'exiger une écriture non autorisée pour un client.
    if (password != null &&
        password.isNotEmpty &&
        PasswordPolicy.validate(password).isNotEmpty) {
      profile = profile.copyWith(mustChangePassword: true);
      mustChangeReason = 'weak-password';
    }

    currentUser = profile.copyWith(lastLogin: DateTime.now());
    restIdToken = token;
    restUid = uid;
    await _persist();
    await _logAudit('Connexion', email, detail: 'firebase-rest');
    // Le jeton existe maintenant : on charge l'équipe réelle depuis Firestore
    // pour que « Équipe » et « Accès personnel » affichent les vrais comptes.
    await loadTeamFromCloud();
    await loadOperationalFromCloud();
    await loadProvidersFromCloud();
    await loadCompanyFromCloud();
    await loadPeppolSecretFromCloud();
    await loadTiersFromCloud();
    await syncSubscriptionsFromCloud();
    await syncSepaFromCloud();
    notifyListeners();
    return true;
  }

  /// Traduit un code d'erreur Firebase en message utilisateur explicite.
  String _authMessage(String? code) {
    switch (code) {
      case 'EMAIL_NOT_FOUND':
        return 'Aucun compte ne correspond à cet e-mail.';
      case 'WRONG_PASSWORD':
        return 'Mot de passe incorrect. Attention aux majuscules/minuscules.';
      case 'INVALID_EMAIL':
        return 'Adresse e-mail invalide (vérifiez qu\'il n\'y a pas d\'espace).';
      case 'INVALID_LOGIN_CREDENTIALS':
      case 'INVALID_CREDENTIAL':
        return 'E-mail ou mot de passe incorrect.';
      case 'USER_DISABLED':
        return 'Ce compte a été désactivé. Contactez l\'administrateur.';
      case 'TOO_MANY_REQUESTS':
        return 'Trop de tentatives. Patientez quelques minutes.';
      case 'NETWORK_REQUEST_FAILED':
      case 'NETWORK-REQUEST-FAILED':
      case 'NETWORK':
        return 'Connexion au serveur impossible. Vérifiez votre connexion internet.';
      case 'UNKNOWN':
        return 'Connexion au serveur impossible. Réessayez dans un instant.';
      case 'OPERATION_NOT_ALLOWED':
        return 'La connexion par e-mail n\'est pas activée sur le projet.';
      default:
        return code == null || code.isEmpty
            ? 'Identifiants invalides. Veuillez réessayer.'
            : 'Erreur de connexion ($code).';
    }
  }

  /// Construit un [AppUser] depuis une fiche Firestore `clients/{id}`.
  AppUser? _profileFromClientRow(Map<String, dynamic> r) {
    final email = (r['email'] as String?) ?? '';
    if (email.isEmpty) return null;
    final id = (r['id'] as String?) ?? email;
    return AppUser(
      id: 'client_$id',
      fullName: (r['fullName'] as String?) ?? email,
      email: email,
      password: '',
      role: UserRole.vipClient,
      phone: r['phone'] as String?,
      clientId: id,
      active: (r['active'] as bool?) ?? true,
      mustChangePassword: false,
    );
  }

  /// Charge (ou met à jour) un client depuis une ligne Firestore `clients`.
  void _upsertClientFromRow(Map<String, dynamic> r) {
    try {
      final c = Client.fromMap(Map<String, dynamic>.from(r));
      final i = clients.indexWhere((e) => e.id == c.id);
      if (i >= 0) {
        clients[i] = c;
      } else {
        clients.insert(0, c);
      }
    } catch (e) {
      // Un décodage qui échoue ne doit JAMAIS être silencieux.
      //
      // DÉFAUT CORRIGÉ. Ce bloc faisait `catch (_) {}` : une fiche client
      // légèrement incomplète (champ `createdAt` absent, `category` à null)
      // levait une exception, la fiche était jetée, et l'utilisateur se
      // retrouvait devant un espace vide — sans message, sans trace, sans
      // moyen de comprendre. J'ai moi-même cherché un « bug majeur » qui
      // n'était qu'un jeu de données incomplet, précisément parce que
      // l'erreur était muette.
      //
      // On ne fait pas échouer la connexion pour autant (le client doit
      // pouvoir entrer), mais on conserve la trace.
      _clientDecodeErrors.add(
        'Fiche ${r['id'] ?? '?'} illisible : ${e.runtimeType} — $e',
      );
      if (kDebugMode) {
        debugPrint('Fiche client illisible : $e');
      }
    }
  }

  /// Dernières fiches client dont le décodage a échoué.
  ///
  /// Exposé pour que l'interface puisse signaler le problème au personnel au
  /// lieu de laisser un dossier invisible sans explication.
  final List<String> _clientDecodeErrors = <String>[];
  List<String> get clientDecodeErrors => List.unmodifiable(_clientDecodeErrors);

  /// Construit un [AppUser] depuis une fiche Firestore `staff/{uid}`.
  AppUser? _profileFromStaff(Map<String, dynamic> r) {
    final email = (r['email'] as String?) ?? '';
    if (email.isEmpty) return null;
    // `displayName` est le nom officiel côté `staff` ; `fullName` n'existe que
    // si un enregistrement a été fait depuis le formulaire « Mon compte ».
    final name =
        (r['displayName'] as String?) ?? (r['fullName'] as String?) ?? email;
    final phone = (r['phone'] as String?) ?? '';
    return AppUser(
      id: (r['uid'] as String?) ?? (r['id'] as String?) ?? email,
      fullName: name,
      email: email,
      password: '',
      role: UserRole.fromName((r['role'] as String?) ?? 'concierge'),
      title: r['department'] as String?,
      // Le téléphone doit être relu en base : sans cela, la valeur enregistrée
      // n'est jamais réaffichée après une reconnexion (champ vide à l'écran
      // alors que la base la contient).
      phone: phone.trim().isEmpty ? null : phone.trim(),
      active: (r['active'] as bool?) ?? true,
      mustChangePassword: (r['mustChangePassword'] as bool?) ?? false,
    );
  }

  AppUser? _localUserByEmail(String email) {
    for (final u in users) {
      if (u.email.toLowerCase() == email) return u;
    }
    return null;
  }

  /// Envoie un lien de réinitialisation de mot de passe.
  ///
  /// REST d'abord (robuste, sans SDK), puis SDK en secours.
  ///
  /// Le lien renvoie vers l'application elle-même ([continueUrl]) : la
  /// personne choisit alors son mot de passe dans NOS écrans, où la règle des
  /// 12 caractères est appliquée, au lieu de la page générique Google.
  Future<bool> sendPasswordReset(String email) async {
    if (await RestAuthService.sendPasswordReset(
      email,
      continueUrl: AppConfig.passwordResetContinueUrl,
      locale: language,
    )) {
      return true;
    }
    return FirebaseAuthService.sendPasswordReset(email);
  }

  /// Change le mot de passe de l'utilisateur connecté (client VIP ou personnel).
  ///
  /// En production (session Firebase nominative), le mot de passe est mis à jour
  /// côté Firebase après ré-authentification ; en mode local, il est mis à jour
  /// dans l'état persisté.
  /// Retourne `true` si Firebase a réellement accepté le nouveau mot de passe.
  /// L'appelant doit vérifier ce résultat : un `false` signifie que le mot de
  /// passe est INCHANGÉ (jeton expiré, refus du service).
  Future<bool> changeOwnPassword(
    String newPassword, {
    String? currentPassword,
  }) async {
    final u = currentUser;
    if (u == null) return false;

    // Session REST (voie principale sur le Web) : mise à jour via l'API
    // officielle avec le jeton obtenu à la connexion.
    if (restIdToken != null && restUid != null) {
      final ok = await RestAuthService.updatePassword(
        restIdToken!,
        newPassword,
      );
      if (!ok) {
        // Sans message, l'écran de changement affichait « succès » alors que
        // Firebase avait refusé (jeton de session expiré, par exemple).
        lastAuthError =
            'La modification a été refusée par le service '
            'd\'authentification : la session a probablement expiré. '
            'Déconnectez-vous puis reconnectez-vous pour réessayer.';
        return false;
      }
      await RestAuthService.clearMustChangePassword(restUid!, restIdToken!);
    } else if (FirebaseAuthService.isNamedUser) {
      if (currentPassword != null) {
        final ok = await FirebaseAuthService.reauthenticate(currentPassword);
        if (!ok) {
          lastAuthError = 'Mot de passe actuel incorrect.';
          return false;
        }
      }
      final ok = await FirebaseAuthService.updatePassword(newPassword);
      if (!ok) {
        lastAuthError =
            'La modification a été refusée par le service '
            'd\'authentification. Reconnectez-vous puis réessayez.';
        return false;
      }
      await _persistStaffFlag(clearMustChange: true);
    }

    final i = users.indexWhere((e) => e.id == u.id || e.email == u.email);
    if (i >= 0) {
      final updated = users[i].copyWith(
        password: newPassword,
        mustChangePassword: false,
      );
      users[i] = updated;
      currentUser = updated;
    } else {
      currentUser = u.copyWith(mustChangePassword: false);
    }
    log('Changement mot de passe', u.email);
    mustChangeReason = null;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Met à jour le drapeau `mustChangePassword` dans la fiche Firestore `staff`.
  Future<void> _persistStaffFlag({required bool clearMustChange}) async {
    try {
      final rows = await FirestoreService.fetchCollection('staff', limit: 50);
      for (final r in rows) {
        final email = (r['email'] as String?)?.toLowerCase();
        if (email != null && email == currentUser?.email.toLowerCase()) {
          await FirestoreService.updateDocument('staff', (r['id'] as String), {
            'mustChangePassword': !clearMustChange,
          });
          break;
        }
      }
    } catch (_) {}
  }

  void logout() {
    if (currentUser != null) log('Déconnexion', currentUser!.email);
    // Ferme toute session Firebase. Aucune session anonyme n'est recréée :
    // les règles de production exigent un utilisateur nominatif.
    FirebaseAuthService.signOut();
    currentUser = null;
    restIdToken = null;
    restUid = null;
    notifyListeners();
  }

  /// Écrit une entrée dans le journal d'audit (local + Firestore si dispo).
  Future<void> _logAudit(String action, String target, {String? detail}) async {
    log(action, target);
    final payload = {
      'type': 'auth_event',
      'action': action,
      'actor': target,
      'target': detail ?? target,
      // UTC impératif : Firestore REST refuse un horodatage sans fuseau.
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    // REST d'abord : la piste d'audit doit être persistée même lorsque le SDK
    // Firebase est indisponible (Safari notamment).
    if (restIdToken != null) {
      final ok = await RestAuthService.appendAuditLog(restIdToken!, payload);
      if (ok) return;
    }
    try {
      await FirestoreService.addDocument('audit_log', payload);
    } catch (_) {}
  }

  // ─────────────────────────── LANGUE ───────────────────────────
  /// Change la langue de l'interface et la persiste.
  Future<void> setLanguage(String code) async {
    if (code == language) return;
    language = code;
    log('Changement de langue', code.toUpperCase());
    await _persist();
    notifyListeners();
  }

  /// Traduit une clé selon la langue active (délègue à L10n).
  String tr(String key) => L10n.tr(language, key);

  bool get isStaff => currentUser?.role.isStaff ?? false;
  bool get isCeo => currentUser?.role == UserRole.ceo;
  bool get isClient => currentUser?.role == UserRole.vipClient;

  Client? get currentClient {
    final id = currentUser?.clientId;
    if (id == null) return null;
    return clientById(id);
  }

  /// Client à utiliser pour les écrans staff (premier client) ou le client connecté
  Client? get effectiveClient =>
      currentClient ?? (clients.isNotEmpty ? clients.first : null);

  // ─────────────────────────── PERMISSIONS ───────────────────────────
  bool can(String permission) {
    final role = currentUser?.role;
    if (role == null) return false;
    switch (permission) {
      case 'finance':
        return role == UserRole.ceo || role == UserRole.finance;
      case 'team':
        return role == UserRole.ceo || role == UserRole.conciergeManager;
      case 'user_access':
        return role == UserRole.ceo || role == UserRole.conciergeManager;
      // Décision d'ouverture d'un compte client : encadrement uniquement.
      // Doit rester aligné sur la fonction `isApprover()` des règles Firestore,
      // faute de quoi l'écran s'afficherait puis échouerait à l'enregistrement.
      case 'client_approval':
        return role == UserRole.ceo ||
            role == UserRole.conciergeManager ||
            role == UserRole.seniorConcierge;
      case 'subscriptions':
        return role == UserRole.ceo;
      case 'security':
        return role == UserRole.ceo ||
            role == UserRole.securityCoordinator ||
            role == UserRole.conciergeManager;
      case 'crm':
        return role != UserRole.vipClient && role != UserRole.finance;
      case 'dashboard_ceo':
        return role == UserRole.ceo;
      case 'all_clients':
        return role == UserRole.ceo ||
            role == UserRole.conciergeManager ||
            role == UserRole.finance;
      default:
        return role.isStaff;
    }
  }

  // ─────────────────────────── LOOKUPS ───────────────────────────
  Client? clientById(String? id) {
    if (id == null) return null;
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  SubscriptionTier? tierById(String? id) {
    if (id == null) return null;
    for (final t in tiers) {
      if (t.id == id) return t;
    }
    return null;
  }

  AppUser? userById(String? id) {
    if (id == null) return null;
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  Provider? providerById(String? id) {
    if (id == null) return null;
    for (final p in providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  ServiceRequest? requestById(String id) {
    for (final r in requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  Itinerary? itineraryById(String id) {
    for (final i in itineraries) {
      if (i.id == id) return i;
    }
    return null;
  }

  FinanceDocument? financeById(String id) {
    for (final f in financeDocs) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<Booking> bookingsForRequest(String requestId) =>
      bookings.where((b) => b.requestId == requestId).toList();

  /// Pièces déjà émises pour une réservation donnée.
  List<FinanceDocument> financeForBooking(String bookingId) =>
      financeDocs.where((f) => f.bookingId == bookingId).toList();

  /// Facture (au sens strict) déjà émise pour cette réservation, s'il y en a
  /// une. Sert de garde-fou contre la double facturation : une prestation ne
  /// peut donner lieu qu'à UNE facture.
  FinanceDocument? invoiceForBooking(String bookingId) {
    for (final f in financeDocs) {
      if (f.bookingId == bookingId && f.type == FinanceDocType.invoice) {
        return f;
      }
    }
    return null;
  }

  List<Booking> bookingsForClient(String clientId) =>
      bookings.where((b) => b.clientId == clientId).toList();

  List<ServiceRequest> requestsForClient(String clientId) =>
      requests.where((r) => r.clientId == clientId).toList();

  List<FinanceDocument> financeForClient(String clientId) =>
      financeDocs.where((f) => f.clientId == clientId).toList();

  List<Conversation> conversationsForClient(String clientId) =>
      conversations.where((c) => c.clientId == clientId).toList();

  List<Appointment> appointmentsForClient(String clientId) =>
      appointments.where((a) => a.clientId == clientId).toList();

  List<Appointment> appointmentsForUser(String userId) =>
      appointments.where((a) => a.ownerId == userId).toList();

  List<Appointment> get upcomingAppointments {
    final now = DateTime.now();
    final list = appointments.where((a) => a.end.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  // ─────────────────────────── AUDIT / LOG ───────────────────────────
  void log(String action, String target, {String? detail}) {
    auditLog.insert(
      0,
      AuditEntry(
        id: 'aud_${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        actor: currentUser?.fullName ?? 'Système',
        actorRole: currentUser?.role.label ?? 'System',
        action: action,
        target: target,
        detail: detail,
      ),
    );
    if (auditLog.length > 300) auditLog = auditLog.sublist(0, 300);
  }

  // ─────────────────────────── REQUESTS ───────────────────────────
  String _nextRequestRef() {
    final n = requests.length + 1;
    return 'GRX-REQ-2025-${n.toString().padLeft(4, '0')}';
  }

  Future<ServiceRequest> createRequest({
    required String clientId,
    required ServiceDomain domain,
    required String subService,
    required String title,
    required String description,
    required DateTime date,
    required String time,
    required String location,
    required UrgencyLevel urgency,
    required double budget,
    bool securityEscalation = false,
    String? escalationNote,
  }) async {
    // ── VALIDATION OBLIGATOIRE ──
    // Un dossier en attente (ou refusé) ne peut pas solliciter la
    // conciergerie : le compte existe, mais les services restent fermés
    // jusqu'à la décision du personnel. Cette garde est côté application ;
    // elle complète les règles Firestore, qui empêchent déjà le client de
    // s'auto-valider.
    final demandeur = clientById(clientId);
    if (demandeur != null && !demandeur.hasServiceAccess) {
      throw ClientNotApprovedException(
        demandeur.isRejected
            ? 'Votre demande n\'a pas été acceptée. Contactez la conciergerie '
                  'pour en connaître le motif.'
            : 'Votre compte est en cours de validation. Vous pourrez adresser '
                  'des demandes dès qu\'il aura été accepté.',
      );
    }
    final client = clientById(clientId);
    final r = ServiceRequest(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}',
      reference: _nextRequestRef(),
      clientId: clientId,
      clientName: client?.fullName ?? 'Client',
      domain: domain,
      subService: subService,
      title: title,
      description: description,
      date: date,
      time: time,
      location: location,
      urgency: urgency,
      budget: budget,
      status: urgency == UrgencyLevel.urgent || urgency == UrgencyLevel.critical
          ? RequestStatus.underReview
          : RequestStatus.new_,
      isSecurityEscalated: securityEscalation,
      escalationNote: escalationNote,
      history: [
        RequestHistoryEntry(
          timestamp: DateTime.now(),
          actor: currentUser?.fullName ?? 'Client',
          action: securityEscalation
              ? 'Demande créée — SÉCURITÉ'
              : 'Demande créée',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    requests.insert(0, r);
    log('Création demande', r.reference, detail: title);
    await _persist();
    notifyListeners();

    // Sauvegarde serveur OBLIGATOIRE : une demande est un engagement
    // contractuel envers le client. Si l'écriture échoue, on retire la demande
    // de l'état local et on signale l'échec, plutôt que d'afficher une demande
    // que le serveur ne connaît pas.
    //
    // `clientEmail` est ajouté au document : c'est le champ sur lequel les
    // règles de sécurité autorisent un client à relire SES demandes. Sans lui,
    // la lecture de collection était refusée (403).
    final payload = r.toMap();
    final ownerEmail = client?.email.trim().toLowerCase();
    if (ownerEmail != null && ownerEmail.isNotEmpty) {
      payload['clientEmail'] = ownerEmail;
    }
    final ok = await _pushToCloud('requests', payload, docId: r.id);
    if (!ok) {
      requests.removeWhere((e) => e.id == r.id);
      await _persist();
      notifyListeners();
      throw const CloudWriteException('Demande de service');
    }
    return r;
  }

  Future<void> updateRequestStatus(
    String id,
    RequestStatus status, {
    String? note,
  }) async {
    final i = requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = requests[i];
    final history = [
      ...r.history,
      RequestHistoryEntry(
        timestamp: DateTime.now(),
        actor: currentUser?.fullName ?? 'Système',
        action: 'Statut → ${status.code}',
        detail: note,
      ),
    ];
    final updated = r.copyWith(
      status: status,
      history: history,
      updatedAt: DateTime.now(),
    );

    // Serveur d'abord : en cas de refus, le statut affiché reste l'ancien.
    final ok = await _pushToCloud('requests', {
      'status': updated.status.name,
      'history': updated.history.map((e) => e.toMap()).toList(),
      'updatedAt': updated.updatedAt.toUtc().toIso8601String(),
    }, docId: id);
    if (!ok) throw const CloudWriteException('Statut de la demande');

    requests[i] = updated;
    log('Changement statut', r.reference, detail: status.code);
    await _persist();
    notifyListeners();
  }

  Future<void> assignRequest(String id, AppUser user) async {
    final i = requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = requests[i];
    final updated = r.copyWith(
      responsibleId: user.id,
      responsibleName: user.fullName,
      history: [
        ...r.history,
        RequestHistoryEntry(
          timestamp: DateTime.now(),
          actor: currentUser?.fullName ?? 'Système',
          action: 'Responsable assigné : ${user.fullName}',
        ),
      ],
      updatedAt: DateTime.now(),
    );

    final ok = await _pushToCloud('requests', {
      'responsibleId': updated.responsibleId,
      'responsibleName': updated.responsibleName,
      'history': updated.history.map((e) => e.toMap()).toList(),
      'updatedAt': updated.updatedAt.toUtc().toIso8601String(),
    }, docId: id);
    if (!ok) throw const CloudWriteException('Assignation de la demande');

    requests[i] = updated;
    log('Assignation', r.reference, detail: user.fullName);
    await _persist();
    notifyListeners();
  }

  Future<void> updateRequest(ServiceRequest updated) async {
    final i = requests.indexWhere((r) => r.id == updated.id);
    if (i < 0) return;
    final next = updated.copyWith(updatedAt: DateTime.now());
    final ok = await _pushToCloud('requests', next.toMap(), docId: next.id);
    if (!ok) throw const CloudWriteException('Demande de service');
    requests[i] = next;
    await _persist();
    notifyListeners();
  }

  Future<void> escalateToSecurity(String id) async {
    final i = requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = requests[i];
    final updated = r.copyWith(
      isSecurityEscalated: true,
      escalationNote:
          'Transmis à GOREX SECURITY le ${DateTime.now().toString().substring(0, 16)}',
      history: [
        ...r.history,
        RequestHistoryEntry(
          timestamp: DateTime.now(),
          actor: currentUser?.fullName ?? 'Système',
          action: 'Escalade GOREX SECURITY',
        ),
      ],
      updatedAt: DateTime.now(),
    );

    final ok = await _pushToCloud('requests', {
      'isSecurityEscalated': true,
      'escalationNote': updated.escalationNote,
      'history': updated.history.map((e) => e.toMap()).toList(),
      'updatedAt': updated.updatedAt.toUtc().toIso8601String(),
    }, docId: id);
    if (!ok) throw const CloudWriteException('Escalade sécurité');

    requests[i] = updated;
    log('Escalade sécurité', r.reference);
    await _persist();
    notifyListeners();
  }

  // ───────────────────── CHARGEMENT DES DONNÉES OPÉRATIONNELLES ─────────────────────

  /// Charge depuis Firestore les données opérationnelles réelles :
  /// demandes, réservations, itinéraires, factures et transactions bancaires.
  ///
  /// Sans cela, chaque connexion repartait de listes vides : ce qui avait été
  /// saisi lors d'une session précédente n'était jamais réaffiché.
  ///
  /// Les erreurs de lecture sont silencieuses : un échec réseau ne doit pas
  /// empêcher l'utilisateur de se connecter. En revanche aucune donnée
  /// fictive n'est injectée en remplacement.
  Future<void> loadOperationalFromCloud() async {
    final token = restIdToken;
    if (token == null || token.isEmpty) return;

    // Un client ne voit que ce qui lui appartient. Les règles de sécurité
    // s'appuient sur `resource.data` : Firestore refuse alors une lecture de
    // collection non filtrée (403) et exige une requête filtrée sur le champ
    // concerné. On filtre donc explicitement pour un client.
    final email = currentUser?.email.trim().toLowerCase();
    final clientId = currentUser?.clientId;
    final staff = isStaff;

    // Lit une collection selon le profil courant.
    //   · staff  → collection entière
    //   · client → uniquement les documents dont [ownerField] vaut [ownerValue]
    Future<List<Map<String, dynamic>>> read(
      String collection, {
      String? ownerField,
      String? ownerValue,
    }) async {
      try {
        if (staff) {
          final rows = await RestAuthService.fetchCollection(
            collection,
            token,
            limit: 300,
          );
          if (rows.isNotEmpty) return rows;
          if (FirestoreService.available) {
            try {
              return await FirestoreService.fetchCollection(
                collection,
                limit: 300,
              );
            } catch (_) {}
          }
          return rows;
        }
        if (ownerField == null || ownerValue == null || ownerValue.isEmpty) {
          return const [];
        }
        return await RestAuthService.queryCollection(
          collection,
          token,
          field: ownerField,
          value: ownerValue,
          limit: 300,
        );
      } catch (_) {
        return const [];
      }
    }

    // Convertit des cartes en objets, en ignorant les documents incomplets
    // plutôt que de faire échouer tout le lot.
    List<T> decode<T>(
      List<Map<String, dynamic>> rows,
      T Function(Map<String, dynamic>) fromMap,
    ) {
      final out = <T>[];
      for (final r in rows) {
        try {
          out.add(fromMap(Map<String, dynamic>.from(r)));
        } catch (_) {}
      }
      return out;
    }

    // ── Demandes de service ──
    final requestRows = await read(
      'requests',
      ownerField: 'clientEmail',
      ownerValue: email,
    );
    final loadedRequests = decode(requestRows, ServiceRequest.fromMap);
    if (loadedRequests.isNotEmpty) {
      requests = loadedRequests
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // ── Fiches clients (donnée métier indispensable au personnel) ──
    //
    // SANS CECI, un membre du personnel voyait « Aucun client enregistré » :
    // la connexion ne chargeait que les demandes, si bien qu'aucune
    // réservation ni facture ne pouvait être rattachée à un client, alors
    // même que les fiches existaient en base. Le personnel a le droit de
    // lire toute la collection (`isStaff()` dans les règles Firestore).
    if (staff) {
      final clientRows = await read('clients');
      if (clientRows.isNotEmpty) {
        final loadedClients = <Client>[];
        for (final r in clientRows) {
          try {
            loadedClients.add(Client.fromMap(Map<String, dynamic>.from(r)));
          } catch (e) {
            // Fiche ancienne ou incomplète : on n'interrompt pas le lot, mais
            // on NE PERD PAS la trace. Une fiche silencieusement écartée se
            // traduit, pour le personnel, par un dossier qui « n'existe pas ».
            _clientDecodeErrors.add(
              'Fiche ${r['id'] ?? '?'} illisible : ${e.runtimeType} — $e',
            );
            if (kDebugMode) {
              debugPrint('Fiche client illisible dans le lot : $e');
            }
          }
        }
        if (loadedClients.isNotEmpty) {
          clients = loadedClients
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );
        }
      }
    }

    // ── Réservations ──
    final bookingRows = await read(
      'bookings',
      ownerField: 'clientId',
      ownerValue: clientId,
    );
    final loadedBookings = decode(bookingRows, Booking.fromMap);
    if (loadedBookings.isNotEmpty) {
      bookings = loadedBookings..sort((a, b) => b.date.compareTo(a.date));
    }

    // ── Itinéraires ──
    final itineraryRows = await read(
      'itineraries',
      ownerField: 'clientId',
      ownerValue: clientId,
    );
    final loadedItineraries = decode(itineraryRows, Itinerary.fromMap);
    if (loadedItineraries.isNotEmpty) {
      itineraries = loadedItineraries
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // ── Factures et devis ──
    final financeRows = await read(
      'finance_docs',
      ownerField: 'clientId',
      ownerValue: clientId,
    );
    final loadedFinance = decode(financeRows, FinanceDocument.fromMap);
    if (loadedFinance.isNotEmpty) {
      financeDocs = loadedFinance..sort((a, b) => b.date.compareTo(a.date));
    }

    // ── Transactions bancaires (donnée interne : personnel uniquement) ──
    List<BankTransaction> loadedTx = const [];
    if (staff) {
      final txRows = await read('bank_transactions');
      loadedTx = decode(txRows, BankTransaction.fromMap);
      if (loadedTx.isNotEmpty) {
        bankTransactions = loadedTx;
      }
    }

    await _persist();
    notifyListeners();
  }

  // ───────────────────── ESPACE PERSONNEL (MON COMPTE) ─────────────────────
  /// Enregistre les informations personnelles de l'utilisateur connecté,
  /// qu'il soit membre du personnel ou client.
  ///
  /// Écrit réellement sur le serveur : les modifications sont donc retrouvées
  /// lors d'une connexion depuis un autre appareil. Lève une
  /// [CloudWriteException] si la sauvegarde échoue, afin que l'interface
  /// l'annonce au lieu de laisser croire à un enregistrement.
  Future<void> saveMyProfile({
    required String fullName,
    required String phone,
    String? language,
  }) async {
    final me = currentUser;
    if (me == null) throw const CloudWriteException('Profil');

    final name = fullName.trim();
    if (name.isEmpty) {
      throw const CloudWriteException('Profil');
    }

    final updated = me.copyWith(
      fullName: name,
      phone: phone.trim().isEmpty ? null : phone.trim(),
    );

    final clientId = updated.clientId;

    // Champs envoyés à la fiche `clients`. La règle Firestore
    // `onlyOwnContactFields()` n'autorise QUE ces clés pour une
    // auto-modification : y ajouter ne serait-ce que `displayName` fait
    // refuser l'écriture en 403.
    final Map<String, dynamic> clientPayload = {
      'fullName': name,
      'phone': updated.phone ?? '',
      if (language != null) 'language': language,
    };

    // Champs envoyés à la fiche `staff` (membre du personnel).
    final Map<String, dynamic> staffPayload = {
      'displayName': name,
      'fullName': name,
      'phone': updated.phone ?? '',
    };

    // ── ORDRE VOLONTAIRE : le serveur d'abord, l'état local ensuite ──
    // Si l'écriture échoue, rien n'est modifié à l'écran : l'utilisateur ne
    // voit jamais une valeur que la base ne contient pas. C'est la garantie
    // demandée (pas de modification « simplement affichée temporairement »).
    final bool ok;
    if (updated.role == UserRole.vipClient) {
      final id = clientId ?? '';
      if (id.isEmpty) throw const CloudWriteException('Profil');
      ok = await _pushToCloud('clients', clientPayload, docId: id);
    } else {
      ok = await _pushToCloud('staff', staffPayload, docId: updated.id);
    }
    if (!ok) throw const CloudWriteException('Profil');

    // Le profil d'identité reste synchronisé pour la lecture du rôle
    // par les règles de sécurité. Réservé aux comptes clients : la fiche
    // d'identité du personnel est administrée par la direction.
    if (restUid != null && updated.role == UserRole.vipClient) {
      await _pushToCloud('user_profiles', {
        'email': updated.email,
        'displayName': name,
        if (language != null) 'language': language,
      }, docId: restUid);
    }

    // ── Le serveur a accepté : on reflète la valeur localement ──
    users = [for (final u in users) u.id == updated.id ? updated : u];
    currentUser = updated;

    // Côté client, le nom et le téléphone vivent aussi dans la fiche `clients`.
    if (updated.role == UserRole.vipClient && clientId != null) {
      final i = clients.indexWhere((e) => e.id == clientId);
      if (i >= 0) {
        clients[i] = clients[i].copyWith(
          fullName: name,
          phone: updated.phone,
          language: language,
        );
      }
    }

    log('Mise à jour profil personnel', updated.email);
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── CLIENTS ───────────────────────────
  /// Dossiers d'inscription en attente de décision, du plus ancien au plus
  /// récent : c'est l'ordre dans lequel le personnel doit les traiter.
  List<Client> get pendingClientApprovals {
    final out = clients.where((c) => c.isPending).toList();
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  /// Nombre de dossiers à traiter (pastille de navigation).
  int get pendingApprovalsCount => pendingClientApprovals.length;

  /// Valide un dossier client : l'accès aux services est ouvert.
  ///
  /// L'écriture serveur est OBLIGATOIRE : une validation qui ne vivrait que
  /// dans le navigateur de l'administrateur laisserait le client bloqué sur
  /// son propre appareil, et la décision serait perdue au rechargement.
  /// En cas d'échec, la décision locale est annulée et l'erreur remontée.
  Future<void> approveClient(String clientId, {String? note}) async {
    final i = clients.indexWhere((c) => c.id == clientId);
    if (i < 0) return;
    final before = clients[i];

    // ── NUMÉRO DÉFINITIF ──────────────────────────────────────────────────
    // Une fiche issue d'une inscription publique porte un numéro provisoire
    // (« GRX-ATTENTE-… »). C'est ICI qu'elle reçoit sa référence durable, et
    // c'est le SERVEUR qui l'attribue : la réservation est atomique, donc
    // deux validateurs simultanés ne peuvent pas obtenir le même numéro.
    //
    // Si la réservation échoue, on N'INVENTE PAS de numéro : sans session ni
    // réseau fiable, mieux vaut refuser la validation que créer un doublon.
    var code = before.code;
    if (code.startsWith(pendingCodePrefix)) {
      final claimed = await _claimNextClientCode(before.id);
      if (claimed == null) {
        throw const CloudWriteException(
          'Attribution du numéro de dossier',
        );
      }
      code = claimed;
    }

    final updated = before.copyWith(
      code: code,
      approvalStatus: ClientApprovalStatus.approved,
      active: true,
      notes: note == null || note.trim().isEmpty
          ? before.notes
          : [before.notes, 'Validation : ${note.trim()}']
                .whereType<String>()
                .where((e) => e.isNotEmpty)
                .join('\n'),
    );
    clients[i] = updated;
    notifyListeners();

    final ok = await _pushToCloud('clients', updated.toMap(), docId: updated.id);
    if (!ok) {
      clients[i] = before; // retour à l'état antérieur : rien n'a changé
      notifyListeners();
      throw const CloudWriteException('Validation du client');
    }
    log(
      'Validation client',
      updated.email,
      detail: 'approuvé par ${currentUser?.email ?? '?'}',
    );
    await _persist();
    notifyListeners();
  }

  /// Refuse un dossier client. Le motif est communiqué à la personne.
  ///
  /// `active` reste vrai : le compte existe et peut se connecter pour lire le
  /// motif. C'est `approvalStatus` qui ferme l'accès aux services.
  Future<void> rejectClient(String clientId, {required String reason}) async {
    final i = clients.indexWhere((c) => c.id == clientId);
    if (i < 0) return;
    final before = clients[i];
    final motif = reason.trim();
    final updated = before.copyWith(
      approvalStatus: ClientApprovalStatus.rejected,
      notes: [before.notes, 'Refus : $motif']
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .join('\n'),
    );
    clients[i] = updated;
    notifyListeners();

    final ok = await _pushToCloud('clients', updated.toMap(), docId: updated.id);
    if (!ok) {
      clients[i] = before;
      notifyListeners();
      throw const CloudWriteException('Refus du client');
    }
    log(
      'Refus client',
      updated.email,
      detail: motif.isEmpty ? 'sans motif' : motif,
    );
    await _persist();
    notifyListeners();
  }

  /// Suspension / réactivation d'un compte déjà validé.
  ///
  /// Distincte de la validation : un compte suspendu garde son statut
  /// `approved` (il a bien été accepté) mais perd l'accès aux services.
  Future<void> setClientActive(String clientId, bool active) async {
    final i = clients.indexWhere((c) => c.id == clientId);
    if (i < 0) return;
    final before = clients[i];
    final updated = before.copyWith(active: active);
    clients[i] = updated;
    notifyListeners();

    final ok = await _pushToCloud('clients', updated.toMap(), docId: updated.id);
    if (!ok) {
      clients[i] = before;
      notifyListeners();
      throw const CloudWriteException('Statut du client');
    }
    log(
      active ? 'Réactivation client' : 'Suspension client',
      updated.email,
    );
    await _persist();
    notifyListeners();
  }

  /// Recharge la fiche du client connecté depuis le serveur.
  ///
  /// Utilisée par l'écran « dossier en cours d'examen » : le personnel peut
  /// valider le dossier pendant que la personne attend, et elle n'a alors pas
  /// besoin de se déconnecter pour en bénéficier.
  Future<void> refreshMyClientStatus() async {
    final token = restIdToken;
    final email = currentUser?.email;
    if (token == null || token.isEmpty || email == null) return;
    try {
      final res = await RestAuthService.findClientByEmail(email, token);
      final row = res.data;
      if (row == null) return;
      _upsertClientFromRow(row);
      // La valeur par défaut est `approved` : une fiche dont le champ est
      // absent est un client historique, déjà accepté.
      final statut = ClientApprovalStatus.fromName(
        row['approvalStatus'] as String?,
      );
      if (kDebugMode) {
        debugPrint('[State] statut du dossier client : ${statut.name}');
      }
      await _persist();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[State] rafraîchissement du dossier : $e');
    }
  }

  Future<void> updateClient(Client c) async {
    final i = clients.indexWhere((e) => e.id == c.id);
    if (i < 0) return;
    clients[i] = c;
    log('Mise à jour client', c.code);
    await _persist();
    notifyListeners();
    // Sauvegarde serveur : la fiche doit survivre à un changement d'appareil.
    final ok = await _pushToCloud('clients', c.toMap(), docId: c.id);
    if (!ok) {
      throw const CloudWriteException('Fiche client');
    }
  }

  /// Numéro de dossier PROVISOIRE, porté par une fiche non encore validée.
  ///
  /// Le numéro DÉFINITIF est attribué par le serveur au moment de la
  /// validation (voir [_claimNextClientCode]). Avant cela, la fiche porte ce
  /// préfixe : il n'est pas unique, et c'est assumé — il n'est jamais présenté
  /// comme une référence durable.
  ///
  /// POURQUOI LA NUMÉROTATION DÉFINITIVE N'EST PAS FAITE ICI : un visiteur qui
  /// s'inscrit ne connaît aucune autre fiche, et les règles Firestore lui
  /// interdisent de lister la collection (un client ne lit que SA fiche).
  /// Tout calcul fait dans le navigateur est donc locale à l'appareil : deux
  /// inscriptions simultanées produiraient le même numéro — exactement le
  /// défaut constaté en production (« GRX-VIP-0001 » attribué deux fois).
  static const String pendingCodePrefix = Client.provisionalCodePrefix;

  String _provisionalClientCode() {
    final now = DateTime.now();
    return '$pendingCodePrefix'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  /// Réserve ATOMIQUEMENT le prochain numéro de dossier définitif.
  ///
  /// ── MÉCANISME ─────────────────────────────────────────────────────────
  /// On n'incrémente PAS un compteur : deux appareils liraient la même valeur
  /// et écriraient le même nombre. On CRÉE le document `client_codes/GRX-VIP-0007`
  /// avec la précondition Firestore « ce document ne doit pas exister »
  /// (`currentDocument.exists=false`). Le serveur arbitre : le second appareil
  /// reçoit 409 ALREADY_EXISTS et passe au numéro suivant. Un numéro déjà
  /// attribué ne peut donc jamais l'être une seconde fois, même en concurrence.
  ///
  /// Mesuré sur le projet réel avant écriture de ce code : le premier appel
  /// répond 200, le second 409 avec `status: ALREADY_EXISTS`.
  ///
  /// ── APPELÉ PAR ────────────────────────────────────────────────────────
  /// `approveClient`, donc par un membre de l'encadrement : lui seul peut
  /// lister les fiches existantes et écrire dans `client_codes`. C'est ce qui
  /// rend le calcul du point de départ fiable.
  ///
  /// Retourne le numéro attribué, ou `null` si la réservation a échoué
  /// (réseau, droits). L'appelant ne doit alors PAS valider avec un numéro
  /// inventé.
  /// Numérotation de secours, utilisée UNIQUEMENT hors production.
  ///
  /// En développement et dans les tests il n'y a pas de session Firebase, donc
  /// pas de réservation serveur possible. On garde alors le comportement
  /// local (plus grand numéro connu + 1), suffisant pour ces usages.
  String _localNextClientCode() {
    var max = 0;
    for (final c in clients) {
      final m = RegExp(r'^GRX-VIP-(\d+)\s*$').firstMatch(c.code);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return 'GRX-VIP-${(max + 1).toString().padLeft(4, '0')}';
  }

  Future<String?> _claimNextClientCode(String clientId) async {
    final token = restIdToken;

    // Hors production, ou sans session : pas de réservation serveur possible.
    if (!AppConfig.isProduction || token == null || token.isEmpty) {
      return _localNextClientCode();
    }

    var max = 0;
    for (final c in clients) {
      final m = RegExp(r'^GRX-VIP-(\d+)\s*$').firstMatch(c.code);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }

    // On tente plusieurs numéros au-delà du maximum connu : celui-ci peut
    // être dépassé si un autre appareil a validé entre-temps, ou si le
    // personnel ne voit qu'une partie des fiches.
    for (var n = max + 1; n <= max + 200; n++) {
      final code = 'GRX-VIP-${n.toString().padLeft(4, '0')}';
      final res = await RestAuthService.createDocumentIfAbsent(
        'client_codes/$code',
        token,
        {
          'code': code,
          'clientId': clientId,
          'claimedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (res.created) return code;
      // 0 = réseau injoignable : le résultat est INCONNU (la réservation a
      // peut-être abouti). On s'arrête au lieu de continuer à tâtons.
      if (res.status == 0) return null;
      // 409 ALREADY_EXISTS → numéro déjà pris, on essaie le suivant.
      // Tout autre code (401, 403…) est un refus : inutile d'insister.
      if (res.status != 409) return null;
    }
    return null;
  }

  Future<Client> createClient(Client draft) async {
    // Une fiche issue d'une inscription publique reste en attente : son
    // numéro définitif sera réservé au moment de la validation, par
    // l'encadrement. D'ici là elle porte un numéro provisoire, non unique.
    //
    // Une fiche créée par le personnel est déjà validée : elle reçoit
    // immédiatement un numéro définitif, réservé côté serveur (le personnel a
    // une session, contrairement au visiteur qui s'inscrit).
    final String code;
    if (draft.isPending) {
      code = _provisionalClientCode();
    } else {
      // Fiche validée d'emblée : il lui faut TOUT DE SUITE un numéro
      // définitif. Si la réservation échoue, on préfère refuser la création
      // plutôt que d'enregistrer un dossier validé affublé d'un numéro
      // provisoire, qui n'identifie rien.
      final claimed = await _claimNextClientCode('(creation-par-le-personnel)');
      if (claimed == null) {
        throw const CloudWriteException('Attribution du numéro de dossier');
      }
      code = claimed;
    }

    final c = Client(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      code: code,
      fullName: draft.fullName,
      companyName: draft.companyName,
      category: draft.category,
      email: draft.email,
      phone: draft.phone,
      secondaryContact: draft.secondaryContact,
      language: draft.language,
      country: draft.country,
      city: draft.city,
      personalAssistant: draft.personalAssistant,
      assistantPhone: draft.assistantPhone,
      confidentiality: draft.confidentiality,
      subscriptionTierId: draft.subscriptionTierId,
      assignedConciergeId: draft.assignedConciergeId,
      preferredHotels: draft.preferredHotels,
      preferredRestaurants: draft.preferredRestaurants,
      preferredDrivers: draft.preferredDrivers,
      travelPreferences: draft.travelPreferences,
      dietaryPreferences: draft.dietaryPreferences,
      interests: draft.interests,
      notes: draft.notes,
      createdAt: DateTime.now(),
      isBusiness: draft.isBusiness,
      companyNumber: draft.companyNumber,
      vatNumber: draft.vatNumber,
      billingAddress: draft.billingAddress,
      billingEmail: draft.billingEmail,
      peppolEnabled: draft.peppolEnabled,
      // Le statut de validation est PROPAGÉ depuis le brouillon.
      // Sans cette ligne, la reconstruction champ par champ retombait sur la
      // valeur par défaut (`approved`) : une inscription passée par le
      // formulaire public devenait un client pleinement opérationnel, ce que
      // la validation par le personnel est précisément censée empêcher.
      approvalStatus: draft.approvalStatus,
    );

    // Serveur d'abord : une fiche client créée par le personnel doit être
    // retrouvée depuis n'importe quel appareil. Sans elle, les réservations
    // et factures rattachées à ce clientId seraient orphelines ailleurs.
    //
    // EXCEPTION VOULUE — parcours d'inscription : à ce moment précis, le
    // compte vient d'être créé par l'API REST mais la session n'est pas
    // encore établie dans l'état applicatif (aucun jeton disponible). Ce
    // n'est pas un échec serveur : l'écran d'inscription écrit lui-même la
    // fiche juste après, avec le jeton qu'il possède. On ne lève donc pas
    // d'exception dans ce cas, sous peine de bloquer toute inscription.
    final hasSession = (restIdToken ?? '').isNotEmpty;
    if (hasSession) {
      final ok = await _pushToCloud('clients', c.toMap(), docId: c.id);
      if (!ok) throw const CloudWriteException('Fiche client');
    }

    clients.insert(0, c);
    log(
      'Création client',
      c.code,
      detail: c.isBusiness ? 'Professionnel (facturation B2B)' : null,
    );
    if (c.isPending) {
      // Trace explicite : c'est la file d'attente que le personnel surveille.
      log('Inscription client à valider', c.email, detail: c.code);
    }
    await _persist();
    notifyListeners();
    return c;
  }

  // ─────────────────────────── ACCÈS & UTILISATEURS ───────────────────────────
  /// Liste des comptes personnel (hors clients VIP)
  List<AppUser> get staffUsers => users.where((u) => u.role.isStaff).toList();

  /// Liste des comptes clients VIP
  List<AppUser> get clientUsers =>
      users.where((u) => u.role == UserRole.vipClient).toList();

  bool emailExists(String email, {String? exceptId}) {
    final e = email.trim().toLowerCase();
    return users.any((u) => u.email.toLowerCase() == e && u.id != exceptId);
  }

  /// Crée un accès (personnel ou client VIP)
  Future<AppUser> createUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? title,
    String? phone,
    String? clientId,
  }) async {
    final u = AppUser(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      fullName: fullName,
      email: email.trim(),
      password: password,
      role: role,
      title: title,
      phone: phone,
      clientId: clientId,
      active: true,
      createdAt: DateTime.now(),
      mustChangePassword: true,
    );
    users.insert(0, u);
    log('Création accès', u.email, detail: '${u.fullName} · ${u.role.label}');
    await _persist();
    notifyListeners();
    return u;
  }

  /// Met à jour un accès existant.
  ///
  /// Persiste côté serveur : le mot de passe n'est JAMAIS écrit (il est géré
  /// exclusivement par Firebase Authentication).
  Future<void> updateUser(AppUser updated) async {
    final i = users.indexWhere((e) => e.id == updated.id);
    if (i < 0) return;
    users[i] = updated;
    if (currentUser?.id == updated.id) currentUser = updated;
    log('Mise à jour accès', updated.email);
    await _persist();
    notifyListeners();

    // Le compte du personnel est stocké dans `staff/{uid}`, la fiche client
    // dans `clients/{clientId}` : on route selon la nature du compte.
    //
    // Les règles Firestore sont volontairement strictes : le niveau de droit
    // (`role`) et l'adresse e-mail ne sont réécrits QUE par un CEO. Un manager
    // qui enregistre une fiche sans changer le rôle n'envoie donc pas ces
    // clés — sinon l'écriture entière serait refusée en 403.
    final bool roleChanged = currentUser?.role != updated.role;

    if (updated.role == UserRole.vipClient) {
      final clientId = updated.clientId;
      if (clientId == null || clientId.isEmpty) return;
      final clientPayload = <String, dynamic>{
        'displayName': updated.fullName,
        'fullName': updated.fullName,
        'department': updated.title ?? updated.role.department,
        'phone': updated.phone ?? '',
        'active': updated.active,
        if (isCeo) 'email': updated.email,
        if (isCeo) 'role': updated.role.name,
      };
      final ok = await _pushToCloud(
        'clients',
        clientPayload,
        docId: clientId,
      );
      if (!ok) throw const CloudWriteException('Compte utilisateur');
      return;
    }

    final staffPayload = <String, dynamic>{
      'displayName': updated.fullName,
      'fullName': updated.fullName,
      'department': updated.title ?? updated.role.department,
      'phone': updated.phone ?? '',
      'active': updated.active,
      // Réservé au CEO : le rôle est une donnée d'autorisation.
      if (isCeo) 'role': updated.role.name,
      if (isCeo) 'email': updated.email,
    };
    final ok = await _pushToCloud('staff', staffPayload, docId: updated.id);
    if (!ok) throw const CloudWriteException('Compte utilisateur');

    // Un manager qui tente de changer un rôle doit être averti clairement :
    // l'écriture des coordonnées a réussi, mais le rôle n'a pas bougé.
    if (roleChanged && !isCeo) {
      throw const CloudWriteException(
        'Seul le CEO peut modifier le rôle d\'un compte. '
        'Les coordonnées ont été enregistrées',
      );
    }
  }

  /// Active / désactive un accès
  Future<void> setUserActive(String id, bool active) async {
    final i = users.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final u = users[i];
    users[i] = u.copyWith(active: active);
    log(active ? 'Activation accès' : 'Désactivation accès', u.email);
    await _persist();
    notifyListeners();
  }

  /// Réinitialise le mot de passe (force le changement à la prochaine connexion)
  Future<void> resetUserPassword(String id, String newPassword) async {
    final i = users.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final u = users[i];
    users[i] = u.copyWith(password: newPassword, mustChangePassword: true);
    log('Réinitialisation mot de passe', u.email);
    await _persist();
    notifyListeners();
  }

  /// Supprime définitivement un accès
  Future<void> deleteUser(String id) async {
    final i = users.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final u = users[i];
    users.removeAt(i);
    log('Suppression accès', u.email);
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── SUBSCRIPTIONS ───────────────────────────
  Future<void> updateTier(SubscriptionTier t) async {
    final i = tiers.indexWhere((e) => e.id == t.id);
    if (i < 0) return;
    tiers[i] = t;
    log('Mise à jour abonnement', t.name);
    await _persist();
    notifyListeners();
    final ok = await _pushToCloud('subscription_tiers', t.toMap(), docId: t.id);
    if (!ok) throw const CloudWriteException('Formule d\'abonnement');
  }

  // ═══════════════════════ DOMICILIATION SEPA ═══════════════════════
  //
  // ── POURQUOI CES DONNÉES SONT HORS DE `_persist()` ──────────────────
  // L'état complet de l'application est sérialisé dans UN SEUL document
  // Firestore (« gorex_state » par utilisateur). Y placer les coordonnées
  // bancaires exposerait l'IBAN de chaque client à quiconque lit ce document.
  // Les mandats et prélèvements sont donc persistés séparément :
  //   • localement, sous une clé de préférences dédiée ;
  //   • dans Firestore, dans les collections `sepa_mandates` / `sepa_debits`
  //     (règles restreintes au CEO, cf. firestore.rules).
  // Les montants d'abonnement, eux, ne sont pas des données bancaires et
  // restent dans l'état normal.

  /// Mandats de domiciliation connus.
  List<SepaMandate> sepaMandates = [];

  /// Ordres de prélèvement (brouillons, pré-notifiés, transmis…).
  List<SepaDebit> sepaDebits = [];

  static const _sepaStorageKey = 'gorex_sepa_v1';

  /// Mandat actif d'un client, s'il existe.
  SepaMandate? mandateForClient(String clientId) {
    for (final m in sepaMandates) {
      if (m.clientId == clientId && m.status == SepaMandateStatus.active) {
        return m;
      }
    }
    return null;
  }

  /// Vrai si le client a une domiciliation utilisable pour un prélèvement.
  bool canDebitClient(String clientId) => mandateForClient(clientId)?.usable ?? false;

  // ─────────────────────── ABONNEMENTS (CONTRATS) ───────────────────────
  //
  // Un abonnement vit dans une collection DÉDIÉE (`subscriptions`), et non
  // dans l'état global `gorex_cloud` : ce dernier n'est lisible que par le
  // CEO et le concierge manager, alors que le client doit pouvoir consulter
  // SON contrat. Comme pour le SEPA, chaque client ne lit que ses documents.

  /// Demande d'abonnement du client connecté (la plus récente), s'il y en a.
  Subscription? get mySubscription {
    final email = currentUser?.email;
    if (email == null) return null;
    final mine = subscriptions.where((s) => s.clientEmail == email).toList();
    if (mine.isEmpty) return null;
    mine.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return mine.first;
  }

  /// Abonnements en attente de décision, du plus ancien au plus récent.
  List<Subscription> get pendingSubscriptions {
    final out =
        subscriptions.where((s) => s.status == SubscriptionStatus.requested).toList();
    out.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    return out;
  }

  /// Abonnement d'un client donné (le plus récent).
  Subscription? subscriptionForClient(String clientId) {
    final mine = subscriptions.where((s) => s.clientId == clientId).toList();
    if (mine.isEmpty) return null;
    mine.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return mine.first;
  }

  /// Enregistre une DEMANDE d'abonnement formulée par le client.
  ///
  /// Elle ne donne aucun droit : le statut est `requested` et le montant est
  /// celui de la grille au moment de la demande, figé ici pour qu'une
  /// modification ultérieure des tarifs ne réécrive pas un contrat en cours.
  Future<Subscription> requestSubscription({
    required String clientId,
    required String tierId,
    required BillingCycle cycle,
  }) async {
    // ── OFFRE FERMÉE ────────────────────────────────────────────────────
    // Tant que les conditions commerciales et légales ne sont pas arrêtées,
    // aucune demande ne peut être enregistrée. REFUS EXPLICITE plutôt que
    // bouton masqué : masquer l'interface ne protège de rien, un appel direct
    // contournerait tout. Voir `SubscriptionPolicy`.
    if (!SubscriptionPolicy.subscriptionsOpen) {
      throw const CloudWriteException(
        'Les formules d\'abonnement ne sont pas encore ouvertes à la '
        'souscription',
      );
    }
    final client = clients.firstWhere(
      (c) => c.id == clientId,
      orElse: () => throw const CloudWriteException('Client introuvable'),
    );
    final tier = tierById(tierId);
    if (tier == null) {
      throw const CloudWriteException('Formule inconnue');
    }

    final sub = Subscription(
      id: 'sub_${DateTime.now().microsecondsSinceEpoch}',
      clientId: clientId,
      clientEmail: client.email,
      tierId: tier.id,
      tierName: tier.name,
      cycle: cycle,
      amount: cycle == BillingCycle.annual ? tier.annualPrice : tier.monthlyPrice,
      status: SubscriptionStatus.requested,
      requestedAt: DateTime.now(),
    );

    // Serveur d'abord : une demande qui ne vivrait que dans le navigateur du
    // client serait invisible pour l'équipe, donc sans effet.
    final ok = await _pushToCloud('subscriptions', sub.toMap(), docId: sub.id);
    if (!ok) throw const CloudWriteException('Demande d\'abonnement');

    subscriptions.insert(0, sub);
    log('Demande d\'abonnement', client.email, detail: '${tier.name} — ${sub.amountLabel}');
    await _persist();
    notifyListeners();
    return sub;
  }

  /// Décision de Gorex Group sur une demande d'abonnement.
  ///
  /// `approve = true` accepte la demande ; le contrat est formé mais reste
  /// NON FACTURABLE tant que le mandat SEPA n'est pas actif (voir
  /// [activateSubscriptionIfReady]). `approve = false` refuse.
  Future<void> decideSubscription(
    String subscriptionId, {
    required bool approve,
    String? note,
  }) async {
    if (!can('finance')) {
      throw const CloudWriteException(
        'Seul le CEO ou le service financier peut décider d\'un abonnement',
      );
    }
    final i = subscriptions.indexWhere((s) => s.id == subscriptionId);
    if (i < 0) return;
    final before = subscriptions[i];

    final updated = before.copyWith(
      status: approve
          ? SubscriptionStatus.approved
          : SubscriptionStatus.ended,
      decidedAt: DateTime.now(),
      decidedBy: currentUser?.email,
      note: note?.trim().isEmpty ?? true ? before.note : note!.trim(),
    );
    subscriptions[i] = updated;
    notifyListeners();

    final ok = await _pushToCloud('subscriptions', updated.toMap(), docId: updated.id);
    if (!ok) {
      subscriptions[i] = before;
      notifyListeners();
      throw const CloudWriteException('Décision d\'abonnement');
    }
    log(
      approve ? 'Abonnement accepté' : 'Abonnement refusé',
      updated.clientEmail,
      detail: '${updated.tierName} — ${updated.amountLabel}',
    );
    await _persist();
    notifyListeners();
  }

  /// Passe un abonnement accepté en `active` si — et seulement si — un mandat
  /// SEPA actif existe pour ce client.
  ///
  /// C'est le verrou qui empêche de facturer sans base contractuelle : sans
  /// mandat, on ne prélève pas, donc on ne facture pas.
  Future<bool> activateSubscriptionIfReady(String clientId) async {
    // ── SECOND VERROU, INDÉPENDANT DU PREMIER ───────────────────────────
    // Même si une demande et une décision avaient été enregistrées avant la
    // fermeture de l'offre, un abonnement ne devient JAMAIS facturable tant
    // que l'ouverture commerciale n'est pas décidée. C'est ce qui garantit
    // qu'aucun prélèvement SEPA ne peut partir par inadvertance.
    if (!SubscriptionPolicy.canActivateBilling) return false;

    final sub = subscriptionForClient(clientId);
    if (sub == null || sub.status != SubscriptionStatus.approved) return false;
    if (!canDebitClient(clientId)) return false;

    final updated = sub.copyWith(
      status: SubscriptionStatus.active,
      activatedAt: DateTime.now(),
    );
    final i = subscriptions.indexWhere((s) => s.id == sub.id);
    subscriptions[i] = updated;
    notifyListeners();

    final ok = await _pushToCloud('subscriptions', updated.toMap(), docId: updated.id);
    if (!ok) {
      subscriptions[i] = sub;
      notifyListeners();
      throw const CloudWriteException('Activation de l\'abonnement');
    }
    log('Abonnement actif', updated.clientEmail, detail: updated.amountLabel);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Recharge les abonnements depuis Firestore.
  ///
  /// Un client ne peut lire que SES documents (règle Firestore) : la méthode
  /// est donc appelée aussi bien par l'espace client que par l'espace
  /// d'encadrement, chacun recevant ce qu'il a le droit de voir.
  Future<void> syncSubscriptionsFromCloud() async {
    final token = restIdToken;
    if (token == null || token.isEmpty) return;
    try {
      // La règle Firestore n'autorise un client qu'à lire SES propres
      // abonnements : une lecture de collection non filtrée se ferait refuser
      // (403). On filtre donc explicitement, pour le client uniquement — le
      // personnel reçoit la collection entière.
      //
      // ⚠️ LE CHAMP FILTRÉ DOIT ÊTRE CELUI QUE LA RÈGLE CONTRÔLE.
      // La règle de lecture est `ownsClientData(resource.data)`, qui compare
      // `data.clientId` à l'identifiant du dossier. Filtrer sur `clientEmail`
      // — ce que faisait le code — produisait un 403 : Firestore ne peut pas
      // prouver, à partir d'une requête sur `clientEmail`, que le résultat
      // satisfait une condition portant sur `clientId`. La requête elle-même
      // est donc refusée, quel que soit son contenu.
      final clientId = currentUser?.clientId;
      final isClientOnly = currentUser?.role == UserRole.vipClient;
      final rows = (isClientOnly &&
              clientId != null &&
              clientId.isNotEmpty)
          ? await RestAuthService.queryCollection(
              'subscriptions',
              token,
              field: 'clientId',
              value: clientId,
              limit: 50,
            )
          : await RestAuthService.fetchCollection(
              'subscriptions',
              token,
              limit: 200,
            );
      if (rows.isEmpty) return;
      final byId = <String, Subscription>{for (final s in subscriptions) s.id: s};
      for (final r in rows) {
        final s = Subscription.fromMap(r);
        if (s.id.isEmpty) continue;
        byId[s.id] = s;
      }
      subscriptions = byId.values.toList();
      await _persist();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[State] abonnements (REST) : $e');
    }
  }

  /// Charge la grille tarifaire officielle depuis Firestore
  /// (`subscription_tiers`).
  ///
  /// ── POURQUOI CE CHARGEMENT EXISTE ────────────────────────────────────
  /// La grille n'existait QUE dans le navigateur : `SeedData.tiers()` en dur,
  /// puis le `localStorage` de chaque appareil. Conséquence : si la direction
  /// modifiait un tarif depuis son ordinateur, un client sur son téléphone
  /// continuait de voir l'ancien prix — et pouvait demander une formule au
  /// montant périmé. Inacceptable pour un document contractuel.
  ///
  /// Le code écrivait déjà dans `subscription_tiers` (voir `_pushToCloud` sur
  /// l'écran Abonnements) mais ne relisait jamais. C'est ce trou que comble
  /// cette méthode.
  ///
  /// La base fait foi : dès qu'une lecture réussit et renvoie au moins une
  /// formule active, elle remplace la grille locale. En cas d'échec (hors
  /// ligne, droits, réseau), la grille locale est CONSERVÉE — jamais écrasée
  /// par du vide, sinon l'écran d'abonnement deviendrait inutilisable.
  Future<void> loadTiersFromCloud() async {
    final token = restIdToken;
    if (token == null || token.isEmpty) return;
    try {
      final rows = await RestAuthService.fetchCollection(
        'subscription_tiers',
        token,
        limit: 50,
      );
      if (rows.isEmpty) return;
      final loaded = <SubscriptionTier>[];
      for (final r in rows) {
        final t = SubscriptionTier.fromMap(r);
        // Un document sans identifiant ou sans nom ne peut pas être proposé.
        if (t.id.isEmpty || t.name.trim().isEmpty) continue;
        loaded.add(t);
      }
      if (loaded.isEmpty) return;
      loaded.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      tiers = loaded;
      await _persist();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[State] formules (REST) : $e');
    }
  }

  /// Charge les coordonnées officielles de la société depuis Firestore.
  ///
  /// ── POURQUOI CE CHARGEMENT EXISTE ────────────────────────────────────
  /// `updateCompany()` écrit bien `company/gorex-group` dans Firestore, mais
  /// aucune lecture n'existait : les coordonnées ne vivaient donc que dans le
  /// `localStorage` du navigateur où elles avaient été saisies. Sur un autre
  /// appareil (exigence §1 du cahier des charges), l'application retombait sur
  /// les valeurs par défaut du modèle — IBAN `BE00 0000 0000 0000`, numéro
  /// d'entreprise `0000.000.000` — et la génération du fichier SEPA échouait.
  ///
  /// La base fait foi : dès qu'une session authentifiée existe, ce sont les
  /// valeurs Firestore qui remplacent l'état local. Si la lecture échoue
  /// (hors ligne, droits, réseau), on conserve l'état local au lieu de
  /// l'écraser par des valeurs vides.
  Future<void> loadCompanyFromCloud() async {
    final token = restIdToken;
    if (token == null || token.isEmpty) return;
    try {
      final row = await RestAuthService.fetchDocument(
        'company/$_companyDocId',
        token,
      );
      if (row == null || row.isEmpty) return;
      // Le décodeur REST ajoute `id` / `uid` : ces clés ne font pas partie du
      // modèle et sont ignorées par `CompanyProfile.fromMap`.
      company = CompanyProfile.fromMap(row);
      await _persist();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[State] société (REST) : $e');
    }
  }

  /// Synchronise mandats et prélèvements depuis Firestore.
  ///
  /// ── POURQUOI CETTE MÉTHODE EXISTE ────────────────────────────────────
  /// `registerMandate()` / `createSubscriptionDebit()` écrivaient bien dans
  /// Firestore, mais `loadSepa()` ne relisait QUE le stockage local du
  /// navigateur. Un mandat saisi sur l'ordinateur du bureau était donc
  /// invisible sur un téléphone — exactement ce que l'exigence §1 du cahier
  /// des charges interdit.
  ///
  /// Stratégie : l'union par identifiant. Firestore fait foi pour un mandat
  /// connu des deux côtés (c'est la version que la banque a vue) ; un
  /// mandat/ordre présent uniquement en local a été créé hors ligne et est
  /// renvoyé vers Firestore au lieu d'être perdu.
  ///
  /// Sans jeton (non connecté), ou si Firestore refuse la lecture, l'état
  /// local est conservé tel quel : jamais d'écrasement par du vide.
  Future<void> syncSepaFromCloud() async {
    final token = restIdToken;
    if (token == null || token.isEmpty) return;

    // ── LECTURE FILTRÉE POUR UN CLIENT (403 CORRIGÉ) ────────────────────
    //
    // DÉFAUT CORRIGÉ. Cette méthode lisait `sepa_mandates` et `sepa_debits`
    // en COLLECTION ENTIÈRE, quel que soit le profil. Or les règles Firestore
    // réservent ces collections au rôle finance (`isFinanceRole()`) et au
    // débiteur pour ses propres documents (`ownsClientData`). Un client
    // connecté recevait donc un 403 à chaque synchronisation — visible dans
    // la console du navigateur comme « Failed to load resource: 403 ».
    //
    // Ce n'était pas qu'une pollution de console : le `try/catch` englobant
    // avalait l'erreur, donc le client ne chargeait JAMAIS ses propres mandats
    // depuis la base. Sur un second appareil, son mandat SEPA était invisible.
    //
    // Un client interroge désormais par le champ `clientId`, exactement comme
    // le prévoient les règles (queryCollection, pas fetchCollection).
    final staff = isStaff;
    final clientId = currentUser?.clientId ?? '';

    Future<List<Map<String, dynamic>>> rows(String c) async {
      if (staff) return RestAuthService.fetchCollection(c, token, limit: 500);
      if (clientId.isEmpty) return const [];
      return RestAuthService.queryCollection(
        c,
        token,
        field: 'clientId',
        value: clientId,
        limit: 500,
      );
    }

    try {
      final cloudMandates = <String, SepaMandate>{};
      for (final r in await rows('sepa_mandates')) {
        final m = SepaMandate.fromMap(r);
        cloudMandates[m.id] = m;
      }
      final cloudDebits = <String, SepaDebit>{};
      for (final r in await rows('sepa_debits')) {
        final d = SepaDebit.fromMap(r);
        cloudDebits[d.id] = d;
      }

      // Rien en base : on ne touche pas à l'état local (première utilisation,
      // ou lecture refusée). Les enregistrements locaux seront renvoyés plus
      // bas s'il y en a.
      if (cloudMandates.isEmpty && cloudDebits.isEmpty) return;

      final localOnlyMandates = sepaMandates
          .where((m) => !cloudMandates.containsKey(m.id))
          .toList();
      final localOnlyDebits = sepaDebits
          .where((d) => !cloudDebits.containsKey(d.id))
          .toList();

      sepaMandates = [...cloudMandates.values, ...localOnlyMandates];
      sepaDebits = [...cloudDebits.values, ...localOnlyDebits];

      await _persistSepa();
      notifyListeners();

      // Remontée des créations faites hors ligne.
      for (final m in localOnlyMandates) {
        await _pushToCloud('sepa_mandates', m.toMap(), docId: m.id);
      }
      for (final d in localOnlyDebits) {
        await _pushToCloud('sepa_debits', d.toMap(), docId: d.id);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SEPA] synchronisation cloud : $e');
    }
  }

  /// Charge les mandats et prélèvements depuis le stockage local.
  Future<void> loadSepa() async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    final raw = prefs.getString(_sepaStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      sepaMandates = [
        for (final e in (m['mandates'] as List? ?? const []))
          SepaMandate.fromMap(Map<String, dynamic>.from(e as Map)),
      ];
      sepaDebits = [
        for (final e in (m['debits'] as List? ?? const []))
          SepaDebit.fromMap(Map<String, dynamic>.from(e as Map)),
      ];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[SEPA] chargement impossible : $e');
    }
  }

  Future<void> _persistSepa() async {
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setString(
      _sepaStorageKey,
      jsonEncode({
        'mandates': sepaMandates.map((e) => e.toMap()).toList(),
        'debits': sepaDebits.map((e) => e.toMap()).toList(),
      }),
    );
  }

  /// Génère une référence de mandat unique (≤ 35 caractères, jeu SEPA).
  String nextMandateReference() {
    var max = 0;
    final re = RegExp(r'GRX-ABO-\d{4}-(\d+)$');
    for (final m in sepaMandates) {
      final match = re.firstMatch(m.mandateReference);
      if (match != null) {
        final n = int.tryParse(match.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    final year = DateTime.now().year;
    return 'GRX-ABO-$year-${(max + 1).toString().padLeft(4, '0')}';
  }

  /// Identifiant de bout en bout unique pour un ordre de prélèvement.
  String _nextEndToEndId() =>
      'GRX-${DateTime.now().microsecondsSinceEpoch}';

  /// Enregistre un mandat de domiciliation.
  ///
  /// Refuse un mandat incohérent (IBAN invalide, référence manquante…) : un
  /// mandat invalide produirait des rejets bancaires facturés.
  Future<SepaMandate> registerMandate({
    required String clientId,
    required String clientName,
    required String accountHolder,
    required String iban,
    String? bic,
    required DateTime signatureDate,
    SepaMandateType type = SepaMandateType.core,
    String? notes,
  }) async {
    if (!can('finance')) {
      throw const CloudWriteException(
        'Seul le CEO ou le service financier peut enregistrer un mandat de '
        'domiciliation',
      );
    }

    final mandate = SepaMandate(
      id: 'mand_${DateTime.now().microsecondsSinceEpoch}',
      clientId: clientId,
      clientName: clientName,
      mandateReference: nextMandateReference(),
      iban: SepaValidator.normalizeIban(iban),
      bic: (bic == null || bic.trim().isEmpty)
          ? null
          : SepaValidator.normalizeBic(bic),
      accountHolder: accountHolder.trim(),
      type: type,
      status: SepaMandateStatus.active,
      signatureDate: signatureDate,
      createdAt: DateTime.now(),
      notes: notes,
    );

    final issues = mandate.validate();
    if (issues.isNotEmpty) {
      throw CloudWriteException('Mandat refusé : ${issues.join(' · ')}');
    }

    // Un seul mandat actif par client : l'ancien est révoqué, jamais supprimé
    // (la trace du mandat précédent reste consultable).
    final previous = mandateForClient(clientId);
    if (previous != null) {
      final i = sepaMandates.indexWhere((e) => e.id == previous.id);
      if (i >= 0) {
        sepaMandates[i] = previous.copyWith(
          status: SepaMandateStatus.cancelled,
          cancelledAt: DateTime.now(),
        );
        await _pushToCloud(
          'sepa_mandates',
          sepaMandates[i].toMap(),
          docId: sepaMandates[i].id,
        );
      }
    }

    sepaMandates.add(mandate);
    await _persistSepa();
    await _logAudit(
      'Mandat SEPA enregistré',
      mandate.clientName,
      detail: '${mandate.mandateReference} (${mandate.maskedIban})',
    );
    final ok = await _pushToCloud(
      'sepa_mandates',
      mandate.toMap(),
      docId: mandate.id,
    );
    notifyListeners();
    if (!ok) {
      throw const CloudWriteException(
        'Mandat enregistré localement mais non synchronisé',
      );
    }
    return mandate;
  }

  /// Signe un mandat de domiciliation depuis l'espace CLIENT.
  ///
  /// ── POURQUOI CETTE MÉTHODE EXISTE ────────────────────────────────────
  /// Jusqu'ici, la seule voie d'enregistrement ([registerMandate]) exigeait
  /// `can('finance')`, donc un membre du personnel. Or un mandat SEPA est
  /// signé par le DÉBITEUR : le faire saisir par le créancier revient à
  /// signer à la place du client. Sans cette méthode, aucun client ne pouvait
  /// jamais fournir de moyen de paiement, et la facturation restait
  /// impossible autrement qu'à la main.
  ///
  /// Différences assumées avec [registerMandate] :
  ///   • le dossier concerné est IMPOSÉ (`currentClient`) : un client ne peut
  ///     pas signer un mandat sur le dossier d'un tiers ;
  ///   • l'acceptation est horodatée et l'auteur consigné (`notes`), ce qui
  ///     constitue la preuve du consentement ;
  ///   • le mandat est créé `active` (le client vient de signer) mais reste
  ///     sans effet tant qu'aucun abonnement n'est activé — l'activation est
  ///     verrouillée par `SubscriptionPolicy`.
  Future<SepaMandate> signMandateAsClient({
    required String accountHolder,
    required String iban,
    String? bic,
    required bool acceptedTerms,
  }) async {
    final client = currentClient;
    if (client == null) {
      throw const CloudWriteException('Aucun dossier client associé à ce compte');
    }
    if (!client.hasServiceAccess) {
      throw const CloudWriteException(
        'Votre dossier doit être validé par Gorex Group avant de signer un '
        'mandat de paiement',
      );
    }
    if (!acceptedTerms) {
      throw const CloudWriteException(
        'Le mandat ne peut être enregistré sans votre accord explicite',
      );
    }

    final normalizedIban = SepaValidator.normalizeIban(iban);
    final check = SepaValidator.validateIban(normalizedIban);
    if (!check.valid) {
      throw CloudWriteException('IBAN refusé : ${check.error}');
    }
    if (accountHolder.trim().length < 2) {
      throw const CloudWriteException('Indiquez le titulaire du compte');
    }

    final now = DateTime.now();
    final mandate = SepaMandate(
      id: 'mand_${now.microsecondsSinceEpoch}',
      clientId: client.id,
      clientName: client.fullName,
      mandateReference: nextMandateReference(),
      iban: normalizedIban,
      bic: (bic == null || bic.trim().isEmpty)
          ? null
          : SepaValidator.normalizeBic(bic),
      accountHolder: accountHolder.trim(),
      type: SepaMandateType.core,
      status: SepaMandateStatus.active,
      signatureDate: now,
      createdAt: now,
      notes: 'Signé par le client dans son espace personnel le '
          '${now.toIso8601String()} (compte ${client.email}).',
    );

    final issues = mandate.validate();
    if (issues.isNotEmpty) {
      throw CloudWriteException('Mandat refusé : ${issues.join(' · ')}');
    }

    // Le serveur d'abord : un mandat qui ne vivrait que dans le navigateur du
    // client serait invisible pour la finance, donc inutilisable.
    final ok = await _pushToCloud(
      'sepa_mandates',
      mandate.toMap(),
      docId: mandate.id,
    );
    if (!ok) {
      throw const CloudWriteException(
        'Le mandat n\'a pas pu être enregistré sur le serveur. '
        'Vérifiez votre connexion et réessayez.',
      );
    }

    // Remplace le mandat précédent éventuel (révoqué, jamais supprimé).
    final previous = mandateForClient(client.id);
    if (previous != null && previous.id != mandate.id) {
      final i = sepaMandates.indexWhere((e) => e.id == previous.id);
      if (i >= 0) {
        sepaMandates[i] = sepaMandates[i].copyWith(
          status: SepaMandateStatus.cancelled,
          cancelledAt: now,
        );
      }
    }
    sepaMandates.add(mandate);
    await _persistSepa();
    await _logAudit(
      'Mandat SEPA signé par le client',
      client.email,
      detail: mandate.maskedIban,
    );
    notifyListeners();
    return mandate;
  }

  /// Révoque un mandat : il ne pourra plus être prélevé, mais reste
  /// consultable (obligation de traçabilité).
  Future<void> revokeMandate(String mandateId, {String? reason}) async {
    if (!can('finance')) {
      throw const CloudWriteException('Révocation réservée au CEO ou à la finance');
    }
    final i = sepaMandates.indexWhere((e) => e.id == mandateId);
    if (i < 0) return;
    final updated = sepaMandates[i].copyWith(
      status: SepaMandateStatus.cancelled,
      cancelledAt: DateTime.now(),
      notes: reason,
    );
    sepaMandates[i] = updated;
    await _persistSepa();
    await _logAudit(
      'Mandat SEPA révoqué',
      updated.clientName,
      detail: '${updated.mandateReference}${reason != null ? ' — $reason' : ''}',
    );
    await _pushToCloud('sepa_mandates', updated.toMap(), docId: updated.id);
    notifyListeners();
  }

  /// Crée un ordre de prélèvement pour l'abonnement d'un client.
  ///
  /// Le montant provient de la formule souscrite (`Client.subscriptionTierId`)
  /// et n'est pas librement saisi : cela évite tout écart entre l'abonnement
  /// contracté et le montant prélevé.
  Future<SepaDebit> createSubscriptionDebit({
    required String clientId,
    required DateTime collectionDate,
    bool annual = false,
    String? remittance,
    String? periodLabel,
  }) async {
    final client = clients.firstWhere(
      (c) => c.id == clientId,
      orElse: () => throw const CloudWriteException('Client introuvable'),
    );
    final mandate = mandateForClient(clientId);
    if (mandate == null) {
      throw const CloudWriteException(
        'Aucun mandat de domiciliation actif pour ce client',
      );
    }
    if (!mandate.usable) {
      throw const CloudWriteException('Le mandat de domiciliation est inutilisable');
    }

    final tier = tierById(client.subscriptionTierId);
    if (tier == null) {
      throw const CloudWriteException('Formule d\'abonnement introuvable');
    }
    final amount = annual ? tier.annualPrice : tier.monthlyPrice;
    if (amount <= 0) {
      throw const CloudWriteException('Montant de la formule invalide');
    }

    final period = periodLabel ?? (annual ? 'annuel' : 'mensuel');
    final debit = SepaDebit(
      id: 'debit_${DateTime.now().microsecondsSinceEpoch}',
      mandateId: mandate.id,
      mandateReference: mandate.mandateReference,
      clientId: clientId,
      clientName: client.fullName,
      iban: mandate.iban,
      amount: amount,
      endToEndId: _nextEndToEndId(),
      remittanceInformation:
          remittance ?? 'Abonnement ${tier.name} - $period',
      requestedCollectionDate: collectionDate,
      sequenceType: mandate.nextSequence,
      status: SepaDebitStatus.draft,
      createdAt: DateTime.now(),
    );

    sepaDebits.add(debit);
    await _persistSepa();
    await _pushToCloud('sepa_debits', debit.toMap(), docId: debit.id);
    notifyListeners();
    return debit;
  }

  /// Marque un ordre comme pré-notifié au client.
  ///
  /// La date de pré-notification conditionne la date de prélèvement : le
  /// règlement SEPA impose 14 jours calendrier. Tant qu'elle n'est pas
  /// renseignée, l'ordre est exclu du fichier `pain.008`.
  Future<void> markDebitPreNotified(String debitId) async {
    final i = sepaDebits.indexWhere((e) => e.id == debitId);
    if (i < 0) return;
    sepaDebits[i] = sepaDebits[i].copyWith(
      status: SepaDebitStatus.preNotified,
      preNotifiedAt: DateTime.now(),
    );
    await _persistSepa();
    await _logAudit(
      'Pré-notification SEPA',
      sepaDebits[i].clientName,
      detail:
          '${sepaDebits[i].endToEndId} — ${sepaDebits[i].amount.toStringAsFixed(2)} EUR',
    );
    await _pushToCloud(
      'sepa_debits',
      sepaDebits[i].toMap(),
      docId: sepaDebits[i].id,
    );
    notifyListeners();
  }

  /// Supprime un ordre de prélèvement encore en brouillon.
  Future<void> deleteDebitDraft(String debitId) async {
    final i = sepaDebits.indexWhere((e) => e.id == debitId);
    if (i < 0) return;
    if (sepaDebits[i].status != SepaDebitStatus.draft) {
      throw const CloudWriteException(
        'Seul un brouillon peut être supprimé (un ordre pré-notifié est engageant)',
      );
    }
    sepaDebits.removeAt(i);
    await _persistSepa();
    notifyListeners();
  }

  /// Génère le fichier de prélèvement `pain.008.001.02` pour les ordres
  /// sélectionnés (ou tous les ordres pré-notifiés si [debitIds] est vide).
  ///
  /// Ne transmet rien à la banque : produit le XML à déposer.
  SepaBatchResult exportSepaBatch({List<String>? debitIds, DateTime? now}) {
    final selected = debitIds == null || debitIds.isEmpty
        ? sepaDebits
              .where(
                (d) =>
                    d.status == SepaDebitStatus.preNotified ||
                    d.status == SepaDebitStatus.draft,
              )
              .toList()
        : sepaDebits.where((d) => debitIds.contains(d.id)).toList();

    return SepaPain008Generator.generate(
      debits: selected,
      mandates: {for (final m in sepaMandates) m.id: m},
      company: company,
      createdAt: now ?? DateTime.now(),
    );
  }

  /// Marque les ordres d'un lot comme transmis et met à jour la date de
  /// dernier usage des mandats (détermine FRST → RCUR pour le mois suivant).
  Future<void> markBatchSubmitted(List<String> debitIds, {String? batchId}) async {
    if (!can('finance')) {
      throw const CloudWriteException('Transmission réservée au CEO ou à la finance');
    }
    final now = DateTime.now();
    final touchedMandates = <String>{};
    for (var i = 0; i < sepaDebits.length; i++) {
      if (!debitIds.contains(sepaDebits[i].id)) continue;
      sepaDebits[i] = sepaDebits[i].copyWith(
        status: SepaDebitStatus.submitted,
        batchId: batchId,
      );
      touchedMandates.add(sepaDebits[i].mandateId);
      await _pushToCloud(
        'sepa_debits',
        sepaDebits[i].toMap(),
        docId: sepaDebits[i].id,
      );
    }
    for (var i = 0; i < sepaMandates.length; i++) {
      if (!touchedMandates.contains(sepaMandates[i].id)) continue;
      sepaMandates[i] = sepaMandates[i].copyWith(lastUsedAt: now);
      await _pushToCloud(
        'sepa_mandates',
        sepaMandates[i].toMap(),
        docId: sepaMandates[i].id,
      );
    }
    await _persistSepa();
    await _logAudit(
      'Lot de prélèvements transmis',
      'Finance',
      detail: '${debitIds.length} ordre(s) — lot ${batchId ?? 'sans identifiant'}',
    );
    notifyListeners();
  }

  /// Indicateurs de synthèse pour l'écran de domiciliation.
  Map<String, num> sepaSummary() {
    final active = sepaMandates
        .where((m) => m.status == SepaMandateStatus.active)
        .length;
    final eligible = clients.where((c) => canDebitClient(c.id)).length;
    final pending = sepaDebits
        .where((d) => d.status == SepaDebitStatus.preNotified)
        .fold<double>(0, (s, d) => s + d.amount);
    final missingMandate = clients
        .where((c) => c.active && mandateForClient(c.id) == null)
        .length;
    return {
      'mandatsActifs': active,
      'clientsEligibles': eligible,
      'clientsSansMandat': missingMandate,
      'montantEnAttente': pending,
    };
  }

  // ─────────────────────────── BOOKINGS ───────────────────────────

  /// Prochain numéro de référence de réservation.
  ///
  /// On repart du PLUS GRAND numéro déjà présent (et non du nombre de lignes) :
  /// après une suppression, `bookings.length` régresse et produirait un doublon
  /// de référence — inacceptable pour un document engageant.
  String _nextBookingRef() {
    var max = 0;
    final re = RegExp(r'(\d+)\s*$');
    for (final b in bookings) {
      final m = re.firstMatch(b.reference);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return 'GRX-BK-2025-${(max + 1).toString().padLeft(4, '0')}';
  }

  Future<void> createBooking(Booking b) async {
    final nb = Booking(
      id: 'b_${DateTime.now().microsecondsSinceEpoch}',
      reference: _nextBookingRef(),
      type: b.type,
      clientId: b.clientId,
      clientName: b.clientName,
      providerId: b.providerId,
      providerName: b.providerName,
      requestId: b.requestId,
      title: b.title,
      date: b.date,
      time: b.time,
      location: b.location,
      providerPrice: b.providerPrice,
      clientPrice: b.clientPrice,
      commission: b.commission,
      status: b.status,
      confirmed: b.confirmed,
      documentNames: b.documentNames,
      notes: b.notes,
    );

    // Serveur d'abord : une réservation engage le prestataire et le client.
    // Si l'écriture échoue, rien n'apparaît à l'écran — on ne montre jamais
    // une réservation que la base ne contient pas.
    final ok = await _pushToCloud('bookings', nb.toMap(), docId: nb.id);
    if (!ok) throw const CloudWriteException('Réservation');

    bookings.insert(0, nb);
    log('Création réservation', nb.reference);
    await _persist();
    notifyListeners();
  }

  Future<void> updateBooking(Booking b) async {
    final i = bookings.indexWhere((e) => e.id == b.id);
    if (i < 0) return;
    final previous = bookings[i];

    final ok = await _pushToCloud('bookings', b.toMap(), docId: b.id);
    if (!ok) throw const CloudWriteException('Réservation');

    bookings[i] = b;
    if (previous.status != b.status) {
      log('Statut réservation', b.reference, detail: b.status.label);
    }
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── ITINERARIES ───────────────────────────

  /// Prochain numéro d'itinéraire (basé sur le plus grand existant).
  String _nextItineraryRef() {
    var max = 0;
    final re = RegExp(r'(\d+)\s*$');
    for (final it in itineraries) {
      final m = re.firstMatch(it.reference);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return 'GRX-ITN-2025-${(max + 1).toString().padLeft(4, '0')}';
  }

  Future<Itinerary> createItinerary(Itinerary draft) async {
    final it = Itinerary(
      id: 'it_${DateTime.now().microsecondsSinceEpoch}',
      reference: _nextItineraryRef(),
      clientId: draft.clientId,
      clientName: draft.clientName,
      title: draft.title,
      destination: draft.destination,
      startDate: draft.startDate,
      endDate: draft.endDate,
      items: draft.items,
      flightInfo: draft.flightInfo,
      hotelInfo: draft.hotelInfo,
      transferInfo: draft.transferInfo,
      contacts: draft.contacts,
      securityIncluded: draft.securityIncluded,
      status: draft.status,
      createdAt: DateTime.now(),
    );

    // Serveur d'abord : le client doit retrouver son itinéraire depuis
    // n'importe quel appareil.
    final ok = await _pushToCloud('itineraries', it.toMap(), docId: it.id);
    if (!ok) throw const CloudWriteException('Itinéraire');

    itineraries.insert(0, it);
    log('Création itinéraire', it.reference);
    await _persist();
    notifyListeners();
    return it;
  }

  Future<void> updateItinerary(Itinerary it) async {
    final i = itineraries.indexWhere((e) => e.id == it.id);
    if (i < 0) return;

    final ok = await _pushToCloud('itineraries', it.toMap(), docId: it.id);
    if (!ok) throw const CloudWriteException('Itinéraire');

    itineraries[i] = it;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── FINANCE ───────────────────────────

  /// Prochain numéro de document financier.
  ///
  /// Basé sur le plus grand numéro existant pour ce type : une facture ne doit
  /// JAMAIS réutiliser une référence (obligation légale de séquence continue).
  String _nextFinanceRef(FinanceDocType t) {
    final prefix = {
      FinanceDocType.invoice: 'GRX-INV',
      FinanceDocType.quote: 'GRX-Q',
      FinanceDocType.deposit: 'GRX-DEP',
      FinanceDocType.credit: 'GRX-CN',
    }[t]!;
    var max = 0;
    final re = RegExp(r'(\d+)\s*$');
    for (final f in financeDocs.where((f) => f.type == t)) {
      final m = re.firstMatch(f.reference);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > max) max = n;
      }
    }
    return '$prefix-2025-${(max + 1).toString().padLeft(4, '0')}';
  }

  Future<FinanceDocument> createFinanceDoc(FinanceDocument draft) async {
    final reference = _nextFinanceRef(draft.type);
    // Enrichissement automatique : régime TVA, mention, numéro client, Peppol.
    final client = clientById(draft.clientId);
    final vat = VatService.computeVat(client);
    final peppol = VatService.isPeppolEligible(client) && client!.peppolEnabled;
    final d = FinanceDocument(
      id: 'f_${DateTime.now().microsecondsSinceEpoch}',
      reference: reference,
      type: draft.type,
      clientId: draft.clientId,
      clientName: draft.clientName,
      requestId: draft.requestId,
      bookingId: draft.bookingId,
      date: draft.date,
      dueDate: draft.dueDate,
      lines: draft.lines,
      taxPercent: draft.taxPercent == 21 ? vat.rate : draft.taxPercent,
      status: draft.status,
      currency: draft.currency,
      amountPaid: draft.amountPaid,
      notes: draft.notes,
      peppolStatus: draft.type == FinanceDocType.invoice && peppol
          ? PeppolStatus.ready
          : PeppolStatus.notApplicable,
      vatMention: vat.mention,
      clientVatNumber: client?.vatNumber,
      structuredCommunication: VatService.structuredCommunication(reference),
      clientReference: draft.clientReference,
    );

    // Serveur d'abord : une facture est une pièce comptable. Si l'écriture
    // échoue, on ne l'affiche pas — sinon le comptable croirait la pièce émise
    // alors qu'elle n'existe que sur ce poste.
    final ok = await _pushToCloud('finance_docs', d.toMap(), docId: d.id);
    if (!ok) throw const CloudWriteException('Document financier');

    financeDocs.insert(0, d);
    log(
      'Création document',
      d.reference,
      detail:
          '${d.type.label} · TVA ${vat.rate.toStringAsFixed(0)}%'
          '${d.peppolStatus == PeppolStatus.ready ? ' · Peppol prêt' : ''}',
    );
    await _persist();
    notifyListeners();
    return d;
  }

  /// Établit la facture d'une réservation.
  ///
  /// Une prestation vendue au client final doit produire une pièce comptable
  /// sans ressaisie : le montant vient du prix client négocié, le libellé de
  /// la réservation. Le coût fournisseur reste interne et n'apparaît JAMAIS
  /// sur la facture du client.
  ///
  /// Refus explicite si une facture existe déjà : la double facturation d'un
  /// même événement est une faute comptable, pas un détail d'affichage.
  Future<FinanceDocument> createInvoiceFromBooking(String bookingId) async {
    Booking? b;
    for (final e in bookings) {
      if (e.id == bookingId) {
        b = e;
        break;
      }
    }
    if (b == null) {
      throw const CloudWriteException(
        'Réservation introuvable : impossible d\'établir la facture',
      );
    }
    if (b.clientId.isEmpty) {
      throw const CloudWriteException(
        'Aucun client rattaché à cette réservation : facture impossible',
      );
    }
    final existing = invoiceForBooking(bookingId);
    if (existing != null) {
      throw CloudWriteException(
        'Une facture existe déjà pour cette réservation (${existing.reference})',
      );
    }
    if (b.clientPrice <= 0) {
      throw const CloudWriteException(
        'Prix client à zéro : renseignez le prix avant de facturer',
      );
    }

    final date = DateFormat('dd/MM/yyyy', 'fr_BE').format(b.date);
    final draft = FinanceDocument(
      id: '',
      reference: '',
      type: FinanceDocType.invoice,
      clientId: b.clientId,
      clientName: b.clientName,
      bookingId: b.id,
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 30)),
      // Le coût fournisseur n'est pas facturé au client : seule la ligne au
      // prix de vente figure sur la pièce.
      lines: [
        FinanceLine(
          description: '${b.title} — $date ${b.time} · ${b.location}',
          unitPrice: b.clientPrice,
        ),
      ],
      status: InvoiceStatus.sent,
      notes: 'Réservation ${b.reference}',
    );

    final doc = await createFinanceDoc(draft);
    log(
      'Facturation réservation',
      b.reference,
      detail: '${doc.reference} · ${b.clientPrice.toStringAsFixed(2)} EUR',
    );
    return doc;
  }

  /// Transmet une facture via l'Access Point Peppol configuré.
  /// Si l'Access Point n'est pas configuré, l'envoi est simulé.
  Future<PeppolSendResult> sendViaPeppol(String docId) async {
    final i = financeDocs.indexWhere((e) => e.id == docId);
    if (i < 0) {
      return const PeppolSendResult(
        success: false,
        message: 'Document introuvable.',
      );
    }
    final d = financeDocs[i];
    final result = await PeppolService.send(
      document: d,
      client: clientById(d.clientId),
      company: company,
      config: peppol,
    );
    if (result.simulated) {
      // ── AUCUNE TRACE D'ENVOI POUR UNE SIMULATION ──────────────────────
      // Avant cette correction, un envoi simulé (Access Point non
      // configuré) écrivait `peppolStatus = sent` et faisait passer la
      // facture de « brouillon » à « émise ». La pièce comptable affirmait
      // donc avoir été transmise à Peppol alors qu'aucune requête n'était
      // partie. Le statut reste donc INCHANGÉ : la facture demeure « Prêt à
      // envoyer », ce qui est la vérité. Seul un accusé réel (référence
      // fournisseur) autorise le passage à « Envoyé ».
      log(
        'Peppol (simulation)',
        d.reference,
        detail: 'Aucun envoi réel — Access Point non configuré',
      );
    } else if (result.success) {
      financeDocs[i] = d.copyWith(
        peppolStatus: PeppolStatus.sent,
        status: d.status == InvoiceStatus.draft ? InvoiceStatus.sent : d.status,
        peppolProviderReference: result.providerReference,
        peppolLastUpdate: DateTime.now(),
      );
      log(
        'Envoi Peppol',
        d.reference,
        detail: 'Transmis · ${result.providerReference ?? 'OK'}',
      );
    } else {
      financeDocs[i] = d.copyWith(
        peppolStatus: PeppolStatus.failed,
        peppolLastUpdate: DateTime.now(),
      );
      log('Échec Peppol', d.reference, detail: result.message);
    }
    await _persist();
    notifyListeners();
    return result;
  }

  /// Interroge l'Access Point pour actualiser le statut d'une facture
  /// (confirmation de distribution asynchrone — polling).
  Future<PeppolStatus?> refreshPeppolStatus(String docId) async {
    final i = financeDocs.indexWhere((e) => e.id == docId);
    if (i < 0) return null;
    final d = financeDocs[i];
    final ref = d.peppolProviderReference;
    if (ref == null || ref.isEmpty) {
      // Aucune référence fournisseur = aucun envoi réel n'a eu lieu. On ne
      // fabrique donc AUCUNE progression de statut : une facture ne peut pas
      // devenir « Distribuée » sans qu'un Access Point l'ait confirmée.
      // (Avant cette correction, un document en mode simulation passait de
      // « Envoyé » à « Distribué » sans qu'aucune requête ne parte.)
      return d.peppolStatus;
    }
    final status = await PeppolService.getSubmissionStatus(
      config: peppol,
      providerReference: ref,
    );
    if (status == null) return d.peppolStatus;
    if (status != d.peppolStatus) {
      financeDocs[i] = d.copyWith(
        peppolStatus: status,
        peppolLastUpdate: DateTime.now(),
      );
      log('Peppol statut', d.reference, detail: '→ ${status.label}');
      await _persist();
      notifyListeners();
    }
    return status;
  }

  /// Rafraîchit le statut de toutes les factures en cours (sent/failed).
  /// Retourne le nombre de statuts mis à jour.
  Future<int> refreshAllPeppolStatuses() async {
    var updated = 0;
    final pending = financeDocs
        .where(
          (d) =>
              d.peppolStatus == PeppolStatus.sent ||
              d.peppolStatus == PeppolStatus.failed,
        )
        .toList();
    for (final d in pending) {
      final before = d.peppolStatus;
      final after = await refreshPeppolStatus(d.id);
      if (after != null && after != before) updated++;
    }
    return updated;
  }

  /// Applique une notification webhook reçue de l'Access Point.
  /// [payload] est le corps JSON brut ; [reference] identifie la facture
  /// (référence interne ou référence fournisseur).
  Future<bool> ingestPeppolWebhook(
    Map<String, dynamic> payload, {
    String? reference,
  }) async {
    final status = PeppolService.parseStatusFromBody(jsonEncode(payload));
    if (status == null) return false;
    final ref =
        reference ??
        (payload['document_submission_guid'] ??
                payload['tracking_id'] ??
                payload['guid'] ??
                payload['reference'])
            ?.toString();
    if (ref == null || ref.isEmpty) return false;
    final i = financeDocs.indexWhere(
      (d) => d.peppolProviderReference == ref || d.reference == ref,
    );
    if (i < 0) return false;
    financeDocs[i] = financeDocs[i].copyWith(
      peppolStatus: status,
      peppolLastUpdate: DateTime.now(),
    );
    log(
      'Webhook Peppol',
      financeDocs[i].reference,
      detail: '→ ${status.label}',
    );
    await _persist();
    notifyListeners();
    return true;
  }

  /// Génère le XML UBL 2.1 (Peppol BIS Billing 3.0) d'une facture.
  UblResult generateUbl(String docId) {
    final d = financeById(docId);
    if (d == null) {
      return const UblResult('', '');
    }
    return PeppolUblGenerator.generate(
      f: d,
      client: clientById(d.clientId),
      company: company,
    );
  }

  /// Met à jour la configuration de l'Access Point Peppol.
  ///
  /// ── DEUX ÉCRITURES, DEUX DESTINATAIRES ────────────────────────────────
  /// La configuration « publique » (URL, identifiants, options) va dans
  /// `company/gorex-group`. Le SECRET (la clé d'API) va dans
  /// `company_secrets/gorex-group`, dont les règles réservent la lecture au
  /// seul rôle finance. Sans cette séparation, la clé serait servie au
  /// navigateur de tout utilisateur connecté, clients VIP compris.
  Future<void> updatePeppol(PeppolConfig config) async {
    // ── ON N'ACTIVE PAS UNE TRANSMISSION QUI ÉCHOUERA ─────────────────
    // Activer la transmission sans identifiant d'entité légale numérique
    // produit une configuration qui a l'air prête mais dont chaque envoi est
    // refusé. On refuse donc l'enregistrement : une configuration incomplète
    // doit rester désactivée, pas silencieusement cassée.
    if (config.enabled &&
        config.isConfigured &&
        config.legalEntityId == null) {
      throw ArgumentError(
        'Identifiant d\'entité légale requis (nombre entier) pour activer '
        'la transmission Peppol.',
      );
    }
    peppol = config;
    log('Configuration Peppol', config.enabled ? 'Activée' : 'Désactivée');
    await _persist();
    notifyListeners();
    final ok = await _pushToCloud('company', {
      'peppol': config.toMap(),
    }, docId: _companyDocId);
    if (!ok) throw const CloudWriteException('Configuration Peppol');

    // Le secret n'est écrit que s'il y a quelque chose à écrire : inutile
    // d'écraser une clé existante avec une chaîne vide quand l'utilisateur
    // modifie un autre champ (le champ est masqué à la saisie).
    if (config.apiKey.trim().isNotEmpty) {
      final secretOk = await _pushToCloud(
        'company_secrets',
        config.toSecretMap(),
        docId: _companyDocId,
      );
      if (!secretOk) {
        throw const CloudWriteException('Clé d\'API Peppol');
      }
    }
  }

  /// Relit la clé d'API Peppol depuis `company_secrets/`.
  ///
  /// Réservée au rôle finance par les règles Firestore : pour les autres
  /// rôles la lecture échoue, ce qui est le comportement attendu — un
  /// utilisateur qui n'a pas à facturer n'a pas à détenir la clé.
  /// Un échec de lecture conserve la valeur locale au lieu de l'effacer.
  Future<void> loadPeppolSecretFromCloud() async {
    final token = restIdToken;
    if (token == null || token.isEmpty) return;
    try {
      final row = await RestAuthService.fetchDocument(
        'company_secrets/$_companyDocId',
        token,
      );
      if (row == null || row.isEmpty) return;
      final merged = peppol.mergeSecretMap(row);
      if (identical(merged, peppol) || merged.apiKey == peppol.apiKey) return;
      peppol = merged;
      await _persist();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[State] clé Peppol (REST) : $e');
    }
  }

  /// Enregistre une confirmation de distribution reçue du destinataire.
  ///
  /// ── CE N'EST PAS UNE SIMULATION ───────────────────────────────────────
  /// Cette méthode traduisait auparavant une « simulation » : elle forçait le
  /// statut à `delivered` sans condition. Une facture pouvait donc être
  /// présentée comme distribuée via Peppol sans qu'aucun document n'ait
  /// jamais quitté l'application.
  ///
  /// Elle exige désormais une **référence fournisseur réelle** : la preuve
  /// qu'un envoi a bien eu lieu. Elle sert alors à consigner un accusé reçu
  /// par un autre canal (e-mail du destinataire, portail de l'Access Point)
  /// quand le webhook n'est pas encore branché. Sans référence, elle refuse.
  Future<bool> markPeppolDelivered(String docId) async {
    final i = financeDocs.indexWhere((e) => e.id == docId);
    if (i < 0) return false;
    final d = financeDocs[i];
    final ref = (d.peppolProviderReference ?? '').trim();
    if (ref.isEmpty) {
      log(
        'Peppol refusé',
        d.reference,
        detail: 'Accusé impossible : aucun envoi réel enregistré',
      );
      return false;
    }
    financeDocs[i] = d.copyWith(peppolStatus: PeppolStatus.delivered);
    log('Peppol distribué', d.reference, detail: 'Accusé saisi · $ref');
    await _persist();
    notifyListeners();
    return true;
  }

  /// Met à jour les coordonnées officielles de Gorex Group (facturation).
  Future<void> updateCompany(CompanyProfile profile) async {
    company = profile;
    log('Mise à jour coordonnées société', profile.legalName);
    await _persist();
    notifyListeners();
    final ok = await _pushToCloud(
      'company',
      company.toMap(),
      docId: _companyDocId,
    );
    if (!ok) {
      throw const CloudWriteException('Coordonnées de la société');
    }
  }

  // ─────────────────────── COMPTABILITÉ & ENCAISSEMENT ───────────────────────
  /// Enregistre le paiement (partiel ou total) d'une facture.
  Future<void> markInvoicePaid(
    String docId, {
    double? amount,
    PaymentMatchMethod method = PaymentMatchMethod.manual,
    DateTime? date,
  }) async {
    final i = financeDocs.indexWhere((e) => e.id == docId);
    if (i < 0) return;
    final d = financeDocs[i];
    final newPaid = amount == null ? d.total : (d.amountPaid + amount);
    final paid = newPaid >= d.total - 0.005;
    final updated = d.copyWith(
      amountPaid: newPaid.clamp(0, d.total),
      status: paid ? InvoiceStatus.paid : d.status,
      paidAt: paid ? (date ?? DateTime.now()) : null,
      paymentMethod: method,
    );

    // Serveur d'abord : un encaissement mal enregistré fausse la comptabilité
    // et le solde client. En cas de refus, le solde affiché reste inchangé.
    // Seuls les champs de paiement sont transmis (updateMask) : on n'écrase
    // jamais les lignes ni la TVA validées à l'émission.
    final ok = await _pushToCloud('finance_docs', {
      'amountPaid': updated.amountPaid,
      'status': updated.status.name,
      'paidAt': updated.paidAt?.toUtc().toIso8601String(),
      'paymentMethod': updated.paymentMethod?.name,
    }, docId: docId);
    if (!ok) throw const CloudWriteException('Encaissement');

    financeDocs[i] = updated;
    log(
      'Encaissement',
      d.reference,
      detail: paid
          ? 'Soldée · ${method.label}'
          : 'Partiel · reste ${(d.total - newPaid).toStringAsFixed(2)} €',
    );
    await _persist();
    notifyListeners();
  }

  /// Rapproche une transaction bancaire d'une facture (paiement + lien).
  Future<void> reconcileTransaction(
    String transactionId,
    String docId, {
    PaymentMatchMethod method = PaymentMatchMethod.manual,
  }) async {
    final ti = bankTransactions.indexWhere((t) => t.id == transactionId);
    if (ti < 0) return;
    final t = bankTransactions[ti];

    // La transaction est marquée AVANT l'encaissement : si celui-ci échoue,
    // le rapprochement est annulé pour rester cohérent.
    final linked = t.copyWith(matched: true, matchedDocumentId: docId);
    final okTx = await _pushToCloud(
      'bank_transactions',
      linked.toMap(),
      docId: linked.id,
    );
    if (!okTx) throw const CloudWriteException('Rapprochement bancaire');

    try {
      await markInvoicePaid(
        docId,
        amount: t.amount,
        method: method,
        date: t.date,
      );
    } on CloudWriteException {
      // Retour arrière : la transaction ne doit pas rester liée à une facture
      // dont l'encaissement n'a pas été enregistré.
      await _pushToCloud('bank_transactions', {
        'matched': false,
        'matchedDocumentId': null,
      }, docId: linked.id);
      rethrow;
    }

    bankTransactions[ti] = linked;
    log(
      'Rapprochement bancaire',
      t.counterparty,
      detail: '${t.amount.toStringAsFixed(2)} € → facture',
    );
    await _persist();
    notifyListeners();
  }

  /// Détache une transaction précédemment rapprochée.
  Future<void> unmatchTransaction(String transactionId) async {
    final ti = bankTransactions.indexWhere((t) => t.id == transactionId);
    if (ti < 0) return;
    final previous = bankTransactions[ti];
    final updated = previous.copyWith(matched: false, matchedDocumentId: null);

    final ok = await _pushToCloud('bank_transactions', {
      'matched': false,
      'matchedDocumentId': null,
    }, docId: previous.id);
    if (!ok) throw const CloudWriteException('Détachement du rapprochement');

    bankTransactions[ti] = updated;
    await _persist();
    notifyListeners();
  }

  /// Rapprochement automatique : associe les crédits non rapprochés aux
  /// factures impayées via communication structurée / référence / montant.
  /// Retourne le nombre de rapprochements effectués.
  ///
  /// Un échec serveur sur une transaction n'interrompt pas le lot : les
  /// suivantes sont tentées, et seules celles réellement enregistrées sont
  /// comptées.
  Future<int> autoReconcile({double threshold = 0.5}) async {
    final open = bankTransactions
        .where((t) => !t.matched && t.amount > 0)
        .toList();
    if (open.isEmpty) return 0;
    final matches = ReconciliationService.autoMatch(
      open,
      financeDocs,
      threshold: threshold,
    );
    var n = 0;
    var failed = 0;
    for (final m in matches) {
      if (m.matched) {
        try {
          await reconcileTransaction(
            m.transaction.id,
            m.document!.id,
            method: m.method,
          );
          n++;
        } on CloudWriteException {
          failed++;
        }
      }
    }
    if (n > 0) log('Rapprochement auto', '$n transaction(s)');
    if (failed > 0) {
      log(
        'Rapprochement auto',
        '$failed échec(s)',
        detail: 'Enregistrement serveur refusé',
      );
    }
    return n;
  }

  /// Envoie (ou marque comme envoyée) la relance suivante d'une facture.
  Future<ReminderPlan?> sendReminder(String docId) async {
    final i = financeDocs.indexWhere((e) => e.id == docId);
    if (i < 0) return null;
    final d = financeDocs[i];
    final p = ReminderService.plan(d, minDays: reminderConfig.minDaysBetween);
    if (!p.due) return p;
    final updated = d.copyWith(
      reminderLevel: p.nextLevel,
      lastReminderAt: DateTime.now(),
      status: d.status == InvoiceStatus.paid ? d.status : InvoiceStatus.overdue,
    );

    // Serveur d'abord : la relance est horodatée. Si elle n'est pas
    // enregistrée, le moteur automatique la renverrait au prochain passage —
    // le client recevrait deux fois la même relance.
    final ok = await _pushToCloud('finance_docs', {
      'reminderLevel': updated.reminderLevel.name,
      'lastReminderAt': updated.lastReminderAt?.toUtc().toIso8601String(),
      'status': updated.status.name,
    }, docId: docId);
    if (!ok) throw const CloudWriteException('Relance');

    financeDocs[i] = updated;
    log(
      'Relance facture',
      d.reference,
      detail: '${p.nextLevel.label} · ${p.daysOverdue} j de retard',
    );
    await _persist();
    notifyListeners();
    return p;
  }

  /// Relance toutes les factures échues nécessitant une action.
  /// Retourne le nombre de relances envoyées.
  /// Relance toutes les factures échues nécessitant une action.
  /// Retourne le nombre de relances réellement enregistrées.
  ///
  /// Un refus serveur sur une facture n'interrompt pas le lot : les autres
  /// relances sont tentées et seules celles persistées sont comptées.
  Future<int> sendAllDueReminders() async {
    final plans = ReminderService.pending(
      financeDocs,
      minDays: reminderConfig.minDaysBetween,
    );
    var sent = 0;
    for (final p in plans) {
      try {
        await sendReminder(p.document.id);
        sent++;
      } on CloudWriteException {
        // Facture ignorée : le compteur ne l'inclut pas, l'interface
        // n'annonce donc pas une relance qui n'a pas été enregistrée.
      }
    }
    return sent;
  }

  /// ── Moteur de relance automatique (planifié) ──
  /// Indique si une exécution automatique est due (démarrage ou intervalle).
  bool get reminderRunDue {
    if (!reminderConfig.enabled) return false;
    final last = reminderConfig.lastRunAt;
    if (last == null) return true;
    final elapsed = DateTime.now().difference(last);
    return elapsed.inHours >= reminderConfig.intervalHours;
  }

  /// Exécute le moteur de relance automatique si les conditions sont réunies.
  /// [force] court-circuite la vérification d'intervalle.
  /// Retourne le nombre de relances envoyées (0 si rien à faire).
  Future<int> runAutoReminders({bool force = false}) async {
    if (!reminderConfig.enabled) return 0;
    if (!force && !reminderRunDue) return 0;
    final plans = ReminderService.pending(
      financeDocs,
      minDays: reminderConfig.minDaysBetween,
    );
    if (reminderConfig.autoSend) {
      for (final p in plans) {
        try {
          await sendReminder(p.document.id);
        } on CloudWriteException {
          // Une facture non enregistrée ne doit pas empêcher les suivantes.
        }
      }
    }
    reminderConfig = reminderConfig.copyWith(
      lastRunAt: DateTime.now(),
      lastRunCount: plans.length,
    );
    log(
      'Relances automatiques',
      '${plans.length} relance(s)',
      detail: reminderConfig.autoSend
          ? 'Envoi automatique'
          : 'Détection seule (envoi désactivé)',
    );
    await _persist();
    notifyListeners();
    return plans.length;
  }

  /// Met à jour la configuration du moteur de relance automatique.
  Future<void> updateReminderConfig(ReminderConfig config) async {
    reminderConfig = config;
    log('Configuration relances', config.enabled ? 'Activée' : 'Désactivée');
    await _persist();
    notifyListeners();
    final ok = await _pushToCloud('company', {
      'reminderConfig': config.toMap(),
    }, docId: _companyDocId);
    if (!ok) throw const CloudWriteException('Configuration des relances');
  }

  /// Email de relance (sujet + corps) pour une facture.
  ({String subject, String body}) buildReminderEmail(
    FinanceDocument d,
    ReminderLevel level,
  ) => ReminderService.buildEmail(
    d,
    level,
    companyName: company.brandName.isNotEmpty
        ? company.brandName
        : company.legalName,
    companyVat: company.vatNumber,
    iban: company.iban,
  );

  /// Factures échues (impayées) triées par ancienneté.
  List<FinanceDocument> get overdueInvoices {
    final list = financeDocs.where((d) => d.isOverdue).toList()
      ..sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));
    return list;
  }

  int get overdueCount => overdueInvoices.length;

  double get overdueAmount =>
      overdueInvoices.fold(0.0, (s, d) => s + d.balance);

  /// Montant déjà encaissé (factures soldées) pour l'exercice courant.
  double get collectedAmount => financeDocs
      .where(
        (d) =>
            d.type == FinanceDocType.invoice && d.status == InvoiceStatus.paid,
      )
      .fold(0.0, (s, d) => s + d.amountPaid);

  /// Transactions bancaires non encore rapprochées.
  List<BankTransaction> get unmatchedTransactions =>
      bankTransactions.where((t) => !t.matched).toList();

  double get unmatchedAmount =>
      unmatchedTransactions.fold(0.0, (s, t) => s + t.amount);

  /// Journaux de vente de l'exercice (factures) — pour export comptable.
  List<FinanceDocument> salesJournal({int? year}) =>
      financeDocs
          .where((d) => d.type == FinanceDocType.invoice)
          .where((d) => year == null || d.date.year == year)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  Future<void> updateFinanceDoc(FinanceDocument d) async {
    final i = financeDocs.indexWhere((e) => e.id == d.id);
    if (i < 0) return;

    // Serveur d'abord : une pièce comptable modifiée doit l'être en base,
    // sinon la version affichée et la version comptable divergent.
    final ok = await _pushToCloud('finance_docs', d.toMap(), docId: d.id);
    if (!ok) throw const CloudWriteException('Document financier');

    financeDocs[i] = d;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── PROVIDERS ───────────────────────────

  /// Crée un prestataire et l'enregistre sur le serveur.
  ///
  /// Un prestataire est une contrepartie contractuelle : sans écriture en
  /// base, il n'existerait que sur ce poste et les réservations qui le
  /// référencent deviendraient orphelines ailleurs.
  Future<Provider> createProvider(Provider draft) async {
    final p = Provider(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      name: draft.name,
      category: draft.category,
      domain: draft.domain,
      country: draft.country,
      city: draft.city,
      contactName: draft.contactName,
      contactEmail: draft.contactEmail,
      contactPhone: draft.contactPhone,
      rate: draft.rate,
      commissionPercent: draft.commissionPercent,
      trustLevel: draft.trustLevel,
      active: draft.active,
      documentNames: draft.documentNames,
      hasContract: draft.hasContract,
      internalNotes: draft.internalNotes,
    );

    final ok = await _pushToCloud('providers', p.toMap(), docId: p.id);
    if (!ok) throw const CloudWriteException('Prestataire');

    providers.insert(0, p);
    log('Création prestataire', p.name, detail: p.category);
    await _persist();
    notifyListeners();
    return p;
  }

  Future<void> updateProvider(Provider p) async {
    final i = providers.indexWhere((e) => e.id == p.id);
    if (i < 0) return;

    // Serveur d'abord : le tarif et la commission conditionnent les marges
    // des réservations. Une valeur non enregistrée fausserait la facturation.
    final ok = await _pushToCloud('providers', p.toMap(), docId: p.id);
    if (!ok) throw const CloudWriteException('Prestataire');

    providers[i] = p;
    log('Mise à jour prestataire', p.name);
    await _persist();
    notifyListeners();
  }

  /// Supprime un prestataire.
  ///
  /// Refusé si des réservations y sont rattachées : les supprimer laisserait
  /// des rendez-vous sans contrepartie identifiée.
  Future<void> deleteProvider(String id) async {
    final i = providers.indexWhere((e) => e.id == id);
    if (i < 0) return;

    final linked = bookings.where((b) => b.providerId == id).length;
    if (linked > 0) {
      throw CloudWriteException(
        'Prestataire : $linked réservation(s) y sont rattachées. '
        'Désactivez-le plutôt que de le supprimer',
      );
    }

    final removed = providers[i];
    final code = await RestAuthService.deleteDocument(
      'providers/$id',
      restIdToken ?? '',
    );
    // Un document déjà absent (404) n'est pas un échec : l'objectif est atteint.
    if (code != 200 && code != 404) {
      throw const CloudWriteException('Suppression du prestataire');
    }

    providers.removeAt(i);
    log('Suppression prestataire', removed.name);
    await _persist();
    notifyListeners();
  }

  /// Charge le carnet de prestataires depuis Firestore.
  ///
  /// Sans cela, un prestataire saisi sur un poste restait invisible partout
  /// ailleurs, et le formulaire de réservation proposait une liste vide.
  Future<void> loadProvidersFromCloud() async {
    // 403 CORRIGÉ. Le carnet de prestataires est réservé au personnel
    // (`match /providers/{doc} { allow read, write: if isStaff(); }`).
    // Un client connecté provoquait un 403 à chaque connexion. Il n'a pas à
    // connaître les prestataires : on ne demande plus rien.
    if (!isStaff) return;

    final token = restIdToken;
    if (token == null || token.isEmpty) return;

    List<Map<String, dynamic>> rows;
    try {
      rows = await RestAuthService.fetchCollection(
        'providers',
        token,
        limit: 500,
      );
      // Le repli SDK ne sert que si la voie REST n'a rien renvoyé.
      if (rows.isEmpty && FirestoreService.available) {
        try {
          rows = await FirestoreService.fetchCollection(
            'providers',
            limit: 500,
          );
        } catch (_) {}
      }
    } catch (_) {
      return;
    }

    if (rows.isEmpty) return;

    final loaded = <Provider>[];
    for (final r in rows) {
      try {
        loaded.add(Provider.fromMap(Map<String, dynamic>.from(r)));
      } catch (_) {
        // Fiche incomplète : ignorée plutôt que de faire échouer le lot.
      }
    }
    if (loaded.isEmpty) return;

    loaded.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    providers = loaded;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── COMMUNICATION ───────────────────────────
  Future<void> sendMessage(
    String conversationId,
    String text, {
    bool internal = false,
  }) async {
    final i = conversations.indexWhere((c) => c.id == conversationId);
    if (i < 0) return;
    final conv = conversations[i];
    final msg = ChatMessage(
      id: 'm_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: currentUser?.id ?? 'anon',
      senderName: currentUser?.fullName ?? 'Utilisateur',
      senderRole: currentUser?.role.label ?? '',
      text: text,
      timestamp: DateTime.now(),
      internal: internal,
    );
    conversations[i] = conv.copyWith(
      messages: [...conv.messages, msg],
      lastActivity: DateTime.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<Conversation> createConversation({
    required String subject,
    required String clientId,
    String? requestId,
  }) async {
    final client = clientById(clientId);
    final conv = Conversation(
      id: 'cv_${DateTime.now().microsecondsSinceEpoch}',
      subject: subject,
      requestId: requestId,
      clientId: clientId,
      clientName: client?.fullName ?? 'Client',
      participantNames: [
        currentUser?.fullName ?? 'Concierge',
        client?.fullName ?? 'Client',
      ],
      messages: [],
      lastActivity: DateTime.now(),
    );
    conversations.insert(0, conv);
    await _persist();
    notifyListeners();
    return conv;
  }

  // ─────────────────────────── AGENDA ───────────────────────────
  Future<void> addAppointment(Appointment a) async {
    appointments.add(a);
    log('Ajout agenda', a.title);
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── CRM ───────────────────────────
  Future<void> updateProspect(Prospect p) async {
    final i = prospects.indexWhere((e) => e.id == p.id);
    if (i < 0) return;
    prospects[i] = p;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── KPIs ───────────────────────────
  int get activeClients => clients.where((c) => c.active).length;
  int get openRequests => requests
      .where(
        (r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.cancelled,
      )
      .length;
  int get urgentRequests => requests
      .where(
        (r) => r.urgency.weight >= 2 && r.status != RequestStatus.completed,
      )
      .length;
  int get activeSubscriptions => clients.length;

  double get totalRevenue => financeDocs
      .where(
        (f) =>
            f.type == FinanceDocType.invoice &&
            f.status != InvoiceStatus.cancelled,
      )
      .fold(0.0, (s, f) => s + f.total);

  double get totalCost => expenses.fold(0.0, (s, e) => s + e.amount);
  double get totalMargin => totalRevenue - totalCost;
  double get totalCommissions => bookings.fold(0.0, (s, b) => s + b.commission);
  double get outstandingBalance => financeDocs
      .where(
        (f) =>
            f.type == FinanceDocType.invoice && f.status != InvoiceStatus.paid,
      )
      .fold(0.0, (s, f) => s + f.balance);

  Map<ServiceDomain, int> get requestsByDomain {
    final m = <ServiceDomain, int>{for (final d in ServiceDomain.values) d: 0};
    for (final r in requests) {
      m[r.domain] = (m[r.domain] ?? 0) + 1;
    }
    return m;
  }

  /// Performance des concierges : demandes assignées
  Map<String, int> get conciergePerformance {
    final m = <String, int>{};
    for (final r in requests) {
      if (r.responsibleName != null) {
        m[r.responsibleName!] = (m[r.responsibleName!] ?? 0) + 1;
      }
    }
    return m;
  }

  List<Client> get topClients {
    final list = [...clients];
    list.sort((a, b) {
      final ta = tierById(a.subscriptionTierId)?.annualPrice ?? 0;
      final tb = tierById(b.subscriptionTierId)?.annualPrice ?? 0;
      return tb.compareTo(ta);
    });
    return list;
  }

  double clientValue(String clientId) {
    final invoices = financeForClient(clientId)
        .where((f) => f.type == FinanceDocType.invoice)
        .fold(0.0, (s, f) => s + f.total);
    final tier =
        tierById(clientById(clientId)?.subscriptionTierId)?.annualPrice ?? 0;
    return invoices + tier;
  }

  // ─────────────────────────── CLIENT SIDE HELPERS ───────────────────────────
  List<ServiceRequest> get myRequests {
    final id = currentClient?.id;
    if (id == null) return [];
    return requestsForClient(id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Conversation> get myConversations {
    final id = currentClient?.id;
    if (id == null) return [];
    return conversationsForClient(id);
  }
}
