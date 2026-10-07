import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/core/billing/vat_service.dart';
import 'package:gorex_concierge/models/client.dart';
import 'package:gorex_concierge/models/company_profile.dart';
import 'package:gorex_concierge/models/enums.dart';
import 'package:gorex_concierge/models/finance.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/settings/company_settings_screen.dart';
import 'package:gorex_concierge/screens/clients/client_form_screen.dart';

Future<AppState> _ready() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await state.init();
  return state;
}

Widget _host(AppState state, Widget child) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: child),
    );

Client _client({
  bool business = true,
  String? vat,
  String? companyNumber,
  bool peppol = false,
}) => Client(
  id: 'x',
  code: 'GRX-VIP-9999',
  fullName: 'Test Client',
  category: ClientCategory.corporate,
  email: 'a@b.com',
  phone: '+32',
  country: 'Belgique',
  city: 'Bruxelles',
  subscriptionTierId: 'tier_executive',
  createdAt: DateTime(2024),
  isBusiness: business,
  vatNumber: vat,
  companyNumber: companyNumber,
  peppolEnabled: peppol,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('VatService — validation TVA / BCE', () {
    test('valid Belgian VAT passes modulo-97 check', () {
      final r = VatService.validateVat('BE0403203462');
      expect(r.valid, isTrue);
      expect(r.isBelgian, isTrue);
      expect(r.isEu, isTrue);
      expect(r.normalized, 'BE0403203462');
    });

    test('Belgian VAT with wrong check digits is rejected', () {
      final r = VatService.validateVat('BE0403203499');
      expect(r.valid, isFalse);
      expect(r.isBelgian, isTrue);
      expect(r.message, contains('modulo 97'));
    });

    test('normalisation removes spaces, dots and dashes', () {
      expect(VatService.normalize('be 0403.203.462'), 'BE0403203462');
      expect(VatService.normalize('BE-0403-203-462'), 'BE0403203462');
    });

    test('EU VAT recognised with expected length', () {
      expect(VatService.validateVat('IT12345678901').isEu, isTrue);
      expect(VatService.validateVat('IT12345678901').valid, isTrue);
      expect(VatService.validateVat('DE123456789').valid, isTrue);
      // wrong length for Germany (expects 11)
      expect(VatService.validateVat('DE123').valid, isFalse);
    });

    test('non-EU identifier accepted if long enough', () {
      final r = VatService.validateVat('CHE123456789');
      expect(r.isEu, isFalse);
      expect(r.isBelgian, isFalse);
      expect(r.valid, isTrue);
    });

    test('empty VAT is invalid', () {
      expect(VatService.validateVat('').valid, isFalse);
      expect(VatService.validateVat('   ').valid, isFalse);
    });

    test('Belgian company number (BCE) validation', () {
      expect(VatService.validateBelgianCompanyNumber('0403203462').valid, isTrue);
      expect(
        VatService.validateBelgianCompanyNumber('0403.203.462').valid,
        isTrue,
      );
      expect(
        VatService.validateBelgianCompanyNumber('12345').valid,
        isFalse,
      );
      expect(
        VatService.validateBelgianCompanyNumber('0403203499').valid,
        isFalse,
      );
    });

    test('formatVat formats Belgian numbers', () {
      expect(VatService.formatVat('BE0403203462'), 'BE 0403.203.462');
      expect(VatService.formatVat('IT12345678901'), 'IT12345678901');
    });
  });

  group('VatService — régimes de TVA', () {
    test('Belgian business → autoliquidation (reverse charge)', () {
      final v = VatService.computeVat(_client(vat: 'BE0403203462'));
      expect(v.rate, 0);
      expect(v.reverseCharge, isTrue);
      expect(v.mention, contains('Autoliquidation'));
    });

    test('EU business (non-BE) → exonération intracommunautaire', () {
      final v = VatService.computeVat(
        _client(vat: 'IT12345678901'),
      );
      expect(v.rate, 0);
      expect(v.intraEuB2b, isTrue);
      expect(v.reverseCharge, isFalse);
      expect(v.mention, contains('intracommunautaire'));
    });

    test('non-EU business → hors champ', () {
      final v = VatService.computeVat(
        _client(vat: 'CHE123456789'),
      );
      expect(v.rate, 0);
      expect(v.mention, contains('Hors champ'));
    });

    test('individual (private) → Belgian VAT at default rate', () {
      final v = VatService.computeVat(_client(business: false));
      expect(v.rate, 21);
      expect(v.reverseCharge, isFalse);
      expect(v.mention, contains('21%'));
    });

    test('null client → default rate', () {
      expect(VatService.computeVat(null).rate, 21);
    });
  });

  group('VatService — Peppol', () {
    test('Belgian business with valid VAT is Peppol eligible', () {
      final c = _client(vat: 'BE0403203462');
      expect(VatService.isPeppolEligible(c), isTrue);
      expect(VatService.peppolIdFor(c), '0208:0403203462');
    });

    test('individual and non-BE are not eligible', () {
      expect(VatService.isPeppolEligible(_client(business: false)), isFalse);
      expect(
        VatService.isPeppolEligible(_client(vat: 'IT12345678901')),
        isFalse,
      );
      expect(VatService.isPeppolEligible(null), isFalse);
    });
  });

  group('VatService — communication structurée (OGM/VCS)', () {
    test('produces a well-formed +++...+++ with valid mod-97 check', () {
      final ogm = VatService.structuredCommunication('GRX-INV-2025-0001');
      expect(ogm.startsWith('+++'), isTrue);
      expect(ogm.endsWith('+++'), isTrue);
      final body = ogm.replaceAll('+', '').replaceAll('/', '');
      expect(body.length, 12);
      final base = int.parse(body.substring(0, 10));
      final check = int.parse(body.substring(10));
      expect(97 - (base % 97), check);
    });

    test('is deterministic for the same reference', () {
      expect(
        VatService.structuredCommunication('REF-1'),
        VatService.structuredCommunication('REF-1'),
      );
    });
  });

  group('AppState — facturation automatique', () {
    test('createFinanceDoc enriches an invoice for a Belgian business', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final client = s.clientById('c_001')!; // business, BE VAT, peppol enabled

      final doc = await s.createFinanceDoc(
        FinanceDocument(
          id: '',
          reference: '',
          type: FinanceDocType.invoice,
          clientId: client.id,
          clientName: client.fullName,
          date: DateTime.now(),
          lines: [
            const FinanceLine(description: 'Prestation', unitPrice: 1000),
          ],
        ),
      );

      expect(doc.reference.startsWith('GRX-INV'), isTrue);
      expect(doc.taxPercent, 0); // autoliquidation
      expect(doc.peppolStatus, PeppolStatus.ready);
      expect(doc.clientVatNumber, 'BE0403203462');
      expect(doc.vatMention, contains('Autoliquidation'));
      expect(doc.structuredCommunication, startsWith('+++'));
    });

    test('createFinanceDoc keeps 21% for an individual', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final c = await s.createClient(_client(business: false));
      final doc = await s.createFinanceDoc(
        FinanceDocument(
          id: '',
          reference: '',
          type: FinanceDocType.invoice,
          clientId: c.id,
          clientName: c.fullName,
          date: DateTime.now(),
          lines: [const FinanceLine(description: 'X', unitPrice: 100)],
        ),
      );
      expect(doc.taxPercent, 21);
      expect(doc.peppolStatus, PeppolStatus.notApplicable);
    });

    test('createClient persists billing fields', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final c = await s.createClient(
        _client(vat: 'BE0403203462', companyNumber: '0403203462', peppol: true),
      );
      final reloaded = s.clientById(c.id)!;
      expect(reloaded.isBusiness, isTrue);
      expect(reloaded.vatNumber, 'BE0403203462');
      expect(reloaded.companyNumber, '0403203462');
      expect(reloaded.peppolEnabled, isTrue);
    });

    test('sendViaPeppol then markPeppolDelivered transitions status', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final client = s.clientById('c_001')!;
      final doc = await s.createFinanceDoc(
        FinanceDocument(
          id: '',
          reference: '',
          type: FinanceDocType.invoice,
          clientId: client.id,
          clientName: client.fullName,
          date: DateTime.now(),
          lines: [const FinanceLine(description: 'X', unitPrice: 100)],
        ),
      );
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.ready);
      await s.sendViaPeppol(doc.id);
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.sent);
      await s.markPeppolDelivered(doc.id);
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.delivered);
    });

    test('updateCompany persists official details', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await s.updateCompany(
        s.company.copyWith(
          legalName: 'Gorex Group SA',
          companyNumber: '0123456749',
          vatNumber: 'BE0123456749',
          iban: 'BE68 5390 0754 7034',
          peppolId: '0208:0123456749',
        ),
      );
      expect(s.company.companyNumber, '0123456749');
      expect(s.company.vatNumber, 'BE0123456749');
      expect(s.company.iban, 'BE68 5390 0754 7034');
    });
  });

  group('CompanyProfile', () {
    test('fullAddress composes the emitter address', () {
      const c = CompanyProfile(
        addressLine: 'Avenue Louise 100',
        postalCode: '1050',
        city: 'Bruxelles',
        country: 'Belgique',
      );
      expect(c.fullAddress, 'Avenue Louise 100, 1050 Bruxelles, Belgique');
    });

    test('toMap / fromMap round-trip', () {
      const c = CompanyProfile(vatNumber: 'BE0123456749');
      final back = CompanyProfile.fromMap(c.toMap());
      expect(back.vatNumber, 'BE0123456749');
      expect(back.brandName, 'GOREX LUXURY CONCIERGE');
    });
  });

  group('Écrans de facturation', () {
    testWidgets('CompanySettingsScreen renders for CEO', (tester) async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await tester.pumpWidget(_host(s, const CompanySettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Paramètres société'), findsWidgets);
      expect(find.text('NUMÉRO D\'ENTREPRISE (BCE)'), findsOneWidget);
    });

    testWidgets('ClientFormScreen renders creation form', (tester) async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await tester.pumpWidget(_host(s, const ClientFormScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Nouveau client VIP'), findsWidgets);
    });
  });
}
