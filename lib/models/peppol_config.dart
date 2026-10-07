/// Configuration de l'Access Point Peppol (facturation électronique).
///
/// Permet de relier l'application à un Access Point Peppol agréé
/// (API REST type Storecove / Tickstar / Unifiedpost) afin de transmettre
/// réellement les factures électroniques au format UBL / Peppol BIS Billing 3.0.
class PeppolConfig {
  /// Active la transmission réelle via l'Access Point.
  /// Si false, l'envoi reste en mode démonstration (simulation locale).
  final bool enabled;

  /// URL de base de l'API de l'Access Point (ex. https://api.storecove.com/api/v2).
  final String apiBaseUrl;

  /// Jeton d'API / clé d'authentification (Bearer).
  final String apiKey;

  /// Identifiant légal de l'émetteur chez l'Access Point.
  final String senderPeppolId; // ex. 0208:0123456749

  /// Identifiant légal de l'émetteur chez l'Access Point (champ API).
  final String senderLegalEntityId; // ex. 1 (id numérique Storecove)

  /// Schéma par défaut du destinataire (0208 = Belgique).
  final String defaultScheme;

  /// Délai d'attente des requêtes HTTP (secondes).
  final int timeoutSeconds;

  /// URL du webhook public où l'Access Point notifie les changements de statut.
  /// (À déclarer côté fournisseur.)
  final String webhookUrl;

  /// Rafraîchissement automatique du statut des factures en attente.
  final bool autoRefresh;

  const PeppolConfig({
    this.enabled = false,
    this.apiBaseUrl = 'https://api.storecove.com/api/v2',
    this.apiKey = '',
    this.senderPeppolId = '',
    this.senderLegalEntityId = '',
    this.defaultScheme = '0208',
    this.timeoutSeconds = 30,
    this.webhookUrl = '',
    this.autoRefresh = false,
  });

  bool get isConfigured =>
      enabled &&
      apiBaseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      senderPeppolId.trim().isNotEmpty;

  PeppolConfig copyWith({
    bool? enabled,
    String? apiBaseUrl,
    String? apiKey,
    String? senderPeppolId,
    String? senderLegalEntityId,
    String? defaultScheme,
    int? timeoutSeconds,
    String? webhookUrl,
    bool? autoRefresh,
  }) => PeppolConfig(
    enabled: enabled ?? this.enabled,
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    apiKey: apiKey ?? this.apiKey,
    senderPeppolId: senderPeppolId ?? this.senderPeppolId,
    senderLegalEntityId: senderLegalEntityId ?? this.senderLegalEntityId,
    defaultScheme: defaultScheme ?? this.defaultScheme,
    timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    webhookUrl: webhookUrl ?? this.webhookUrl,
    autoRefresh: autoRefresh ?? this.autoRefresh,
  );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'apiBaseUrl': apiBaseUrl,
    'apiKey': apiKey,
    'senderPeppolId': senderPeppolId,
    'senderLegalEntityId': senderLegalEntityId,
    'defaultScheme': defaultScheme,
    'timeoutSeconds': timeoutSeconds,
    'webhookUrl': webhookUrl,
    'autoRefresh': autoRefresh,
  };

  factory PeppolConfig.fromMap(Map<String, dynamic> m) => PeppolConfig(
    enabled: m['enabled'] as bool? ?? false,
    apiBaseUrl: m['apiBaseUrl'] as String? ?? 'https://api.storecove.com/api/v2',
    apiKey: m['apiKey'] as String? ?? '',
    senderPeppolId: m['senderPeppolId'] as String? ?? '',
    senderLegalEntityId: m['senderLegalEntityId'] as String? ?? '',
    defaultScheme: m['defaultScheme'] as String? ?? '0208',
    timeoutSeconds: (m['timeoutSeconds'] as num?)?.toInt() ?? 30,
    webhookUrl: m['webhookUrl'] as String? ?? '',
    autoRefresh: m['autoRefresh'] as bool? ?? false,
  );
}
