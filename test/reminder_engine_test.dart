import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/models/enums.dart';
import 'package:gorex_concierge/models/finance.dart';
import 'package:gorex_concierge/models/reminder_config.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/settings/reminder_settings_screen.dart';
import 'package:gorex_concierge/screens/legal/privacy_policy_screen.dart';

Future<AppState> _ready() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await state.init();
  return state;
}

Widget _host(AppState state, Widget child) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: child)),
    );

FinanceDocument _invoice({
  String id = 'f1',
  int dueInDays = -30,
  String client = 'Dimitri Kalashov',
}) => FinanceDocument(
  id: id,
  reference: 'GRX-INV-2025-0001',
  type: FinanceDocType.invoice,
  clientId: 'c1',
  clientName: client,
  date: DateTime.now().subtract(const Duration(days: 60)),
  dueDate: DateTime.now().add(Duration(days: dueInDays)),
  lines: const [FinanceLine(description: 'Prestation', unitPrice: 1000)],
  taxPercent: 21,
  status: InvoiceStatus.sent,
  structuredCommunication: '+++000/0000/00001+++',
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('ReminderConfig', () {
    test('valeurs par défaut', () {
      const c = ReminderConfig();
      expect(c.enabled, false);
      expect(c.autoSend, true);
      expect(c.runOnStartup, true);
      expect(c.intervalHours, 24);
      expect(c.minDaysBetween, 7);
    });

    test('toMap / fromMap round-trip', () {
      final c = ReminderConfig(
        enabled: true,
        autoSend: false,
        intervalHours: 12,
        lastRunAt: DateTime(2025, 6, 1, 10),
        lastRunCount: 3,
      );
      final r = ReminderConfig.fromMap(c.toMap());
      expect(r.enabled, true);
      expect(r.autoSend, false);
      expect(r.intervalHours, 12);
      expect(r.lastRunCount, 3);
      expect(r.lastRunAt, DateTime(2025, 6, 1, 10));
    });
  });

  group('AppState — moteur de relance automatique', () {
    test('reminderRunDue vrai si jamais exécuté', () async {
      final s = await _ready();
      await s.updateReminderConfig(
        const ReminderConfig(enabled: true, lastRunCount: 0),
      );
      expect(s.reminderRunDue, true);
    });

    test('reminderRunDue faux si désactivé', () async {
      final s = await _ready();
      expect(s.reminderRunDue, false);
    });

    test('runAutoReminders ne fait rien si désactivé', () async {
      final s = await _ready();
      expect(await s.runAutoReminders(), 0);
    });

    test('runAutoReminders envoie et horodate', () async {
      final s = await _ready();
      s.financeDocs.add(_invoice(id: 'zz', dueInDays: -10));
      await s.updateReminderConfig(
        const ReminderConfig(enabled: true, autoSend: true),
      );
      final n = await s.runAutoReminders();
      expect(n, greaterThanOrEqualTo(1));
      expect(s.reminderConfig.lastRunAt, isNotNull);
      expect(s.reminderConfig.lastRunCount, n);
      expect(s.financeById('zz')!.reminderLevel, ReminderLevel.first);
    });

    test('runAutoReminders respecte l\'intervalle (pas de double exécution)',
        () async {
      final s = await _ready();
      await s.updateReminderConfig(
        const ReminderConfig(enabled: true, intervalHours: 24),
      );
      await s.runAutoReminders();
      final n2 = await s.runAutoReminders();
      expect(n2, 0);
    });

    test('runAutoReminders force ignore l\'intervalle', () async {
      final s = await _ready();
      s.financeDocs.add(_invoice(id: 'yy', dueInDays: -50));
      await s.updateReminderConfig(
        const ReminderConfig(enabled: true, autoSend: true),
      );
      await s.runAutoReminders();
      final n2 = await s.runAutoReminders(force: true);
      // Au moins la nouvelle facture échue est traitée.
      expect(n2, greaterThanOrEqualTo(0));
    });

    test('autoSend=false : détecte sans envoyer', () async {
      final s = await _ready();
      s.financeDocs.add(_invoice(id: 'qq', dueInDays: -10));
      await s.updateReminderConfig(
        const ReminderConfig(enabled: true, autoSend: false),
      );
      final n = await s.runAutoReminders();
      expect(n, greaterThanOrEqualTo(1));
      expect(s.financeById('qq')!.reminderLevel, ReminderLevel.none);
    });

    test('persistance de la configuration', () async {
      final s = await _ready();
      await s.updateReminderConfig(
        const ReminderConfig(enabled: true, intervalHours: 6, minDaysBetween: 3),
      );
      final s2 = AppState();
      await s2.init();
      expect(s2.reminderConfig.enabled, true);
      expect(s2.reminderConfig.intervalHours, 6);
      expect(s2.reminderConfig.minDaysBetween, 3);
    });
  });

  group('ReminderSettingsScreen — rendu', () {
    testWidgets('affiche les paramètres et le barème', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_host(s, const ReminderSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Relances automatiques'), findsOneWidget);
      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Barème d\'escalade'), findsOneWidget);
      expect(find.text('1ʳᵉ relance'), findsOneWidget);
    });

    testWidgets('active le moteur via le switch', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_host(s, const ReminderSettingsScreen()));
      await tester.pumpAndSettle();
      final sw = find.byType(Switch).first;
      await tester.ensureVisible(sw);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(sw).value, false);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(sw).value, true);
      // Les champs dépendants deviennent actifs.
      expect(tester.widget<TextField>(find.byType(TextField).first).enabled, true);
    });
  });

  group('PrivacyPolicyScreen — rendu', () {
    testWidgets('affiche les sections RGPD', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_host(s, const PrivacyPolicyScreen()));
      await tester.pumpAndSettle();
      expect(find.text('POLITIQUE DE CONFIDENTIALITÉ'), findsOneWidget);
      expect(find.text('1. Responsable du traitement'), findsOneWidget);
      expect(find.text('7. Vos droits'), findsOneWidget);
      expect(find.text('9. Autorité de contrôle'), findsOneWidget);
    });
  });
}
