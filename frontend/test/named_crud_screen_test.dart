import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/screens/categories_screen.dart';
import 'package:vorrat/screens/locations_screen.dart';
import 'package:vorrat/state/settings_provider.dart';

/// Records what the screen asked the backend to do, so the shared
/// [NamedCrudScreen] can be checked to route each entity's callbacks to the
/// right API method.
class FakeApiClient extends ApiClient {
  FakeApiClient(super.settings);

  final List<String> calls = [];

  @override
  Future<List<Category>> listCategories({int? limit, int? offset}) async {
    calls.add('listCategories');
    return [Category(id: 1, name: 'Dairy'), Category(id: 2, name: 'Bakery')];
  }

  @override
  Future<List<Location>> listLocations() async {
    calls.add('listLocations');
    return [Location(id: 1, name: 'Fridge')];
  }

  @override
  Future<void> deleteCategory(int id) async => calls.add('deleteCategory:$id');

  @override
  Future<void> deleteLocation(int id) async => calls.add('deleteLocation:$id');
}

Widget _wrap(FakeApiClient api, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      Provider<ApiClient>.value(value: api),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('CategoriesScreen lists categories from listCategories', (tester) async {
    final api = FakeApiClient(SettingsProvider());
    await tester.pumpWidget(_wrap(api, const CategoriesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Dairy'), findsOneWidget);
    expect(find.text('Bakery'), findsOneWidget);
    expect(api.calls, contains('listCategories'));
  });

  testWidgets('LocationsScreen lists locations from listLocations', (tester) async {
    final api = FakeApiClient(SettingsProvider());
    await tester.pumpWidget(_wrap(api, const LocationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Fridge'), findsOneWidget);
    expect(api.calls, contains('listLocations'));
  });

  testWidgets('deleting routes to the entity-specific API call', (tester) async {
    final api = FakeApiClient(SettingsProvider());
    await tester.pumpWidget(_wrap(api, const LocationsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('deleteLocation:1'));
    expect(api.calls.any((c) => c.startsWith('deleteCategory')), isFalse);
  });
}
