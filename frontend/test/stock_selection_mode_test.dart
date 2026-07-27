import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/stock_overview_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

// Bulk actions for #123: this covers entering/exiting selection mode on the
// Stock screen and wiring the three bulk actions (consume/delete/move) to
// ApiClient. Follows the FakeApiClient-per-test-file pattern used by
// product_batches_screen_test.dart etc.
class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);

  List<int>? bulkConsumedIds;
  List<int>? bulkDeletedIds;
  List<int>? bulkMovedIds;
  int? bulkMovedLocationId;

  @override
  Future<List<StockItem>> listStock({
    int? locationId,
    int? productId,
    String? search,
    int? expiringWithinDays,
    int? categoryId,
    int? limit,
    int? offset,
  }) async => [
    StockItem(id: 1, productId: 1, amount: 2, productName: 'Jam', status: 'ok'),
    StockItem(id: 2, productId: 2, amount: 1, productName: 'Milk', status: 'ok'),
  ];

  @override
  Future<List<Location>> listLocations() async => [Location(id: 1, name: 'Pantry')];

  @override
  Future<List<Category>> listCategories({int? limit, int? offset}) async => [];

  @override
  Future<AppSettingsData> getSettings() async =>
      AppSettingsData(expiringSoonDays: 3, currency: 'EUR');

  @override
  Future<int> bulkConsumeStock(List<int> entryIds, {String reason = 'used'}) async {
    bulkConsumedIds = entryIds;
    return entryIds.length;
  }

  @override
  Future<int> bulkDeleteStock(List<int> entryIds) async {
    bulkDeletedIds = entryIds;
    return entryIds.length;
  }

  @override
  Future<int> bulkMoveStock(List<int> entryIds, int locationId) async {
    bulkMovedIds = entryIds;
    bulkMovedLocationId = locationId;
    return entryIds.length;
  }
}

Future<FakeApiClient> _pumpScreen(WidgetTester tester) async {
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
        home: const StockOverviewScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('entering selection mode shows checkboxes and a selection app bar', (tester) async {
    await _pumpScreen(tester);

    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('0 selected'), findsOneWidget);

    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('exiting selection mode clears the selection without calling the API', (tester) async {
    final api = await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.checklist), findsOneWidget);
    expect(api.bulkConsumedIds, isNull);
    expect(api.bulkDeletedIds, isNull);
    expect(api.bulkMovedIds, isNull);

    // Re-entering selection mode starts from a clean slate.
    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);
  });

  testWidgets('bulk-consuming selected entries calls the API and exits selection mode', (tester) async {
    final api = await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jam'));
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    expect(api.bulkConsumedIds, unorderedEquals([1, 2]));
    // Selection mode exits back to the normal toolbar on success.
    expect(find.byIcon(Icons.checklist), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('bulk delete asks for confirmation before calling the API', (tester) async {
    final api = await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Confirmation dialog shown, nothing deleted yet.
    expect(find.text('Remove selected batches?'), findsOneWidget);
    expect(api.bulkDeletedIds, isNull);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(api.bulkDeletedIds, [1]);
  });

  testWidgets('bulk move prompts for a location and calls the API with it', (tester) async {
    final api = await _pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.drive_file_move_outline));
    await tester.pumpAndSettle();

    expect(find.text('Move to location'), findsOneWidget);

    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();

    expect(api.bulkMovedIds, [2]);
    expect(api.bulkMovedLocationId, 1);
  });
}
