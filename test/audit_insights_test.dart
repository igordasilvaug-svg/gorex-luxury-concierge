import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gorex_concierge/core/audit/audit_insights.dart';
import 'package:gorex_concierge/models/crm_agenda.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/security/security_dashboard_screen.dart';

AuditEntry _e(
  String action, {
  DateTime? at,
  String actor = 'Alexandre',
  String role = 'CEO',
}) => AuditEntry(
  id: 'x',
  timestamp: at ?? DateTime.now(),
  actor: actor,
  actorRole: role,
  action: action,
  target: 'cible',
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('AuditInsights — catégorisation', () {
    test('classe les actions dans les bonnes catégories', () {
      expect(AuditInsights.categoryOf('Connexion'), AuditCategory.access);
      expect(AuditInsights.categoryOf('Déconnexion'), AuditCategory.access);
      expect(
        AuditInsights.categoryOf('Changement mot de passe'),
        AuditCategory.security,
      );
      expect(
        AuditInsights.categoryOf('Escalade sécurité'),
        AuditCategory.security,
      );
      expect(
        AuditInsights.categoryOf('Peppol distribué'),
        AuditCategory.billing,
      );
      expect(
        AuditInsights.categoryOf('Rapprochement auto'),
        AuditCategory.billing,
      );
      expect(
        AuditInsights.categoryOf('Suppression accès'),
        AuditCategory.administration,
      );
      expect(
        AuditInsights.categoryOf('Création demande'),
        AuditCategory.operations,
      );
      expect(
        AuditInsights.categoryOf('Action inconnue xyz'),
        AuditCategory.other,
      );
    });
  });

  group('AuditInsights — agrégats', () {
    test('byCategory trie par volume décroissant', () {
      final ins = AuditInsights([
        _e('Connexion'),
        _e('Connexion'),
        _e('Connexion'),
        _e('Peppol distribué'),
        _e('Escalade sécurité'),
      ]);
      final byCat = ins.byCategory();
      expect(byCat[AuditCategory.access], 3);
      expect(byCat[AuditCategory.billing], 1);
      expect(byCat[AuditCategory.security], 1);
      expect(
        byCat.keys.first,
        AuditCategory.access,
      ); // le plus fréquent en tête
    });

    test('todayCount et activeActorsCount', () {
      final ins = AuditInsights([
        _e('Connexion', actor: 'A'),
        _e('Connexion', actor: 'B'),
        _e(
          'Vieille action',
          actor: 'C',
          at: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ]);
      expect(ins.total, 3);
      expect(ins.todayCount, 2);
      expect(ins.activeActorsCount, 3);
    });

    test('daily renvoie exactement N points, dernier = aujourd\'hui', () {
      final ins = AuditInsights([_e('Connexion')]);
      final d = ins.daily(14);
      expect(d.length, 14);
      final today = DateTime.now();
      final last = d.last.day;
      expect(last.year, today.year);
      expect(last.month, today.month);
      expect(last.day, today.day);
      expect(d.last.count, 1);
    });

    test('lastActivity null si journal vide, sinon dernière entrée', () {
      expect(AuditInsights([]).lastActivity, isNull);
      final ins = AuditInsights([_e('Connexion')]);
      expect(ins.lastActivity, isNotNull);
    });
  });

  group('AuditInsights — événements sensibles', () {
    test('isSensitive détecte échecs, suppressions, escalades', () {
      expect(AuditInsights.isSensitive(_e('Échec Peppol')), isTrue);
      expect(AuditInsights.isSensitive(_e('Suppression accès')), isTrue);
      expect(AuditInsights.isSensitive(_e('Escalade sécurité')), isTrue);
      expect(AuditInsights.isSensitive(_e('Connexion')), isFalse);
    });

    test('sensitiveEvents triés du plus récent au plus ancien', () {
      final old = _e(
        'Échec Peppol',
        at: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final recent = _e('Suppression accès');
      final ins = AuditInsights([old, recent, _e('Connexion')]);
      final s = ins.sensitiveEvents;
      expect(s.length, 2);
      expect(s.first.action, 'Suppression accès');
    });
  });

  group('Écran Tableau de bord sécurité', () {
    testWidgets('rend sans exception avec des données', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.init();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      s.log('Connexion', 'test');
      s.log('Échec Peppol', 'doc-1');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: s,
          child: const MaterialApp(home: SecurityDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tableau de bord sécurité'), findsWidgets);
      expect(find.text('Activité — 14 derniers jours'), findsOneWidget);
      expect(find.text('Événements sensibles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('affiche l\'état sain sans événement sensible', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.init();
      await s.wipeAll(); // journal vide
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: s,
          child: const MaterialApp(home: SecurityDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Aucun événement sensible détecté. '
          'Aucun échec, suppression ou escalade récent.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
