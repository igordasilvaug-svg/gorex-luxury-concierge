import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/core/i18n/app_localizations.dart';
import 'package:gorex_concierge/screens/about/about_screen.dart';
import 'package:gorex_concierge/screens/legal/legal_hub_screen.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/widgets/language_selector.dart';

/// Vérifie la localisation (FR/NL/EN), le sélecteur de langue et la page À propos.
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

  group('L10n — table de traductions', () {
    test('les trois langues sont supportées', () {
      expect(L10n.supported, containsAll(['fr', 'nl', 'en']));
    });

    test('traduction FR/NL/EN cohérente pour nav.dashboard', () {
      expect(L10n.tr('fr', 'nav.dashboard'), 'Tableau de bord');
      expect(L10n.tr('nl', 'nav.dashboard'), 'Dashboard');
      expect(L10n.tr('en', 'nav.dashboard'), 'Dashboard');
    });

    test('clé inconnue retombe sur la clé brute', () {
      expect(L10n.tr('fr', 'cle.inexistante'), 'cle.inexistante');
    });

    test('langue inconnue retombe sur le français', () {
      expect(L10n.tr('xx', 'nav.dashboard'), 'Tableau de bord');
    });
  });

  group('AppState — langue', () {
    test('langue par défaut = fr', () async {
      final s = await readyState();
      expect(s.language, 'fr');
    });

    test('setLanguage change la langue et tr() suit', () async {
      final s = await readyState();
      await s.setLanguage('en');
      expect(s.language, 'en');
      expect(s.tr('nav.dashboard'), 'Dashboard');
      await s.setLanguage('nl');
      expect(s.tr('nav.dashboard'), 'Dashboard');
      await s.setLanguage('fr');
      expect(s.tr('nav.dashboard'), 'Tableau de bord');
    });
  });

  group('Sélecteur de langue', () {
    testWidgets('affiche FR / NL / EN et change la langue', (tester) async {
      final s = await readyState();
      await tester.pumpWidget(host(s, const Scaffold(body: LanguageSelector())));
      await tester.pumpAndSettle();

      expect(find.text('FR'), findsOneWidget);
      expect(find.text('NL'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);

      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(s.language, 'en');
    });
  });

  group('Page À propos', () {
    testWidgets('rend en français', (tester) async {
      final s = await readyState();
      await tester.pumpWidget(host(s, const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('À PROPOS'), findsOneWidget);
      expect(find.text('L\'excellence discrète'), findsOneWidget);
      expect(find.text('Nos cinq piliers'), findsOneWidget);
    });

    testWidgets('bascule en anglais', (tester) async {
      final s = await readyState();
      await s.setLanguage('en');
      await tester.pumpWidget(host(s, const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ABOUT'), findsOneWidget);
      expect(find.text('Discreet excellence'), findsOneWidget);
    });
  });

  group('Hub légal — localisé', () {
    testWidgets('affiche les titres en néerlandais', (tester) async {
      final s = await readyState();
      await s.setLanguage('nl');
      await tester.pumpWidget(host(s, const LegalHubScreen()));
      await tester.pumpAndSettle();

      expect(find.text('JURIDISCHE INFORMATIE'), findsOneWidget);
      expect(find.text('Privacybeleid'), findsOneWidget);
      expect(find.text('Cookiebeleid'), findsOneWidget);
    });
  });
}
