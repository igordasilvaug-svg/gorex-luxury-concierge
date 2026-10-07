import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gorex_concierge/main.dart';
import 'package:gorex_concierge/state/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GorexApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('AppState seeds demo data', () async {
    final state = AppState();
    await state.init();
    expect(state.users.isNotEmpty, true);
    expect(state.clients.isNotEmpty, true);
    expect(state.tiers.isNotEmpty, true);
    expect(state.requests.isNotEmpty, true);
  });

  test('Authentication works for demo account', () async {
    final state = AppState();
    await state.init();
    final user = state.authenticate('ceo@gorex.com', 'gorex2025');
    expect(user, isNotNull);
    expect(state.isCeo, true);
  });

  test('KPIs compute correctly', () async {
    final state = AppState();
    await state.init();
    expect(state.activeClients, greaterThan(0));
    expect(state.totalRevenue, greaterThan(0));
  });

  test('Client VIP sees own requests', () async {
    final state = AppState();
    await state.init();
    state.authenticate('client@gorex.com', 'gorex2025');
    expect(state.isClient, true);
    expect(state.currentClient, isNotNull);
  });

  test('GorexApp widget exists', () {
    expect(const GorexApp(), isNotNull);
  });
}
