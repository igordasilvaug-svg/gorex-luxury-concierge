// GOREX LUXURY CONCIERGE — Demande et contrat d'abonnement.
//
// POURQUOI CE MODÈLE EXISTE
// Jusqu'ici le palier d'un client était un simple champ sur sa fiche
// (`Client.subscriptionTierId`), renseigné d'office à l'inscription. Un
// visiteur qui n'avait rien demandé, rien signé et rien payé voyait donc
// s'afficher « GOREX ESSENTIAL » comme s'il y était abonné. C'était une
// affirmation commerciale faite à sa place, et elle était fausse.
//
// Un abonnement est un CONTRAT : il a une demande, une décision, une date
// d'effet, un prix, et un moyen de paiement. Ce modèle porte cet état.
//
// CIRCUIT
//   requested  → le client a désigné une formule ; rien n'est dû.
//   approved   → Gorex Group a accepté ; le contrat est formé.
//   active     → le mandat SEPA est signé ET actif : la facturation peut
//                commencer. C'est le SEUL état où l'on prélève.
//   suspended  → contrat en pause (impayé, demande du client).
//   ended      → contrat terminé.
//
// Un abonnement `approved` sans mandat actif n'est JAMAIS facturé : c'est
// exactement ce qui manquait pour éviter d'encaisser sans base contractuelle.

/// État d'un abonnement.
enum SubscriptionStatus {
  requested('Demande envoyée', "En attente de décision de Gorex Group."),
  approved('Acceptée', 'Formule acceptée ; en attente du mandat de paiement.'),
  active('Active', 'Contrat en cours et facturable.'),
  suspended('Suspendue', 'Contrat en pause ; aucune facturation.'),
  ended('Terminée', 'Contrat clos.');

  const SubscriptionStatus(this.label, this.description);
  final String label;
  final String description;

  static SubscriptionStatus fromName(String? n) =>
      SubscriptionStatus.values.firstWhere(
        (e) => e.name == n,
        // Valeur de repli PRUDENTE : un abonnement dont l'état est inconnu ou
        // absent ne doit jamais être considéré comme actif, sous peine de
        // facturer sans contrat. On retombe donc sur `requested`.
        orElse: () => SubscriptionStatus.requested,
      );

  /// L'abonnement est-il facturable ? Seul `active` l'est.
  bool get isBillable => this == SubscriptionStatus.active;

  /// Occupe-t-il une place dans le circuit commercial ?
  bool get isLive =>
      this == SubscriptionStatus.requested ||
      this == SubscriptionStatus.approved ||
      this == SubscriptionStatus.active;
}

/// Rythme de facturation choisi par le client.
enum BillingCycle {
  monthly('Mensuel'),
  annual('Annuel');

  const BillingCycle(this.label);
  final String label;

  static BillingCycle fromName(String? n) =>
      BillingCycle.values.firstWhere(
        (e) => e.name == n,
        orElse: () => BillingCycle.annual,
      );
}

/// Demande puis contrat d'abonnement d'un client.
class Subscription {
  final String id;

  /// Client titulaire (référence `Client.id`).
  final String clientId;
  final String clientEmail;

  /// Formule demandée (référence `SubscriptionTier.id`).
  final String tierId;

  /// Nom de la formule au moment de la demande.
  ///
  /// Conservé en dur : si la grille tarifaire évolue, le contrat doit garder
  /// la trace de ce qui a été demandé et accepté. Un prix de contrat n'est
  /// pas une donnée qu'on met à jour rétroactivement.
  final String tierName;

  final BillingCycle cycle;

  /// Montant convenu au moment de la demande, en euros.
  final double amount;

  final SubscriptionStatus status;

  /// Date de la demande du client.
  final DateTime requestedAt;

  /// Date de la décision de Gorex Group (null tant que non traitée).
  final DateTime? decidedAt;

  /// Auteur de la décision (adresse e-mail du membre du personnel).
  final String? decidedBy;

  /// Date d'effet de la facturation (passage en `active`).
  final DateTime? activatedAt;

  /// Motif d'un refus, d'une suspension ou d'une résiliation.
  final String? note;

  const Subscription({
    required this.id,
    required this.clientId,
    required this.clientEmail,
    required this.tierId,
    required this.tierName,
    required this.cycle,
    required this.amount,
    this.status = SubscriptionStatus.requested,
    required this.requestedAt,
    this.decidedAt,
    this.decidedBy,
    this.activatedAt,
    this.note,
  });

  /// Un abonnement ne peut être facturé que s'il est actif.
  bool get isBillable => status.isBillable;

  /// Libellé du montant, pour l'affichage.
  String get amountLabel {
    final eur = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$eur € / ${cycle == BillingCycle.annual ? 'an' : 'mois'}';
  }

  Subscription copyWith({
    String? tierId,
    String? tierName,
    BillingCycle? cycle,
    double? amount,
    SubscriptionStatus? status,
    DateTime? decidedAt,
    String? decidedBy,
    DateTime? activatedAt,
    String? note,
  }) => Subscription(
    id: id,
    clientId: clientId,
    clientEmail: clientEmail,
    tierId: tierId ?? this.tierId,
    tierName: tierName ?? this.tierName,
    cycle: cycle ?? this.cycle,
    amount: amount ?? this.amount,
    status: status ?? this.status,
    requestedAt: requestedAt,
    decidedAt: decidedAt ?? this.decidedAt,
    decidedBy: decidedBy ?? this.decidedBy,
    activatedAt: activatedAt ?? this.activatedAt,
    note: note ?? this.note,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'clientEmail': clientEmail,
    'tierId': tierId,
    'tierName': tierName,
    'cycle': cycle.name,
    'amount': amount,
    'status': status.name,
    'requestedAt': requestedAt.toIso8601String(),
    'decidedAt': decidedAt?.toIso8601String(),
    'decidedBy': decidedBy,
    'activatedAt': activatedAt?.toIso8601String(),
    'note': note,
  };

  factory Subscription.fromMap(Map<String, dynamic> m) => Subscription(
    id: (m['id'] ?? '') as String,
    clientId: (m['clientId'] ?? '') as String,
    clientEmail: (m['clientEmail'] ?? '') as String,
    tierId: (m['tierId'] ?? '') as String,
    tierName: (m['tierName'] ?? '') as String,
    cycle: BillingCycle.fromName(m['cycle'] as String?),
    amount: ((m['amount'] as num?) ?? 0).toDouble(),
    status: SubscriptionStatus.fromName(m['status'] as String?),
    requestedAt:
        DateTime.tryParse('${m['requestedAt']}') ?? DateTime.now(),
    decidedAt: DateTime.tryParse('${m['decidedAt']}'),
    decidedBy: m['decidedBy'] as String?,
    activatedAt: DateTime.tryParse('${m['activatedAt']}'),
    note: m['note'] as String?,
  );
}
