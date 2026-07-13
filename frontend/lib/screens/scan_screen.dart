import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../state/scan_history.dart';
import '../state/scan_queue.dart';
import 'pending_scans_screen.dart';
import 'product_batches_screen.dart';
import 'product_detail_screen.dart';
import 'scan_history_screen.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.invalidBarcodeMessage)),
        );
      }
      return;
    }
    _lastRejected = null;
    await _lookUp(code);
  }

  Future<void> _enterManually() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.enterBarcodeTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.lookUpButton),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    if (!isPlausibleBarcode(code)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invalidBarcodeMessage)));
      return;
    }
    await _lookUp(code);
  }

  Future<void> _openHistory() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanHistoryScreen()));
    if (code != null) await _lookUp(code);
  }

  Future<void> _lookUp(String code) async {
    if (_handling) return;
    setState(() => _handling = true);
    final api = context.read<ApiClient>();
    final queue = context.read<ScanQueue>();
    final history = context.read<ScanHistory>();
    try {
      final result = await api.lookupBarcode(code);
      if (!mounted) return;
      final name = result.localProduct?.name ?? result.prefill?.name;
      if (name != null) await history.add(code, name);
      if (!mounted) return;
      final existing = result.localProduct;
      await Navigator.of(context).push(
        MaterialPageRoute(
          // A barcode that already matches a local product might have stock
          // on hand to consume/discard/mark opened -- not just more to add
          // (#56). ProductBatchesScreen covers all of that (plus adding a
          // new batch via its own FAB) and degrades gracefully to an
          // add-only empty state if this product currently has none.
          builder: (_) => existing != null
              ? ProductBatchesScreen(productId: existing.id, productName: existing.name)
              : ProductDetailScreen(barcode: code, prefill: result.prefill),
        ),
      );
    } on http.ClientException catch (_) {
      // A connection-level failure (package:http wraps SocketException into
      // this on IO platforms too, see ClientException docs) -- worth queuing
      // for later rather than just failing, unlike a real API error below.
      await queue.add(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.savedForLater(queue.length))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.lookupFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = context.watch<ScanQueue>().length;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: l10n.enterManuallyTooltip,
            onPressed: _handling ? null : _enterManually,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.recentlyScanned,
            onPressed: _handling ? null : _openHistory,
          ),
          if (pendingCount > 0)
            IconButton(
              icon: Badge(label: Text('$pendingCount'), child: const Icon(Icons.pending_actions)),
              tooltip: l10n.pendingScans,
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
            errorBuilder: (context, error) => Center(child: Text(error.errorCode.message)),
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
