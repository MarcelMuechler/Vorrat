import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/consumption_history_screen.dart';
import 'package:vorrat/state/settings_provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  String? lastReason;
  DateTime? lastSince;

  @override
  Future<List<ConsumptionLogEntry>> listConsumptionLog({
    DateTime? since,
    DateTime? until,
    String? reason,
  }) async {
    lastReason = reason;
    lastSince = since;
    final all = [
      ConsumptionLogEntry(
        id: 1,
        productId: 1,
        productName: 'Milk',
        amount: 1,
        reason: 'spoiled',
        quantityUnit: 'l',
        createdAt: DateTime.utc(2026, 7, 20, 10),
      ),
      ConsumptionLogEntry(
        id: 2,
        productId: 2,
        productName: 'Bread',
        amount: 2,
        reason: 'used',
        quantityUnit: 'pcs',
        createdAt: DateTime.utc(2026, 7, 19, 9),
      ),
    ];
    return reason == null ? all : all.where((e) => e.reason == reason).toList();
  }

  @override
  Future<ConsumptionSummary> consumptionSummary({DateTime? since, DateTime? until}) async =>
      ConsumptionSummary(usedEntries: 1, usedValue: 2.5, spoiledEntries: 1, spoiledValue: 4.0);
}

Widget _app(ApiClient api, SettingsProvider settings) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<ApiClient>.value(value: api),
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
    // Values come from the server-side summary, not from summing the list.
    expect(find.textContaining('worth 4'), findsOneWidget);
    expect(find.textContaining('worth 2.5'), findsOneWidget);
  });

  testWidgets('the reason chips filter through the API, not client-side', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_app(api, settings));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Spoiled'));
    await tester.pumpAndSettle();

    expect(api.lastReason, 'spoiled');
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Bread'), findsNothing);
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
