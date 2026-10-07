import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/finance.dart';

/// Résultat du calcul d'une relance à envoyer pour une facture impayée.
class ReminderPlan {
  final FinanceDocument document;
  final ReminderLevel nextLevel;
  final int daysOverdue;
  final bool due; // true si une relance doit être envoyée maintenant
  final String reason;

  const ReminderPlan({
    required this.document,
    required this.nextLevel,
    required this.daysOverdue,
    required this.due,
    required this.reason,
  });
}

/// Service de gestion des relances de factures impayées.
///
/// Détermine, pour chaque facture échue, le niveau de relance à envoyer
/// (1ʳᵉ relance → 2ᵉ relance → mise en demeure) selon le nombre de jours
/// de retard et la date de la dernière relance.
class ReminderService {
  ReminderService._();

  /// Seuil de jours de retard déclenchant chaque niveau de relance.
  static const Map<ReminderLevel, int> thresholds = {
    ReminderLevel.first: 7,
    ReminderLevel.second: 21,
    ReminderLevel.finalNotice: 45,
  };

  /// Délai minimal (jours) entre deux relances successives.
  static const int minDaysBetween = 7;

  static final _date = DateFormat('dd/MM/yyyy', 'fr_BE');

  /// Niveau de relance cible en fonction du nombre de jours de retard.
  static ReminderLevel targetLevel(int daysOverdue) {
    if (daysOverdue >= thresholds[ReminderLevel.finalNotice]!) {
      return ReminderLevel.finalNotice;
    }
    if (daysOverdue >= thresholds[ReminderLevel.second]!) {
      return ReminderLevel.second;
    }
    if (daysOverdue >= thresholds[ReminderLevel.first]!) {
      return ReminderLevel.first;
    }
    return ReminderLevel.none;
  }

  /// Calcule le plan de relance d'une facture (faut-il relancer ? à quel niveau ?).
  static ReminderPlan plan(FinanceDocument d) {
    final days = d.daysOverdue;
    final target = targetLevel(days);

    if (!d.isOverdue) {
      return ReminderPlan(
        document: d,
        nextLevel: ReminderLevel.none,
        daysOverdue: 0,
        due: false,
        reason: 'Facture non échue ou déjà réglée.',
      );
    }
    if (target == ReminderLevel.none) {
      return ReminderPlan(
        document: d,
        nextLevel: ReminderLevel.first,
        daysOverdue: days,
        due: false,
        reason: 'Échéance récente — relance dans '
            '${thresholds[ReminderLevel.first]! - days} jour(s).',
      );
    }
    // Déjà relancé à un niveau supérieur ou égal → rien à faire.
    if (d.reminderLevel.level >= target.level) {
      return ReminderPlan(
        document: d,
        nextLevel: target,
        daysOverdue: days,
        due: false,
        reason: 'Relance ${target.label} déjà envoyée.',
      );
    }
    // Anti-spam : respecter le délai minimal entre deux relances.
    final last = d.lastReminderAt;
    if (last != null) {
      final since = DateTime.now().difference(last).inDays;
      if (since < minDaysBetween) {
        return ReminderPlan(
          document: d,
          nextLevel: d.reminderLevel.next,
          daysOverdue: days,
          due: false,
          reason: 'Dernière relance il y a $since jour(s) '
              '(délai minimum $minDaysBetween jours).',
        );
      }
    }
    return ReminderPlan(
      document: d,
      nextLevel: target,
      daysOverdue: days,
      due: true,
      reason: '$days jours de retard — ${target.label} à envoyer.',
    );
  }

  /// Toutes les factures nécessitant une relance immédiate.
  static List<ReminderPlan> pending(List<FinanceDocument> documents) {
    final plans = documents
        .where((d) => d.type == FinanceDocType.invoice)
        .map(plan)
        .where((p) => p.due)
        .toList()
      ..sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));
    return plans;
  }

  /// Sujet et corps de l'email de relance (français, ton courtois et ferme).
  static ({String subject, String body}) buildEmail(
    FinanceDocument d,
    ReminderLevel level, {
    required String companyName,
    String? companyVat,
    String? iban,
  }) {
    final eur = NumberFormat.currency(
      locale: 'fr_BE',
      symbol: '€',
      decimalDigits: 2,
    );
    final subject = switch (level) {
      ReminderLevel.first => 'Rappel — Facture ${d.reference}',
      ReminderLevel.second => '2ᵉ rappel — Facture ${d.reference}',
      ReminderLevel.finalNotice =>
        'Mise en demeure — Facture ${d.reference}',
      ReminderLevel.none => 'Facture ${d.reference}',
    };

    final intro = switch (level) {
      ReminderLevel.first =>
        'Sauf erreur de notre part, nous n\'avons pas encore reçu le '
            'paiement de la facture ci-dessous, échue le '
            '${_date.format(d.dueDate ?? d.date)}.',
      ReminderLevel.second =>
        'Malgré notre précédent rappel, la facture ci-dessous demeure '
            'impayée (échue le ${_date.format(d.dueDate ?? d.date)}).',
      ReminderLevel.finalNotice =>
        'En dépit de nos rappels, la facture ci-dessous reste impayée. '
            'Nous vous invitons à régulariser sous 8 jours afin d\'éviter '
            'tout recouvrement contentieux.',
      ReminderLevel.none => 'Veuillez trouver le détail de votre facture.',
    };

    final b = StringBuffer()
      ..writeln('Madame, Monsieur,')
      ..writeln()
      ..writeln(intro)
      ..writeln()
      ..writeln('Facture : ${d.reference}')
      ..writeln('Date : ${_date.format(d.date)}')
      ..writeln('Échéance : ${_date.format(d.dueDate ?? d.date)}')
      ..writeln('Montant dû : ${eur.format(d.balance)}')
      ..writeln(
        'Retard : ${d.daysOverdue} jour(s)',
      );
    if (d.structuredCommunication != null) {
      b.writeln('Communication structurée : ${d.structuredCommunication}');
    }
    if (iban != null && iban.isNotEmpty) {
      b.writeln('Compte bancaire : $iban');
    }
    b
      ..writeln()
      ..writeln(
        'Nous vous remercions de bien vouloir procéder au virement '
        'dans les meilleurs délais.',
      )
      ..writeln()
      ..writeln('Veuillez agréer, Madame, Monsieur, l\'expression de nos '
          'salutations distinguées.')
      ..writeln()
      ..writeln(companyName);
    if (companyVat != null && companyVat.isNotEmpty) {
      b.writeln('TVA $companyVat');
    }
    return (subject: subject, body: b.toString());
  }
}
