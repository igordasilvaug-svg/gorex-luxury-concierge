/// Formule d'abonnement configurable (jamais hardcodé dans l'UI)
class SubscriptionTier {
  final String id;
  final String name; // GOREX ESSENTIAL, EXECUTIVE, ELITE, PRIVATE
  final String tagline;
  final double annualPrice;
  final double monthlyPrice;
  final int requestsIncluded; // -1 = illimité
  final String priority; // Standard, High, Highest, Absolute
  final String availability; // ex: 24/7, Business hours
  final List<String> includedServices;
  final List<String> excludedServices; // facturés séparément
  final int responseMinutes; // SLA de réponse
  final bool conciergeDedicated;
  final bool active;
  final int displayOrder;

  const SubscriptionTier({
    required this.id,
    required this.name,
    required this.tagline,
    required this.annualPrice,
    required this.monthlyPrice,
    required this.requestsIncluded,
    required this.priority,
    required this.availability,
    this.includedServices = const [],
    this.excludedServices = const [],
    this.responseMinutes = 60,
    this.conciergeDedicated = false,
    this.active = true,
    this.displayOrder = 0,
  });

  String get requestsLabel =>
      requestsIncluded < 0 ? 'Illimité' : '$requestsIncluded / mois';

  SubscriptionTier copyWith({
    String? name,
    String? tagline,
    double? annualPrice,
    double? monthlyPrice,
    int? requestsIncluded,
    String? priority,
    String? availability,
    List<String>? includedServices,
    List<String>? excludedServices,
    int? responseMinutes,
    bool? conciergeDedicated,
    bool? active,
  }) => SubscriptionTier(
    id: id,
    name: name ?? this.name,
    tagline: tagline ?? this.tagline,
    annualPrice: annualPrice ?? this.annualPrice,
    monthlyPrice: monthlyPrice ?? this.monthlyPrice,
    requestsIncluded: requestsIncluded ?? this.requestsIncluded,
    priority: priority ?? this.priority,
    availability: availability ?? this.availability,
    includedServices: includedServices ?? this.includedServices,
    excludedServices: excludedServices ?? this.excludedServices,
    responseMinutes: responseMinutes ?? this.responseMinutes,
    conciergeDedicated: conciergeDedicated ?? this.conciergeDedicated,
    active: active ?? this.active,
    displayOrder: displayOrder,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'tagline': tagline,
    'annualPrice': annualPrice,
    'monthlyPrice': monthlyPrice,
    'requestsIncluded': requestsIncluded,
    'priority': priority,
    'availability': availability,
    'includedServices': includedServices,
    'excludedServices': excludedServices,
    'responseMinutes': responseMinutes,
    'conciergeDedicated': conciergeDedicated,
    'active': active,
    'displayOrder': displayOrder,
  };

  factory SubscriptionTier.fromMap(Map<String, dynamic> m) => SubscriptionTier(
    id: m['id'] as String,
    name: m['name'] as String,
    tagline: m['tagline'] as String,
    annualPrice: (m['annualPrice'] as num).toDouble(),
    monthlyPrice: (m['monthlyPrice'] as num).toDouble(),
    requestsIncluded: m['requestsIncluded'] as int,
    priority: m['priority'] as String,
    availability: m['availability'] as String,
    includedServices:
        (m['includedServices'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    excludedServices:
        (m['excludedServices'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    responseMinutes: m['responseMinutes'] as int? ?? 60,
    conciergeDedicated: m['conciergeDedicated'] as bool? ?? false,
    active: m['active'] as bool? ?? true,
    displayOrder: m['displayOrder'] as int? ?? 0,
  );
}
