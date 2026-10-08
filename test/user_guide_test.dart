import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gorex_concierge/screens/legal/user_guide_screen.dart';
import 'package:gorex_concierge/screens/legal/privacy_policy_screen.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:provider/provider.dart';

/// Vérifie que le guide d'utilisation et la politique de confidentialité
/// s'affichent correctement et restent navigables (sommaire ↔ chapitres).
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

  testWidgets('Guide d\'utilisation — le sommaire affiche les chapitres', (
    tester,
  ) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const UserGuideScreen()));
    await tester.pumpAndSettle();

    expect(find.text('GUIDE D\'UTILISATION'), findsOneWidget);
    expect(find.text('Prise en main'), findsOneWidget);
    expect(find.text('Comptabilité'), findsOneWidget);
    expect(find.text('Sécurité & confidentialité'), findsOneWidget);
  });

  testWidgets('Guide d\'utilisation — ouvrir un chapitre puis revenir', (
    tester,
  ) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const UserGuideScreen()));
    await tester.pumpAndSettle();

    // Ouvrir le premier chapitre
    await tester.tap(find.text('Prise en main'));
    await tester.pumpAndSettle();
    expect(find.text('CHAPITRE 1'), findsOneWidget);
    expect(find.text('Bienvenue'), findsOneWidget);

    // Revenir au sommaire via le bouton retour de l'AppBar
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('GUIDE D\'UTILISATION'), findsOneWidget);
  });

  testWidgets('Guide d\'utilisation — bouton SUIVANT avance de chapitre', (
    tester,
  ) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const UserGuideScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prise en main'));
    await tester.pumpAndSettle();
    expect(find.text('CHAPITRE 1'), findsOneWidget);

    // Faire défiler jusqu'au bouton puis avancer
    await tester.ensureVisible(find.text('SUIVANT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SUIVANT'));
    await tester.pumpAndSettle();
    expect(find.text('CHAPITRE 2'), findsOneWidget);
    expect(find.text('Espace membre'), findsOneWidget);
  });

  testWidgets('Politique de confidentialité — rend sans exception', (
    tester,
  ) async {
    final s = await readyState();
    await tester.pumpWidget(host(s, const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('POLITIQUE DE CONFIDENTIALITÉ'), findsOneWidget);
    expect(find.text('1. Responsable du traitement'), findsOneWidget);
    expect(find.text('10. Cookies et stockage local'), findsOneWidget);
  });
}
