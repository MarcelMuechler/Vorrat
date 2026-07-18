import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/stock_overview_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

// #222: the Stock filter row (expiring-soon chip + location pill + category
// pill) used to be a Wrap that dropped a pill to a second line on a narrow
// phone, making the row's height jump around. It's now a single Row whose
// pills flex and ellipsize, so every filter stays on one line at any width.
class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);

  @override
  Future<List<StockItem>> listStock({
    int? locationId,
    int? productId,
    String? search,
    int? expiringWithinDays,
    int? categoryId,
    int? limit,
    int? offset,
  }) async => [StockItem(id: 1, productId: 1, amount: 2, productName: 'Jam', status: 'ok')];

  // Deliberately long, German-style names -- the worst case for the pill row.
  @override
  Future<List<Location>> listLocations() async => [Location(id: 1, name: 'Vorratskammer')];

  @override
  Future<List<Category>> listCategories({int? limit, int? offset}) async =>
      [Category(id: 1, name: 'Konserven und Eingemachtes')];

  @override
  Future<int> getExpiringSoonDays() async => 3;
}

void main() {
  testWidgets('filter row keeps a location and a category pill on one line on a narrow German phone', (
    tester,
  ) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });

    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StockOverviewScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both pills and the chip render; a leftover overflow would have thrown
    // during pump, so reaching here means the row fit on a single line.
    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilterChip, 'Bald ablaufend'), findsOneWidget);
    expect(find.text('Alle Standorte'), findsOneWidget);
    expect(find.text('Alle Kategorien'), findsOneWidget);
  });
}
