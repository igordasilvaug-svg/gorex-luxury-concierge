import 'enums.dart';

/// Demande de service concierge
class ServiceRequest {
  final String id;
  final String reference; // GRX-REQ-2025-0001
  final String clientId;
  final String clientName;
  final ServiceDomain domain;
  final String subService;
  final String title;
  final String description;
  final DateTime date;
  final String time;
  final String location;
  final UrgencyLevel urgency;
  final double budget;
  final RequestStatus status;
  final String? responsibleId; // concierge responsable
  final String? responsibleName;
  final List<String> providerIds;
  final double cost;
  final double margin;
  final List<String> documentNames;
  final List<RequestHistoryEntry> history;
  final List<String> linkedBookingIds;
  final bool isSecurityEscalated; // transmis à GOREX SECURITY
  final String? escalationNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  const ServiceRequest({
    required this.id,
    required this.reference,
    required this.clientId,
    required this.clientName,
    required this.domain,
    required this.subService,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.urgency,
    required this.budget,
    required this.status,
    this.responsibleId,
    this.responsibleName,
    this.providerIds = const [],
    this.cost = 0,
    this.margin = 0,
    this.documentNames = const [],
    this.history = const [],
    this.linkedBookingIds = const [],
    this.isSecurityEscalated = false,
    this.escalationNote,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  double get marginAmount => margin != 0 ? margin : (budget - cost);
  double get marginPercent => budget > 0 ? ((budget - cost) / budget) * 100 : 0;

  ServiceRequest copyWith({
    String? title,
    String? description,
    DateTime? date,
    String? time,
    String? location,
    UrgencyLevel? urgency,
    double? budget,
    RequestStatus? status,
    String? responsibleId,
    String? responsibleName,
    List<String>? providerIds,
    double? cost,
    double? margin,
    List<String>? documentNames,
    List<RequestHistoryEntry>? history,
    List<String>? linkedBookingIds,
    bool? isSecurityEscalated,
    String? escalationNote,
    DateTime? updatedAt,
    List<String>? tags,
  }) => ServiceRequest(
    id: id,
    reference: reference,
    clientId: clientId,
    clientName: clientName,
    domain: domain,
    subService: subService,
    title: title ?? this.title,
    description: description ?? this.description,
    date: date ?? this.date,
    time: time ?? this.time,
    location: location ?? this.location,
    urgency: urgency ?? this.urgency,
    budget: budget ?? this.budget,
    status: status ?? this.status,
    responsibleId: responsibleId ?? this.responsibleId,
    responsibleName: responsibleName ?? this.responsibleName,
    providerIds: providerIds ?? this.providerIds,
    cost: cost ?? this.cost,
    margin: margin ?? this.margin,
    documentNames: documentNames ?? this.documentNames,
    history: history ?? this.history,
    linkedBookingIds: linkedBookingIds ?? this.linkedBookingIds,
    isSecurityEscalated: isSecurityEscalated ?? this.isSecurityEscalated,
    escalationNote: escalationNote ?? this.escalationNote,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tags: tags ?? this.tags,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'reference': reference,
    'clientId': clientId,
    'clientName': clientName,
    'domain': domain.name,
    'subService': subService,
    'title': title,
    'description': description,
    'date': date.toIso8601String(),
    'time': time,
    'location': location,
    'urgency': urgency.name,
    'budget': budget,
    'status': status.name,
    'responsibleId': responsibleId,
    'responsibleName': responsibleName,
    'providerIds': providerIds,
    'cost': cost,
    'margin': margin,
    'documentNames': documentNames,
    'history': history.map((e) => e.toMap()).toList(),
    'linkedBookingIds': linkedBookingIds,
    'isSecurityEscalated': isSecurityEscalated,
    'escalationNote': escalationNote,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'tags': tags,
  };

  factory ServiceRequest.fromMap(Map<String, dynamic> m) => ServiceRequest(
    id: m['id'] as String,
    reference: m['reference'] as String,
    clientId: m['clientId'] as String,
    clientName: m['clientName'] as String,
    domain: ServiceDomain.fromName(m['domain'] as String),
    subService: m['subService'] as String,
    title: m['title'] as String,
    description: m['description'] as String,
    date: DateTime.parse(m['date'] as String),
    time: m['time'] as String,
    location: m['location'] as String,
    urgency: UrgencyLevel.fromName(m['urgency'] as String),
    budget: (m['budget'] as num).toDouble(),
    status: RequestStatus.fromName(m['status'] as String),
    responsibleId: m['responsibleId'] as String?,
    responsibleName: m['responsibleName'] as String?,
    providerIds: _strList(m['providerIds']),
    cost: (m['cost'] as num?)?.toDouble() ?? 0,
    margin: (m['margin'] as num?)?.toDouble() ?? 0,
    documentNames: _strList(m['documentNames']),
    history: _histList(m['history']),
    linkedBookingIds: _strList(m['linkedBookingIds']),
    isSecurityEscalated: m['isSecurityEscalated'] as bool? ?? false,
    escalationNote: m['escalationNote'] as String?,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    tags: _strList(m['tags']),
  );

  static List<String> _strList(dynamic v) =>
      v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();

  static List<RequestHistoryEntry> _histList(dynamic v) => v == null
      ? <RequestHistoryEntry>[]
      : (v as List)
            .map(
              (e) => RequestHistoryEntry.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
}

class RequestHistoryEntry {
  final DateTime timestamp;
  final String actor;
  final String action;
  final String? detail;

  const RequestHistoryEntry({
    required this.timestamp,
    required this.actor,
    required this.action,
    this.detail,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'actor': actor,
    'action': action,
    'detail': detail,
  };

  factory RequestHistoryEntry.fromMap(Map<String, dynamic> m) =>
      RequestHistoryEntry(
        timestamp: DateTime.parse(m['timestamp'] as String),
        actor: m['actor'] as String,
        action: m['action'] as String,
        detail: m['detail'] as String?,
      );
}
