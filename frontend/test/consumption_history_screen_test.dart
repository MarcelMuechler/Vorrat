import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/consumption_history_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  DateTime? lastSince;
  int calls = 0;

  @override
  Future<List<ConsumptionLogEntry>> listConsumptionLog({
    DateTime? since,
    DateTime? until,
    String? reason,
  }) async {
    calls++;
    lastSince = since;
    final all = [
      ConsumptionLogEntry(
        id: 1,
        productId: 1,
        productName: 'Milk',
        amount: 1,
        reason: 'spoiled',
        quantityUnit: 'l',
        price: 4.0,
        createdAt: DateTime.utc(2026, 7, 20, 10),
      ),
      ConsumptionLogEntry(
        id: 2,
        productId: 2,
        productName: 'Bread',
        amount: 2,
        reason: 'used',
        quantityUnit: 'pcs',
        price: 1.25,
        createdAt: DateTime.utc(2026, 7, 19, 9),
      ),
    ];
    return reason == null ? all : all.where((e) => e.reason == reason).toList();
  }
}

Widget _app(ApiClient api, SettingsProvider settings) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<ApiClient>.value(value: api),
        // The summary line formats values in the configured currency (#324).
        ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ConsumptionHistoryScreen(),
      ),
    );

void main() {
  // #322: the log was export-only. This screen is the in-app answer to
  // "what did we get through, and what keeps going off".
  testWidgets('lists the log with a value summary above it', (tester) async {
    final settings = SettingsProvider();
    await tester.pumpWidget(_app(FakeApiClient(settings), settings));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    // Folded from the loaded rows: 1 x 4.00 spoiled, 2 x 1.25 used.
    expect(find.textContaining('€4.00'), findsOneWidget);
    expect(find.textContaining('€2.50'), findsOneWidget);
  });

  testWidgets('the reason chips filter the loaded window without refetching', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_app(api, settings));
    await tester.pumpAndSettle();
    expect(api.calls, 1);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Spoiled'));
    await tester.pumpAndSettle();

    expect(api.calls, 1);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsNothing);
    // The summary stays the whole window's, not the filtered list's.
    expect(find.textContaining('€2.50'), findsOneWidget);
  });

  testWidgets('the All range chip drops the since filter', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_app(api, settings));
    await tester.pumpAndSettle();
    expect(api.lastSince, isNotNull);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All').first);
    await tester.pumpAndSettle();

    expect(api.lastSince, isNull);
  });
}
