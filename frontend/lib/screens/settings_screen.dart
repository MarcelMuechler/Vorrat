import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../main.dart';
import '../state/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  String? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<SettingsProvider>().serverUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          ],
        ),
      ),
    );
  }
}

/// Scans a QR code (or any barcode) and pops with its decoded text, treated
/// as a server URL by the caller. There's no in-app way yet to generate that
/// QR code on the server side — see issue #12 — so today this expects one
/// produced out-of-band (e.g. a label with the server's LAN address encoded
/// as a URL).
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
