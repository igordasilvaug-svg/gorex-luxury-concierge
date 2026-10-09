import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_localizations.dart';
import '../core/billing/peppol_service.dart';
import '../core/billing/peppol_ubl_generator.dart';
import '../core/billing/reconciliation_service.dart';
import '../core/billing/reminder_service.dart';
import '../core/billing/vat_service.dart';
import '../data/seed_data.dart';
import '../data/seed_operations.dart';
import '../models/app_user.dart';
import '../models/client.dart';
import '../models/company_profile.dart';
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

/// État applicatif central — persistance locale (shared_preferences JSON)
/// Architecture API-ready : chaque mutation passe par une méthode dédiée
/// qui pourra être remplacée par un appel HTTP.
class AppState extends ChangeNotifier {
  static const _storageKey = 'gorex_state_v1';

  AppUser? currentUser;

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
  List<AuditEntry> auditLog = [];

  bool _ready = false;
  bool get ready => _ready;

  // ─────────────────────────── INIT ───────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
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
    _ready = true;
    notifyListeners();
  }

  void _seed() {
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
    if (users.isEmpty || clients.isEmpty) _seed();
  }

  List<T> _mapList<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      v == null
      ? <T>[]
      : (v as List).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'company': company.toMap(),
        'peppol': peppol.toMap(),
        'reminderConfig': reminderConfig.toMap(),
        'language': language,
        'users': users.map((e) => e.toMap()).toList(),
        'clients': clients.map((e) => e.toMap()).toList(),
        'tiers': tiers.map((e) => e.toMap()).toList(),
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
  Future<void> importMap(Map<String, dynamic> data) => _applyImport(data);

  Future<void> _applyImport(Map<String, dynamic> data) async {
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
      currentUser = null; // session close → reconnexion requise
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

  // ─────────────────────────── AUTH ───────────────────────────
  AppUser? authenticate(String email, String password) {
    final e = email.trim().toLowerCase();
    for (var i = 0; i < users.length; i++) {
      final u = users[i];
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

  /// Change le mot de passe de l'utilisateur connecté (client VIP ou personnel)
  Future<void> changeOwnPassword(String newPassword) async {
    final u = currentUser;
    if (u == null) return;
    final i = users.indexWhere((e) => e.id == u.id);
    if (i < 0) return;
    final updated = users[i].copyWith(
      password: newPassword,
      mustChangePassword: false,
    );
    users[i] = updated;
    currentUser = updated;
    log('Changement mot de passe', updated.email);
    await _persist();
    notifyListeners();
  }

  void logout() {
    if (currentUser != null) log('Déconnexion', currentUser!.email);
    currentUser = null;
    notifyListeners();
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
    requests[i] = r.copyWith(
      status: status,
      history: history,
      updatedAt: DateTime.now(),
    );
    log('Changement statut', r.reference, detail: status.code);
    await _persist();
    notifyListeners();
  }

  Future<void> assignRequest(String id, AppUser user) async {
    final i = requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = requests[i];
    requests[i] = r.copyWith(
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
    log('Assignation', r.reference, detail: user.fullName);
    await _persist();
    notifyListeners();
  }

  Future<void> updateRequest(ServiceRequest updated) async {
    final i = requests.indexWhere((r) => r.id == updated.id);
    if (i < 0) return;
    requests[i] = updated.copyWith(updatedAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> escalateToSecurity(String id) async {
    final i = requests.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = requests[i];
    requests[i] = r.copyWith(
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
    log('Escalade sécurité', r.reference);
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── CLIENTS ───────────────────────────
  Future<void> updateClient(Client c) async {
    final i = clients.indexWhere((e) => e.id == c.id);
    if (i < 0) return;
    clients[i] = c;
    log('Mise à jour client', c.code);
    await _persist();
    notifyListeners();
  }

  String _nextClientCode() =>
      'GRX-VIP-${(clients.length + 1).toString().padLeft(4, '0')}';

  Future<Client> createClient(Client draft) async {
    final c = Client(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      code: _nextClientCode(),
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
    );
    clients.insert(0, c);
    log(
      'Création client',
      c.code,
      detail: c.isBusiness ? 'Professionnel (facturation B2B)' : null,
    );
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

  /// Met à jour un accès existant
  Future<void> updateUser(AppUser updated) async {
    final i = users.indexWhere((e) => e.id == updated.id);
    if (i < 0) return;
    users[i] = updated;
    if (currentUser?.id == updated.id) currentUser = updated;
    log('Mise à jour accès', updated.email);
    await _persist();
    notifyListeners();
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
  }

  // ─────────────────────────── BOOKINGS ───────────────────────────
  String _nextBookingRef() =>
      'GRX-BK-2025-${(bookings.length + 1).toString().padLeft(4, '0')}';

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
    bookings.insert(0, nb);
    log('Création réservation', nb.reference);
    await _persist();
    notifyListeners();
  }

  Future<void> updateBooking(Booking b) async {
    final i = bookings.indexWhere((e) => e.id == b.id);
    if (i < 0) return;
    bookings[i] = b;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── ITINERARIES ───────────────────────────
  String _nextItineraryRef() =>
      'GRX-ITN-2025-${(itineraries.length + 1).toString().padLeft(4, '0')}';

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
    itineraries.insert(0, it);
    log('Création itinéraire', it.reference);
    await _persist();
    notifyListeners();
    return it;
  }

  Future<void> updateItinerary(Itinerary it) async {
    final i = itineraries.indexWhere((e) => e.id == it.id);
    if (i < 0) return;
    itineraries[i] = it;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── FINANCE ───────────────────────────
  String _nextFinanceRef(FinanceDocType t) {
    final prefix = {
      FinanceDocType.invoice: 'GRX-INV',
      FinanceDocType.quote: 'GRX-Q',
      FinanceDocType.deposit: 'GRX-DEP',
      FinanceDocType.credit: 'GRX-CN',
    }[t]!;
    final count = financeDocs.where((f) => f.type == t).length + 1;
    return '$prefix-2025-${count.toString().padLeft(4, '0')}';
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
    if (result.success) {
      financeDocs[i] = d.copyWith(
        peppolStatus: PeppolStatus.sent,
        status: d.status == InvoiceStatus.draft ? InvoiceStatus.sent : d.status,
        peppolProviderReference: result.providerReference,
        peppolLastUpdate: DateTime.now(),
      );
      log(
        'Envoi Peppol',
        d.reference,
        detail: result.simulated
            ? 'Simulation (Access Point non configuré)'
            : 'Transmis · ${result.providerReference ?? 'OK'}',
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
      // En mode simulation, on simule la progression sent → delivered.
      if (!peppol.isConfigured && d.peppolStatus == PeppolStatus.sent) {
        financeDocs[i] = d.copyWith(
          peppolStatus: PeppolStatus.delivered,
          peppolLastUpdate: DateTime.now(),
        );
        log('Peppol (simulation)', d.reference, detail: 'Statut → Distribué');
        await _persist();
        notifyListeners();
        return PeppolStatus.delivered;
      }
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

  /// Teste la connexion à l'Access Point Peppol.
  Future<PeppolSendResult> testPeppolConnection() =>
      PeppolService.testConnection(peppol);

  /// Met à jour la configuration de l'Access Point Peppol.
  Future<void> updatePeppol(PeppolConfig config) async {
    peppol = config;
    log('Configuration Peppol', config.enabled ? 'Activée' : 'Désactivée');
    await _persist();
    notifyListeners();
  }

  /// Simule la confirmation de distribution Peppol (accusé du destinataire).
  Future<void> markPeppolDelivered(String docId) async {
    final i = financeDocs.indexWhere((e) => e.id == docId);
    if (i < 0) return;
    financeDocs[i] = financeDocs[i].copyWith(
      peppolStatus: PeppolStatus.delivered,
    );
    log('Peppol distribué', financeDocs[i].reference);
    await _persist();
    notifyListeners();
  }

  /// Met à jour les coordonnées officielles de Gorex Group (facturation).
  Future<void> updateCompany(CompanyProfile profile) async {
    company = profile;
    log('Mise à jour coordonnées société', profile.legalName);
    await _persist();
    notifyListeners();
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
    financeDocs[i] = d.copyWith(
      amountPaid: newPaid.clamp(0, d.total),
      status: paid ? InvoiceStatus.paid : d.status,
      paidAt: paid ? (date ?? DateTime.now()) : null,
      paymentMethod: method,
    );
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
    bankTransactions[ti] = t.copyWith(matched: true, matchedDocumentId: docId);
    await markInvoicePaid(
      docId,
      amount: t.amount,
      method: method,
      date: t.date,
    );
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
    bankTransactions[ti] = bankTransactions[ti].copyWith(
      matched: false,
      matchedDocumentId: null,
    );
    await _persist();
    notifyListeners();
  }

  /// Rapprochement automatique : associe les crédits non rapprochés aux
  /// factures impayées via communication structurée / référence / montant.
  /// Retourne le nombre de rapprochements effectués.
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
    for (final m in matches) {
      if (m.matched) {
        await reconcileTransaction(
          m.transaction.id,
          m.document!.id,
          method: m.method,
        );
        n++;
      }
    }
    if (n > 0) log('Rapprochement auto', '$n transaction(s)');
    return n;
  }

  /// Envoie (ou marque comme envoyée) la relance suivante d'une facture.
  Future<ReminderPlan?> sendReminder(String docId) async {
    final i = financeDocs.indexWhere((e) => e.id == docId);
    if (i < 0) return null;
    final d = financeDocs[i];
    final p = ReminderService.plan(d, minDays: reminderConfig.minDaysBetween);
    if (!p.due) return p;
    financeDocs[i] = d.copyWith(
      reminderLevel: p.nextLevel,
      lastReminderAt: DateTime.now(),
      status: d.status == InvoiceStatus.paid ? d.status : InvoiceStatus.overdue,
    );
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
  Future<int> sendAllDueReminders() async {
    final plans = ReminderService.pending(
      financeDocs,
      minDays: reminderConfig.minDaysBetween,
    );
    for (final p in plans) {
      await sendReminder(p.document.id);
    }
    return plans.length;
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
        await sendReminder(p.document.id);
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
    financeDocs[i] = d;
    await _persist();
    notifyListeners();
  }

  // ─────────────────────────── PROVIDERS ───────────────────────────
  Future<void> updateProvider(Provider p) async {
    final i = providers.indexWhere((e) => e.id == p.id);
    if (i < 0) return;
    providers[i] = p;
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
