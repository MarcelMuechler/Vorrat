import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/product_batches_screen.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';
import 'package:vorrat/widgets/add_batch_sheet.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);
  bool opened = false;
  bool addStockCalled = false;

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
        StockItem(
          id: 1,
          productId: 1,
          amount: 2,
          productName: 'Jam',
          status: 'ok',
          openedAt: opened ? DateTime(2026, 1, 1) : null,
        ),
      ];

  @override
  Future<void> markStockOpened(int id) async {
    opened = true;
  }

  @override
  Future<List<Location>> listLocations() async => [];

  @override
  Future<void> addStock(Map<String, dynamic> payload) async {
    addStockCalled = true;
  }
}

Widget _app(ApiClient api, SettingsProvider settings, {Locale? locale}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProductBatchesScreen(productId: 1, productName: 'Jam'),
      ),
    );

void main() {
  // The summary action row keeps its icon+label buttons where there's room --
  // even the longer German labels render as text on a wide layout.
  testWidgets('summary action buttons keep their labels when there is room (German)', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_app(api, settings, locale: const Locale('de')));
    await tester.pumpAndSettle();

    expect(find.text('Verbraucht'), findsOneWidget);
    expect(find.text('Verdorben'), findsOneWidget);
    expect(find.text('Hinzufügen'), findsOneWidget);
  });

  // Regression test (#222): on a narrow German phone the three squeezed
  // buttons used to clip their labels; now they fall back to icon-only
  // buttons with the label in a Tooltip. A leftover overflow throws during
  // pump, so rendering without an exception is itself the assertion.
  //
  // Also a regression test (#252): the icon-only fallback used to wrap each
  // IconButton in a separate Tooltip widget, which never reaches Flutter
  // Web's semantics tree -- screen readers saw three unlabeled buttons. The
  // fix moved the label into IconButton's own `tooltip:` param, which Flutter
  // folds into the accessible name on the web (SemanticsData.tooltip, see
  // web_ui's computeDomSemanticsLabel) -- so this also asserts each button's
  // semantics tooltip is non-empty and matches the expected German text.
  testWidgets('summary action buttons fall back to icon-only on a narrow German phone', (tester) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });
    final semanticsHandle = tester.ensureSemantics();

    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    await tester.pumpWidget(_app(api, settings, locale: const Locale('de')));
    await tester.pumpAndSettle();

    expect(find.text('Verbraucht'), findsNothing);
    expect(find.text('Verdorben'), findsNothing);
    expect(find.text('Hinzufügen'), findsNothing);
    expect(find.byTooltip('Verbraucht'), findsOneWidget);
    expect(find.byTooltip('Verdorben'), findsOneWidget);
    expect(find.byTooltip('Hinzufügen'), findsOneWidget);

    // The accessible name (#252) is carried by the semantics tooltip, which
    // IconButton's own `tooltip:` param populates -- unlike a separate
    // Tooltip(child: IconButton(...)) wrapper, which never attaches to this
    // node at all. Note: there's also a FAB using Icons.add on this screen,
    // so scope by the (unique) Tooltip finder rather than the icon itself.
    expect(tester.getSemantics(find.byIcon(Icons.check_circle_outline)).tooltip, 'Verbraucht');
    expect(tester.getSemantics(find.byIcon(Icons.delete_outline)).tooltip, 'Verdorben');
    expect(tester.getSemantics(find.byTooltip('Hinzufügen')).tooltip, 'Hinzufügen');

    semanticsHandle.dispose();
  });

  testWidgets('marking a batch opened hides the open button', (tester) async {
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
          home: const ProductBatchesScreen(productId: 1, productName: 'Jam'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The product detail screen's expiry banner also shows the amount ("2"),
    // so the batch row's own "2" (rendered below it) is the last match.
    // Tap the tile to reveal the Open/Use/Spoil buttons (#75).
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_open), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pumpAndSettle();
    expect(api.opened, isTrue);

    // Re-expand -- Open is no longer offered once the batch is opened.
    await tester.tap(find.text('2').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_open), findsNothing);
  });

  testWidgets('the FAB adds a new batch to the same product', (tester) async {
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
          home: const ProductBatchesScreen(productId: 1, productName: 'Jam'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The FAB now opens the lightweight AddBatchSheet (not a full
    // ProductDetailScreen push) since the product already exists.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Jam'), findsWidgets);

    // The product detail screen's own action row also has an "Add" button
    // (opens this same sheet) -- scope the tap to the sheet's own button.
    await tester.tap(
      find.descendant(of: find.byType(AddBatchSheet), matching: find.widgetWithText(FilledButton, 'Add')),
    );
    await tester.pumpAndSettle();

    expect(api.addStockCalled, isTrue);
  });

  // Regression test (#252): the AddBatchSheet's icon-only quantity +/-
  // steppers had no tooltip at all (a plainer variant of the same
  // no-accessible-name bug the batch action buttons had), so screen readers
  // couldn't tell them apart either. Both now set IconButton's own
  // `tooltip:` param, which Flutter folds into the accessible name on the
  // web (SemanticsData.tooltip).
  testWidgets('quantity stepper buttons in the add-batch sheet have an accessible name', (tester) async {
    final settings = SettingsProvider();
    final api = FakeApiClient(settings);
    final semanticsHandle = tester.ensureSemantics();
    await tester.pumpWidget(_app(api, settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Scoped to the sheet -- the underlying screen has its own Icons.add
    // (FAB and/or the wide-layout action row) that would otherwise collide.
    final sheet = find.byType(AddBatchSheet);
    expect(
      tester.getSemantics(find.descendant(of: sheet, matching: find.byIcon(Icons.remove))).tooltip,
      'Decrease amount',
    );
    expect(
      tester.getSemantics(find.descendant(of: sheet, matching: find.byIcon(Icons.add))).tooltip,
      'Increase amount',
    );

    semanticsHandle.dispose();
  });
}
