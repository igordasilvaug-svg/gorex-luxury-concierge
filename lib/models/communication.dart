/// Message dans une conversation interne
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime timestamp;
  final bool internal; // true = visible équipe uniquement

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    this.internal = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderRole': senderRole,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'internal': internal,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'] as String,
    conversationId: m['conversationId'] as String,
    senderId: m['senderId'] as String,
    senderName: m['senderName'] as String,
    senderRole: m['senderRole'] as String,
    text: m['text'] as String,
    timestamp: DateTime.parse(m['timestamp'] as String),
    internal: m['internal'] as bool? ?? false,
  );
}

/// Conversation rattachée à une demande ou réservation
class Conversation {
  final String id;
  final String subject;
  final String? requestId;
  final String? bookingId;
  final String clientId;
  final String clientName;
  final List<String> participantNames;
  final List<ChatMessage> messages;
  final DateTime lastActivity;

  const Conversation({
    required this.id,
    required this.subject,
    this.requestId,
    this.bookingId,
    required this.clientId,
    required this.clientName,
    this.participantNames = const [],
    this.messages = const [],
    required this.lastActivity,
  });

  Conversation copyWith({
    List<ChatMessage>? messages,
    DateTime? lastActivity,
  }) => Conversation(
    id: id,
    subject: subject,
    requestId: requestId,
    bookingId: bookingId,
    clientId: clientId,
    clientName: clientName,
    participantNames: participantNames,
    messages: messages ?? this.messages,
    lastActivity: lastActivity ?? this.lastActivity,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'subject': subject,
    'requestId': requestId,
    'bookingId': bookingId,
    'clientId': clientId,
    'clientName': clientName,
    'participantNames': participantNames,
    'messages': messages.map((e) => e.toMap()).toList(),
    'lastActivity': lastActivity.toIso8601String(),
  };

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
    id: m['id'] as String,
    subject: m['subject'] as String,
    requestId: m['requestId'] as String?,
    bookingId: m['bookingId'] as String?,
    clientId: m['clientId'] as String,
    clientName: m['clientName'] as String,
    participantNames:
        (m['participantNames'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    messages: m['messages'] == null
        ? []
        : (m['messages'] as List)
              .map(
                (e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
    lastActivity: DateTime.parse(m['lastActivity'] as String),
  );
}
