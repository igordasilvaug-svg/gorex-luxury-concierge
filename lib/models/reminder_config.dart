/// Configuration du moteur de relance automatique des factures impayées.
///
/// Permet à GOREX LUXURY CONCIERGE de planifier l'envoi des relances
/// (1ʳᵉ relance → 2ᵉ relance → mise en demeure) sans intervention manuelle :
/// au démarrage de l'application et/ou à intervalle régulier.
class ReminderConfig {
  /// Active le moteur de relance automatique.
  final bool enabled;

  /// Envoie réellement les relances (sinon simple détection/notification).
  final bool autoSend;

  /// Lance une vérification à chaque démarrage de l'application.
  final bool runOnStartup;

  /// Intervalle (heures) entre deux vérifications automatiques.
  final int intervalHours;

  /// Délai minimum (jours) entre deux relances d'une même facture.
  final int minDaysBetween;

  /// Horodatage de la dernière exécution automatique.
  final DateTime? lastRunAt;

  /// Nombre de relances envoyées lors de la dernière exécution.
  final int lastRunCount;

  const ReminderConfig({
    this.enabled = false,
    this.autoSend = true,
    this.runOnStartup = true,
    this.intervalHours = 24,
    this.minDaysBetween = 7,
    this.lastRunAt,
    this.lastRunCount = 0,
  });

  ReminderConfig copyWith({
    bool? enabled,
    bool? autoSend,
    bool? runOnStartup,
    int? intervalHours,
    int? minDaysBetween,
    DateTime? lastRunAt,
    int? lastRunCount,
  }) => ReminderConfig(
    enabled: enabled ?? this.enabled,
    autoSend: autoSend ?? this.autoSend,
    runOnStartup: runOnStartup ?? this.runOnStartup,
    intervalHours: intervalHours ?? this.intervalHours,
    minDaysBetween: minDaysBetween ?? this.minDaysBetween,
    lastRunAt: lastRunAt ?? this.lastRunAt,
    lastRunCount: lastRunCount ?? this.lastRunCount,
  );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'autoSend': autoSend,
    'runOnStartup': runOnStartup,
    'intervalHours': intervalHours,
    'minDaysBetween': minDaysBetween,
    'lastRunAt': lastRunAt?.toIso8601String(),
    'lastRunCount': lastRunCount,
  };

  factory ReminderConfig.fromMap(Map<String, dynamic> m) => ReminderConfig(
    enabled: m['enabled'] as bool? ?? false,
    autoSend: m['autoSend'] as bool? ?? true,
    runOnStartup: m['runOnStartup'] as bool? ?? true,
    intervalHours: (m['intervalHours'] as num?)?.toInt() ?? 24,
    minDaysBetween: (m['minDaysBetween'] as num?)?.toInt() ?? 7,
    lastRunAt: m['lastRunAt'] != null
        ? DateTime.tryParse(m['lastRunAt'] as String)
        : null,
    lastRunCount: (m['lastRunCount'] as num?)?.toInt() ?? 0,
  );
}
