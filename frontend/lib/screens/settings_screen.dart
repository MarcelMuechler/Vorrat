import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/client.dart';
import '../main.dart';
import '../state/settings_provider.dart';
import '../state/stock_provider.dart';
import 'locations_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<SettingsProvider>().serverUrl);
    _expiringSoonController = TextEditingController(text: '${context.read<StockProvider>().expiringSoonDays}');
    _loadExpiringSoonDays();
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
    final days = int.tryParse(_expiringSoonController.text);
    if (days == null || days <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a whole number greater than 0.')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
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
    final settings = context.read<SettingsProvider>();
    final api = context.read<ApiClient>();
    await settings.setServerUrl(_controller.text);
    final health = await api.checkHealth();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = health != null ? 'Connected — server v${health['version']}' : 'Could not reach server';
    });
  }

  Future<void> _scanToConnect() async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrConnectScanner()),
    );
    if (url == null || !mounted) return;
    _controller.text = url;
    await _testConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server URL. Leave blank when running inside Home Assistant '
              '(same-origin via Ingress). Native apps and local dev need the '
              'full URL, e.g. http://192.168.1.20:8099',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.1.20:8099',
                border: const OutlineInputBorder(),
                suffixIcon: ValueListenableBuilder<bool>(
                  valueListenable: cameraAvailable,
                  builder: (context, hasCamera, _) => hasCamera
                      ? IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'Scan to connect',
                          onPressed: _scanToConnect,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _testing ? null : _testConnection,
              child: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save & test connection'),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Text(_testResult!),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const Text('"Expiring soon" applies to items due within this many days.'),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _expiringSoonController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _savingExpiringSoon ? null : _saveExpiringSoonDays,
                  child: _savingExpiringSoon
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Locations'),
              subtitle: const Text('Rename or delete storage locations'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocationsScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Products'),
              subtitle: const Text('Browse, edit, or delete products'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductsScreen()),
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 32),
              const Text(
                'Pair another device: open Settings → Scan to connect on it, '
                'then scan this code.',
              ),
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
      appBar: AppBar(title: const Text('Scan server QR code')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
