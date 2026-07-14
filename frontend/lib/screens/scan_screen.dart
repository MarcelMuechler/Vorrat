import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/scan_history.dart';
import '../state/scan_queue.dart';
import '../state/stock_provider.dart';
import '../widgets/add_batch_sheet.dart';
import 'pending_scans_screen.dart';
import 'product_detail_screen.dart';
import 'scan_history_screen.dart';

/// What a scan does, chosen up front instead of after the fact (#69) --
/// scanning repeatedly in Open/Consume/Discard mode acts on each barcode
/// immediately, similar to how Barcode Buddy's mode-first workflow works.
/// Add is the default and behaves exactly like before #69.
enum ScanMode { add, open, consume, discard }

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
  ScanMode _mode = ScanMode.add;

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
      if (_mode == ScanMode.add) {
        final existing = result.localProduct;
        if (existing != null) {
          // Known product: stay on this screen and add a batch inline via a
          // bottom sheet (#98) instead of a full-screen round trip -- the
          // other three modes already act in place, and Add was the odd one
          // out for someone unloading a full grocery haul. Unknown barcodes
          // still need the full ProductDetailScreen form below, since there's
          // a whole product to create first.
          final added = await AddBatchSheet.show(context, existing);
          if (!mounted) return;
          if (added == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.addedToStockMessage(existing.name))),
            );
          }
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProductDetailScreen(barcode: code, prefill: result.prefill)),
          );
        }
      } else {
        await _actOnScan(api, result);
      }
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

  /// Open/Consume/Discard mode: acts immediately on the soonest-best-before
  /// batch of a known product (already the API's default order -- see
  /// ProductBatchesScreen), whole-batch, no prompt (#69's decision). Stays
  /// on this screen either way, ready for the next scan. If there's nothing
  /// to act on -- an unknown barcode, or a known product with no stock --
  /// shows an error and stays in the same mode rather than falling back to
  /// Add (#69's decision).
  Future<void> _actOnScan(ApiClient api, BarcodeLookupResult result) async {
    final l10n = AppLocalizations.of(context)!;
    final product = result.localProduct;
    final batches = product != null ? await api.listStock(productId: product.id) : <StockItem>[];
    if (!mounted) return;
    if (product == null || batches.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.nothingToActOn)));
      return;
    }
    final batch = batches.first;
    final stock = context.read<StockProvider>();
    switch (_mode) {
      case ScanMode.add:
        return; // unreachable -- Add is handled entirely by _lookUp
      case ScanMode.open:
        // Skip batches already opened -- unlike the manual UI's per-batch
        // "Open" button (only shown while canOpen), acting on batches.first
        // unconditionally would silently reset an already-set openedAt.
        final unopened = batches.where((b) => b.openedAt == null);
        if (unopened.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.nothingToActOn)));
          return;
        }
        await stock.markOpened(unopened.first.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.scannedOpened(product.name))));
      case ScanMode.consume:
        await stock.consume(batch.id, batch.amount, reason: 'used');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.scannedUsed(product.name))));
      case ScanMode.discard:
        await stock.consume(batch.id, batch.amount, reason: 'spoiled');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.scannedDiscarded(product.name))));
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            // Horizontally scrollable -- four segments with locale-dependent
            // label lengths (e.g. German "Verbrauchen") can be wider than a
            // narrow phone screen.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ScanMode>(
                segments: [
                  ButtonSegment(value: ScanMode.add, label: Text(l10n.scanModeAdd)),
                  ButtonSegment(value: ScanMode.open, label: Text(l10n.scanModeOpen)),
                  ButtonSegment(value: ScanMode.consume, label: Text(l10n.scanModeUse)),
                  ButtonSegment(value: ScanMode.discard, label: Text(l10n.scanModeDiscard)),
                ],
                selected: {_mode},
                onSelectionChanged: (selected) => setState(() => _mode = selected.first),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Center(child: Text(error.errorCode.message)),
                ),
                if (_handling) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
