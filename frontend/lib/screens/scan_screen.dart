import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../main.dart';
import '../state/scan_queue.dart';
import 'pending_scans_screen.dart';
import 'product_detail_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

/// A permissive sanity check, not a full barcode-format validator -- only
/// rejects the obviously-malformed (empty, or a numeric format with clearly
/// the wrong digit count for what it claims to be). Anything that merely
/// isn't in the local DB or on Open Food Facts is still a valid lookup, not
/// a validation failure.
bool isPlausibleBarcode(String value, [BarcodeFormat? format]) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  switch (format) {
    case BarcodeFormat.ean13:
      return RegExp(r'^\d{13}$').hasMatch(trimmed);
    case BarcodeFormat.ean8:
      return RegExp(r'^\d{8}$').hasMatch(trimmed);
    case BarcodeFormat.upcA:
      return RegExp(r'^\d{12}$').hasMatch(trimmed);
    case BarcodeFormat.upcE:
      return RegExp(r'^\d{6,8}$').hasMatch(trimmed);
    default:
      // QR/DataMatrix/PDF417 encode arbitrary data, and Code128/Code39/etc.
      // vary too much in length to check meaningfully -- just require
      // something was actually detected. Also used for manual entry, where
      // the format isn't known: a loose digit-length check covers the
      // common EAN/UPC range without rejecting valid non-numeric formats.
      return format == null ? RegExp(r'^\d{6,14}$').hasMatch(trimmed) : true;
  }
}

class _ScanScreenState extends State<ScanScreen> {
  bool _handling = false;
  String? _lastRejected;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;
    if (code == null) return;

    if (!isPlausibleBarcode(code, barcode!.format)) {
      // onDetect fires on every camera frame while the same (bad) value is
      // in view -- only tell the user once per distinct value instead of
      // spamming a snackbar per frame.
      if (_lastRejected != code) {
        _lastRejected = code;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("That doesn't look like a valid barcode.")));
      }
      return;
    }
    _lastRejected = null;

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
    final pendingCount = context.watch<ScanQueue>().length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          if (pendingCount > 0)
            IconButton(
              icon: Badge(label: Text('$pendingCount'), child: const Icon(Icons.pending_actions)),
              tooltip: 'Pending scans',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PendingScansScreen()),
              ),
            ),
        ],
      ),
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
