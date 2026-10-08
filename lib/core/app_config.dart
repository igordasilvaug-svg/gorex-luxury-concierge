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
}
