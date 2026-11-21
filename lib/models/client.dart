import 'enums.dart';

/// Profil client VIP confidentiel
class Client {
  final String id;
  final String code; // ex: GRX-VIP-0001
  final String fullName;
  final String? companyName;
  final ClientCategory category;
  final String email;
  final String phone;
  final String? secondaryContact;
  final String language;
  final String country;
  final String city;
  final String? personalAssistant;
  final String? assistantPhone;
  final ConfidentialityLevel confidentiality;
  final String subscriptionTierId;
  final String? assignedConciergeId;

  // Préférences
  final List<String> preferredHotels;
  final List<String> preferredRestaurants;
  final List<String> preferredDrivers;
  final List<String> travelPreferences;
  final List<String> dietaryPreferences;
  final List<String> interests;

  final String? notes;
  final bool active;

  /// Statut de validation du compte (voir [ClientApprovalStatus]).
  ///
  /// Une inscription passée par le formulaire public arrive en `pending` :
  /// l'accès aux services reste fermé jusqu'à décision du personnel.
  final ClientApprovalStatus approvalStatus;

  final DateTime createdAt;

  // ─── Identification & facturation ───
  /// true = client professionnel/indépendant (facturation B2B)
  final bool isBusiness;

  /// Numéro d'entreprise BCE belge (ex. 0123.456.789)
  final String? companyNumber;

  /// Numéro de TVA (ex. BE0123456789) — Belgique ou étranger
  final String? vatNumber;

  /// Adresse de facturation (si différente)
  final String? billingAddress;

  /// Adresse e-mail dédiée à la facturation
  final String? billingEmail;

  /// Le client accepte la réception des factures via le réseau Peppol
  final bool peppolEnabled;

  const Client({
    required this.id,
    required this.code,
    required this.fullName,
    this.companyName,
    required this.category,
    required this.email,
    required this.phone,
    this.secondaryContact,
    this.language = 'Français',
    required this.country,
    required this.city,
    this.personalAssistant,
    this.assistantPhone,
    this.confidentiality = ConfidentialityLevel.elevated,
    required this.subscriptionTierId,
    this.assignedConciergeId,
    this.preferredHotels = const [],
    this.preferredRestaurants = const [],
    this.preferredDrivers = const [],
    this.travelPreferences = const [],
    this.dietaryPreferences = const [],
    this.interests = const [],
    this.notes,
    this.active = true,
    this.approvalStatus = ClientApprovalStatus.approved,
    required this.createdAt,
    this.isBusiness = false,
    this.companyNumber,
    this.vatNumber,
    this.billingAddress,
    this.billingEmail,
    this.peppolEnabled = false,
  });

  Client copyWith({
    String? fullName,
    String? companyName,
    ClientCategory? category,
    String? email,
    String? phone,
    String? secondaryContact,
    String? language,
    String? country,
    String? city,
    String? personalAssistant,
    String? assistantPhone,
    ConfidentialityLevel? confidentiality,
    String? subscriptionTierId,
    String? assignedConciergeId,
    List<String>? preferredHotels,
    List<String>? preferredRestaurants,
    List<String>? preferredDrivers,
    List<String>? travelPreferences,
    List<String>? dietaryPreferences,
    List<String>? interests,
    String? notes,
    bool? active,
    bool? isBusiness,
    String? companyNumber,
    String? vatNumber,
    String? billingAddress,
    String? billingEmail,
    bool? peppolEnabled,
    ClientApprovalStatus? approvalStatus,
    String? code,
  }) => Client(
    id: id,
    code: code ?? this.code,
    fullName: fullName ?? this.fullName,
    companyName: companyName ?? this.companyName,
    category: category ?? this.category,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    secondaryContact: secondaryContact ?? this.secondaryContact,
    language: language ?? this.language,
    country: country ?? this.country,
    city: city ?? this.city,
    personalAssistant: personalAssistant ?? this.personalAssistant,
    assistantPhone: assistantPhone ?? this.assistantPhone,
    confidentiality: confidentiality ?? this.confidentiality,
    subscriptionTierId: subscriptionTierId ?? this.subscriptionTierId,
    assignedConciergeId: assignedConciergeId ?? this.assignedConciergeId,
    preferredHotels: preferredHotels ?? this.preferredHotels,
    preferredRestaurants: preferredRestaurants ?? this.preferredRestaurants,
    preferredDrivers: preferredDrivers ?? this.preferredDrivers,
    travelPreferences: travelPreferences ?? this.travelPreferences,
    dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
    interests: interests ?? this.interests,
    notes: notes ?? this.notes,
    active: active ?? this.active,
    approvalStatus: approvalStatus ?? this.approvalStatus,
    createdAt: createdAt,
    isBusiness: isBusiness ?? this.isBusiness,
    companyNumber: companyNumber ?? this.companyNumber,
    vatNumber: vatNumber ?? this.vatNumber,
    billingAddress: billingAddress ?? this.billingAddress,
    billingEmail: billingEmail ?? this.billingEmail,
    peppolEnabled: peppolEnabled ?? this.peppolEnabled,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'fullName': fullName,
    'companyName': companyName,
    'category': category.name,
    'email': email,
    'phone': phone,
    'secondaryContact': secondaryContact,
    'language': language,
    'country': country,
    'city': city,
    'personalAssistant': personalAssistant,
    'assistantPhone': assistantPhone,
    'confidentiality': confidentiality.name,
    'subscriptionTierId': subscriptionTierId,
    'assignedConciergeId': assignedConciergeId,
    'preferredHotels': preferredHotels,
    'preferredRestaurants': preferredRestaurants,
    'preferredDrivers': preferredDrivers,
    'travelPreferences': travelPreferences,
    'dietaryPreferences': dietaryPreferences,
    'interests': interests,
    'notes': notes,
    'active': active,
    'approvalStatus': approvalStatus.name,
    'createdAt': createdAt.toIso8601String(),
    'isBusiness': isBusiness,
    'companyNumber': companyNumber,
    'vatNumber': vatNumber,
    'billingAddress': billingAddress,
    'billingEmail': billingEmail,
    'peppolEnabled': peppolEnabled,
  };

  factory Client.fromMap(Map<String, dynamic> m) => Client(
    id: m['id'] as String,
    code: m['code'] as String,
    fullName: m['fullName'] as String,
    companyName: m['companyName'] as String?,
    // `as String? ?? ''` : `fromName` accepte un `String` NON NULLABLE. Une
    // fiche dont `category` vaut null levait donc une TypeError AVANT
    // d'atteindre le `orElse` prévu pour les valeurs inconnues. La chaîne vide
    // ne correspond à aucun nom d'énumération : on retombe alors proprement
    // sur la valeur par défaut, au lieu de perdre la fiche entière.
    category: ClientCategory.fromName((m['category'] as String?) ?? ''),
    email: m['email'] as String,
    phone: m['phone'] as String,
    secondaryContact: m['secondaryContact'] as String?,
    language: m['language'] as String? ?? 'Français',
    country: m['country'] as String,
    city: m['city'] as String,
    personalAssistant: m['personalAssistant'] as String?,
    assistantPhone: m['assistantPhone'] as String?,
    confidentiality: ConfidentialityLevel.fromName(
      (m['confidentiality'] as String?) ?? '',
    ),
    // `?? ''` : une fiche peut désormais n'avoir AUCUNE formule de référence
    // (le candidat a répondu « à définir avec mon concierge »). Un cast direct
    // `as String` ferait échouer le décodage de la fiche entière — donc
    // empêcherait le client de se connecter — pour un champ facultatif.
    subscriptionTierId: (m['subscriptionTierId'] as String?) ?? '',
    assignedConciergeId: m['assignedConciergeId'] as String?,
    preferredHotels: _list(m['preferredHotels']),
    preferredRestaurants: _list(m['preferredRestaurants']),
    preferredDrivers: _list(m['preferredDrivers']),
    travelPreferences: _list(m['travelPreferences']),
    dietaryPreferences: _list(m['dietaryPreferences']),
    interests: _list(m['interests']),
    notes: m['notes'] as String?,
    active: m['active'] as bool? ?? true,
    approvalStatus: ClientApprovalStatus.fromName(
      m['approvalStatus'] as String?,
    ),
    // ── DATE DE CRÉATION TOLÉRANTE ───────────────────────────────────────
    //
    // DÉFAUT CORRIGÉ. `createdAt` était lu par `DateTime.parse(m['createdAt']
    // as String)`. Une fiche dépourvue de ce champ — import, migration, ajout
    // manuel dans la console Firestore — levait une exception. Comme l'appelant
    // avalait l'erreur, la fiche DISPARAISSAIT sans le moindre message : le
    // client se connectait et ne voyait aucune de ses données.
    //
    // Le champ est donc facultatif. Une fiche sans date reçoit l'époque Unix
    // comme sentinelle explicitement documentée : mieux vaut un dossier
    // consultable avec une date « inconnue » qu'un dossier invisible.
    createdAt: _date(m['createdAt']),
    isBusiness: m['isBusiness'] as bool? ?? false,
    companyNumber: m['companyNumber'] as String?,
    vatNumber: m['vatNumber'] as String?,
    billingAddress: m['billingAddress'] as String?,
    billingEmail: m['billingEmail'] as String?,
    peppolEnabled: m['peppolEnabled'] as bool? ?? false,
  );

  /// Date de création tolérante : ne fait jamais échouer le décodage.
  ///
  /// Renvoie l'époque Unix (1970-01-01) pour une valeur absente ou illisible.
  /// Cette sentinelle est reconnaissable et n'invente pas une date plausible.
  static DateTime _date(dynamic v) {
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static List<String> _list(dynamic v) =>
      v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();

  /// Dossier en attente de décision : la personne peut se connecter, mais pas
  /// solliciter la conciergerie.
  bool get isPending => approvalStatus == ClientApprovalStatus.pending;

  /// Dossier refusé : la personne ne doit pas accéder aux services.
  bool get isRejected => approvalStatus == ClientApprovalStatus.rejected;

  /// Préfixe des numéros PROVISOIRES portés par une fiche non encore validée.
  ///
  /// Le numéro définitif (`GRX-VIP-0007`) n'est réservé qu'à la validation,
  /// côté serveur, par l'encadrement (voir `AppState.approveClient`). Avant
  /// cela un visiteur ne connaît aucune autre fiche et n'a pas le droit de
  /// lister la collection : tout numéro calculé dans son navigateur serait
  /// local à son appareil, donc sujet aux doublons. Ce préfixe rend cet état
  /// visible au lieu de faire croire à une référence durable.
  static const String provisionalCodePrefix = 'GRX-ATTENTE-';

  /// La fiche porte-t-elle déjà sa référence de dossier DÉFINITIVE ?
  bool get hasAssignedCode =>
      code.isNotEmpty && !code.startsWith(provisionalCodePrefix);

  /// Le compte est-il en droit de solliciter la conciergerie ?
  ///
  /// Deux conditions : le dossier doit être validé ET le compte non suspendu.
  bool get hasServiceAccess =>
      approvalStatus == ClientApprovalStatus.approved && active;
}
