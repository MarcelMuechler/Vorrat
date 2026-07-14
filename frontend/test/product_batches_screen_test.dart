import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/product_batches_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  bool opened = false;
  bool addStockCalled = false;

  @override
  Future<List<StockItem>> listStock({
    int? locationId,
    int? productId,
    String? search,
    int? expiringWithinDays,
    int? categoryId,
  }) async => [
        StockItem(
          id: 1,
          productId: 1,
          amount: 2,
          productName: 'Jam',
          status: 'ok',
          openedAt: opened ? DateTime(2026, 1, 1) : null,
        ),
      ];

  @override
  Future<void> markStockOpened(int id) async {
    opened = true;
  }

  @override
  Future<List<Location>> listLocations() async => [];

  @override
  Future<void> addStock(Map<String, dynamic> payload) async {
    addStockCalled = true;
  }
}

void main() {
  testWidgets('marking a batch opened hides the open button', (tester) async {
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProductBatchesScreen(productId: 1, productName: 'Jam'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the tile to reveal the Open/Use/Spoil buttons (#75).
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_open), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pumpAndSettle();
    expect(api.opened, isTrue);

    // Re-expand -- Open is no longer offered once the batch is opened.
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_open), findsNothing);
  });

  testWidgets('the FAB adds a new batch to the same product', (tester) async {
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProductBatchesScreen(productId: 1, productName: 'Jam'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Add to stock'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.addStockCalled, isTrue);
    expect(find.text('Jam'), findsWidgets);
  });
}
