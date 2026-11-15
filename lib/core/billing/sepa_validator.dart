// GOREX LUXURY CONCIERGE — Validation des données de domiciliation SEPA.
//
// Ce fichier ne fait aucun appel réseau et ne stocke rien : il valide.
// La règle « pas de simulation » impose de refuser une coordonnée bancaire
// invalide AVANT qu'elle n'entre dans un ordre de prélèvement : un IBAN
// erroné génère des rejets bancaires facturés et des impayés clients.

import 'dart:math' as math;

/// Résultat d'une validation IBAN, avec la raison exacte en cas d'échec.
class IbanValidation {
  final bool valid;
  final String? error;
  final String country; // 2 lettres (vide si invalide)
  final String formatted; // IBAN normalisé par groupes de 4

  const IbanValidation._({
    required this.valid,
    this.error,
    this.country = '',
    this.formatted = '',
  });

  const IbanValidation.valid(String country, String formatted)
    : this._(valid: true, country: country, formatted: formatted);

  const IbanValidation.invalid(String reason)
    : this._(valid: false, error: reason);
}

/// Utilitaires de validation bancaire SEPA.
class SepaValidator {
  SepaValidator._();

  /// Longueurs IBAN officielles (ISO 13616) des pays de la zone SEPA.
  /// Un pays absent de cette table est refusé : mieux vaut une erreur claire
  /// qu'un IBAN accepté puis rejeté par la banque.
  static const Map<String, int> _ibanLengths = {
    'AD': 24, 'AT': 20, 'BE': 16, 'BG': 22, 'CH': 21, 'CY': 28, 'CZ': 24,
    'DE': 22, 'DK': 18, 'EE': 20, 'ES': 24, 'FI': 18, 'FO': 18, 'FR': 27,
    'GB': 22, 'GI': 23, 'GL': 18, 'GR': 27, 'HR': 21, 'HU': 28, 'IE': 22,
    'IS': 26, 'IT': 27, 'LI': 21, 'LT': 20, 'LU': 20, 'LV': 21, 'MC': 27,
    'MT': 31, 'NL': 18, 'NO': 15, 'PL': 28, 'PT': 25, 'RO': 24, 'SE': 24,
    'SI': 19, 'SK': 24, 'SM': 27, 'VA': 22,
  };

  /// Retire espaces, tirets et points : les IBAN sont souvent copiés formatés.
  static String normalizeIban(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-.]'), '').toUpperCase();

  /// Valide un IBAN par la norme ISO 13616 (contrôle modulo 97).
  static IbanValidation validateIban(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const IbanValidation.invalid('IBAN manquant');
    }
    final iban = normalizeIban(raw);

    if (iban.length < 15 || iban.length > 34) {
      return const IbanValidation.invalid(
        'Longueur d\'IBAN invalide (15 à 34 caractères)',
      );
    }
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$').hasMatch(iban)) {
      return const IbanValidation.invalid(
        'Format invalide : 2 lettres, 2 chiffres, puis caractères alphanumériques',
      );
    }

    final country = iban.substring(0, 2);
    final expected = _ibanLengths[country];
    if (expected == null) {
      return IbanValidation.invalid(
        'Pays « $country » hors zone SEPA ou non pris en charge',
      );
    }
    if (iban.length != expected) {
      return IbanValidation.invalid(
        'Un IBAN $country doit comporter $expected caractères '
        '(reçu : ${iban.length})',
      );
    }

    // Contrôle modulo 97 : on déplace les 4 premiers caractères à la fin,
    // on convertit les lettres en chiffres (A=10 … Z=35) et on vérifie que
    // le reste de la division par 97 vaut 1.
    final rearranged = iban.substring(4) + iban.substring(0, 4);
    final digits = StringBuffer();
    for (final ch in rearranged.split('')) {
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        digits.write(ch);
      } else {
        digits.write(code - 55); // 'A' = 65 → 10
      }
    }

    // Calcul du modulo par blocs : la chaîne peut dépasser la capacité d'un int
    // natif sur le web (JavaScript), d'où le traitement progressif.
    var remainder = 0;
    for (final ch in digits.toString().split('')) {
      remainder = (remainder * 10 + (ch.codeUnitAt(0) - 48)) % 97;
    }
    if (remainder != 1) {
      return const IbanValidation.invalid(
        'Clé de contrôle IBAN incorrecte (le numéro contient une faute de frappe)',
      );
    }

    return IbanValidation.valid(country, formatIban(iban));
  }

  /// Présente l'IBAN par groupes de 4 : « BE68 5390 0754 7034 ».
  static String formatIban(String iban) {
    final clean = normalizeIban(iban);
    final groups = <String>[];
    for (var i = 0; i < clean.length; i += 4) {
      groups.add(clean.substring(i, math.min(i + 4, clean.length)));
    }
    return groups.join(' ');
  }

  /// Version masquée pour l'affichage : « BE68 **** **** 7034 ».
  ///
  /// L'IBAN est une donnée financière : il ne doit pas être lisible en clair
  /// sur un écran partagé ou dans une capture d'écran.
  static String maskIban(String? iban) {
    if (iban == null || iban.trim().isEmpty) return '—';
    final clean = normalizeIban(iban);
    if (clean.length < 8) return '****';
    final head = clean.substring(0, 4);
    final tail = clean.substring(clean.length - 4);
    final stars = '*' * (clean.length - 8);
    return formatIban('$head$stars$tail');
  }

  /// Valide un BIC/SWIFT : 8 ou 11 caractères (ISO 9362).
  static String? validateBic(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null; // facultatif en SEPA
    final bic = raw.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (!RegExp(r'^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$').hasMatch(bic)) {
      return 'BIC invalide : 8 ou 11 caractères attendus (ex. GEBABEBB)';
    }
    return null;
  }

  static String normalizeBic(String raw) =>
      raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Calcule l'identifiant créancier SEPA (ICS) belge à partir du numéro
  /// d'entreprise BCE.
  ///
  /// Format : `BE` + 2 chiffres de contrôle + `ZZZ` + numéro d'entreprise
  /// (10 chiffres, sans points). Ex. pour 0123.456.789 → `BE??ZZZ0123456789`.
  ///
  /// Les 2 chiffres de contrôle suivent le même algorithme que l'IBAN.
  static String? creditorIdFromEnterpriseNumber(String? enterpriseNumber) {
    if (enterpriseNumber == null) return null;
    final digits = enterpriseNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) return null;

    final base = 'ZZZ$digits';
    // On ajoute BE00 pour le calcul, puis on déplace en fin de chaîne.
    final rearranged = '${base}BE00';
    final buf = StringBuffer();
    for (final ch in rearranged.split('')) {
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        buf.write(ch);
      } else {
        buf.write(code - 55);
      }
    }
    var remainder = 0;
    for (final ch in buf.toString().split('')) {
      remainder = (remainder * 10 + (ch.codeUnitAt(0) - 48)) % 97;
    }
    final check = 98 - remainder;
    return 'BE${check.toString().padLeft(2, '0')}$base';
  }

  /// Vérifie qu'un identifiant créancier est bien formé (structure + contrôle).
  static String? validateCreditorId(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Identifiant créancier SEPA (ICS) manquant';
    }
    final id = raw.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,28}$').hasMatch(id)) {
      return 'Identifiant créancier SEPA invalide';
    }
    if (id.length < 7 || id.length > 35) {
      return 'Identifiant créancier SEPA : 7 à 35 caractères attendus';
    }
    // Contrôle modulo 97, identique à l'IBAN mais sans longueur imposée.
    final rearranged = id.substring(4) + id.substring(0, 4);
    final buf = StringBuffer();
    for (final ch in rearranged.split('')) {
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        buf.write(ch);
      } else {
        buf.write(code - 55);
      }
    }
    var remainder = 0;
    for (final ch in buf.toString().split('')) {
      remainder = (remainder * 10 + (ch.codeUnitAt(0) - 48)) % 97;
    }
    if (remainder != 1) {
      return 'Clé de contrôle de l\'identifiant créancier incorrecte';
    }
    return null;
  }
}
