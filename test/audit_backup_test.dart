import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/audit/audit_log_screen.dart';
import 'package:gorex_concierge/screens/backup/backup_screen.dart';

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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('Journal d\'audit — log()', () {
    test('log() ajoute une entrée horodatée avec acteur et rôle', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final before = s.auditLog.length;

      s.log('Action de test', 'Cible test', detail: 'détail');

      expect(s.auditLog.length, before + 1);
      final e = s.auditLog.first;
      expect(e.action, 'Action de test');
      expect(e.target, 'Cible test');
      expect(e.detail, 'détail');
      expect(e.actor.isNotEmpty, isTrue);
      expect(e.actorRole.isNotEmpty, isTrue);
      // La plus récente est en tête.
      expect(
        e.timestamp.isAfter(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });

    test('log() est borné à 300 entrées', () async {
      final s = await _ready();
      for (var i = 0; i < 340; i++) {
        s.log('Boucle', 'i=$i');
      }
      expect(s.auditLog.length, 300);
    });
  });

  group('Sauvegarde / restauration — export & import', () {
    test('exportState contient les jeux de données attendus', () async {
      final s = await _ready();
      final data = s.exportState();
      expect(data['app'], 'GOREX LUXURY CONCIERGE');
      expect(data['schema'], 1);
      expect(data['clients'], isA<List>());
      expect(data['users'], isA<List>());
      expect(data['auditLog'], isA<List>());
      expect((data['clients'] as List).isNotEmpty, isTrue);
    });

    test('exportJson produit un JSON valide et indenté', () async {
      final s = await _ready();
      final json = s.exportJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['app'], 'GOREX LUXURY CONCIERGE');
      expect(json.contains('\n'), isTrue); // indenté
    });

    test('round-trip : export → wipe → import restaure les données', () async {
      final s = await _ready();
      final before = s.dataCounts['clients']!;
      expect(before, greaterThan(0));
      final backup = s.exportJson();

      await s.wipeAll();
      expect(s.clients.length, 0);
      expect(s.currentUser, isNull);

      await s.importJson(backup);
      expect(s.clients.length, before);
      // Session close après restauration (sécurité).
      expect(s.currentUser, isNull);
      // L'import journalise l'opération.
      expect(
        s.auditLog.any((e) => e.action == 'Restauration sauvegarde'),
        isTrue,
      );
    });

    test('importJson rejette un JSON invalide', () async {
      final s = await _ready();
      expect(
        () => s.importJson('{ ceci n\'est pas du json '),
        throwsA(isA<FormatException>()),
      );
    });

    test('importMap sans utilisateurs/clients lève une exception', () async {
      final s = await _ready();
      expect(() => s.importMap({'app': 'x'}), throwsA(isA<FormatException>()));
    });

    test('import invalide ne corrompt pas l\'état (rollback)', () async {
      final s = await _ready();
      final clientsBefore = s.clients.length;
      s.authenticate('ceo@gorex.com', 'gorex2025');

      try {
        await s.importJson('{"users": [], "clients": []}');
      } catch (_) {
        // attendu
      }
      // Les données et la session sont intactes.
      expect(s.clients.length, clientsBefore);
      expect(s.currentUser, isNotNull);
    });

    test('wipeAll efface toutes les données', () async {
      final s = await _ready();
      await s.wipeAll();
      expect(s.clients, isEmpty);
      expect(s.users, isEmpty);
      expect(s.requests, isEmpty);
      expect(s.auditLog, isEmpty);
    });
  });

  group('Écran Journal d\'audit', () {
    testWidgets('affiche les entrées après log()', (tester) async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      s.log('Opération sensible', 'Client VIP');

      await tester.pumpWidget(_host(s, const AuditLogScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Journal d\'audit'), findsWidgets);
      expect(find.text('Opération sensible'), findsOneWidget);
      expect(find.text('Client VIP'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('état vide sans entrée', (tester) async {
      final s = await _ready();
      await s.wipeAll(); // aucun journal
      await tester.pumpWidget(_host(s, const AuditLogScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Aucune entrée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Écran Sauvegarde', () {
    testWidgets('rend sans exception et affiche les actions', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_host(s, const BackupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sauvegarde & restauration'), findsWidgets);
      // GoldButton met le libellé en majuscules.
      expect(find.text('PARTAGER / ENREGISTRER'), findsOneWidget);
      expect(find.text('COPIER LE JSON'), findsOneWidget);
      expect(find.text('Tout effacer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
