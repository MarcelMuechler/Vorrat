import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/shopping_list_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';
import 'package:vorrat/widgets/add_batch_sheet.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  List<ShoppingListItem> items = [
    ShoppingListItem(
      id: 1,
      productId: 7,
      name: 'Milk',
      amount: 2,
      done: false,
      createdAt: DateTime(2026, 1, 1),
    ),
    ShoppingListItem(id: 2, name: 'Something scribbled', amount: 1, done: false, createdAt: DateTime(2026, 1, 1)),
  ];
  Map<String, dynamic>? addedStock;

  @override
  Future<List<ShoppingListItem>> listShoppingList() async => List.of(items);

  @override
  Future<List<Product>> listProducts({String? search, int? limit, int? offset}) async => [];

  @override
  Future<List<Location>> listLocations() async => [];

  @override
  Future<Product> getProduct(int id) async => Product(id: id, name: 'Milk', quantityUnit: 'l');

  @override
  Future<ShoppingListItem> updateShoppingListItem(int id, Map<String, dynamic> payload) async {
    final index = items.indexWhere((i) => i.id == id);
    final item = items[index];
    final updated = ShoppingListItem(
      id: item.id,
      productId: item.productId,
      name: item.name,
      amount: item.amount,
      unit: item.unit,
      done: payload['done'] ?? item.done,
      createdAt: item.createdAt,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> addStock(Map<String, dynamic> payload) async {
    addedStock = payload;
  }
}

Widget _wrap(ApiClient api, SettingsProvider settings) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ShoppingListScreen(),
      ),
    );

void main() {
  // #323: "add low stock" pushed stock -> list, and nothing came back the
  // other way -- ticking an item off left the buy half of the loop unrecorded.
  testWidgets('ticking a product-linked item off offers to add it to stock', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api, settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to stock'));
    await tester.pumpAndSettle();

    // The sheet opens prefilled with the amount that was on the list.
    expect(find.byType(AddBatchSheet), findsOneWidget);
    final amountField = find.descendant(of: find.byType(AddBatchSheet), matching: find.byType(TextField)).first;
    expect(tester.widget<TextField>(amountField).controller!.text, '2');

    await tester.tap(
      find.descendant(of: find.byType(AddBatchSheet), matching: find.widgetWithText(FilledButton, 'Add')),
    );
    await tester.pumpAndSettle();

    expect(api.addedStock!['product_id'], 7);
    expect(api.addedStock!['amount'], 2.0);
  });

  testWidgets('a free-text item has no product to stock, so nothing is offered', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api, settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(find.text('Add to stock'), findsNothing);
  });
}
