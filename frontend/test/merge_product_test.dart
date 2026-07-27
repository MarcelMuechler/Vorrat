import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/products_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  List<Product> products = [
    Product(id: 1, name: 'Milk', barcode: '4001234567890'),
    Product(id: 2, name: 'Milch', barcode: '4009876543210'),
  ];
  List<int>? merged;

  @override
  Future<List<Product>> listProducts({String? search, int? limit, int? offset}) async => products;

  @override
  Future<List<Category>> listCategories({int? limit, int? offset}) async => [];

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

  @override
  Future<Product> mergeProduct(int id, int intoProductId) async {
    merged = [id, intoProductId];
    products = products.where((p) => p.id != id).toList();
    return products.first;
  }
}

void main() {
  // #333: duplicates are easy to create and there was no way back --
  // delete_product refuses while stock exists, so the only route was deleting
  // every batch by hand, which logs waste that never happened.
  testWidgets('merging picks a target, confirms, and calls the API', (tester) async {
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
          home: const ProductsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<void Function()>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge into…'));
    await tester.pumpAndSettle();

    // Only the other product is offered as a target.
    expect(find.text('Milk'), findsWidgets);
    await tester.tap(find.text('Milk').last);
    await tester.pumpAndSettle();

    // Confirmed before anything moves.
    expect(api.merged, isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Merge into…'));
    await tester.pumpAndSettle();

    expect(api.merged, [2, 1]);
  });
}
