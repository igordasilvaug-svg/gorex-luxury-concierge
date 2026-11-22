/// Configuration de l'Access Point Peppol (facturation électronique).
///
/// Permet de relier l'application à un Access Point Peppol agréé
/// (API REST type Storecove / Tickstar / Unifiedpost) afin de transmettre
/// réellement les factures électroniques au format UBL / Peppol BIS Billing 3.0.
///
/// ── OÙ VIT LA CLÉ D'API (et pourquoi pas ici) ──────────────────────────
/// `apiKey` est un SECRET. Elle n'est donc **volontairement pas** incluse dans
/// [toMap]. Cette méthode sérialise la configuration « publique » : celle qui
/// est enregistrée dans `company/gorex-group`, un document que TOUT
/// utilisateur connecté peut lire — y compris un client VIP (règle
/// `allow read: if isRealUser()`), et que l'écran de profil client lit déjà
/// pour afficher le téléphone de la conciergerie.
///
/// Avant cette séparation, `apiKey` figurait dans `toMap()`. Le jour où une
/// vraie clé aurait été saisie, elle aurait été servie au navigateur de chaque
/// client. Le secret est désormais écrit dans `company_secrets/gorex-group`,
/// lisible du seul rôle finance ([toSecretMap]).
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

  /// Identifiant **numérique** de l'entité légale chez l'Access Point.
  ///
  /// Retourne `null` si le champ est vide ou ne contient pas un nombre.
  /// Cette absence est une erreur de saisie à signaler : l'API Storecove
  /// attend un entier (`legal_entity_id`), pas un nom. Envoyer malgré tout
  /// ferait transmettre la facture sous une entité qui n'est pas la nôtre.
  int? get legalEntityId {
    final t = senderLegalEntityId.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

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

  /// Partie **publique** de la configuration — sans le secret.
  ///
  /// C'est cette carte qui est écrite dans `company/gorex-group`. Elle peut
  /// donc être lue par n'importe quel utilisateur connecté sans conséquence.
  /// Pour le secret, voir [toSecretMap].
  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'apiBaseUrl': apiBaseUrl,
    'senderPeppolId': senderPeppolId,
    'senderLegalEntityId': senderLegalEntityId,
    'defaultScheme': defaultScheme,
    'timeoutSeconds': timeoutSeconds,
    'webhookUrl': webhookUrl,
    'autoRefresh': autoRefresh,
  };

  /// Partie **secrète** de la configuration.
  ///
  /// Destinée à `company_secrets/gorex-group`, lisible du seul rôle finance.
  /// Ne jamais l'écrire dans un document lisible par `isRealUser()`.
  Map<String, dynamic> toSecretMap() => {'apiKey': apiKey};

  factory PeppolConfig.fromMap(Map<String, dynamic> m) => PeppolConfig(
    enabled: m['enabled'] as bool? ?? false,
    apiBaseUrl:
        m['apiBaseUrl'] as String? ?? 'https://api.storecove.com/api/v2',
    // `apiKey` n'est plus publiée dans `company/` : la lire ici reste
    // nécessaire pour hydrater le stockage LOCAL (et les anciennes
    // sauvegardes), mais elle est écrasée par `company_secrets/` dès qu'une
    // session authentifiée la fournit ([mergeSecretMap]).
    apiKey: m['apiKey'] as String? ?? '',
    senderPeppolId: m['senderPeppolId'] as String? ?? '',
    senderLegalEntityId: m['senderLegalEntityId'] as String? ?? '',
    defaultScheme: m['defaultScheme'] as String? ?? '0208',
    timeoutSeconds: (m['timeoutSeconds'] as num?)?.toInt() ?? 30,
    webhookUrl: m['webhookUrl'] as String? ?? '',
    autoRefresh: m['autoRefresh'] as bool? ?? false,
  );

  /// Applique le secret relu depuis `company_secrets/`.
  ///
  /// Si [m] ne contient pas de clé exploitable, la configuration est renvoyée
  /// inchangée : une lecture manquante ne doit jamais effacer une clé déjà
  /// saisie sur ce poste.
  PeppolConfig mergeSecretMap(Map<String, dynamic>? m) {
    final k = (m?['apiKey'] as String? ?? '').trim();
    if (k.isEmpty) return this;
    return copyWith(apiKey: k);
  }
}
