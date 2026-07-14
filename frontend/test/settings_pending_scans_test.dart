import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/settings_screen.dart';
import 'package:vorrat/state/scan_queue.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

/// Stands in for the real backend -- SettingsScreen fires off a couple of
/// best-effort background loads (waste summary, expiring-soon days) that
/// this test doesn't care about, so just answer them instantly instead of
/// hitting the network.
class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);

  @override
  Future<List<ConsumptionLogEntry>> listConsumptionLog({DateTime? since, DateTime? until, String? reason}) async => [];

  @override
  Future<int> getExpiringSoonDays() async => 3;
}

Widget _wrap(SettingsProvider settings, ApiClient api, ScanQueue queue) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<ScanQueue>.value(value: queue),
        ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('pending scans tile is hidden when the queue is empty, shown once it has entries', (
    tester,
  ) async {
    // SettingsScreen's body is a plain (non-scrolling) Column, so give the
    // test surface enough height to lay it all out without tripping an
    // unrelated overflow -- this test cares about tile visibility, not layout.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    final queue = ScanQueue();
    await queue.load();

    await tester.pumpWidget(_wrap(settings, api, queue));
    await tester.pump();

    expect(find.text('Pending scans'), findsNothing);

    await queue.add('4260299353119');
    await tester.pump();

    expect(find.text('Pending scans'), findsOneWidget);
    expect(find.text('1 barcode waiting to be looked up'), findsOneWidget);

    await queue.remove(queue.pending.single);
    await tester.pump();

    expect(find.text('Pending scans'), findsNothing);
  });
}
