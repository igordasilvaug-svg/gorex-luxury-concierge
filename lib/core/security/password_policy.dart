// GOREX LUXURY CONCIERGE — Politique de mot de passe.
//
// Cette politique est APPLIQUÉE PAR L'APPLICATION, à chaque endroit où un mot
// de passe est créé, changé ou réinitialisé. Elle ne remplace pas le réglage
// « Politique de mot de passe » de la console Firebase (qui bloque une
// création de compte hors application) : elle s'y ajoute, et couvre les
// parcours que la console ne contrôle pas (changement depuis l'espace client).
//
// Exigences :
//   · 12 caractères minimum (résiste au bourrage d'identifiants) ;
//   · au moins une majuscule, une minuscule, un chiffre et un symbole ;
//   · aucun mot de passe figurant dans la liste des plus courants ;
//   · pas de suite triviale (123456, azerty, gorex…) ;
//   · pas de répétition d'un même caractère plus de 3 fois.

class PasswordPolicy {
  PasswordPolicy._();

  /// Longueur minimale imposée par l'application.
  static const int minLength = 12;

  /// Fragments interdits : ils apparaissent en tête des listes de mots de
  /// passe les plus utilisés, ou sont devinables depuis le nom du service.
  static const List<String> _forbidden = [
    'password',
    'motdepasse',
    'mot de passe',
    'azerty',
    'qwerty',
    '123456',
    '000000',
    '111111',
    'gorex',
    'concierge',
    'luxury',
    'admin',
    'welcome',
    'bienvenue',
    'letmein',
    'soleil',
    'bonjour',
  ];

  /// Évalue un mot de passe et retourne la liste des manquements.
  ///
  /// Liste vide = mot de passe accepté. Chaque message est rédigé pour être
  /// affiché tel quel à l'utilisateur, en français.
  static List<String> validate(String? value) {
    final pwd = value ?? '';
    final issues = <String>[];

    if (pwd.length < minLength) {
      issues.add('Au moins $minLength caractères');
    }
    if (!RegExp(r'[A-Z]').hasMatch(pwd)) {
      issues.add('Au moins une majuscule');
    }
    if (!RegExp(r'[a-z]').hasMatch(pwd)) {
      issues.add('Au moins une minuscule');
    }
    if (!RegExp(r'\d').hasMatch(pwd)) {
      issues.add('Au moins un chiffre');
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pwd)) {
      issues.add('Au moins un symbole (!, #, €, …)');
    }

    final lower = pwd.toLowerCase();
    for (final bad in _forbidden) {
      if (lower.contains(bad)) {
        issues.add('Ne doit pas contenir « $bad »');
        break;
      }
    }

    // Répétition : « aaaa », « 1111 »…
    if (RegExp(r'(.)\1{3,}').hasMatch(pwd)) {
      issues.add('Pas plus de 3 caractères identiques de suite');
    }

    // Suite croissante ou décroissante simple : « 12345 », « abcde ».
    if (_hasSequentialRun(pwd, 4)) {
      issues.add('Pas de suite de caractères (1234, abcd…)');
    }

    return issues;
  }

  /// Vrai si le mot de passe est conforme.
  static bool isValid(String? value) => validate(value).isEmpty;

  /// Message d'erreur unique, ou `null` si le mot de passe convient.
  static String? errorText(String? value) {
    final issues = validate(value);
    if (issues.isEmpty) return null;
    return issues.join(' · ');
  }

  /// Détecte une suite d'au moins [run] caractères consécutifs dans le code
  /// ASCII, dans un sens ou dans l'autre.
  static bool _hasSequentialRun(String pwd, int run) {
    if (pwd.length < run) return false;
    var up = 1;
    var down = 1;
    for (var i = 1; i < pwd.length; i++) {
      final d = pwd.codeUnitAt(i) - pwd.codeUnitAt(i - 1);
      up = d == 1 ? up + 1 : 1;
      down = d == -1 ? down + 1 : 1;
      if (up >= run || down >= run) return true;
    }
    return false;
  }
}
