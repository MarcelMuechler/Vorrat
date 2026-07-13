import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/widgets/category_field.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(SettingsProvider());
  final List<Category> categories = [Category(id: 1, name: 'Dairy')];
  int _nextId = 2;

  @override
  Future<List<Category>> listCategories() async => categories;

  @override
  Future<Category> createCategory(String name) async {
    final created = Category(id: _nextId++, name: name);
    categories.add(created);
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
    final key = GlobalKey<CategoryFieldState>();
    await tester.pumpWidget(
      _wrap(
        api,
        CategoryField(
          key: key,
          categoryId: null,
          categoryName: null,
          label: 'Category',
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
    final key = GlobalKey<CategoryFieldState>();
    await tester.pumpWidget(
      _wrap(
        api,
        CategoryField(
          key: key,
          categoryId: null,
          categoryName: null,
          label: 'Category',
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
    final key = GlobalKey<CategoryFieldState>();
    await tester.pumpWidget(
      _wrap(
        api,
        CategoryField(
          key: key,
          categoryId: null,
          categoryName: null,
          label: 'Category',
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
      final key = GlobalKey<CategoryFieldState>();
      await tester.pumpWidget(
        _wrap(
          api,
          Column(
            children: [
              CategoryField(
                key: key,
                categoryId: null,
                categoryName: null,
                label: 'Category',
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
}
