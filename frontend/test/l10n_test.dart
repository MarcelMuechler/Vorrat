import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vorrat/l10n/app_localizations.dart';

void main() {
  testWidgets('resolves German strings when locale is de', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Column(
              children: [Text(l10n.stockTitle), Text(l10n.scanTitle), Text(l10n.settingsTitle)],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bestand'), findsOneWidget);
    expect(find.text('Scannen'), findsOneWidget);
    expect(find.text('Einstellungen'), findsOneWidget);
  });
}
