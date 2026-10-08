import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gorex_concierge/screens/legal/legal_hub_screen.dart';
import 'package:gorex_concierge/screens/legal/legal_notice_screen.dart';
import 'package:gorex_concierge/screens/legal/terms_of_sale_screen.dart';
import 'package:gorex_concierge/screens/legal/cookie_policy_screen.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:provider/provider.dart';

/// Vérifie le rendu et la navigation des documents juridiques
/// (hub, mentions légales, CGV, cookies).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  Future<AppState> readyState() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.init();
    return s;
  }

  Widget host(AppState s, Widget child) =>
      ChangeNotifierProvider<AppState>.value(
        value: s,
        child: MaterialApp(home: child),
      );

  testWidgets('Hub légal — affiche les quatre documents', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const LegalHubScreen()));
    await tester.pumpAndSettle();

    expect(find.text('INFORMATIONS LÉGALES'), findsOneWidget);
    expect(find.text('Politique de confidentialité'), findsOneWidget);
    expect(find.text('Conditions Générales de Vente'), findsOneWidget);
    expect(find.text('Mentions légales'), findsOneWidget);
    expect(find.text('Politique cookies'), findsOneWidget);
  });

  testWidgets('Hub légal — ouvre les mentions légales', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const LegalHubScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mentions légales'));
    await tester.pumpAndSettle();
    expect(find.text('MENTIONS LÉGALES'), findsOneWidget);
    expect(find.text('1. Éditeur du site et de l\'application'), findsOneWidget);
  });

  testWidgets('Hub légal — ouvre les CGV', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const LegalHubScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Conditions Générales de Vente'));
    await tester.pumpAndSettle();
    expect(find.text('CONDITIONS GÉNÉRALES DE VENTE'), findsOneWidget);
    expect(find.text('5. Paiement'), findsOneWidget);
  });

  testWidgets('Hub légal — ouvre la politique cookies', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const LegalHubScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Politique cookies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Politique cookies'));
    await tester.pumpAndSettle();
    expect(find.text('POLITIQUE COOKIES'), findsOneWidget);
    expect(find.text('2. Cookies et stockages utilisés'), findsOneWidget);
  });

  testWidgets('Mentions légales — rend sans exception', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const LegalNoticeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('MENTIONS LÉGALES'), findsOneWidget);
    expect(find.text('8. Droit applicable et juridiction'), findsOneWidget);
  });

  testWidgets('CGV — rend sans exception', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const TermsOfSaleScreen()));
    await tester.pumpAndSettle();
    expect(find.text('CONDITIONS GÉNÉRALES DE VENTE'), findsOneWidget);
    expect(find.text('13. Droit applicable et règlement des litiges'), findsOneWidget);
  });

  testWidgets('Cookies — rend sans exception', (tester) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const CookiePolicyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('POLITIQUE COOKIES'), findsOneWidget);
    expect(find.text('7. Vos droits'), findsOneWidget);
  });
}
