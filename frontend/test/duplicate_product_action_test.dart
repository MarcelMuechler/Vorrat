import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/product_edit_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  Map<String, dynamic>? createdProduct;

  @override
  Future<List<Location>> listLocations() async => [Location(id: 3, name: 'Fridge')];

  @override
  Future<List<Category>> listCategories({int? limit, int? offset}) async => [];

  @override
  Future<Product> createProduct(Map<String, dynamic> payload) async {
    createdProduct = payload;
    return Product(id: 99, name: payload['name']);
  }
}

final _yoghurt = Product(
  id: 1,
  name: 'Yoghurt natur',
  barcode: '4001234567890',
  imageUrl: '/uploads/1-abc.jpg',
  quantityUnit: 'g',
  defaultLocationId: 3,
  defaultBestBeforeDays: 28,
  lowStockThreshold: 2,
  doesNotSpoil: false,
);

void main() {
  // #334: ten sorts of yoghurt meant typing the same nine fields ten times.
  testWidgets('Duplicate copies the defaults but not name, barcode or photo', (tester) async {
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
          home: ProductEditScreen(product: _yoghurt),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Duplicate'));
    await tester.pumpAndSettle();

    // Prefilled with a name that's obviously a copy, and editable.
    expect(find.text('Yoghurt natur (copy)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Yoghurt Vanille');
    await tester.tap(find.widgetWithText(FilledButton, 'Duplicate'));
    await tester.pumpAndSettle();

    expect(api.createdProduct!['name'], 'Yoghurt Vanille');
    expect(api.createdProduct!['quantity_unit'], 'g');
    expect(api.createdProduct!['default_location_id'], 3);
    expect(api.createdProduct!['default_best_before_days'], 28);
    expect(api.createdProduct!['low_stock_threshold'], 2.0);
    // The three fields that actually differ between copies aren't carried over.
    expect(api.createdProduct!.containsKey('barcode'), isFalse);
    expect(api.createdProduct!.containsKey('image_url'), isFalse);
  });
}
