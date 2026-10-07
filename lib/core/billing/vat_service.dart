import '../../models/client.dart';

/// Résultat de validation d'un numéro BCE / TVA.
class VatValidationResult {
  final bool valid;
  final String? normalized; // numéro normalisé (ex. BE0123456789)
  final bool isBelgian;
  final bool isEu;
  final String? message;

  const VatValidationResult({
    required this.valid,
    this.normalized,
    this.isBelgian = false,
    this.isEu = false,
    this.message,
  });
}

/// Résultat d'un calcul de TVA.
class VatComputation {
  final double rate; // taux appliqué (%)
  final bool reverseCharge; // autoliquidation (TVA due par le preneur)
  final String mention; // mention légale à faire figurer
  final bool intraEuB2b; // livraison intracommunautaire B2B

  const VatComputation({
    required this.rate,
    required this.reverseCharge,
    required this.mention,
    this.intraEuB2b = false,
  });
}

/// Service de facturation : validation des identifiants d'entreprise,
/// détermination du régime TVA et éligibilité Peppol.
///
/// ⚠️ Ce service applique les règles belges/UE standards. Il ne remplace pas
/// la validation officielle (VIES / Banque-Carrefour des Entreprises) ; il est
/// conçu pour être branché sur ces API en production.
class VatService {
  VatService._();

  static const _euPrefixes = {
    'AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'EL', 'ES', 'FI', 'FR',
    'HR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO',
    'SE', 'SI', 'SK',
  };

  /// Normalise un numéro de TVA (majuscules, sans espaces/points/tirets).
  static String normalize(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Valide un numéro de TVA (format + checksum belge).
  static VatValidationResult validateVat(String raw) {
    final n = normalize(raw);
    if (n.isEmpty) {
      return const VatValidationResult(valid: false, message: 'Numéro vide');
    }
    final prefix = n.length >= 2 ? n.substring(0, 2) : '';
    final isEu = _euPrefixes.contains(prefix);
    final isBe = prefix == 'BE';

    if (!isEu) {
      // Hors UE : on accepte un identifiant non vide (numéro local du pays)
      return VatValidationResult(
        valid: n.length >= 4,
        normalized: n,
        isBelgian: false,
        isEu: false,
        message: n.length >= 4 ? null : 'Format trop court',
      );
    }

    // Longueurs attendues par pays UE
    final expected = <String, int>{
      'AT': 11, 'BE': 12, 'BG': 12, 'CY': 11, 'CZ': 12, 'DE': 11, 'DK': 10,
      'EE': 11, 'EL': 11, 'ES': 11, 'FI': 12, 'FR': 13, 'HR': 13, 'HU': 10,
      'IE': 11, 'IT': 13, 'LT': 11, 'LU': 10, 'LV': 13, 'MT': 10, 'NL': 14,
      'PL': 12, 'PT': 12, 'RO': 10, 'SE': 14, 'SI': 10, 'SK': 12,
    };
    final len = expected[prefix];
    if (len != null && n.length != len) {
      return VatValidationResult(
        valid: false,
        normalized: n,
        isBelgian: isBe,
        isEu: true,
        message: 'Longueur attendue pour $prefix : $len caractères',
      );
    }

    // Contrôle modulo 97 spécifique à la Belgique (BE 0XXX.XXX.XXX)
    if (isBe) {
      final digits = n.substring(2);
      final base = int.tryParse(digits.substring(0, 8));
      final check = int.tryParse(digits.substring(8));
      if (base == null || check == null) {
        return VatValidationResult(
          valid: false,
          normalized: n,
          isBelgian: true,
          isEu: true,
          message: 'Format belge invalide',
        );
      }
      final ok = (97 - (base % 97)) == check;
      return VatValidationResult(
        valid: ok,
        normalized: n,
        isBelgian: true,
        isEu: true,
        message: ok ? null : 'Clé de contrôle belge incorrecte (modulo 97)',
      );
    }

    return VatValidationResult(
      valid: true,
      normalized: n,
      isBelgian: false,
      isEu: true,
    );
  }

  /// Valide un numéro d'entreprise belge (BCE) — format XXXX.XXX.XXX.
  static VatValidationResult validateBelgianCompanyNumber(String raw) {
    final n = normalize(raw);
    if (n.length != 10) {
      return const VatValidationResult(
        valid: false,
        message: 'Le numéro BCE belge comporte 10 chiffres',
      );
    }
    final base = int.tryParse(n.substring(0, 8));
    final check = int.tryParse(n.substring(8));
    if (base == null || check == null) {
      return const VatValidationResult(valid: false, message: 'Format invalide');
    }
    final ok = (97 - (base % 97)) == check;
    return VatValidationResult(
      valid: ok,
      normalized: n,
      isBelgian: true,
      isEu: true,
      message: ok ? null : 'Clé de contrôle BCE incorrecte',
    );
  }

  /// Formate un numéro de TVA belge : BE0123456789 → BE 0123.456.789.
  static String formatVat(String raw) {
    final n = normalize(raw);
    if (n.startsWith('BE') && n.length == 12) {
      final d = n.substring(2);
      return 'BE ${d.substring(0, 4)}.${d.substring(4, 7)}.${d.substring(7)}';
    }
    return raw.trim();
  }

  /// Détermine le régime TVA applicable à un client.
  ///
  /// - Client belge assujetti (numéro TVA) → autoliquidation possible (art. 51 §2.4 CTVA).
  /// - Client UE assujetti (numéro TVA) → livraison intracommunautaire exonérée.
  /// - Client hors UE → hors champ / exportation.
  /// - Particulier belge → TVA belge au taux standard.
  static VatComputation computeVat(Client? client, {double defaultRate = 21}) {
    if (client == null) {
      return VatComputation(
        rate: defaultRate,
        reverseCharge: false,
        mention: 'TVA ${defaultRate.toStringAsFixed(0)}%',
      );
    }

    final isBusiness = client.isBusiness;
    final vat = validateVat(client.vatNumber ?? '');

    if (isBusiness && vat.valid && vat.isBelgian) {
      return const VatComputation(
        rate: 0,
        reverseCharge: true,
        mention: 'Autoliquidation — TVA due par le preneur (art. 51 §2.4 CTVA)',
      );
    }

    if (isBusiness && vat.valid && vat.isEu && !vat.isBelgian) {
      return VatComputation(
        rate: 0,
        reverseCharge: false,
        intraEuB2b: true,
        mention:
            'Exonération TVA — livraison intracommunautaire (art. 39bis CTVA) · TVA ${client.vatNumber}',
      );
    }

    if (isBusiness && !vat.isEu) {
      return const VatComputation(
        rate: 0,
        reverseCharge: false,
        mention: 'Hors champ de la TVA belge — exportation / prestation hors UE',
      );
    }

    // Particulier (ou pro sans numéro valide) → TVA belge
    return VatComputation(
      rate: defaultRate,
      reverseCharge: false,
      mention: 'TVA ${defaultRate.toStringAsFixed(0)}%',
    );
  }

  /// Éligibilité Peppol : un client belge assujetti (numéro BCE/TVA valide)
  /// est considéré comme joignable via le réseau Peppol.
  static bool isPeppolEligible(Client? client) {
    if (client == null || !client.isBusiness) return false;
    final vat = validateVat(client.vatNumber ?? '');
    return vat.valid && vat.isBelgian;
  }

  /// Identifiant Peppol du client (schéma 0208 pour la Belgique).
  static String? peppolIdFor(Client? client) {
    if (client == null || !isPeppolEligible(client)) return null;
    final vat = validateVat(client.vatNumber ?? '');
    final digits = (vat.normalized ?? '').replaceFirst('BE', '');
    return '0208:$digits';
  }

  /// Génère une communication structurée belge (OGM/VCS, contrôle modulo 97).
  /// Format : +++123/4567/89012+++
  static String structuredCommunication(String invoiceRef) {
    // Dérive un nombre à 10 chiffres à partir de la référence facture.
    var hash = 0;
    for (final c in invoiceRef.codeUnits) {
      hash = (hash * 31 + c) % 10000000;
    }
    final base = hash.toString().padLeft(10, '0');
    final check = 97 - (int.parse(base) % 97);
    final cc = check.toString().padLeft(2, '0');
    final body = '$base$cc'; // 12 chiffres
    return '+++${body.substring(0, 3)}/${body.substring(3, 7)}/'
        '${body.substring(7)}+++';
  }
}
