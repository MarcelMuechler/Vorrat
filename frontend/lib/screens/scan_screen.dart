import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../main.dart';
import '../state/scan_queue.dart';
import 'product_detail_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handling = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    setState(() => _handling = true);
    final api = context.read<ApiClient>();
    final queue = context.read<ScanQueue>();
    try {
      final result = await api.lookupBarcode(code);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            barcode: code,
            existingProduct: result.localProduct,
            prefill: result.prefill,
          ),
        ),
      );
    } on http.ClientException catch (_) {
      // A connection-level failure (package:http wraps SocketException into
      // this on IO platforms too, see ClientException docs) -- worth queuing
      // for later rather than just failing, unlike a real API error below.
      await queue.add(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No connection — saved for later (${queue.length} pending).')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lookup failed: $e\n\nCheck the server URL in Settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              if (error.errorCode == MobileScannerErrorCode.unsupported) {
                // Don't flip the notifier mid-build of this widget — it would
                // trigger HomeShell's ValueListenableBuilder to rebuild (and
                // remove this very tab) while this build is still in progress.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  cameraAvailable.value = false;
                });
              }
              return Center(child: Text(error.errorCode.message));
            },
          ),
          if (_handling) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
