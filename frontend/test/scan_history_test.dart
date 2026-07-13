import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vorrat/state/scan_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records a scan and persists it across a reload', () async {
    final history = ScanHistory();
    await history.load();
    expect(history.entries, isEmpty);

    await history.add('4260299353119', 'Milk');
    expect(history.entries.single.barcode, '4260299353119');
    expect(history.entries.single.name, 'Milk');

    final reloaded = ScanHistory();
    await reloaded.load();
    expect(reloaded.entries.single.barcode, '4260299353119');
  });

  test('re-scanning moves the entry to the front with the latest name', () async {
    final history = ScanHistory();
    await history.load();
    await history.add('111', 'First');
    await history.add('222', 'Second');
    await history.add('111', 'First (renamed)');

    expect(history.entries.length, 2);
    expect(history.entries.first.barcode, '111');
    expect(history.entries.first.name, 'First (renamed)');
  });

  test('caps history at 20 entries', () async {
    final history = ScanHistory();
    await history.load();
    for (var i = 0; i < 25; i++) {
      await history.add('$i', 'Product $i');
    }
    expect(history.entries.length, 20);
    expect(history.entries.first.barcode, '24');
  });
}
