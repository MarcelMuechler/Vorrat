import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/shopping_list_screen.dart';
import 'package:vorrat/state/settings_provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  final List<ShoppingListItem> items = [
    ShoppingListItem(id: 1, name: 'Milk', amount: 1, done: false, createdAt: DateTime(2026, 1, 1)),
  ];
  int _nextId = 2;
  Map<String, dynamic>? lastCreatePayload;

  @override
  Future<List<ShoppingListItem>> listShoppingList() async => List.of(items);

  @override
  Future<List<Product>> listProducts({String? search}) async => [];

  @override
  Future<void> deleteShoppingListItem(int id) async {
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<ShoppingListItem> createShoppingListItem({
    int? productId,
    String? name,
    double? amount,
    String? unit,
  }) async {
    lastCreatePayload = {'productId': productId, 'name': name, 'amount': amount, 'unit': unit};
    final created = ShoppingListItem(
      id: _nextId++,
      productId: productId,
      name: name ?? 'restored',
      amount: amount ?? 1,
      unit: unit,
      done: false,
      createdAt: DateTime(2026, 1, 2),
    );
    items.add(created);
    return created;
  }
}

Widget _wrap(ApiClient api, SettingsProvider settings) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<ApiClient>.value(value: api),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ShoppingListScreen(),
      ),
    );

void main() {
  testWidgets('swiping an item away offers Undo, which re-creates it (#137)', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api, settings));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);

    await tester.drag(find.text('Milk'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(api.lastCreatePayload, {'productId': null, 'name': 'Milk', 'amount': 1.0, 'unit': null});
  });
}
