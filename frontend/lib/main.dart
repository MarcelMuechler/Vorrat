import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/client.dart';
import 'l10n/app_localizations.dart';
import 'screens/scan_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shopping_list_screen.dart';
import 'screens/stock_overview_screen.dart';
import 'state/scan_history.dart';
import 'state/scan_queue.dart';
import 'state/settings_provider.dart';
import 'state/stock_provider.dart';

// One deliberate theme for both brightnesses (#199) -- the M3 seed defaults
// left surfaces flat (near-black in dark mode with no layering) and every
// text field/dialog relying on Flutter's bare OutlineInputBorder. Filled,
// tonal surfaces give the filter row and cards a visible base to sit on.
ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: brightness);
  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarThemeData(backgroundColor: colorScheme.surface, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.secondaryContainer,
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: colorScheme.surfaceContainer),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      actionTextColor: colorScheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsProvider();
  await settings.load();
  final scanQueue = ScanQueue();
  await scanQueue.load();
  final scanHistory = ScanHistory();
  await scanHistory.load();
  runApp(VorratApp(settings: settings, scanQueue: scanQueue, scanHistory: scanHistory));
}

class VorratApp extends StatelessWidget {
  final SettingsProvider settings;
  final ScanQueue scanQueue;
  final ScanHistory scanHistory;

  const VorratApp({
    super.key,
    required this.settings,
    required this.scanQueue,
    required this.scanHistory,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: scanQueue),
        ChangeNotifierProvider.value(value: scanHistory),
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }
}

enum _AppTab { stock, shopping, scan, settings }

class _Tab {
  final _AppTab id;
  final Widget screen;
  final IconData icon;
  final String label;

  const _Tab({required this.id, required this.screen, required this.icon, required this.label});
}

List<_Tab> _allTabs(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return [
    _Tab(id: _AppTab.stock, screen: const StockOverviewScreen(), icon: Icons.kitchen, label: l10n.stockTitle),
    _Tab(
      id: _AppTab.shopping,
      screen: const ShoppingListScreen(),
      icon: Icons.shopping_cart_outlined,
      label: l10n.shoppingListTitle,
    ),
    _Tab(id: _AppTab.scan, screen: const ScanScreen(), icon: Icons.qr_code_scanner, label: l10n.scanTitle),
    _Tab(id: _AppTab.settings, screen: const SettingsScreen(), icon: Icons.settings, label: l10n.settingsTitle),
  ];
}

/// Main content is centered and capped at this width on wide screens so text
/// and lists don't stretch uncomfortably far (#135). The bottom [NavigationBar]
/// is kept at every width, even wide desktop/HA-panel layouts (#199 wireframe
/// revamp) -- Home Assistant's own left sidebar already fills the "rail"
/// role there, so a second one would be redundant.
const double _contentMaxWidth = 900;

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
    final scanEnabled = context.watch<SettingsProvider>().scanEnabled;

    final allTabs = _allTabs(context);
    final tabs = scanEnabled ? allTabs : allTabs.where((t) => t.id != _AppTab.scan).toList();
    var index = tabs.indexWhere((t) => t.id == _selected);
    if (index == -1) index = 0; // the selected tab (Scan) just disappeared

    Widget iconFor(_Tab t) => t.id == _AppTab.scan && pendingScans > 0
        ? Badge(label: Text('$pendingScans'), child: Icon(t.icon))
        : Icon(t.icon);

    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: tabs[index].screen,
      ),
    );

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _selected = tabs[i].id),
        destinations: [for (final t in tabs) NavigationDestination(icon: iconFor(t), label: t.label)],
      ),
    );
  }
}
