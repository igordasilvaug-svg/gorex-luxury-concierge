import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/models/enums.dart';
import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/access/staff_access_screen.dart';

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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  group('Gestion des accès — CRUD', () {
    test('createUser adds a staff account with mustChangePassword', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final before = s.staffUsers.length;

      final u = await s.createUser(
        fullName: 'Test Concierge',
        email: 'test.concierge@gorex.com',
        password: 'Temp1234',
        role: UserRole.concierge,
        title: 'Concierge',
      );

      expect(s.staffUsers.length, before + 1);
      expect(u.mustChangePassword, isTrue);
      expect(u.active, isTrue);
      expect(s.userById(u.id)?.email, 'test.concierge@gorex.com');
    });

    test('emailExists detects duplicates except self', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final u = await s.createUser(
        fullName: 'Dup Test',
        email: 'dup@gorex.com',
        password: 'Temp1234',
        role: UserRole.concierge,
      );
      expect(s.emailExists('dup@gorex.com'), isTrue);
      expect(s.emailExists('DUP@gorex.com'), isTrue);
      expect(s.emailExists('dup@gorex.com', exceptId: u.id), isFalse);
    });

    test('setUserActive toggles access and blocks authentication', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final u = await s.createUser(
        fullName: 'Toggle Test',
        email: 'toggle@gorex.com',
        password: 'Temp1234',
        role: UserRole.concierge,
      );
      await s.setUserActive(u.id, false);
      expect(s.userById(u.id)?.active, isFalse);
      // cannot authenticate a disabled account
      final s2 = AppState();
      s2.users = List.of(s.users);
      expect(s2.authenticate('toggle@gorex.com', 'Temp1234'), isNull);
    });

    test('resetUserPassword forces change on next login', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final u = await s.createUser(
        fullName: 'Reset Test',
        email: 'reset@gorex.com',
        password: 'Temp1234',
        role: UserRole.concierge,
      );
      await s.updateUser(u.copyWith(mustChangePassword: false));
      expect(s.userById(u.id)?.mustChangePassword, isFalse);

      await s.resetUserPassword(u.id, 'NewPass99');
      expect(s.userById(u.id)?.mustChangePassword, isTrue);
      expect(s.userById(u.id)?.password, 'NewPass99');
    });

    test('deleteUser removes the account', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      final u = await s.createUser(
        fullName: 'Delete Test',
        email: 'delete@gorex.com',
        password: 'Temp1234',
        role: UserRole.concierge,
      );
      expect(s.userById(u.id), isNotNull);
      await s.deleteUser(u.id);
      expect(s.userById(u.id), isNull);
    });

    test('user_access permission: CEO & Manager yes, others no', () async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      expect(s.can('user_access'), isTrue);

      s.authenticate('manager@gorex.com', 'gorex2025');
      expect(s.can('user_access'), isTrue);

      s.authenticate('concierge@gorex.com', 'gorex2025');
      expect(s.can('user_access'), isFalse);
    });
  });

  group('Écran Accès personnel', () {
    testWidgets('renders for CEO without exception', (tester) async {
      final s = await _ready();
      s.authenticate('ceo@gorex.com', 'gorex2025');
      await tester.pumpWidget(_host(s, const StaffAccessScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Accès personnel'), findsWidgets);
    });

    testWidgets('shows restricted state for non-authorized role', (
      tester,
    ) async {
      final s = await _ready();
      s.authenticate('concierge@gorex.com', 'gorex2025');
      await tester.pumpWidget(_host(s, const StaffAccessScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Accès restreint'), findsOneWidget);
    });
  });
}
