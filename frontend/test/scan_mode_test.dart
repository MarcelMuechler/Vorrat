import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/scan_screen.dart';
import 'package:vorrat/state/scan_history.dart';
import 'package:vorrat/state/scan_queue.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  List<StockItem> batches = [
    StockItem(id: 1, productId: 1, amount: 5, productName: 'Jam', status: 'ok'),
  ];
  List<Map<String, dynamic>> consumeCalls = [];
  List<Map<String, dynamic>> addStockCalls = [];
  bool markedOpened = false;

  @override
  Future<BarcodeLookupResult> lookupBarcode(String code) async =>
      BarcodeLookupResult(source: 'local', localProduct: Product(id: 1, name: 'Jam', barcode: code));

  @override
  Future<List<Location>> listLocations() async => [];

  @override
  Future<void> addStock(Map<String, dynamic> payload) async {
    addStockCalls.add(payload);
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
  }) async => batches;

  @override
  Future<int> consumeStock(int id, double amount, {String reason = 'used'}) async {
    consumeCalls.add({'id': id, 'amount': amount, 'reason': reason});
    batches = [];
    return consumeCalls.length;
  }

  @override
  Future<void> markStockOpened(int id) async {
    markedOpened = true;
  }
}

Widget _wrap(ApiClient api) => MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<ScanQueue>(create: (_) => ScanQueue()),
        ChangeNotifierProvider<ScanHistory>(create: (_) => ScanHistory()),
        ChangeNotifierProxyProvider<ApiClient, StockProvider>(
          create: (_) => StockProvider(api),
          update: (_, api, previous) => previous ?? StockProvider(api),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ScanScreen(),
      ),
    );

Future<void> _enterBarcode(WidgetTester tester, String code) async {
  await tester.tap(find.byIcon(Icons.keyboard));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.text('Look up'));
  // Not pumpAndSettle -- _handling shows a continuously-animating spinner
  // while the lookup/action is in flight, which never settles. Pumping with
  // a small duration a few times flushes the async
  // lookupBarcode/listStock/action chain across frames instead.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // ScanHistory/ScanQueue persist via SharedPreferences -- without a mocked
  // channel, getInstance() never resolves in the test environment and every
  // scan silently stalls before reaching the mode dispatch.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Use mode consumes the whole batch immediately, no navigation', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    await _enterBarcode(tester, '1234567890123');

    expect(api.consumeCalls, [
      {'id': 1, 'amount': 5.0, 'reason': 'used'},
    ]);
    // Stayed on the Scan screen -- ready for the next scan.
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('Discard mode consumes the whole batch as spoiled', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    await _enterBarcode(tester, '1234567890123');

    expect(api.consumeCalls, [
      {'id': 1, 'amount': 5.0, 'reason': 'spoiled'},
    ]);
  });

  testWidgets('Open mode marks the batch opened, no amount involved', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await _enterBarcode(tester, '1234567890123');

    expect(api.markedOpened, isTrue);
    expect(api.consumeCalls, isEmpty);
  });

  testWidgets('nothing to act on shows an error and stays in the same mode', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    api.batches = []; // known product, but no stock on hand
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    await _enterBarcode(tester, '1234567890123');

    expect(api.consumeCalls, isEmpty);
    expect(find.textContaining('Nothing to act on'), findsOneWidget);
    // Mode selector is still showing "Use" as an available option -- the
    // scan screen itself, not some other flow, is still active.
    expect(find.text('Use'), findsOneWidget);
  });

  testWidgets('Add mode shows an inline sheet for a known product, no navigation', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    // Add is the default mode -- no need to switch segments first.
    await _enterBarcode(tester, '1234567890123');

    // The sheet appeared over the scan screen instead of pushing a route.
    expect(find.text('Jam'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Amount'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(api.addStockCalls, [
      {'product_id': 1, 'location_id': null, 'amount': 1.0, 'best_before_date': null},
    ]);
    // Sheet dismissed, snackbar confirms, still on the Scan screen.
    expect(find.text('Added "Jam" to stock.'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('Cancelling the add-batch sheet saves nothing', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_wrap(api));
    await tester.pumpAndSettle();

    await _enterBarcode(tester, '1234567890123');

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.addStockCalls, isEmpty);
    expect(find.text('Scan'), findsOneWidget);
  });
}
