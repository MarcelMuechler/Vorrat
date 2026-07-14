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
}
