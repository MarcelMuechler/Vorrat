import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/client.dart';
import 'screens/scan_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stock_overview_screen.dart';
import 'state/scan_queue.dart';
import 'state/settings_provider.dart';
import 'state/stock_provider.dart';

/// Whether the device has a usable camera, per `ScanScreen`'s
/// `MobileScanner.errorBuilder` (the only way mobile_scanner reports this —
/// it has no standalone check). Starts true so the Scan tab shows until
/// proven otherwise; flips false (and stays false) the first time starting
/// the scanner fails with [MobileScannerErrorCode.unsupported].
final ValueNotifier<bool> cameraAvailable = ValueNotifier<bool>(true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsProvider();
  await settings.load();
  final scanQueue = ScanQueue();
  await scanQueue.load();
  runApp(VorratApp(settings: settings, scanQueue: scanQueue));
}

class VorratApp extends StatelessWidget {
  final SettingsProvider settings;
  final ScanQueue scanQueue;

  const VorratApp({super.key, required this.settings, required this.scanQueue});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: scanQueue),
        ProxyProvider<SettingsProvider, ApiClient>(
          update: (_, settings, _) => ApiClient(settings),
        ),
        ChangeNotifierProxyProvider<ApiClient, StockProvider>(
          create: (context) => StockProvider(context.read<ApiClient>()),
          update: (_, api, previous) => previous ?? StockProvider(api),
        ),
      ],
      child: MaterialApp(
        title: 'Vorrat',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        ),
        home: const HomeShell(),
      ),
    );
  }
}

enum _AppTab { stock, scan, settings }

class _Tab {
  final _AppTab id;
  final Widget screen;
  final NavigationDestination destination;

  const _Tab({required this.id, required this.screen, required this.destination});
}

const _allTabs = [
  _Tab(
    id: _AppTab.stock,
    screen: StockOverviewScreen(),
    destination: NavigationDestination(icon: Icon(Icons.kitchen), label: 'Stock'),
  ),
  _Tab(
    id: _AppTab.scan,
    screen: ScanScreen(),
    destination: NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
  ),
  _Tab(
    id: _AppTab.settings,
    screen: SettingsScreen(),
    destination: NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
  ),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  _AppTab _selected = _AppTab.stock;

  @override
  Widget build(BuildContext context) {
    final pendingScans = context.watch<ScanQueue>().length;

    return ValueListenableBuilder<bool>(
      valueListenable: cameraAvailable,
      builder: (context, hasCamera, _) {
        final tabs = hasCamera ? _allTabs : _allTabs.where((t) => t.id != _AppTab.scan).toList();
        var index = tabs.indexWhere((t) => t.id == _selected);
        if (index == -1) index = 0; // the selected tab (Scan) just disappeared
        return Scaffold(
          body: tabs[index].screen,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _selected = tabs[i].id),
            destinations: [
              for (final t in tabs)
                t.id == _AppTab.scan && pendingScans > 0
                    ? NavigationDestination(
                        icon: Badge(
                          label: Text('$pendingScans'),
                          child: const Icon(Icons.qr_code_scanner),
                        ),
                        label: 'Scan',
                      )
                    : t.destination,
            ],
          ),
        );
      },
    );
  }
}
