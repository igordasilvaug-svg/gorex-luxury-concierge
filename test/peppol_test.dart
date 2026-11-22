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

    test('toMap ne divulgue JAMAIS la clé d\'API (secret)', () {
      const c = PeppolConfig(
        enabled: true,
        apiBaseUrl: 'https://x',
        apiKey: 'secret',
        senderPeppolId: '0208:123',
        senderLegalEntityId: '7',
        timeoutSeconds: 12,
      );
      final pub = c.toMap();

      // `company/gorex-group` est lisible par TOUT utilisateur connecté
      // (clients VIP compris) : la clé ne doit pas y figurer.
      expect(pub.containsKey('apiKey'), isFalse);
      expect(pub.values, isNot(contains('secret')));

      // Elle vit dans la carte secrète, écrite ailleurs.
      expect(c.toSecretMap(), {'apiKey': 'secret'});

      // La partie publique reste complète et relisible.
      final back = PeppolConfig.fromMap(pub);
      expect(back.enabled, isTrue);
      expect(back.senderLegalEntityId, '7');
      expect(back.timeoutSeconds, 12);
      expect(back.apiKey, isEmpty); // absente de la carte publique
    });

    test('mergeSecretMap hydrate la clé sans jamais l\'effacer', () {
      const base = PeppolConfig(apiKey: 'existante');
      // Une lecture vide (autre rôle, réseau) ne doit pas effacer la clé.
      expect(base.mergeSecretMap(null).apiKey, 'existante');
      expect(base.mergeSecretMap({}).apiKey, 'existante');
      expect(base.mergeSecretMap({'apiKey': ''}).apiKey, 'existante');
      // Une lecture fructueuse la remplace.
      expect(base.mergeSecretMap({'apiKey': 'nouvelle'}).apiKey, 'nouvelle');
    });

    test('legalEntityId refuse une valeur non numérique', () {
      // C'est un NOMBRE chez l'Access Point, pas un nom de personne.
      expect(const PeppolConfig(senderLegalEntityId: '7').legalEntityId, 7);
      expect(const PeppolConfig(senderLegalEntityId: ' 42 ').legalEntityId, 42);
      expect(
        const PeppolConfig(senderLegalEntityId: 'Da Silva Augustin Igor')
            .legalEntityId,
        isNull,
      );
      expect(const PeppolConfig(senderLegalEntityId: '').legalEntityId, isNull);
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

    test('Access Point non configuré → AUCUN envoi, statut inchangé', () async {
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
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.ready);

      final res = await s.sendViaPeppol(doc.id);

      // Rien n'a été transmis : ce n'est pas un succès.
      expect(res.success, isFalse);
      expect(res.simulated, isTrue);
      // Et surtout : la pièce comptable ne doit pas mentir.
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.ready);
      expect(s.financeById(doc.id)!.status, isNot(InvoiceStatus.sent));
      expect(s.financeById(doc.id)!.peppolProviderReference, isNull);
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
          // Identifiant numérique requis : sans lui l'envoi est refusé AVANT
          // la requête réseau, et le test ne mesurerait plus la panne réseau.
          senderLegalEntityId: '1',
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
    test('refreshPeppolStatus n\'invente AUCUNE distribution', () async {
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
      await s.sendViaPeppol(doc.id); // non configuré → aucun envoi
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.ready);

      final st = await s.refreshPeppolStatus(doc.id);

      // Sans référence fournisseur, aucune requête n'a eu lieu : le statut
      // ne peut pas progresser vers « Distribué ».
      expect(st, PeppolStatus.ready);
      expect(s.financeById(doc.id)!.peppolStatus, PeppolStatus.ready);
      expect(s.financeById(doc.id)!.peppolProviderReference, isNull);
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
          senderLegalEntityId: '1',
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

    test('refreshAllPeppolStatuses ne fabrique aucun statut', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final client = s.clientById('c_001')!;
      final ids = <String>[];
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
        ids.add(doc.id);
        await s.sendViaPeppol(doc.id); // aucun envoi (non configuré)
      }
      // Aucune facture n'est réellement partie : le rafraîchissement ne peut
      // donc rien avoir à mettre à jour. Il renvoyait auparavant 2, en
      // faisant passer chaque facture à « Distribué » sans aucun envoi.
      final updated = await s.refreshAllPeppolStatuses();
      expect(updated, 0);
      for (final id in ids) {
        expect(s.financeById(id)!.peppolStatus, PeppolStatus.ready);
      }
    });

    test('updatePeppol refuse d\'activer sans entité légale numérique', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');

      // Configuration complète MAIS entité légale = un nom de personne :
      // c'est exactement ce qui était en base de production.
      await expectLater(
        () => s.updatePeppol(
          const PeppolConfig(
            enabled: true,
            apiKey: 'k',
            senderPeppolId: '0208:1009679037',
            senderLegalEntityId: 'Da Silva Augustin Igor',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      // Rien n'a été enregistré : l'état reste sur la configuration d'origine.
      expect(s.peppol.enabled, isFalse);

      // Une configuration VALIDE passe.
      await s.updatePeppol(
        const PeppolConfig(
          enabled: true,
          apiKey: 'k',
          senderPeppolId: '0208:1009679037',
          senderLegalEntityId: '1',
        ),
      );
      expect(s.peppol.enabled, isTrue);
      expect(s.peppol.legalEntityId, 1);
    });

    test('une configuration incomplète reste enregistrable (désactivée)', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      // Transmission non activée : on peut sauvegarder un brouillon de config
      // sans clé ni identifiant. Le garde-fou ne doit pas bloquer ce cas.
      await s.updatePeppol(
        const PeppolConfig(enabled: false, apiBaseUrl: 'https://x'),
      );
      expect(s.peppol.enabled, isFalse);
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

    testWidgets('annonce que la réception par webhook n\'est pas active', (
      tester,
    ) async {
      // L'application sait traiter une notification, mais aucun serveur ne
      // l'écoute (le site est statique : les POST répondent 405). Demander au
      // client de déclarer une URL reviendrait à lui faire croire à une
      // réception qui n'existe pas.
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await tester.pumpWidget(_host(s, const PeppolSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      final texte = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');

      expect(texte, contains('NON active'));
      expect(texte, contains('aucun serveur'));
      expect(texte, contains('rafraîchissement manuel'));
      // La consigne trompeuse a disparu.
      expect(texte, isNot(contains('Déclarez cette URL')));
    });

    testWidgets('n\'annonce plus d\'envoi « simulé »', (tester) async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await tester.pumpWidget(_host(s, const PeppolSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      final texte = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');

      // Un envoi qui n'envoie rien n'est pas une « simulation ».
      expect(texte, isNot(contains('envoi simulé')));
      expect(texte, isNot(contains('mode démonstration')));
      expect(texte, contains('Aucune transmission'));
    });
  });
}
