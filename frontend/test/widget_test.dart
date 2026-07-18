import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/main.dart';
import 'package:vorrat/state/scan_history.dart';
import 'package:vorrat/state/scan_queue.dart';
import 'package:vorrat/state/settings_provider.dart';

void main() {
  testWidgets('app boots to the Stock tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      VorratApp(settings: SettingsProvider(), scanQueue: ScanQueue(), scanHistory: ScanHistory()),
    );
    await tester.pump();

    expect(find.text('Stock'), findsWidgets);
  });

  testWidgets('wide screens still show the bottom bar, not a NavigationRail', (
    WidgetTester tester,
  ) async {
    // Home Assistant's own left sidebar already fills the "rail" role on
    // wide/HA-panel layouts (#199 wireframe revamp), so the bottom nav bar
    // stays consistent at every width instead of switching to a rail.
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });

    await tester.pumpWidget(
      VorratApp(settings: SettingsProvider(), scanQueue: ScanQueue(), scanHistory: ScanHistory()),
    );
    await tester.pump();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  // Flutter reports RenderFlex overflows via FlutterError, which flutter_test
  // turns into a test failure -- so just rendering each tab at a small width
  // (iPhone SE / small Android) is enough to catch "goes off the edge" bugs.
  // Runs once per supported locale (app_*.arb) since German strings tend to
  // run longer than English and are where overflows have shown up in practice.
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('no tab overflows on a narrow phone screen ($locale)', (WidgetTester tester) async {
      final originalSize = tester.view.physicalSize;
      final originalRatio = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(() {
        tester.view.physicalSize = originalSize;
        tester.view.devicePixelRatio = originalRatio;
        tester.platformDispatcher.clearLocaleTestValue();
      });

      await tester.pumpWidget(
        VorratApp(settings: SettingsProvider(), scanQueue: ScanQueue(), scanHistory: ScanHistory()),
      );
      await tester.pump();

      // Tap by icon, not label text, so this doesn't depend on the locale's
      // translated strings.
      for (final icon in [Icons.shopping_cart_outlined, Icons.qr_code_scanner, Icons.settings]) {
        final destination = find.byIcon(icon);
        if (destination.evaluate().isEmpty) continue;
        await tester.tap(destination.first);
        await tester.pump();
      }
    });
  }
}
