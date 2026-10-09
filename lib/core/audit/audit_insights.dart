import '../../models/crm_agenda.dart';

/// Catégories d'actions du journal d'audit.
enum AuditCategory {
  access,
  security,
  operations,
  billing,
  administration,
  other,
}

/// Point d'activité quotidienne (nombre d'entrées pour un jour donné).
class DailyActivity {
  final DateTime day;
  final int count;
  const DailyActivity(this.day, this.count);
}

/// Analyse du journal d'audit : agrégats, tendances et événements sensibles.
///
/// Utilisé par le tableau de bord sécurité et l'export PDF du journal.
class AuditInsights {
  final List<AuditEntry> entries;
  AuditInsights(this.entries);

  int get total => entries.length;

  // ── Classement des actions ──
  static AuditCategory categoryOf(String action) {
    final a = action.toLowerCase();
    if (a.contains('connexion') || a.contains('déconnexion')) {
      return AuditCategory.access;
    }
    if (a.contains('mot de passe') ||
        a.contains('escalade') ||
        a.contains('sécurité') ||
        a.contains('securite')) {
      return AuditCategory.security;
    }
    if (a.contains('peppol') ||
        a.contains('rapprochement') ||
        a.contains('facture') ||
        a.contains('relance')) {
      return AuditCategory.billing;
    }
    if (a.contains('accès') ||
        a.contains('acces') ||
        a.contains('suppression') ||
        a.contains('ajout')) {
      return AuditCategory.administration;
    }
    if (a.contains('création') ||
        a.contains('creation') ||
        a.contains('statut') ||
        a.contains('assignation') ||
        a.contains('mise à jour')) {
      return AuditCategory.operations;
    }
    return AuditCategory.other;
  }

  static String categoryLabel(AuditCategory c) {
    switch (c) {
      case AuditCategory.access:
        return 'Accès';
      case AuditCategory.security:
        return 'Sécurité';
      case AuditCategory.operations:
        return 'Opérations';
      case AuditCategory.billing:
        return 'Facturation';
      case AuditCategory.administration:
        return 'Administration';
      case AuditCategory.other:
        return 'Autres';
    }
  }

  /// Répartition des entrées par catégorie (décroissant).
  Map<AuditCategory, int> byCategory() {
    final m = <AuditCategory, int>{};
    for (final e in entries) {
      final c = categoryOf(e.action);
      m[c] = (m[c] ?? 0) + 1;
    }
    final sorted = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  // ── Comptages temporels ──
  int get todayCount {
    final now = DateTime.now();
    return entries
        .where(
          (e) =>
              e.timestamp.year == now.year &&
              e.timestamp.month == now.month &&
              e.timestamp.day == now.day,
        )
        .length;
  }

  int get last7Count {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return entries.where((e) => e.timestamp.isAfter(since)).length;
  }

  /// Activité quotidienne sur [days] jours, du plus ancien au plus récent.
  List<DailyActivity> daily([int days = 14]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <DailyActivity>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final count = entries
          .where(
            (e) =>
                e.timestamp.year == day.year &&
                e.timestamp.month == day.month &&
                e.timestamp.day == day.day,
          )
          .length;
      result.add(DailyActivity(day, count));
    }
    return result;
  }

  int get activeActorsCount => {for (final e in entries) e.actor}.length;

  // ── Événements sensibles ──
  static bool isSensitive(AuditEntry e) {
    final a = e.action.toLowerCase();
    return a.contains('échec') ||
        a.contains('echec') ||
        a.contains('suppression') ||
        a.contains('escalade') ||
        a.contains('mot de passe') ||
        a.contains('sécurité') ||
        a.contains('securite') ||
        a.contains('erreur');
  }

  /// Événements sensibles (les plus récents d'abord).
  List<AuditEntry> get sensitiveEvents =>
      entries.where(isSensitive).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  /// Heure de la dernière activité enregistrée (ou null si journal vide).
  DateTime? get lastActivity =>
      entries.isEmpty ? null : entries.first.timestamp;
}
