import 'package:flutter_test/flutter_test.dart';
import 'package:gorex_concierge/models/company_profile.dart';

void main() {
  group('CompanyProfile — complétude des coordonnées officielles', () {
    test('les valeurs par défaut signalent des champs manquants', () {
      const c = CompanyProfile();
      expect(c.isConfigured, isFalse);
      expect(c.missingFields, contains('Numéro d\'entreprise (BCE)'));
      expect(c.missingFields, contains('Numéro de TVA'));
      expect(c.missingFields, contains('IBAN professionnel'));
      expect(c.missingFields, contains('Banque'));
      expect(c.missingFields, contains('Adresse'));
      expect(c.missingFields, contains('Identifiant Peppol'));
    });

    test('un profil complètement renseigné est considéré configuré', () {
      const c = CompanyProfile(
        companyNumber: '0403.201.350',
        vatNumber: 'BE0403201350',
        iban: 'BE68 5390 0754 7034',
        bankName: 'KBC Bank',
        addressLine: 'Avenue Louise 250',
        peppolId: '0208:0403201350',
      );
      expect(c.isConfigured, isTrue);
      expect(c.missingFields, isEmpty);
    });

    test('un IBAN avec des zéros reste détecté comme non renseigné', () {
      const c = CompanyProfile(
        companyNumber: '0403.201.350',
        vatNumber: 'BE0403201350',
        iban: 'BE00 0000 0000 0000',
        bankName: 'KBC Bank',
        addressLine: 'Avenue Louise 250',
        peppolId: '0208:0403201350',
      );
      expect(c.isConfigured, isFalse);
      expect(c.missingFields, contains('IBAN professionnel'));
    });
  });
}
