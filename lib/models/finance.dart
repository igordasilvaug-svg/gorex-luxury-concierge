import 'enums.dart';

/// Ligne d'un document financier
class FinanceLine {
  final String description;
  final double quantity;
  final double unitPrice;
  final bool billable;

  const FinanceLine({
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    this.billable = true,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'billable': billable,
  };

  factory FinanceLine.fromMap(Map<String, dynamic> m) => FinanceLine(
    description: m['description'] as String,
    quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
    unitPrice: (m['unitPrice'] as num).toDouble(),
    billable: m['billable'] as bool? ?? true,
  );
}

/// Document financier : devis / facture / acompte
class FinanceDocument {
  final String id;
  final String reference; // GRX-INV-2025-0001
  final FinanceDocType type;
  final String clientId;
  final String clientName;
  final String? requestId;
  final DateTime date;
  final DateTime? dueDate;
  final List<FinanceLine> lines;
  final double taxPercent;
  final InvoiceStatus status;
  final String currency;
  final double amountPaid;
  final String? notes;

  const FinanceDocument({
    required this.id,
    required this.reference,
    required this.type,
    required this.clientId,
    required this.clientName,
    this.requestId,
    required this.date,
    this.dueDate,
    this.lines = const [],
    this.taxPercent = 21,
    this.status = InvoiceStatus.draft,
    this.currency = 'EUR',
    this.amountPaid = 0,
    this.notes,
  });

  double get subtotal => lines.fold(0.0, (s, l) => s + l.total);
  double get taxAmount => subtotal * (taxPercent / 100);
  double get total => subtotal + taxAmount;
  double get balance => total - amountPaid;

  FinanceDocument copyWith({
    InvoiceStatus? status,
    double? amountPaid,
    List<FinanceLine>? lines,
    String? notes,
  }) => FinanceDocument(
    id: id,
    reference: reference,
    type: type,
    clientId: clientId,
    clientName: clientName,
    requestId: requestId,
    date: date,
    dueDate: dueDate,
    lines: lines ?? this.lines,
    taxPercent: taxPercent,
    status: status ?? this.status,
    currency: currency,
    amountPaid: amountPaid ?? this.amountPaid,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'reference': reference,
    'type': type.name,
    'clientId': clientId,
    'clientName': clientName,
    'requestId': requestId,
    'date': date.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'lines': lines.map((e) => e.toMap()).toList(),
    'taxPercent': taxPercent,
    'status': status.name,
    'currency': currency,
    'amountPaid': amountPaid,
    'notes': notes,
  };

  factory FinanceDocument.fromMap(Map<String, dynamic> m) => FinanceDocument(
    id: m['id'] as String,
    reference: m['reference'] as String,
    type: FinanceDocType.fromName(m['type'] as String),
    clientId: m['clientId'] as String,
    clientName: m['clientName'] as String,
    requestId: m['requestId'] as String?,
    date: DateTime.parse(m['date'] as String),
    dueDate: m['dueDate'] != null
        ? DateTime.parse(m['dueDate'] as String)
        : null,
    lines: m['lines'] == null
        ? []
        : (m['lines'] as List)
              .map(
                (e) => FinanceLine.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
    taxPercent: (m['taxPercent'] as num?)?.toDouble() ?? 21,
    status: InvoiceStatus.fromName(m['status'] as String),
    currency: m['currency'] as String? ?? 'EUR',
    amountPaid: (m['amountPaid'] as num?)?.toDouble() ?? 0,
    notes: m['notes'] as String?,
  );
}

/// Dépense (coût fournisseur)
class Expense {
  final String id;
  final String label;
  final String providerName;
  final String? requestId;
  final double amount;
  final DateTime date;
  final String category;

  const Expense({
    required this.id,
    required this.label,
    required this.providerName,
    this.requestId,
    required this.amount,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'providerName': providerName,
    'requestId': requestId,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category,
  };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
    id: m['id'] as String,
    label: m['label'] as String,
    providerName: m['providerName'] as String,
    requestId: m['requestId'] as String?,
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.parse(m['date'] as String),
    category: m['category'] as String,
  );
}
