// Capture visuelle de l'écran de domiciliation SEPA.
//
// Objectif : produire une PREUVE VISUELLE du rendu, sans se connecter à la
// production et sans toucher aux comptes réels. On alimente un AppState en
// mémoire avec les vraies coordonnées de Gorex Group et deux mandats, puis on
// rend l'écran à une taille de téléphone et on écrit un PNG.
//
// Ce test échoue si l'écran lève une exception de layout ou de peinture.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gorex_concierge/core/theme/app_colors.dart';
import 'package:gorex_concierge/models/company_profile.dart';
import 'package:gorex_concierge/models/sepa_mandate.dart';
import 'package:gorex_concierge/screens/finance/sepa_direct_debit_screen.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

const _company = CompanyProfile(
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

  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  testWidgets('capture PNG de l\'écran Domiciliation SEPA', (tester) async {
    tester.view.physicalSize = const Size(1200, 3400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 11, 15);
    final state = AppState();
    state.company = _company;
    state.sepaMandates = [
      SepaMandate(
        id: 'm1',
        clientId: 'c1',
        clientName: 'Van den Berghe & Fils',
        mandateReference: 'GRX-ABO-2026-0001',
        iban: 'BE68539007547034',
        bic: 'GEBABEBB',
        accountHolder: 'Van den Berghe & Fils',
        status: SepaMandateStatus.active,
        signatureDate: DateTime(2026, 1, 12),
        createdAt: now,
        lastUsedAt: DateTime(2026, 10, 1),
      ),
      SepaMandate(
        id: 'm2',
        clientId: 'c2',
        clientName: 'Dupont',
        mandateReference: 'GRX-ABO-2026-0002',
        iban: 'BE71096123456769',
        accountHolder: 'Dupont',
        status: SepaMandateStatus.pending,
        signatureDate: DateTime(2026, 3, 4),
        createdAt: now,
      ),
    ];
    state.sepaDebits = [
      SepaDebit(
        id: 'd1',
        mandateId: 'm1',
        mandateReference: 'GRX-ABO-2026-0001',
        clientId: 'c1',
        clientName: 'Van den Berghe & Fils',
        iban: 'BE68539007547034',
        amount: 950,
        endToEndId: 'GRX-1',
        remittanceInformation: 'Abonnement Prestige — décembre 2026',
        requestedCollectionDate: DateTime(2026, 12, 15),
        sequenceType: SepaSequenceType.recurring,
        status: SepaDebitStatus.preNotified,
        preNotifiedAt: DateTime(2026, 11, 1),
        createdAt: now,
      ),
    ];

    final key = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: AppColors.black,
            body: RepaintBoundary(
              key: key,
              child: const SepaDirectDebitScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Rendu réel → PNG.
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);

    final out = File('/home/user/shots/sepa_rendu.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('CAPTURE ÉCRITE : ${out.path} (${bytes.lengthInBytes} octets)');

    // Vérifications de contenu : ce que l'écran doit dire à l'utilisateur.
    expect(find.textContaining('Domiciliation SEPA'), findsWidgets);
    expect(
      find.textContaining('Aucune transmission bancaire automatique'),
      findsOneWidget,
    );
    expect(find.text('Van den Berghe & Fils'), findsWidgets);
    // L'IBAN doit être masqué à l'écran, jamais affiché en clair.
    expect(find.textContaining('BE68 5390 0754 7034'), findsNothing);
  });
}
