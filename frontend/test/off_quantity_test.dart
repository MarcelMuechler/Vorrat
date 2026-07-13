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
  @override
  Future<List<Location>> listLocations() async => [];
}

void main() {
  testWidgets('prefills amount and unit from OFF quantity data', (tester) async {
    final api = FakeApiClient();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<StockProvider>(create: (_) => StockProvider(api)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProductDetailScreen(
            barcode: '5449000000996',
            prefill: ProductPrefill(
              barcode: '5449000000996',
              name: 'Coca-Cola',
              amount: 330.0,
              quantityUnit: 'ml',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('330.0'), findsOneWidget);
    expect(find.text('ml'), findsOneWidget);
  });
}
