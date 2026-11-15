// GOREX LUXURY CONCIERGE — Domiciliation SEPA (mandats & ordres de prélèvement).
//
// Modèles métier de la domiciliation : le mandat signé par le client, puis les
// ordres de prélèvement individuels qui en découlent, regroupés en un lot
// transmis à la banque au format ISO 20022 `pain.008.001.02`.
//
// Références normatives appliquées :
//  • Règlement SEPA (UE) n° 260/2012 — formats et règles de mandat.
//  • ISO 20022 — message `pain.008.001.02` (Customer Direct Debit Initiation).
//  • Livre blanc SEPA « Rulebook » de l'EPC : pré-notification au moins
//    14 jours calendrier avant la date de prélèvement (sauf accord contraire).

import '../core/billing/sepa_validator.dart';

/// Type de mandat SEPA.
///
///  • [core] : mandat « CORE » — particuliers et entreprises, délais standards,
///    remboursement possible par le débiteur pendant 8 semaines.
///  • [b2b] : mandat « B2B » — réservé aux paiements entre entreprises ; le
///    débiteur ne peut pas être remboursé, ce qui offre plus de sécurité au
///    créancier mais exige un compte professionnel.
enum SepaMandateType {
  core('CORE', 'SEPA Core'),
  b2b('B2B', 'SEPA B2B');

  const SepaMandateType(this.code, this.label);
  final String code;
  final String label;

  static SepaMandateType fromName(String? n) =>
      SepaMandateType.values.firstWhere(
        (e) => e.name == n,
        orElse: () => SepaMandateType.core,
      );
}

/// Cycle de vie d'un mandat. Un mandat [cancelled] ne peut plus être prélevé.
enum SepaMandateStatus {
  pending('En attente de signature'),
  active('Actif'),
  suspended('Suspendu'),
  cancelled('Révoqué');

  const SepaMandateStatus(this.label);
  final String label;

  static SepaMandateStatus fromName(String? n) =>
      SepaMandateStatus.values.firstWhere(
        (e) => e.name == n,
        orElse: () => SepaMandateStatus.pending,
      );
}

/// Séquence d'un prélèvement, exigée par le schéma `pain.008` (champ `SeqTp`).
///
/// La séquence doit être exacte : une banque rejette un premier prélèvement
/// annoncé en `RCUR`, et un rejet est facturé au créancier.
enum SepaSequenceType {
  /// `FRST` — premier prélèvement d'un mandat.
  first('FRST', 'Premier prélèvement'),

  /// `RCUR` — prélèvement récurrent.
  recurring('RCUR', 'Prélèvement récurrent'),

  /// `FNAL` — dernier prélèvement du mandat.
  finalDebit('FNAL', 'Dernier prélèvement'),

  /// `OOFF` — prélèvement unique (mandat à usage unique).
  oneOff('OOFF', 'Prélèvement unique');

  const SepaSequenceType(this.code, this.label);
  final String code;
  final String label;

  static SepaSequenceType fromName(String? n) =>
      SepaSequenceType.values.firstWhere(
        (e) => e.name == n,
        orElse: () => SepaSequenceType.first,
      );
}

/// Statut d'un ordre de prélèvement dans le cycle de vie interne.
enum SepaDebitStatus {
  draft('Brouillon'),
  preNotified('Pré-notifié'),
  submitted('Transmis à la banque'),
  collected('Encaissé'),
  rejected('Rejeté'),
  refunded('Remboursé');

  const SepaDebitStatus(this.label);
  final String label;

  static SepaDebitStatus fromName(String? n) =>
      SepaDebitStatus.values.firstWhere(
        (e) => e.name == n,
        orElse: () => SepaDebitStatus.draft,
      );
}

/// Mandat de domiciliation signé par un client.
///
/// ⚠️ L'IBAN est une donnée financière à caractère personnel. Il est stocké
/// tel quel (nécessaire pour générer l'ordre) mais ne doit **jamais** être
/// affiché en clair à l'écran : utiliser [SepaValidator.maskIban].
class SepaMandate {
  final String id;

  /// Identifiant du client titulaire (référence `Client.id`).
  final String clientId;
  final String clientName;

  /// Référence unique du mandat (≤ 35 caractères, `[A-Za-z0-9+/?:().,'-]`).
  /// Elle est contractuelle : elle figure sur le mandat signé et doit
  /// correspondre exactement à celle transmise à la banque.
  final String mandateReference;

  final String iban;
  final String? bic;

  /// Titulaire du compte — peut différer du nom du client (compte joint,
  /// société, conjoint). C'est ce nom qui apparaît sur le mandat.
  final String accountHolder;

  final SepaMandateType type;
  final SepaMandateStatus status;

  /// Date de signature du mandat par le client (date de l'accord).
  final DateTime signatureDate;

  /// Date de création de l'enregistrement dans l'application.
  final DateTime createdAt;
  final DateTime? cancelledAt;

  /// Dernière date de prélèvement effectif (sert à déterminer FRST/RCUR).
  final DateTime? lastUsedAt;

  /// Délai de pré-notification en jours calendrier (minimum légal : 14).
  final int preNotificationDays;

  final String? notes;

  const SepaMandate({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.mandateReference,
    required this.iban,
    this.bic,
    required this.accountHolder,
    this.type = SepaMandateType.core,
    this.status = SepaMandateStatus.pending,
    required this.signatureDate,
    required this.createdAt,
    this.cancelledAt,
    this.lastUsedAt,
    this.preNotificationDays = 14,
    this.notes,
  });

  /// Vrai si ce mandat peut être utilisé pour un nouveau prélèvement.
  bool get usable =>
      status == SepaMandateStatus.active &&
      cancelledAt == null &&
      SepaValidator.validateIban(iban).valid;

  /// IBAN masqué destiné à l'affichage.
  String get maskedIban => SepaValidator.maskIban(iban);

  /// Détermine la séquence à utiliser pour un nouveau prélèvement.
  SepaSequenceType get nextSequence =>
      lastUsedAt == null ? SepaSequenceType.first : SepaSequenceType.recurring;

  /// Date la plus proche à laquelle un prélèvement peut être exécuté si la
  /// pré-notification part aujourd'hui.
  DateTime earliestCollectionDate(DateTime from) =>
      DateTime(from.year, from.month, from.day + preNotificationDays);

  SepaMandate copyWith({
    String? clientName,
    String? mandateReference,
    String? iban,
    String? bic,
    String? accountHolder,
    SepaMandateType? type,
    SepaMandateStatus? status,
    DateTime? signatureDate,
    DateTime? cancelledAt,
    DateTime? lastUsedAt,
    int? preNotificationDays,
    String? notes,
  }) => SepaMandate(
    id: id,
    clientId: clientId,
    clientName: clientName ?? this.clientName,
    mandateReference: mandateReference ?? this.mandateReference,
    iban: iban ?? this.iban,
    bic: bic ?? this.bic,
    accountHolder: accountHolder ?? this.accountHolder,
    type: type ?? this.type,
    status: status ?? this.status,
    signatureDate: signatureDate ?? this.signatureDate,
    createdAt: createdAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    preNotificationDays: preNotificationDays ?? this.preNotificationDays,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'clientName': clientName,
    'mandateReference': mandateReference,
    'iban': iban,
    'bic': bic,
    'accountHolder': accountHolder,
    'type': type.name,
    'status': status.name,
    'signatureDate': signatureDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    'preNotificationDays': preNotificationDays,
    'notes': notes,
  };

  factory SepaMandate.fromMap(Map<String, dynamic> m) => SepaMandate(
    id: m['id'] as String,
    clientId: (m['clientId'] as String?) ?? '',
    clientName: (m['clientName'] as String?) ?? '',
    mandateReference: (m['mandateReference'] as String?) ?? '',
    iban: (m['iban'] as String?) ?? '',
    bic: m['bic'] as String?,
    accountHolder: (m['accountHolder'] as String?) ?? '',
    type: SepaMandateType.fromName(m['type'] as String?),
    status: SepaMandateStatus.fromName(m['status'] as String?),
    signatureDate:
        DateTime.tryParse((m['signatureDate'] as String?) ?? '') ??
        DateTime.now(),
    createdAt:
        DateTime.tryParse((m['createdAt'] as String?) ?? '') ?? DateTime.now(),
    cancelledAt: m['cancelledAt'] == null
        ? null
        : DateTime.tryParse(m['cancelledAt'] as String),
    lastUsedAt: m['lastUsedAt'] == null
        ? null
        : DateTime.tryParse(m['lastUsedAt'] as String),
    preNotificationDays: (m['preNotificationDays'] as num?)?.toInt() ?? 14,
    notes: m['notes'] as String?,
  );

  /// Contrôles de cohérence avant enregistrement. Retourne la liste des
  /// problèmes ; une liste vide signifie que le mandat est utilisable.
  List<String> validate() {
    final issues = <String>[];

    if (mandateReference.trim().isEmpty) {
      issues.add('Référence de mandat manquante');
    } else if (mandateReference.length > 35) {
      issues.add('Référence de mandat : 35 caractères maximum');
    } else if (!RegExp(r"^[A-Za-z0-9+/?:().,'-]+$").hasMatch(mandateReference)) {
      issues.add(
        'Référence de mandat : caractères autorisés A-Z a-z 0-9 + / ? : ( ) . , \' -',
      );
    }

    final ibanCheck = SepaValidator.validateIban(iban);
    if (!ibanCheck.valid) issues.add(ibanCheck.error!);

    final bicError = SepaValidator.validateBic(bic);
    if (bicError != null) issues.add(bicError);

    if (accountHolder.trim().isEmpty) {
      issues.add('Titulaire du compte manquant');
    }
    if (preNotificationDays < 14) {
      issues.add(
        'Pré-notification : 14 jours minimum exigés par le règlement SEPA',
      );
    }
    return issues;
  }
}

/// Ordre de prélèvement individuel rattaché à un mandat.
class SepaDebit {
  final String id;

  /// Identifiant du lot (`pain.008`) auquel cet ordre appartient, si généré.
  final String? batchId;

  final String mandateId;
  final String mandateReference;
  final String clientId;
  final String clientName;
  final String iban;

  /// Montant en euros. Arrondi à 2 décimales à la génération du XML.
  final double amount;

  /// Devise ISO 4217 — `EUR` imposé par le schéma SEPA.
  final String currency;

  /// Identifiant de bout en bout, unique et non réutilisable (`EndToEndId`).
  final String endToEndId;

  /// Libellé visible sur le relevé du client.
  final String remittanceInformation;

  /// Date d'exécution souhaitée (settlement / due date).
  final DateTime requestedCollectionDate;

  final SepaSequenceType sequenceType;
  final SepaDebitStatus status;

  /// Date d'envoi de la pré-notification au client.
  final DateTime? preNotifiedAt;

  final DateTime createdAt;

  const SepaDebit({
    required this.id,
    this.batchId,
    required this.mandateId,
    required this.mandateReference,
    required this.clientId,
    required this.clientName,
    required this.iban,
    required this.amount,
    this.currency = 'EUR',
    required this.endToEndId,
    required this.remittanceInformation,
    required this.requestedCollectionDate,
    this.sequenceType = SepaSequenceType.first,
    this.status = SepaDebitStatus.draft,
    this.preNotifiedAt,
    required this.createdAt,
  });

  /// Un ordre ne peut être validé que si la pré-notification a été envoyée au
  /// moins [SepaMandate.preNotificationDays] jours avant l'exécution.
  bool isPreNotificationCompliant(int preNotificationDays) {
    if (preNotifiedAt == null) return false;
    final deadline = DateTime(
      preNotifiedAt!.year,
      preNotifiedAt!.month,
      preNotifiedAt!.day + preNotificationDays,
    );
    return !requestedCollectionDate.isBefore(deadline);
  }

  SepaDebit copyWith({
    String? batchId,
    String? remittanceInformation,
    DateTime? requestedCollectionDate,
    SepaSequenceType? sequenceType,
    SepaDebitStatus? status,
    DateTime? preNotifiedAt,
  }) => SepaDebit(
    id: id,
    batchId: batchId ?? this.batchId,
    mandateId: mandateId,
    mandateReference: mandateReference,
    clientId: clientId,
    clientName: clientName,
    iban: iban,
    amount: amount,
    currency: currency,
    endToEndId: endToEndId,
    remittanceInformation: remittanceInformation ?? this.remittanceInformation,
    requestedCollectionDate:
        requestedCollectionDate ?? this.requestedCollectionDate,
    sequenceType: sequenceType ?? this.sequenceType,
    status: status ?? this.status,
    preNotifiedAt: preNotifiedAt ?? this.preNotifiedAt,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'batchId': batchId,
    'mandateId': mandateId,
    'mandateReference': mandateReference,
    'clientId': clientId,
    'clientName': clientName,
    'iban': iban,
    'amount': amount,
    'currency': currency,
    'endToEndId': endToEndId,
    'remittanceInformation': remittanceInformation,
    'requestedCollectionDate': requestedCollectionDate.toIso8601String(),
    'sequenceType': sequenceType.name,
    'status': status.name,
    'preNotifiedAt': preNotifiedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory SepaDebit.fromMap(Map<String, dynamic> m) => SepaDebit(
    id: m['id'] as String,
    batchId: m['batchId'] as String?,
    mandateId: (m['mandateId'] as String?) ?? '',
    mandateReference: (m['mandateReference'] as String?) ?? '',
    clientId: (m['clientId'] as String?) ?? '',
    clientName: (m['clientName'] as String?) ?? '',
    iban: (m['iban'] as String?) ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    currency: (m['currency'] as String?) ?? 'EUR',
    endToEndId: (m['endToEndId'] as String?) ?? '',
    remittanceInformation: (m['remittanceInformation'] as String?) ?? '',
    requestedCollectionDate:
        DateTime.tryParse((m['requestedCollectionDate'] as String?) ?? '') ??
        DateTime.now(),
    sequenceType: SepaSequenceType.fromName(m['sequenceType'] as String?),
    status: SepaDebitStatus.fromName(m['status'] as String?),
    preNotifiedAt: m['preNotifiedAt'] == null
        ? null
        : DateTime.tryParse(m['preNotifiedAt'] as String),
    createdAt:
        DateTime.tryParse((m['createdAt'] as String?) ?? '') ?? DateTime.now(),
  );
}
