/// Coordonnées officielles de l'émetteur des factures : GOREX GROUP.
/// Centralisées ici pour automatiser la facturation et éviter les erreurs.
class CompanyProfile {
  final String legalName; // raison sociale
  final String brandName; // nom commercial
  final String companyNumber; // numéro d'entreprise BCE (ex. 0123.456.789)
  final String vatNumber; // numéro de TVA (ex. BE0123456789)
  final String iban; // compte bancaire professionnel
  final String bic; // code BIC/SWIFT
  final String bankName;
  final String addressLine; // rue + numéro
  final String postalCode;
  final String city;
  final String country; // libellé (ex. Belgique)
  final String countryCode; // ISO (ex. BE)
  final String email;
  final String phone;
  final String website;

  // Identifiant Peppol de l'émetteur (schéma:identifiant, ex. 0208:0123456789)
  final String peppolId;

  const CompanyProfile({
    this.legalName = 'Gorex Group SA',
    this.brandName = 'GOREX LUXURY CONCIERGE',
    this.companyNumber = '0000.000.000',
    this.vatNumber = 'BE0000000000',
    this.iban = 'BE00 0000 0000 0000',
    this.bic = 'GEBABEBB',
    this.bankName = 'Banque — à configurer',
    this.addressLine = 'Avenue Louise 000',
    this.postalCode = '1050',
    this.city = 'Bruxelles',
    this.country = 'Belgique',
    this.countryCode = 'BE',
    this.email = 'concierge@gorex.com',
    this.phone = '+32 2 555 01 00',
    this.website = 'www.gorex.be',
    this.peppolId = '0208:0000000000',
  });

  /// Adresse complète sur une ligne (émetteur).
  String get fullAddress =>
      '$addressLine, $postalCode $city, $country';

  /// Liste des champs encore laissés à leur valeur d'exemple (placeholder).
  /// Sert à alerter la direction tant que les coordonnées réelles de
  /// Gorex Group n'ont pas été saisies.
  List<String> get missingFields {
    final missing = <String>[];
    if (companyNumber.replaceAll(RegExp(r'[^0-9]'), '').replaceAll(
          RegExp(r'^0+$'),
          '',
        ).isEmpty ||
        companyNumber == '0000.000.000') {
      missing.add('Numéro d\'entreprise (BCE)');
    }
    final vatDigits = vatNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (vatDigits.isEmpty ||
        vatDigits.split('').toSet().length == 1 ||
        vatNumber == 'BE0000000000') {
      missing.add('Numéro de TVA');
    }
    if (iban.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').replaceAll('BE', '') ==
            '000000000000' ||
        iban == 'BE00 0000 0000 0000') {
      missing.add('IBAN professionnel');
    }
    if (bankName.toLowerCase().contains('configurer') ||
        bankName.trim().isEmpty) {
      missing.add('Banque');
    }
    if (addressLine.contains('000') || addressLine.trim().isEmpty) {
      missing.add('Adresse');
    }
    if (peppolId == '0208:0000000000') {
      missing.add('Identifiant Peppol');
    }
    return missing;
  }

  /// Vrai si toutes les coordonnées officielles sont renseignées.
  bool get isConfigured => missingFields.isEmpty;

  CompanyProfile copyWith({
    String? legalName,
    String? brandName,
    String? companyNumber,
    String? vatNumber,
    String? iban,
    String? bic,
    String? bankName,
    String? addressLine,
    String? postalCode,
    String? city,
    String? country,
    String? countryCode,
    String? email,
    String? phone,
    String? website,
    String? peppolId,
  }) => CompanyProfile(
    legalName: legalName ?? this.legalName,
    brandName: brandName ?? this.brandName,
    companyNumber: companyNumber ?? this.companyNumber,
    vatNumber: vatNumber ?? this.vatNumber,
    iban: iban ?? this.iban,
    bic: bic ?? this.bic,
    bankName: bankName ?? this.bankName,
    addressLine: addressLine ?? this.addressLine,
    postalCode: postalCode ?? this.postalCode,
    city: city ?? this.city,
    country: country ?? this.country,
    countryCode: countryCode ?? this.countryCode,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    website: website ?? this.website,
    peppolId: peppolId ?? this.peppolId,
  );

  Map<String, dynamic> toMap() => {
    'legalName': legalName,
    'brandName': brandName,
    'companyNumber': companyNumber,
    'vatNumber': vatNumber,
    'iban': iban,
    'bic': bic,
    'bankName': bankName,
    'addressLine': addressLine,
    'postalCode': postalCode,
    'city': city,
    'country': country,
    'countryCode': countryCode,
    'email': email,
    'phone': phone,
    'website': website,
    'peppolId': peppolId,
  };

  factory CompanyProfile.fromMap(Map<String, dynamic> m) => CompanyProfile(
    legalName: m['legalName'] as String? ?? 'Gorex Group SA',
    brandName: m['brandName'] as String? ?? 'GOREX LUXURY CONCIERGE',
    companyNumber: m['companyNumber'] as String? ?? '0000.000.000',
    vatNumber: m['vatNumber'] as String? ?? 'BE0000000000',
    iban: m['iban'] as String? ?? 'BE00 0000 0000 0000',
    bic: m['bic'] as String? ?? 'GEBABEBB',
    bankName: m['bankName'] as String? ?? 'Banque — à configurer',
    addressLine: m['addressLine'] as String? ?? 'Avenue Louise 000',
    postalCode: m['postalCode'] as String? ?? '1050',
    city: m['city'] as String? ?? 'Bruxelles',
    country: m['country'] as String? ?? 'Belgique',
    countryCode: m['countryCode'] as String? ?? 'BE',
    email: m['email'] as String? ?? 'concierge@gorex.com',
    phone: m['phone'] as String? ?? '+32 2 555 01 00',
    website: m['website'] as String? ?? 'www.gorex.be',
    peppolId: m['peppolId'] as String? ?? '0208:0000000000',
  );
}
