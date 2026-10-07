import 'enums.dart';

/// Prestataire (fournisseur premium)
class Provider {
  final String id;
  final String name;
  final String category; // Hôtel, Restaurant, Chauffeur, Jet privé, etc.
  final ServiceDomain domain;
  final String country;
  final String city;
  final String contactName;
  final String contactEmail;
  final String contactPhone;
  final double rate; // tarif indicatif
  final double commissionPercent;
  final int trustLevel; // 1-5
  final bool active;
  final List<String> documentNames;
  final bool hasContract;
  final String? internalNotes;

  const Provider({
    required this.id,
    required this.name,
    required this.category,
    required this.domain,
    required this.country,
    required this.city,
    required this.contactName,
    required this.contactEmail,
    required this.contactPhone,
    required this.rate,
    required this.commissionPercent,
    this.trustLevel = 4,
    this.active = true,
    this.documentNames = const [],
    this.hasContract = false,
    this.internalNotes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'domain': domain.name,
    'country': country,
    'city': city,
    'contactName': contactName,
    'contactEmail': contactEmail,
    'contactPhone': contactPhone,
    'rate': rate,
    'commissionPercent': commissionPercent,
    'trustLevel': trustLevel,
    'active': active,
    'documentNames': documentNames,
    'hasContract': hasContract,
    'internalNotes': internalNotes,
  };

  factory Provider.fromMap(Map<String, dynamic> m) => Provider(
    id: m['id'] as String,
    name: m['name'] as String,
    category: m['category'] as String,
    domain: ServiceDomain.fromName(m['domain'] as String),
    country: m['country'] as String,
    city: m['city'] as String,
    contactName: m['contactName'] as String,
    contactEmail: m['contactEmail'] as String,
    contactPhone: m['contactPhone'] as String,
    rate: (m['rate'] as num).toDouble(),
    commissionPercent: (m['commissionPercent'] as num).toDouble(),
    trustLevel: m['trustLevel'] as int? ?? 4,
    active: m['active'] as bool? ?? true,
    documentNames: _list(m['documentNames']),
    hasContract: m['hasContract'] as bool? ?? false,
    internalNotes: m['internalNotes'] as String?,
  );

  static List<String> _list(dynamic v) =>
      v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();
}

/// Réservation
class Booking {
  final String id;
  final String reference; // GRX-BK-2025-0001
  final BookingType type;
  final String clientId;
  final String clientName;
  final String providerId;
  final String providerName;
  final String? requestId;
  final String title;
  final DateTime date;
  final String time;
  final String location;
  final double providerPrice;
  final double clientPrice;
  final double commission;
  final BookingStatus status;
  final bool confirmed;
  final List<String> documentNames;
  final String? notes;

  const Booking({
    required this.id,
    required this.reference,
    required this.type,
    required this.clientId,
    required this.clientName,
    required this.providerId,
    required this.providerName,
    this.requestId,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.providerPrice,
    required this.clientPrice,
    this.commission = 0,
    this.status = BookingStatus.pending,
    this.confirmed = false,
    this.documentNames = const [],
    this.notes,
  });

  double get margin => clientPrice - providerPrice;

  Booking copyWith({
    BookingStatus? status,
    bool? confirmed,
    double? providerPrice,
    double? clientPrice,
    double? commission,
    String? notes,
    List<String>? documentNames,
  }) => Booking(
    id: id,
    reference: reference,
    type: type,
    clientId: clientId,
    clientName: clientName,
    providerId: providerId,
    providerName: providerName,
    requestId: requestId,
    title: title,
    date: date,
    time: time,
    location: location,
    providerPrice: providerPrice ?? this.providerPrice,
    clientPrice: clientPrice ?? this.clientPrice,
    commission: commission ?? this.commission,
    status: status ?? this.status,
    confirmed: confirmed ?? this.confirmed,
    documentNames: documentNames ?? this.documentNames,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'reference': reference,
    'type': type.name,
    'clientId': clientId,
    'clientName': clientName,
    'providerId': providerId,
    'providerName': providerName,
    'requestId': requestId,
    'title': title,
    'date': date.toIso8601String(),
    'time': time,
    'location': location,
    'providerPrice': providerPrice,
    'clientPrice': clientPrice,
    'commission': commission,
    'status': status.name,
    'confirmed': confirmed,
    'documentNames': documentNames,
    'notes': notes,
  };

  factory Booking.fromMap(Map<String, dynamic> m) => Booking(
    id: m['id'] as String,
    reference: m['reference'] as String,
    type: BookingType.fromName(m['type'] as String),
    clientId: m['clientId'] as String,
    clientName: m['clientName'] as String,
    providerId: m['providerId'] as String,
    providerName: m['providerName'] as String,
    requestId: m['requestId'] as String?,
    title: m['title'] as String,
    date: DateTime.parse(m['date'] as String),
    time: m['time'] as String,
    location: m['location'] as String,
    providerPrice: (m['providerPrice'] as num).toDouble(),
    clientPrice: (m['clientPrice'] as num).toDouble(),
    commission: (m['commission'] as num?)?.toDouble() ?? 0,
    status: BookingStatus.fromName(m['status'] as String),
    confirmed: m['confirmed'] as bool? ?? false,
    documentNames: _list(m['documentNames']),
    notes: m['notes'] as String?,
  );

  static List<String> _list(dynamic v) =>
      v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();
}
