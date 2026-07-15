import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/product_detail_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  bool createProductCalled = false;
  int? stockedProductId;
  Map<String, dynamic>? lastUpdatePayload;

  @override
  Future<List<Location>> listLocations() async => [];

  @override
  Future<List<Product>> listProducts({String? search, int? limit, int? offset}) async =>
      [Product(id: 42, name: 'Homemade Jam')];

  @override
  Future<Product> createProduct(Map<String, dynamic> payload) async {
    createProductCalled = true;
    return Product(id: 99, name: payload['name']);
  }

  @override
  Future<Product> updateProduct(int id, Map<String, dynamic> payload) async {
    lastUpdatePayload = {'id': id, ...payload};
    return Product(id: id, name: 'Homemade Jam', barcode: payload['barcode']);
  }

  @override
  Future<void> addStock(Map<String, dynamic> payload) async {
    stockedProductId = payload['product_id'] as int?;
  }

  @override
  Future<List<StockItem>> listStock({
    int? locationId,
    int? productId,
    String? search,
    int? expiringWithinDays,
    int? categoryId,
    int? limit,
    int? offset,
  }) async => [];
}

Widget _wrap(ApiClient api, SettingsProvider settings, {String? barcode}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProductDetailScreen(barcode: barcode),
      ),
    );

void main() {
  testWidgets('warns when a barcode-less product name matches an existing one', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api, settings));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'homemade jam');
    await tester.tap(find.text('Save'));
    // Not pumpAndSettle -- the save button's spinner animates continuously
    // while `_saving` is true, which never settles. A couple of pumps is
    // enough to flush the async listProducts() lookup and the dialog route.
    await tester.pump();
    await tester.pump();

    expect(find.text('Similar product exists'), findsOneWidget);

    await tester.tap(find.text('Use existing'));
    await tester.pumpAndSettle();

    expect(api.createProductCalled, isFalse);
    expect(api.stockedProductId, 42);
  });

  testWidgets('creating new anyway still creates a product', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api, settings));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'homemade jam');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Create new'));
    await tester.pumpAndSettle();

    expect(api.createProductCalled, isTrue);
    expect(api.stockedProductId, 99);
  });

  // Regression test: a scanned barcode used to skip the duplicate-name check
  // entirely, so two different barcodes for the same name (or a barcode scan
  // matching an existing barcode-less product) could silently create two
  // separate products with an identical name.
  testWidgets('a barcode-carrying scan still warns about a matching product name', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api, settings, barcode: '4001234'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'homemade jam');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Similar product exists'), findsOneWidget);

    await tester.tap(find.text('Use existing'));
    await tester.pumpAndSettle();

    expect(api.createProductCalled, isFalse);
    expect(api.stockedProductId, 42);
    // The scanned barcode is attached to the reused product so re-scanning
    // it is recognized locally next time.
    expect(api.lastUpdatePayload, {'id': 42, 'barcode': '4001234'});
  });
}
