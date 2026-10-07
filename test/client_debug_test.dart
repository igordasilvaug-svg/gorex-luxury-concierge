import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/shell/client_shell.dart';
import 'package:gorex_concierge/screens/dashboard/ceo_dashboard.dart';
import 'package:gorex_concierge/screens/finance/finance_screen.dart';
import 'package:gorex_concierge/screens/crm/crm_screen.dart';

/// Regression tests: every screen using DateFormat('...', 'fr_BE') must render
/// without a LocaleDataException (which previously caused a grey error screen).
Future<AppState> _ready() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await state.init();
  return state;
}

Widget _host(AppState state, Widget child) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: child),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_BE', null);
  });

  testWidgets('ClientShell renders without exception', (tester) async {
    final state = await _ready();
    state.authenticate('client@gorex.com', 'gorex2025');
    await tester.pumpWidget(_host(state, const ClientShell()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('CEO dashboard renders without exception', (tester) async {
    final state = await _ready();
    state.authenticate('ceo@gorex.com', 'gorex2025');
    await tester.pumpWidget(_host(state, const Scaffold(body: CeoDashboard())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Finance screen renders without exception', (tester) async {
    final state = await _ready();
    state.authenticate('ceo@gorex.com', 'gorex2025');
    await tester.pumpWidget(_host(state, const Scaffold(body: FinanceScreen())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('CRM screen renders without exception', (tester) async {
    final state = await _ready();
    state.authenticate('ceo@gorex.com', 'gorex2025');
    await tester.pumpWidget(_host(state, const Scaffold(body: CrmScreen())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
