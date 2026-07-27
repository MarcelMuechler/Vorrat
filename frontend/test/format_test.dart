import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vorrat/util/format.dart';

void main() {
  test('whole numbers render without a decimal point (#133)', () {
    expect(formatAmount(3.0), '3');
    expect(formatAmount(0.0), '0');
    expect(formatAmount(2.50), '2.5');
  });

  test('fractional amounts keep up to 2 decimals with trailing zeros trimmed', () {
    expect(formatAmount(1.5), '1.5');
    expect(formatAmount(0.25), '0.25');
  });


  // #324: prices used to render as bare numbers, so a German household was
  // told its stock was worth "47.5".
  testWidgets('formatMoney renders the configured currency for the locale', (tester) async {
    late BuildContext german;
    late BuildContext english;
    await tester.pumpWidget(
      Column(
        textDirection: TextDirection.ltr,
        children: [
          Localizations(
            locale: const Locale('de'),
            delegates: const [DefaultWidgetsLocalizations.delegate, DefaultMaterialLocalizations.delegate],
            child: Builder(builder: (context) {
              german = context;
              return const SizedBox();
            }),
          ),
          Localizations(
            locale: const Locale('en'),
            delegates: const [DefaultWidgetsLocalizations.delegate, DefaultMaterialLocalizations.delegate],
            child: Builder(builder: (context) {
              english = context;
              return const SizedBox();
            }),
          ),
        ],
      ),
    );

    expect(formatMoney(german, 47.5, 'EUR'), contains('47,50'));
    expect(formatMoney(english, 47.5, 'USD'), '\$47.50');
    // An unrecognized code degrades to showing the code, never throws.
    expect(formatMoney(english, 1, 'XTS'), contains('XTS'));
  });
}
