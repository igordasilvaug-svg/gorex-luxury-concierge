import '../../models/enums.dart';
import '../../models/finance.dart';

/// Résultat d'un rapprochement entre une transaction bancaire et une facture.
class ReconciliationMatch {
  final BankTransaction transaction;
  final FinanceDocument? document;
  final PaymentMatchMethod method;
  final double confidence; // 0.0 → 1.0

  const ReconciliationMatch({
    required this.transaction,
    required this.document,
    required this.method,
    required this.confidence,
  });

  bool get matched => document != null;
}

/// Service de rapprochement bancaire automatique.
///
/// Met en correspondance les crédits d'un relevé bancaire avec les factures
/// impayées, en s'appuyant sur la communication structurée (OGM/VCS), la
/// référence de facture et le montant.
class ReconciliationService {
  ReconciliationService._();

  /// Extrait les chiffres d'une chaîne (utilisé pour comparer les OGM).
  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Score de correspondance entre une transaction et une facture (0 → 1).
  ///
  /// Pondération :
  /// - communication structurée identique → forte confiance
  /// - référence de facture présente → confiance
  /// - montant identique → confiance
  static double score(BankTransaction t, FinanceDocument d) {
    if (d.type != FinanceDocType.invoice) return 0;
    if (d.status == InvoiceStatus.paid) return 0;
    if (t.amount <= 0) return 0;

    double s = 0;
    final comm = _digits(t.communication);
    final dComm = _digits(d.structuredCommunication ?? '');
    final refDigits = _digits(d.reference);

    if (dComm.isNotEmpty && comm.isNotEmpty && comm.contains(dComm)) {
      s += 0.6; // OGM identique
    }
    if (refDigits.isNotEmpty && comm.isNotEmpty && comm.contains(refDigits)) {
      s += 0.3;
    }
    if (t.communication.toUpperCase().contains(d.reference.toUpperCase())) {
      s += 0.3;
    }
    // Montant identique (tolérance 0.01)
    if ((t.amount - d.total).abs() < 0.01) {
      s += 0.4;
    } else if ((t.amount - d.balance).abs() < 0.01) {
      s += 0.4;
    }
    // Nom du client présent dans la contrepartie
    final cp = t.counterparty.toLowerCase();
    final name = d.clientName.toLowerCase();
    if (name.isNotEmpty &&
        (cp.contains(name) || name.contains(cp) && cp.length > 3)) {
      s += 0.2;
    }
    return s.clamp(0.0, 1.0);
  }

  /// Suggère la meilleure facture pour une transaction (ou null si aucune
  /// correspondance suffisamment fiable).
  static ReconciliationMatch reconcile(
    BankTransaction t,
    List<FinanceDocument> documents, {
    double threshold = 0.5,
  }) {
    FinanceDocument? best;
    double bestScore = 0;
    for (final d in documents) {
      final sc = score(t, d);
      if (sc > bestScore) {
        bestScore = sc;
        best = d;
      }
    }
    if (best == null || bestScore < threshold) {
      return ReconciliationMatch(
        transaction: t,
        document: null,
        method: PaymentMatchMethod.manual,
        confidence: bestScore,
      );
    }
    final method =
        (best.structuredCommunication != null &&
            _digits(t.communication).contains(
              _digits(best.structuredCommunication!),
            ))
        ? PaymentMatchMethod.structuredCommunication
        : PaymentMatchMethod.reference;
    return ReconciliationMatch(
      transaction: t,
      document: best,
      method: method,
      confidence: bestScore,
    );
  }

  /// Rapproche automatiquement une liste de transactions.
  /// Retourne les correspondances (une par transaction).
  static List<ReconciliationMatch> autoMatch(
    List<BankTransaction> transactions,
    List<FinanceDocument> documents, {
    double threshold = 0.5,
  }) {
    final usedDocIds = <String>{};
    final results = <ReconciliationMatch>[];
    // Traiter d'abord les transactions les plus fiables.
    final sorted = [...transactions]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    for (final t in sorted) {
      final candidates = documents
          .where((d) => !usedDocIds.contains(d.id))
          .toList();
      final m = reconcile(t, candidates, threshold: threshold);
      if (m.matched) usedDocIds.add(m.document!.id);
      results.add(m);
    }
    return results;
  }
}
