import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salati/features/home/presentation/salati_dashboard_screen.dart';

void main() {
  testWidgets('dashboard exposes the primary services from the new design', (
    tester,
  ) async {
    var prayerOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SalatiDashboardScreen(
              onOpenQuran: () {},
              onOpenPrayer: () => prayerOpened = true,
              onOpenAdhkar: () {},
              onOpenDuas: () {},
              onOpenAi: () {},
              onOpenStore: () {},
              onUnavailable: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('صلاة الظهر'), findsOneWidget);
    expect(find.text('قرآن'), findsOneWidget);
    expect(find.text('الصلاة'), findsOneWidget);
    expect(find.text('الأذكار'), findsOneWidget);

    await tester.tap(find.text('الصلاة'));
    expect(prayerOpened, isTrue);
  });
}
