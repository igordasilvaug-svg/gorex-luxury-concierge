import 'enums.dart';

/// Élément d'un itinéraire
class ItineraryItem {
  final String id;
  final String day; // ex: Day 1
  final DateTime? date;
  final String time;
  final String title;
  final String description;
  final ServiceDomain domain;
  final String? contact;

  const ItineraryItem({
    required this.id,
    required this.day,
    this.date,
    required this.time,
    required this.title,
    required this.description,
    required this.domain,
    this.contact,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'day': day,
    'date': date?.toIso8601String(),
    'time': time,
    'title': title,
    'description': description,
    'domain': domain.name,
    'contact': contact,
  };

  factory ItineraryItem.fromMap(Map<String, dynamic> m) => ItineraryItem(
    id: m['id'] as String,
    day: m['day'] as String,
    date: m['date'] != null ? DateTime.parse(m['date'] as String) : null,
    time: m['time'] as String,
    title: m['title'] as String,
    description: m['description'] as String,
    domain: ServiceDomain.fromName(m['domain'] as String),
    contact: m['contact'] as String?,
  );
}

/// Itinéraire premium construit
class Itinerary {
  final String id;
  final String reference;
  final String clientId;
  final String clientName;
  final String title;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final List<ItineraryItem> items;
  final String? flightInfo;
  final String? hotelInfo;
  final String? transferInfo;
  final List<String> contacts;
  final bool securityIncluded;
  final RequestStatus status;
  final DateTime createdAt;

  const Itinerary({
    required this.id,
    required this.reference,
    required this.clientId,
    required this.clientName,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.items = const [],
    this.flightInfo,
    this.hotelInfo,
    this.transferInfo,
    this.contacts = const [],
    this.securityIncluded = false,
    this.status = RequestStatus.underReview,
    required this.createdAt,
  });

  Itinerary copyWith({
    String? title,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    List<ItineraryItem>? items,
    String? flightInfo,
    String? hotelInfo,
    String? transferInfo,
    List<String>? contacts,
    bool? securityIncluded,
    RequestStatus? status,
  }) => Itinerary(
    id: id,
    reference: reference,
    clientId: clientId,
    clientName: clientName,
    title: title ?? this.title,
    destination: destination ?? this.destination,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    items: items ?? this.items,
    flightInfo: flightInfo ?? this.flightInfo,
    hotelInfo: hotelInfo ?? this.hotelInfo,
    transferInfo: transferInfo ?? this.transferInfo,
    contacts: contacts ?? this.contacts,
    securityIncluded: securityIncluded ?? this.securityIncluded,
    status: status ?? this.status,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'reference': reference,
    'clientId': clientId,
    'clientName': clientName,
    'title': title,
    'destination': destination,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'items': items.map((e) => e.toMap()).toList(),
    'flightInfo': flightInfo,
    'hotelInfo': hotelInfo,
    'transferInfo': transferInfo,
    'contacts': contacts,
    'securityIncluded': securityIncluded,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Itinerary.fromMap(Map<String, dynamic> m) => Itinerary(
    id: m['id'] as String,
    reference: m['reference'] as String,
    clientId: m['clientId'] as String,
    clientName: m['clientName'] as String,
    title: m['title'] as String,
    destination: m['destination'] as String,
    startDate: DateTime.parse(m['startDate'] as String),
    endDate: DateTime.parse(m['endDate'] as String),
    items: m['items'] == null
        ? []
        : (m['items'] as List)
              .map(
                (e) =>
                    ItineraryItem.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
    flightInfo: m['flightInfo'] as String?,
    hotelInfo: m['hotelInfo'] as String?,
    transferInfo: m['transferInfo'] as String?,
    contacts: (m['contacts'] as List?)?.map((e) => e.toString()).toList() ?? [],
    securityIncluded: m['securityIncluded'] as bool? ?? false,
    status: RequestStatus.fromName(m['status'] as String),
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}
