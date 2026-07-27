import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/widgets/named_entity_field.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(SettingsProvider());
  final List<Category> categories = [Category(id: 1, name: 'Dairy')];
  final List<Location> locations = [Location(id: 1, name: 'Pantry')];
  int _nextId = 2;

  @override
  Future<List<Category>> listCategories({int? limit, int? offset}) async => categories;

  @override
  Future<Category> createCategory(String name) async {
    final created = Category(id: _nextId++, name: name);
    categories.add(created);
    return created;
  }

  @override
  Future<List<Location>> listLocations() async => locations;

  @override
  Future<Location> createLocation(String name) async {
    final created = Location(id: _nextId++, name: name);
    locations.add(created);
    return created;
  }
}

Widget _wrap(ApiClient api, Widget child) => MultiProvider(
      providers: [Provider<ApiClient>.value(value: api)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('resolve() matches an existing category by name without creating a duplicate', (tester) async {
    final api = FakeApiClient();
    Category? reported;
    final key = GlobalKey<NamedEntityFieldState<Category>>();
    await tester.pumpWidget(
      _wrap(
        api,
        NamedEntityField<Category>(
          key: key,
          initialName: null,
          label: 'Category',
          clearTooltip: 'Clear',
          load: (api) => api.listCategories(),
          create: (api, name) => api.createCategory(name),
          errorMessage: (e) => 'failed: $e',
          onChanged: (c) => reported = c,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Dairy');
    await key.currentState!.resolve();

    expect(reported?.id, 1);
    expect(api.categories.length, 1);
  });

  testWidgets('resolve() creates a new category for text that matches nothing existing', (tester) async {
    final api = FakeApiClient();
    Category? reported;
    final key = GlobalKey<NamedEntityFieldState<Category>>();
    await tester.pumpWidget(
      _wrap(
        api,
        NamedEntityField<Category>(
          key: key,
          initialName: null,
          label: 'Category',
          clearTooltip: 'Clear',
          load: (api) => api.listCategories(),
          create: (api, name) => api.createCategory(name),
          errorMessage: (e) => 'failed: $e',
          onChanged: (c) => reported = c,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Snacks');
    await key.currentState!.resolve();

    expect(reported?.name, 'Snacks');
    expect(api.categories.map((c) => c.name), contains('Snacks'));
  });

  testWidgets('resolve() reports null when left blank', (tester) async {
    final api = FakeApiClient();
    Category? reported = Category(id: 99, name: 'placeholder');
    final key = GlobalKey<NamedEntityFieldState<Category>>();
    await tester.pumpWidget(
      _wrap(
        api,
        NamedEntityField<Category>(
          key: key,
          initialName: null,
          label: 'Category',
          clearTooltip: 'Clear',
          load: (api) => api.listCategories(),
          create: (api, name) => api.createCategory(name),
          errorMessage: (e) => 'failed: $e',
          onChanged: (c) => reported = c,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await key.currentState!.resolve();

    expect(reported, isNull);
  });

  testWidgets(
    'a save button that awaits resolve() before reading the value never races the create-category call',
    (tester) async {
      final api = FakeApiClient();
      Category? saved;
      final key = GlobalKey<NamedEntityFieldState<Category>>();
      await tester.pumpWidget(
        _wrap(
          api,
          Column(
            children: [
              NamedEntityField<Category>(
                key: key,
                initialName: null,
                label: 'Category',
                clearTooltip: 'Clear',
                load: (api) => api.listCategories(),
                create: (api, name) => api.createCategory(name),
                errorMessage: (e) => 'failed: $e',
                onChanged: (c) => saved = c,
              ),
              ElevatedButton(
                onPressed: () async {
                  await key.currentState?.resolve();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Frozen');
      // Tap Save immediately, with no separate blur/submit step first --
      // this is exactly the sequence that raced the async createCategory
      // call before _save() awaited resolve() explicitly.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved?.name, 'Frozen');
    },
  );

  // #338: the same field now backs locations, so a product's default
  // location can be typed inline instead of sending the user off to the
  // locations screen and back.
  testWidgets('resolve() creates a location that does not exist yet', (tester) async {
    final api = FakeApiClient();
    Location? reported;
    final key = GlobalKey<NamedEntityFieldState<Location>>();
    await tester.pumpWidget(
      _wrap(
        api,
        NamedEntityField<Location>(
          key: key,
          initialName: null,
          label: 'Location',
          clearTooltip: 'Clear',
          load: (api) => api.listLocations(),
          create: (api, name) => api.createLocation(name),
          errorMessage: (e) => 'failed: $e',
          onChanged: (l) => reported = l,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Cellar');
    await key.currentState!.resolve();

    expect(reported?.name, 'Cellar');
    expect(api.locations.map((l) => l.name), ['Pantry', 'Cellar']);
  });

  testWidgets('initialId prefills the name from the loaded list', (tester) async {
    final api = FakeApiClient();
    await tester.pumpWidget(
      _wrap(
        api,
        NamedEntityField<Location>(
          initialId: 1,
          label: 'Location',
          clearTooltip: 'Clear',
          load: (api) => api.listLocations(),
          create: (api, name) => api.createLocation(name),
          errorMessage: (e) => 'failed: $e',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pantry'), findsOneWidget);
  });

  testWidgets('an initialId field whose list failed to load reports nothing on resolve', (tester) async {
    // The form no longer blocks on this list, so a blank field can mean "the
    // load failed" -- resolving it must not clear the selection the owning
    // record already has.
    final api = _FailingApiClient();
    var reportCount = 0;
    final key = GlobalKey<NamedEntityFieldState<Location>>();
    await tester.pumpWidget(
      _wrap(
        api,
        NamedEntityField<Location>(
          key: key,
          initialId: 1,
          label: 'Location',
          clearTooltip: 'Clear',
          load: (api) => api.listLocations(),
          create: (api, name) => api.createLocation(name),
          errorMessage: (e) => 'failed: $e',
          onChanged: (_) => reportCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await key.currentState!.resolve(), isNull);
    expect(reportCount, 0);
  });
}

class _FailingApiClient extends FakeApiClient {
  @override
  Future<List<Location>> listLocations() async => throw Exception('offline');
}
