import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vorrat/state/scan_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('queues a scan and persists it across a reload', () async {
    final queue = ScanQueue();
    await queue.load();
    expect(queue.length, 0);

    await queue.add('4260299353119');
    expect(queue.length, 1);
    expect(queue.pending.single.barcode, '4260299353119');

    final reloaded = ScanQueue();
    await reloaded.load();
    expect(reloaded.length, 1);
    expect(reloaded.pending.single.barcode, '4260299353119');
  });

  test('removes a queued scan', () async {
    final queue = ScanQueue();
    await queue.load();
    await queue.add('111');
    await queue.add('222');
    expect(queue.length, 2);

    await queue.remove(queue.pending.first);
    expect(queue.length, 1);
    expect(queue.pending.single.barcode, '222');
  });
}
