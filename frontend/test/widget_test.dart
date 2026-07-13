import 'package:flutter_test/flutter_test.dart';

import 'package:vorrat/main.dart';
import 'package:vorrat/state/scan_history.dart';
import 'package:vorrat/state/scan_queue.dart';
import 'package:vorrat/state/settings_provider.dart';

void main() {
  testWidgets('app boots to the Stock tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      VorratApp(settings: SettingsProvider(), scanQueue: ScanQueue(), scanHistory: ScanHistory()),
    );
    await tester.pump();

    expect(find.text('Stock'), findsWidgets);
  });
}
