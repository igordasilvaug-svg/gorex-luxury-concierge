/// Configuration globale de l'application.
///
/// Le drapeau [isProduction] est activé au moment de la compilation pour les
/// versions destinées au store (Google Play), afin de masquer les éléments de
/// démonstration (comptes de test, remplissage rapide, etc.).
///
/// Exemple :
///   flutter build appbundle --release --dart-define=PRODUCTION=true
///
/// En l'absence de définition, la valeur par défaut est `false`
/// (build de développement / démonstration).
class AppConfig {
  const AppConfig._();

  /// `true` pour les builds de production (store) — masque la démo.
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  /// Affiche-t-on les comptes de démonstration sur l'écran de connexion ?
  static bool get showDemoAccounts => !isProduction;

  /// Adresse de contact et d'assistance du groupe.
  ///
  /// Boîte opérationnelle fournie par le groupe (`ops@gorex-group.eu`).
  /// Elle est AFFICHÉE dans l'application comme point de contact : elle ne peut
  /// pas être l'expéditeur des e-mails d'authentification, ceux-ci étant émis
  /// par l'infrastructure Firebase depuis `noreply@<projet>.firebaseapp.com`.
  /// Utiliser un expéditeur `@gorex-group.eu` exigerait un serveur SMTP
  /// externe et des enregistrements SPF/DKIM dans la zone DNS du domaine.
  static const String supportEmail = 'ops@gorex-group.eu';

  /// Adresse de retour des liens de réinitialisation de mot de passe.
  ///
  /// Firebase y renvoie la personne APRÈS qu'elle a choisi son nouveau mot de
  /// passe : la session s'ouvre alors directement dans l'application.
  static const String passwordResetContinueUrl =
      'https://gorex-luxury-concierge.eu/';

  /// Paramètre d'URL transportant le code de réinitialisation.
  ///
  /// Firebase transmet ce code sous le nom `oobCode` (out-of-band code) ; on
  /// accepte aussi `code` et `ticket`, utilisés par d'autres émetteurs.
  static const List<String> resetCodeParams = ['oobCode', 'code', 'ticket'];

  /// Vrai si l'URL courante porte un code de réinitialisation.
  static bool isPasswordResetUrl(Uri uri) {
    for (final p in resetCodeParams) {
      final v = uri.queryParameters[p];
      if (v != null && v.trim().isNotEmpty) return true;
    }
    return false;
  }

  /// Extrait le code de réinitialisation d'une URL, ou `null`.
  static String? resetCodeFrom(Uri uri) {
    for (final p in resetCodeParams) {
      final v = uri.queryParameters[p];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// Code de réinitialisation porté par l'URL courante, ou `null`.
  ///
  /// `Uri.base` désigne l'adresse de la page sur le Web (et un chemin de
  /// fichier hors Web, sans paramètres) : aucun import spécifique au Web
  /// n'est donc nécessaire, le code reste compilable sur toutes les cibles.
  static String? get passwordResetCode => resetCodeFrom(Uri.base);
}
