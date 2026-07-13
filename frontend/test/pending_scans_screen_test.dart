import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/pending_scans_screen.dart';
import 'package:vorrat/state/scan_queue.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

/// Stands in for the real backend so this test can drive the sync flow
/// without a network -- mirrors what a successful lookup+save looks like
/// once the server is reachable again.
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(SettingsProvider());

  @override
  Future<BarcodeLookupResult> lookupBarcode(String code) async {
    return BarcodeLookupResult(source: 'off', prefill: ProductPrefill(barcode: code, name: 'Test Product'));
  }

  @override
  Future<List<Location>> listLocations() async => [];

  @override
  Future<Product> createProduct(Map<String, dynamic> payload) async {
    return Product(id: 1, name: payload['name'] as String, barcode: payload['barcode'] as String?);
  }

  @override
  Future<void> addStock(Map<String, dynamic> payload) async {}

  @override
  Future<List<StockItem>> listStock({int? locationId, String? search, int? expiringWithinDays}) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('syncing a pending scan removes it once the product is saved', (tester) async {
    final api = FakeApiClient();
    final queue = ScanQueue();
    await queue.load();
    await queue.add('4260299353119');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<ScanQueue>.value(value: queue),
          ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
        ],
        child: const MaterialApp(home: PendingScansScreen()),
      ),
    );

    expect(find.text('4260299353119'), findsOneWidget);

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    // The lookup succeeded, so we should have navigated to the normal
    // add-to-stock flow, prefilled from the fake OFF lookup.
    expect(find.text('Add to stock'), findsOneWidget);
    expect(find.text('Test Product'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(queue.length, 0);
  });
}
