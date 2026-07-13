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
  FakeApiClient() : super(SettingsProvider());
  bool createProductCalled = false;
  int? stockedProductId;

  @override
  Future<List<Location>> listLocations() async => [];

  @override
  Future<List<Product>> listProducts({String? search}) async =>
      [Product(id: 42, name: 'Homemade Jam')];

  @override
  Future<Product> createProduct(Map<String, dynamic> payload) async {
    createProductCalled = true;
    return Product(id: 99, name: payload['name']);
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
  }) async => [];
}

Widget _wrap(ApiClient api) => MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProductDetailScreen(),
      ),
    );

void main() {
  testWidgets('warns when a barcode-less product name matches an existing one', (tester) async {
    final api = FakeApiClient();
    await tester.pumpWidget(_wrap(api));
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
    final api = FakeApiClient();
    await tester.pumpWidget(_wrap(api));
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
}
