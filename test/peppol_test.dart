import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/core/billing/peppol_service.dart';
import 'package:gorex_concierge/core/billing/peppol_ubl_generator.dart';
import 'package:gorex_concierge/models/client.dart';
import 'package:gorex_concierge/models/company_profile.dart';
import 'package:gorex_concierge/models/enums.dart';
import 'package:gorex_concierge/models/finance.dart';
import 'package:gorex_concierge/models/peppol_config.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/settings/peppol_settings_screen.dart';

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

Client _client({bool business = true, String? vat}) => Client(
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
  peppolEnabled: true,
);

FinanceDocument _invoice({double tax = 0}) => FinanceDocument(
  id: 'f1',
  reference: 'GRX-INV-2025-0001',
  type: FinanceDocType.invoice,
  clientId: 'x',
  clientName: 'Test Client',
  date: DateTime(2025, 3, 10),
  dueDate: DateTime(2025, 4, 9),
  lines: const [FinanceLine(description: 'Prestation VIP', unitPrice: 1000)],
  taxPercent: tax,
  status: InvoiceStatus.sent,
  clientVatNumber: 'BE0403203462',
  vatMention: 'Autoliquidation — TVA due par le preneur',
  structuredCommunication: '+++123/4567/89012+++',
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('PeppolUblGenerator — UBL 2.1 / BIS Billing 3.0', () {
    test('produces a well-formed invoice with required Peppol elements', () {
      final res = PeppolUblGenerator.generate(
        f: _invoice(),
        client: _client(vat: 'BE0403203462'),
        company: const CompanyProfile(vatNumber: 'BE0123456749'),
      );
      final xml = res.xml;
      expect(res.filename, 'GRX-INV-2025-0001.xml');
      expect(xml.startsWith('<?xml'), isTrue);
      expect(xml, contains('urn:fdc:peppol.eu:2017:poacc:billing:3.0'));
      expect(xml, contains('<cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0'));
      expect(xml, contains('<cbc:ID>GRX-INV-2025-0001</cbc:ID>'));
      expect(xml, contains('<cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>'));
      expect(xml, contains('<cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>'));
      expect(xml, contains('schemeID="0208"'));
      expect(xml, contains('<cbc:EndpointID schemeID="0208">0208:0403203462</cbc:EndpointID>'));
      expect(xml, contains('<cac:PayeeFinancialAccount>'));
      expect(xml, contains('+++123/4567/89012+++'));
    });

    test('uses AE category for a Belgian business (autoliquidation)', () {
      final f = _invoice();
      final c = _client(vat: 'BE0403203462');
      expect(PeppolUblGenerator.vatCategoryCode(f, c), 'AE');
    });

    test('uses E for EU business and G for non-EU', () {
      final f = _invoice();
      expect(
        PeppolUblGenerator.vatCategoryCode(f, _client(vat: 'IT12345678901')),
        'E',
      );
      expect(
        PeppolUblGenerator.vatCategoryCode(f, _client(vat: 'CHE123456789')),
        'G',
      );
    });

    test('uses S for an individual', () {
      final f = _invoice(tax: 21);
      expect(
        PeppolUblGenerator.vatCategoryCode(f, _client(business: false)),
        'S',
      );
    });

    test('escapes reserved XML characters', () {
      final f = FinanceDocument(
        id: 'f2',
        reference: 'REF<&>"',
        type: FinanceDocType.invoice,
        clientId: 'x',
        clientName: 'A & B',
        date: DateTime(2025),
        lines: const [FinanceLine(description: 'A < B & C', unitPrice: 10)],
      );
      final xml = PeppolUblGenerator.generate(
        f: f,
        client: _client(vat: 'BE0403203462'),
        company: const CompanyProfile(),
      ).xml;
      expect(xml, contains('A &amp; B'));
      expect(xml, contains('A &lt; B &amp; C'));
      expect(xml, isNot(contains('A < B')));
    });

    test('maps country names to ISO codes', () {
      final xml = PeppolUblGenerator.generate(
        f: _invoice(),
        client: _client(vat: 'BE0403203462'),
        company: const CompanyProfile(country: 'Belgique'),
      ).xml;
      expect(xml, contains('<cbc:IdentificationCode>BE</cbc:IdentificationCode>'));
    });
  });

  group('PeppolConfig', () {
    test('isConfigured requires enabled + url + key + id', () {
      const base = PeppolConfig(
        apiBaseUrl: 'https://api.example.com',
        apiKey: 'k',
        senderPeppolId: '0208:1',
      );
      expect(base.isConfigured, isFalse); // not enabled
      expect(base.copyWith(enabled: true).isConfigured, isTrue);
      expect(base.copyWith(enabled: true, apiKey: '').isConfigured, isFalse);
    });

    test('toMap / fromMap round-trip', () {
      const c = PeppolConfig(
        enabled: true,
        apiBaseUrl: 'https://x',
        apiKey: 'secret',
        senderPeppolId: '0208:123',
        senderLegalEntityId: '7',
        timeoutSeconds: 12,
      );
      final back = PeppolConfig.fromMap(c.toMap());
      expect(back.enabled, isTrue);
      expect(back.apiKey, 'secret');
      expect(back.senderLegalEntityId, '7');
      expect(back.timeoutSeconds, 12);
    });
  });

  group('PeppolService', () {
    test('buildStorecovePayload base64-encodes the UBL', () {
      const cfg = PeppolConfig(senderLegalEntityId: '5');
      final payload = PeppolService.buildStorecovePayload(
        config: cfg,
        ublXml: '<Invoice/>',
        filename: 'a.xml',
        isInvoice: true,
      );
      expect(payload['legal_entity_id'], 5);
      final doc = payload['document'] as Map;
      final raw = doc['raw_document'] as Map;
      expect(raw['raw_document_type'], 'xml');
      expect(raw['raw_document_data'], isNotEmpty);
    });

    test('unconfigured Access Point → simulated success', () async {
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
          lines: const [FinanceLine(description: 'X', unitPrice: 100)],
        ),
      );
      final res = await s.sendViaPeppol(doc.id);
      expect(res.success, isTrue);
      expect(res.simulated, isTrue);
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.sent);
    });

    test('configured but unreachable Access Point → failure + failed status',
        () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await s.updatePeppol(
        const PeppolConfig(
          enabled: true,
          apiBaseUrl: 'http://127.0.0.1:1',
          apiKey: 'x',
          senderPeppolId: '0208:0403203462',
          timeoutSeconds: 3,
        ),
      );
      final client = s.clientById('c_001')!;
      final doc = await s.createFinanceDoc(
        FinanceDocument(
          id: '',
          reference: '',
          type: FinanceDocType.invoice,
          clientId: client.id,
          clientName: client.fullName,
          date: DateTime.now(),
          lines: const [FinanceLine(description: 'X', unitPrice: 100)],
        ),
      );
      final res = await s.sendViaPeppol(doc.id);
      expect(res.success, isFalse);
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.failed);
    });

    test('generateUbl returns the document UBL from state', () async {
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
          lines: const [FinanceLine(description: 'X', unitPrice: 100)],
        ),
      );
      final ubl = s.generateUbl(doc.id);
      expect(ubl.xml, contains(doc.reference));
      expect(ubl.filename, '${doc.reference}.xml');
    });

    test('updatePeppol persists the configuration', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await s.updatePeppol(
        const PeppolConfig(enabled: true, apiKey: 'abc'),
      );
      expect(s.peppol.enabled, isTrue);
      expect(s.peppol.apiKey, 'abc');
    });
  });

  group('PeppolService — mapping de statut (suivi asynchrone)', () {
    test('delivered events map to delivered', () {
      expect(
        PeppolService.parseStatusFromBody('{"status":"DELIVERED"}'),
        PeppolStatus.delivered,
      );
      expect(
        PeppolService.parseStatusFromBody('{"status":"ACCEPTED"}'),
        PeppolStatus.delivered,
      );
      expect(
        PeppolService.parseStatusFromBody(
          '{"document_submission_status":"IN_PROGRESS","events":[{"event_type":"DELIVERED"}]}',
        ),
        PeppolStatus.delivered,
      );
    });

    test('failure events map to failed', () {
      expect(
        PeppolService.parseStatusFromBody('{"status":"FAILED"}'),
        PeppolStatus.failed,
      );
      expect(
        PeppolService.parseStatusFromBody('{"status":"REJECTED"}'),
        PeppolStatus.failed,
      );
    });

    test('sent / processing map to sent', () {
      expect(
        PeppolService.parseStatusFromBody('{"status":"SENT"}'),
        PeppolStatus.sent,
      );
      expect(
        PeppolService.parseStatusFromBody('{"status":"PROCESSING"}'),
        PeppolStatus.sent,
      );
    });

    test('empty or invalid body returns null', () {
      expect(PeppolService.parseStatusFromBody(''), isNull);
      expect(PeppolService.parseStatusFromBody('not json'), isNull);
    });
  });

  group('AppState — suivi asynchrone Peppol', () {
    test('refreshPeppolStatus simulates progression sent → delivered', () async {
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
          lines: const [FinanceLine(description: 'X', unitPrice: 100)],
        ),
      );
      await s.sendViaPeppol(doc.id); // simulated → sent
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.sent);
      final st = await s.refreshPeppolStatus(doc.id);
      expect(st, PeppolStatus.delivered);
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.delivered);
      expect(s.financeById(doc.id)!.peppolLastUpdate, isNotNull);
    });

    test('ingestPeppolWebhook updates status by provider reference', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await s.updatePeppol(
        const PeppolConfig(
          enabled: true,
          apiBaseUrl: 'http://127.0.0.1:1',
          apiKey: 'x',
          senderPeppolId: '0208:0403203462',
          timeoutSeconds: 2,
        ),
      );
      final client = s.clientById('c_001')!;
      final doc = await s.createFinanceDoc(
        FinanceDocument(
          id: '',
          reference: '',
          type: FinanceDocType.invoice,
          clientId: client.id,
          clientName: client.fullName,
          date: DateTime.now(),
          lines: const [FinanceLine(description: 'X', unitPrice: 100)],
        ),
      );
      await s.sendViaPeppol(doc.id); // unreachable → failed, ref null
      // Inject a manual provider reference then apply a webhook
      await s.updateFinanceDoc(
        s.financeById(doc.id)!.copyWith(peppolProviderReference: 'SUB-123'),
      );
      final ok = await s.ingestPeppolWebhook(
        {'document_submission_guid': 'SUB-123', 'status': 'DELIVERED'},
      );
      expect(ok, isTrue);
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.delivered);
    });

    test('ingestPeppolWebhook ignores unknown references', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final ok = await s.ingestPeppolWebhook(
        {'document_submission_guid': 'NOPE', 'status': 'DELIVERED'},
      );
      expect(ok, isFalse);
    });

    test('refreshAllPeppolStatuses reports updated count', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final client = s.clientById('c_001')!;
      for (var k = 0; k < 2; k++) {
        final doc = await s.createFinanceDoc(
          FinanceDocument(
            id: '',
            reference: '',
            type: FinanceDocType.invoice,
            clientId: client.id,
            clientName: client.fullName,
            date: DateTime.now(),
            lines: const [FinanceLine(description: 'X', unitPrice: 100)],
          ),
        );
        await s.sendViaPeppol(doc.id);
      }
      final updated = await s.refreshAllPeppolStatuses();
      expect(updated, greaterThanOrEqualTo(2));
    });

    test('peppol config persists webhook + autoRefresh', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await s.updatePeppol(
        const PeppolConfig(
          enabled: true,
          webhookUrl: 'https://x/hook',
          autoRefresh: true,
        ),
      );
      expect(s.peppol.webhookUrl, 'https://x/hook');
      expect(s.peppol.autoRefresh, isTrue);
    });
  });

  group('Écran Access Point Peppol', () {
    testWidgets('renders for CEO', (tester) async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await tester.pumpWidget(_host(s, const PeppolSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Access Point Peppol'), findsWidgets);
    });
  });
}
