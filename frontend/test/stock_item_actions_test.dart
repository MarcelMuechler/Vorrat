import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/widgets/stock_item_actions.dart';

Widget _wrap({
  required bool canOpen,
  required VoidCallback onOpen,
  required Future<bool> Function(double, String) onConsume,
  required Future<bool> Function() onDelete,
  Locale? locale,
}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StockItemActions(
          leading: const Icon(Icons.circle),
          title: const Text('Jam'),
          subtitle: const Text('Fridge'),
          amount: 2,
          productName: 'Jam',
          canOpen: canOpen,
          onOpen: onOpen,
          onConsume: onConsume,
          onDelete: onDelete,
          dismissibleKey: 1,
        ),
      ),
    );

void main() {
  testWidgets('tapping the tile reveals Open/Use/Spoil, Open omitted once opened', (tester) async {
    await tester.pumpWidget(
      _wrap(canOpen: false, onOpen: () {}, onConsume: (_, _) async => true, onDelete: () async => true),
    );

    expect(find.text('Used'), findsNothing);

    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_open), findsNothing); // canOpen: false
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Spoiled'), findsOneWidget);
  });

  testWidgets('tapping Use prompts for an amount and reports it with reason "used"', (tester) async {
    double? consumedAmount;
    String? consumedReason;
    await tester.pumpWidget(
      _wrap(
        canOpen: true,
        onOpen: () {},
        onConsume: (amount, reason) async {
          consumedAmount = amount;
          consumedReason = reason;
          return true;
        },
        onDelete: () async => true,
      ),
    );

    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Used'));
    await tester.pumpAndSettle();

    // Prefilled with the full amount -- confirm as-is.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(consumedAmount, 2);
    expect(consumedReason, 'used');
  });

  testWidgets('tapping Spoil prompts for an amount and reports it with reason "spoiled"', (tester) async {
    String? consumedReason;
    await tester.pumpWidget(
      _wrap(
        canOpen: true,
        onOpen: () {},
        onConsume: (_, reason) async {
          consumedReason = reason;
          return true;
        },
        onDelete: () async => true,
      ),
    );

    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spoiled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(consumedReason, 'spoiled');
  });

  testWidgets('swiping right consumes the whole amount as used, no dialog', (tester) async {
    double? consumedAmount;
    String? consumedReason;
    await tester.pumpWidget(
      _wrap(
        canOpen: true,
        onOpen: () {},
        onConsume: (amount, reason) async {
          consumedAmount = amount;
          consumedReason = reason;
          return true;
        },
        onDelete: () async => true,
      ),
    );

    await tester.drag(find.text('Jam'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(consumedAmount, 2);
    expect(consumedReason, 'used');
  });

  testWidgets('typing more than what is in stock shows an error and blocks submission (#156)', (tester) async {
    double? consumedAmount;
    await tester.pumpWidget(
      _wrap(
        canOpen: true,
        onOpen: () {},
        onConsume: (amount, _) async {
          consumedAmount = amount;
          return true;
        },
        onDelete: () async => true,
      ),
    );

    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Used'));
    await tester.pumpAndSettle();

    // widget.amount is 2 (see _wrap) -- 3 exceeds what's actually in stock.
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Dialog stays open showing the error -- onConsume was never called.
    expect(find.textContaining('at most 2'), findsOneWidget);
    expect(consumedAmount, isNull);

    // Correcting it to a valid amount still works.
    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(consumedAmount, 2);
  });

  testWidgets('swiping left spoils the whole amount, no dialog', (tester) async {
    double? consumedAmount;
    String? consumedReason;
    var deleteCalled = false;
    await tester.pumpWidget(
      _wrap(
        canOpen: true,
        onOpen: () {},
        onConsume: (amount, reason) async {
          consumedAmount = amount;
          consumedReason = reason;
          return true;
        },
        onDelete: () async {
          deleteCalled = true;
          return true;
        },
      ),
    );

    await tester.drag(find.text('Jam'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Matches the visible "Spoiled" swipe background -- same immediate,
    // no-dialog behavior as swipe-right, just the other reason. Delete
    // (with its confirmation) stays reachable via long-press only.
    expect(consumedAmount, 2);
    expect(consumedReason, 'spoiled');
    expect(deleteCalled, isFalse);
  });

  // On a wide layout there's room for the full icon+label buttons, so the
  // German labels render as text -- even the long "Als geöffnet markieren".
  testWidgets('action buttons keep their labels when there is room (canOpen: true, German)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        canOpen: true,
        onOpen: () {},
        onConsume: (_, _) async => true,
        onDelete: () async => true,
        locale: const Locale('de'),
      ),
    );

    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();

    expect(find.text('Als geöffnet markieren'), findsOneWidget);
    expect(find.text('Verbraucht'), findsOneWidget);
    expect(find.text('Verdorben'), findsOneWidget);
  });

  // Regression test (#222): three icon+label buttons with the longer German
  // labels can't fit one line on a narrow phone. #221's Wrap dropped a button
  // to a second line (unpredictable height); the fix falls back to icon-only
  // buttons whose label is carried by a Tooltip. A leftover overflow throws
  // during pump, so simply rendering without an exception is the assertion --
  // plus the labels being gone as visible text and the icons still present.
  //
  // Also a regression test (#252): the icon-only fallback used to wrap each
  // IconButton in a separate Tooltip widget, which never reaches Flutter
  // Web's semantics tree -- screen readers saw three unlabeled buttons. The
  // fix moved the label into IconButton's own `tooltip:` param, which Flutter
  // folds into the accessible name on the web (SemanticsData.tooltip, see
  // web_ui's computeDomSemanticsLabel) -- so this also asserts each button's
  // semantics tooltip is non-empty and matches the expected German text.
  testWidgets('action buttons fall back to icon-only on a narrow German phone (canOpen: true)', (
    tester,
  ) async {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        canOpen: true,
        onOpen: () {},
        onConsume: (_, _) async => true,
        onDelete: () async => true,
        locale: const Locale('de'),
      ),
    );

    await tester.tap(find.text('Jam'));
    await tester.pumpAndSettle();

    // Labels no longer take horizontal space -- they moved into Tooltips.
    expect(find.text('Als geöffnet markieren'), findsNothing);
    expect(find.text('Verbraucht'), findsNothing);
    expect(find.text('Verdorben'), findsNothing);
    expect(find.byTooltip('Verbraucht'), findsOneWidget);
    expect(find.byTooltip('Verdorben'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);

    // The accessible name (#252) is carried by the semantics tooltip, which
    // IconButton's own `tooltip:` param populates -- unlike a separate
    // Tooltip(child: IconButton(...)) wrapper, which never attaches to this
    // node at all.
    expect(tester.getSemantics(find.byIcon(Icons.lock_open)).tooltip, 'Als geöffnet markieren');
    expect(tester.getSemantics(find.byIcon(Icons.check_circle_outline)).tooltip, 'Verbraucht');
    expect(tester.getSemantics(find.byIcon(Icons.delete_outline)).tooltip, 'Verdorben');

    semanticsHandle.dispose();
  });
}
