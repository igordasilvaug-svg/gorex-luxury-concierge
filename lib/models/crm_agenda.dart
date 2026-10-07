import 'enums.dart';

/// Événement d'agenda
class Appointment {
  final String id;
  final String title;
  final AppointmentType type;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? clientId;
  final String? clientName;
  final String? ownerId;
  final String? ownerName;
  final String? notes;
  final bool reminderSet;

  const Appointment({
    required this.id,
    required this.title,
    required this.type,
    required this.start,
    required this.end,
    this.location,
    this.clientId,
    this.clientName,
    this.ownerId,
    this.ownerName,
    this.notes,
    this.reminderSet = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'type': type.name,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'location': location,
    'clientId': clientId,
    'clientName': clientName,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'notes': notes,
    'reminderSet': reminderSet,
  };

  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
    id: m['id'] as String,
    title: m['title'] as String,
    type: AppointmentType.fromName(m['type'] as String),
    start: DateTime.parse(m['start'] as String),
    end: DateTime.parse(m['end'] as String),
    location: m['location'] as String?,
    clientId: m['clientId'] as String?,
    clientName: m['clientName'] as String?,
    ownerId: m['ownerId'] as String?,
    ownerName: m['ownerName'] as String?,
    notes: m['notes'] as String?,
    reminderSet: m['reminderSet'] as bool? ?? false,
  );
}

/// Prospect CRM VIP
class Prospect {
  final String id;
  final String name;
  final String? company;
  final String email;
  final String phone;
  final String source;
  final ProspectStage stage;
  final ClientCategory category;
  final double estimatedValue;
  final String? ownerId;
  final String? ownerName;
  final List<String> communicationLog;
  final DateTime createdAt;
  final DateTime? nextFollowUp;
  final String? notes;

  const Prospect({
    required this.id,
    required this.name,
    this.company,
    required this.email,
    required this.phone,
    this.source = 'Referral',
    this.stage = ProspectStage.lead,
    this.category = ClientCategory.individualVip,
    this.estimatedValue = 0,
    this.ownerId,
    this.ownerName,
    this.communicationLog = const [],
    required this.createdAt,
    this.nextFollowUp,
    this.notes,
  });

  Prospect copyWith({
    ProspectStage? stage,
    double? estimatedValue,
    List<String>? communicationLog,
    DateTime? nextFollowUp,
    String? notes,
  }) => Prospect(
    id: id,
    name: name,
    company: company,
    email: email,
    phone: phone,
    source: source,
    stage: stage ?? this.stage,
    category: category,
    estimatedValue: estimatedValue ?? this.estimatedValue,
    ownerId: ownerId,
    ownerName: ownerName,
    communicationLog: communicationLog ?? this.communicationLog,
    createdAt: createdAt,
    nextFollowUp: nextFollowUp ?? this.nextFollowUp,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'company': company,
    'email': email,
    'phone': phone,
    'source': source,
    'stage': stage.name,
    'category': category.name,
    'estimatedValue': estimatedValue,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'communicationLog': communicationLog,
    'createdAt': createdAt.toIso8601String(),
    'nextFollowUp': nextFollowUp?.toIso8601String(),
    'notes': notes,
  };

  factory Prospect.fromMap(Map<String, dynamic> m) => Prospect(
    id: m['id'] as String,
    name: m['name'] as String,
    company: m['company'] as String?,
    email: m['email'] as String,
    phone: m['phone'] as String,
    source: m['source'] as String? ?? 'Referral',
    stage: ProspectStage.fromName(m['stage'] as String),
    category: ClientCategory.fromName(m['category'] as String),
    estimatedValue: (m['estimatedValue'] as num?)?.toDouble() ?? 0,
    ownerId: m['ownerId'] as String?,
    ownerName: m['ownerName'] as String?,
    communicationLog:
        (m['communicationLog'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    createdAt: DateTime.parse(m['createdAt'] as String),
    nextFollowUp: m['nextFollowUp'] != null
        ? DateTime.parse(m['nextFollowUp'] as String)
        : null,
    notes: m['notes'] as String?,
  );
}

/// Entrée du journal d'audit (confidentialité / RGPD)
class AuditEntry {
  final String id;
  final DateTime timestamp;
  final String actor;
  final String actorRole;
  final String action;
  final String target;
  final String? detail;

  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.actor,
    required this.actorRole,
    required this.action,
    required this.target,
    this.detail,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'actor': actor,
    'actorRole': actorRole,
    'action': action,
    'target': target,
    'detail': detail,
  };

  factory AuditEntry.fromMap(Map<String, dynamic> m) => AuditEntry(
    id: m['id'] as String,
    timestamp: DateTime.parse(m['timestamp'] as String),
    actor: m['actor'] as String,
    actorRole: m['actorRole'] as String,
    action: m['action'] as String,
    target: m['target'] as String,
    detail: m['detail'] as String?,
  );
}
