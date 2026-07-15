import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/scan_queue.dart';
import '../state/settings_provider.dart';
import '../state/stock_provider.dart';
import '../util/open_url.dart';
import 'categories_screen.dart';
import 'locations_screen.dart';
import 'pending_scans_screen.dart';
import 'products_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  late final TextEditingController _expiringSoonController;
  String? _testResult;
  bool _testing = false;
  bool _savingExpiringSoon = false;
  int? _wastedThisMonth;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<SettingsProvider>().serverUrl);
    _expiringSoonController = TextEditingController(text: '${context.read<StockProvider>().expiringSoonDays}');
    _loadExpiringSoonDays();
    _loadWasteSummary();
  }

  Future<void> _loadWasteSummary() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    try {
      final entries = await context.read<ApiClient>().listConsumptionLog(
        since: startOfMonth,
        reason: 'spoiled',
      );
      if (mounted) setState(() => _wastedThisMonth = entries.length);
    } catch (_) {
      // Silent -- this is a small supplementary stat, not worth its own
      // error state on top of the rest of the screen's.
    }
  }

  Future<void> _loadExpiringSoonDays() async {
    final stock = context.read<StockProvider>();
    await stock.loadExpiringSoonDays();
    if (mounted) _expiringSoonController.text = '${stock.expiringSoonDays}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _expiringSoonController.dispose();
    super.dispose();
  }

  Future<void> _saveExpiringSoonDays() async {
    final l10n = AppLocalizations.of(context)!;
    final days = int.tryParse(_expiringSoonController.text);
    if (days == null || days <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterWholeNumber)));
      return;
    }
    setState(() => _savingExpiringSoon = true);
    final api = context.read<ApiClient>();
    final stock = context.read<StockProvider>();
    try {
      await api.setExpiringSoonDays(days);
      await stock.loadExpiringSoonDays();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotSave('$e'))));
      }
    } finally {
      if (mounted) setState(() => _savingExpiringSoon = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final api = context.read<ApiClient>();
    await settings.setServerUrl(_controller.text);
    final health = await api.checkHealth();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = health != null
          ? l10n.connectedVersion('${health['version']}')
          : l10n.couldNotReachServer;
    });
  }

  Future<void> _exportStockCsv() async {
    final l10n = AppLocalizations.of(context)!;
    final url = context.read<ApiClient>().exportStockCsvUrl();
    try {
      await openInBrowser(url.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotExport('$e'))));
      }
    }
  }

  Future<void> _exportConsumptionLogCsv() async {
    final l10n = AppLocalizations.of(context)!;
    final url = context.read<ApiClient>().exportConsumptionLogCsvUrl();
    try {
      await openInBrowser(url.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotExport('$e'))));
      }
    }
  }

  Future<void> _importStockCsv() async {
    const typeGroup = XTypeGroup(label: 'csv', extensions: ['csv'], mimeTypes: ['text/csv']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final api = context.read<ApiClient>();
    final stock = context.read<StockProvider>();
    try {
      final csv = await file.readAsString();
      final result = await api.importStockCsv(csv);
      if (!mounted) return;
      await stock.refresh();
      if (!mounted) return;
      await _showImportResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotImport('$e'))));
      }
    }
  }

  Future<void> _showImportResult(StockImportResult result) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importResultTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.importedCount(result.imported)),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.importErrorsHeading(result.errors.length)),
                const SizedBox(height: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: result.errors.length,
                      itemBuilder: (context, index) {
                        final error = result.errors[index];
                        return Text(l10n.importRowError(error.row, error.error));
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.closeButton)),
        ],
      ),
    );
  }

  Future<void> _scanToConnect() async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrConnectScanner()),
    );
    if (url == null || !mounted) return;
    _controller.text = url;
    await _testConnection();
  }

  // Groups a section's children into a bordered, labeled card (#199
  // wireframe revamp) -- pure layout wrapper, no behavior change to what's
  // inside.
  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final pendingScans = context.watch<ScanQueue>().length;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(context, l10n.settingsConnectionSection, [
                Text(l10n.serverUrlDescription),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: l10n.serverUrlLabel,
                    hintText: 'http://192.168.1.20:8099',
                    suffixIcon: settings.scanEnabled
                        ? IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            tooltip: l10n.scanToConnectTooltip,
                            onPressed: _scanToConnect,
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _testing ? null : _testConnection,
                  child: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.saveTestConnectionButton),
                ),
                if (_testResult != null) ...[const SizedBox(height: 8), Text(_testResult!)],
              ]),
              _section(context, l10n.settingsPreferencesSection, [
                Text(l10n.expiringSoonDescription),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _expiringSoonController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _savingExpiringSoon ? null : _saveExpiringSoonDays,
                      child: _savingExpiringSoon
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l10n.saveButton),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.qr_code_scanner),
                  title: Text(l10n.barcodeScanningTitle),
                  subtitle: Text(l10n.barcodeScanningSubtitle),
                  value: settings.scanEnabled,
                  onChanged: settings.setScanEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.category_outlined),
                  title: Text(l10n.offCategorySuggestionsTitle),
                  subtitle: Text(l10n.offCategorySuggestionsSubtitle),
                  value: settings.offCategorySuggestionsEnabled,
                  onChanged: settings.setOffCategorySuggestionsEnabled,
                ),
                if (pendingScans > 0)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pending_actions),
                    title: Text(l10n.pendingScans),
                    subtitle: Text(l10n.pendingScansSubtitle(pendingScans)),
                    trailing: Badge(label: Text('$pendingScans'), child: const Icon(Icons.chevron_right)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PendingScansScreen()),
                    ),
                  ),
              ]),
              _section(context, l10n.settingsManageSection, [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(l10n.locationsTitle),
                  subtitle: Text(l10n.locationsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocationsScreen())),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(l10n.productsTitle),
                  subtitle: Text(l10n.productsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductsScreen())),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.category_outlined),
                  title: Text(l10n.categoriesTitle),
                  subtitle: Text(l10n.categoriesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                ),
              ]),
              _section(context, l10n.settingsDataSection, [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(l10n.exportCsvTitle),
                  subtitle: Text(l10n.exportCsvSubtitle),
                  onTap: _exportStockCsv,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_upload_outlined),
                  title: Text(l10n.importCsvTitle),
                  subtitle: Text(l10n.importCsvSubtitle),
                  onTap: _importStockCsv,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(l10n.exportConsumptionLogCsvTitle),
                  subtitle: Text(l10n.exportConsumptionLogCsvSubtitle),
                  onTap: _exportConsumptionLogCsv,
                ),
                if (_wastedThisMonth != null) ...[
                  const Divider(),
                  Text(l10n.spoiledThisMonth(_wastedThisMonth!)),
                ],
              ]),
              if (kIsWeb) ...[
                Text(l10n.pairDeviceHint),
                const SizedBox(height: 12),
                Center(
                  child: QrImageView(
                    // Always port 8099, regardless of how this page itself was
                    // reached — matters when this loads through HA Ingress
                    // (a dynamic, session-bound proxy path another device can't
                    // use), where the pairable address is still the add-on's
                    // own direct LAN port (see vorrat/DOCS.md).
                    data: '${Uri.base.scheme}://${Uri.base.host}:8099',
                    size: 220,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Scans a QR code (or any barcode) and pops with its decoded text, treated
/// as a server URL by the caller — pairs with the QR code the web UI shows
/// on itself further up this screen.
class _QrConnectScanner extends StatefulWidget {
  const _QrConnectScanner();

  @override
  State<_QrConnectScanner> createState() => _QrConnectScannerState();
}

class _QrConnectScannerState extends State<_QrConnectScanner> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (value == null) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.scanQrTitle)),
      body: MobileScanner(
        onDetect: _onDetect,
        errorBuilder: (context, error) => Center(child: Text(error.errorCode.message)),
      ),
    );
  }
}
