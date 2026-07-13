import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vorrat/screens/scan_screen.dart';

void main() {
  test('accepts correctly-sized EAN/UPC formats', () {
    expect(isPlausibleBarcode('4260299353119', BarcodeFormat.ean13), isTrue);
    expect(isPlausibleBarcode('40123455', BarcodeFormat.ean8), isTrue);
    expect(isPlausibleBarcode('012345678905', BarcodeFormat.upcA), isTrue);
  });

  test('rejects the wrong digit count for a known numeric format', () {
    expect(isPlausibleBarcode('123', BarcodeFormat.ean13), isFalse);
    expect(isPlausibleBarcode('123456789012345', BarcodeFormat.ean13), isFalse);
  });

  test('rejects empty or whitespace-only input regardless of format', () {
    expect(isPlausibleBarcode('', BarcodeFormat.ean13), isFalse);
    expect(isPlausibleBarcode('   ', null), isFalse);
  });

  test('is permissive for formats that legitimately vary (QR, Code128)', () {
    expect(isPlausibleBarcode('https://example.com', BarcodeFormat.qrCode), isTrue);
    expect(isPlausibleBarcode('ABC-123-xyz', BarcodeFormat.code128), isTrue);
  });

  test('applies a loose digit-length check for manual entry (no known format)', () {
    expect(isPlausibleBarcode('4260299353119', null), isTrue);
    expect(isPlausibleBarcode('12', null), isFalse);
    expect(isPlausibleBarcode('not-a-barcode', null), isFalse);
  });
}
