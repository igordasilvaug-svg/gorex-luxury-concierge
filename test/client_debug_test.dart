import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:gorex_concierge/state/app_state.dart';
import 'package:gorex_concierge/screens/shell/client_shell.dart';

void main() {
  testWidgets('client shell renders without exception', (tester) async {
    await initializeDateFormatting('fr_BE', null);
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    state.authenticate('client@gorex.com', 'gorex2025');

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: ClientShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final err = tester.takeException();
    if (err != null) {
      // ignore: avoid_print
      print('EXCEPTION: $err');
    }
    expect(err, isNull);
  });
}
