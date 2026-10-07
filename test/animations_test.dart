import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorex_concierge/widgets/animations.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('FadeSlideIn eventually reveals its child', (tester) async {
    await tester.pumpWidget(
      host(const FadeSlideIn(child: Text('CONTENU'))),
    );
    expect(find.text('CONTENU'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1);
  });

  testWidgets('GoldCountUp animates to the target value', (tester) async {
    await tester.pumpWidget(
      host(GoldCountUp(value: 1500, formatter: (v) => '$v €')),
    );
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('1500 €'), findsOneWidget);
  });

  testWidgets('AnimatedRingAvatar renders initials', (tester) async {
    await tester.pumpWidget(
      host(const AnimatedRingAvatar(initials: 'AD', size: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ListSkeleton renders without exception', (tester) async {
    await tester.pumpWidget(host(const ListSkeleton(items: 3)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DashboardSkeleton renders without exception', (tester) async {
    await tester.pumpWidget(host(const DashboardSkeleton()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('PulseGlow renders its child', (tester) async {
    await tester.pumpWidget(
      host(const PulseGlow(child: Text('URGENT'))),
    );
    expect(find.text('URGENT'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  test('GoldPageTransitionsBuilder is constructible', () {
    expect(const GoldPageTransitionsBuilder(), isNotNull);
  });
}
