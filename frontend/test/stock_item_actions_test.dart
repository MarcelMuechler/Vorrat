import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vorrat/l10n/app_localizations.dart';
import 'package:vorrat/widgets/stock_item_actions.dart';

Widget _wrap({
  required bool canOpen,
  required VoidCallback onOpen,
  required Future<void> Function(double, String) onConsume,
  required Future<bool> Function() onDelete,
}) =>
    MaterialApp(
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
      _wrap(canOpen: false, onOpen: () {}, onConsume: (_, _) async {}, onDelete: () async => true),
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
        onConsume: (_, reason) async => consumedReason = reason,
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
        },
        onDelete: () async => true,
      ),
    );

    await tester.drag(find.text('Jam'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(consumedAmount, 2);
    expect(consumedReason, 'used');
  });

  testWidgets('swiping left deletes the batch, no dialog', (tester) async {
    var deleteCalled = false;
    await tester.pumpWidget(
      _wrap(
        canOpen: true,
        onOpen: () {},
        onConsume: (_, _) async {},
        onDelete: () async {
          deleteCalled = true;
          return true;
        },
      ),
    );

    await tester.drag(find.text('Jam'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(deleteCalled, isTrue);
  });
}
