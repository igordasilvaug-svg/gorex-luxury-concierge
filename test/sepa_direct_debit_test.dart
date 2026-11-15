// Écran de domiciliation SEPA — test de rendu et de génération.
//
// Ce test vérifie deux choses distinctes :
//   1. que l'écran SE CONSTRUIT réellement (aucune exception de layout, aucun
//      widget manquant) — c'est ce qui n'avait jamais été vérifié ;
//   2. qu'un lot `pain.008` est produit avec les coordonnées RÉELLES de
//      Gorex Group (celles stockées dans Firestore, `company/gorex-group`),
//      et non avec les valeurs par défaut du modèle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gorex_concierge/core/billing/sepa_pain008_generator.dart';
import 'package:gorex_concierge/core/billing/sepa_validator.dart';
import 'package:gorex_concierge/core/theme/app_colors.dart';
import 'package:gorex_concierge/models/company_profile.dart';
import 'package:gorex_concierge/models/sepa_mandate.dart';
import 'package:gorex_concierge/screens/finance/sepa_direct_debit_screen.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:provider/provider.dart';

/// Coordonnées réellement présentes dans Firestore (`company/gorex-group`).
CompanyProfile _gorexCompany() => const CompanyProfile(
  legalName: 'Gorex Group',
  brandName: 'GOREX LUXURY CONCIERGE',
  companyNumber: '1009679037',
  vatNumber: 'BE1009679037',
  iban: 'BE97001980531549',
  bic: 'GEBABEBB',
  bankName: 'BNP Paribas Fortis Banque',
  addressLine: 'Koornstraat 5B',
  postalCode: '8800',
  city: 'Roeselare',
  country: 'Belgique',
  countryCode: 'BE',
  email: 'info@gorex-group.eu',
  phone: '+32 491117154',
  website: 'https://www.gorex-group.eu',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // L'écran formate des dates en `fr_BE` : sans cette initialisation,
  // `DateFormat('dd/MM/yyyy', 'fr_BE')` lève une LocaleDataException.
  // En production, `main()` appelle déjà la même fonction au démarrage.
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('Coordonnées réelles de Gorex Group', () {
    test('l\'IBAN professionnel est valide au sens ISO 13616', () {
      final v = SepaValidator.validateIban(_gorexCompany().iban);
      expect(v.valid, isTrue, reason: v.error);
      expect(v.country, 'BE');
    });

    test('le BIC est valide', () {
      expect(SepaValidator.validateBic(_gorexCompany().bic), isNull);
    });

    test('un numéro d\'entreprise composé de zéros est rejeté', () {
      // `0000.000.000` produisait auparavant BE71ZZZ0000000000 : un ICS
      // syntaxiquement valide mais rattaché à aucune entité réelle.
      expect(
        SepaValidator.isValidBelgianEnterpriseNumber('0000.000.000'),
        isFalse,
      );
      expect(
        SepaValidator.creditorIdFromEnterpriseNumber('0000.000.000'),
        isNull,
      );
      expect(
        SepaValidator.isValidBelgianEnterpriseNumber('1009679037'),
        isTrue,
      );
    });

    test('l\'ICS se dérive du numéro d\'entreprise et passe le modulo-97', () {
      final ics = SepaValidator.creditorIdFromEnterpriseNumber(
        _gorexCompany().companyNumber,
      );
      expect(ics, 'BE32ZZZ1009679037');
      expect(SepaValidator.validateCreditorId(ics), isNull);
    });
  });

  group('Génération pain.008 avec les coordonnées réelles', () {
    final now = DateTime(2026, 11, 15);
    final due = DateTime(2026, 12, 15);

    SepaMandate mandate({bool active = true, DateTime? lastUsed}) => SepaMandate(
      id: 'm1',
      clientId: 'c1',
      clientName: 'Van den Berghe & Fils',
      mandateReference: 'GRX-ABO-2026-0001',
      iban: 'BE68539007547034',
      bic: 'GEBABEBB',
      accountHolder: 'Van den Berghe & Fils',
      status: active ? SepaMandateStatus.active : SepaMandateStatus.pending,
      signatureDate: DateTime(2026, 1, 12),
      createdAt: now,
      lastUsedAt: lastUsed,
    );

    SepaDebit debit({
      double amount = 950,
      DateTime? preNotifiedAt,
      SepaSequenceType seq = SepaSequenceType.recurring,
    }) => SepaDebit(
      id: 'd1',
      mandateId: 'm1',
      mandateReference: 'GRX-ABO-2026-0001',
      clientId: 'c1',
      clientName: 'Van den Berghe & Fils',
      iban: 'BE68539007547034',
      amount: amount,
      endToEndId: 'GRX-1',
      remittanceInformation: 'Abonnement mensuel',
      requestedCollectionDate: due,
      sequenceType: seq,
      status: SepaDebitStatus.preNotified,
      preNotifiedAt: preNotifiedAt,
      createdAt: now,
    );

    test('un ordre conforme produit un fichier exploitable', () {
      final r = SepaPain008Generator.generate(
        debits: [debit(preNotifiedAt: DateTime(2026, 11, 1))],
        mandates: {'m1': mandate(lastUsed: DateTime(2026, 10, 1))},
        company: _gorexCompany(),
        createdAt: now,
      );
      expect(r.included, 1);
      expect(r.total, 950);
      expect(r.excluded, isEmpty);
      expect(r.xml, contains('BE97001980531549'));
      expect(r.xml, contains('GEBABEBB'));
      expect(r.xml, contains('BE32ZZZ1009679037'));
      // Le nom du client contient « & » : il doit être échappé, sans quoi le
      // fichier est rejeté par la banque.
      expect(r.xml, contains('Van den Berghe &amp; Fils'));
      expect(r.xml, isNot(contains('& Fils')));
    });

    test('la pré-notification tardive exclut l\'ordre avec un motif', () {
      final r = SepaPain008Generator.generate(
        debits: [debit(preNotifiedAt: DateTime(2026, 12, 10))],
        mandates: {'m1': mandate()},
        company: _gorexCompany(),
        createdAt: now,
      );
      expect(r.included, 0);
      expect(r.xml, isEmpty);
      expect(r.excluded.single, contains('pré-notification'));
    });

    test('sans coordonnées valides, le générateur refuse d\'émettre', () {
      final r = SepaPain008Generator.generate(
        debits: [debit(preNotifiedAt: DateTime(2026, 11, 1))],
        mandates: {'m1': mandate()},
        company: const CompanyProfile(), // valeurs par défaut invalides
        createdAt: now,
      );
      expect(r.xml, isEmpty);
      expect(r.included, 0);
      expect(r.excluded.single, contains('ICS'));
      expect(r.excluded.single, contains('contrôle BCE'));
    });
  });

  group('Rendu de l\'écran de domiciliation', () {
    testWidgets('l\'écran se construit sans exception', (tester) async {
      final state = AppState();
      state.company = _gorexCompany();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              backgroundColor: AppColors.black,
              body: SingleChildScrollView(child: SepaDirectDebitScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Le titre et l'avertissement d'absence de transmission bancaire doivent
      // être visibles : c'est une information contractuelle pour l'utilisateur.
      expect(find.text('Domiciliation SEPA'), findsWidgets);
      expect(
        find.textContaining('Aucune transmission bancaire automatique'),
        findsOneWidget,
      );
    });

    testWidgets('sur un écran de téléphone, aucun débordement', (tester) async {
      // Régression : à 430 px, le titre « Mandats de domiciliation » et le
      // bouton « Enregistrer un mandat » étaient sur la même ligne ; le
      // bouton écrasait le titre jusqu'à le couper au milieu d'un mot
      // (« DOMICILIATI / ON »). L'en-tête doit s'empiler sous 520 px.
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState();
      state.company = _gorexCompany();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(
            home: Scaffold(
              backgroundColor: AppColors.black,
              body: SingleChildScrollView(child: SepaDirectDebitScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      // Un débordement de layout se manifeste par une exception Flutter.
      expect(tester.takeException(), isNull);
    });
  });
}
