import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../state/scan_queue.dart';
import 'product_detail_screen.dart';

class PendingScansScreen extends StatefulWidget {
  const PendingScansScreen({super.key});

  @override
  State<PendingScansScreen> createState() => _PendingScansScreenState();
}

class _PendingScansScreenState extends State<PendingScansScreen> {
  bool _syncing = false;

  Future<void> _syncAll(ScanQueue queue) async {
    setState(() => _syncing = true);
    final api = context.read<ApiClient>();
    var failures = 0;
    // Snapshot the list -- queue.pending shrinks as items succeed, so
    // iterating queue.pending directly would skip entries.
    for (final scan in queue.pending.toList()) {
      try {
        final result = await api.lookupBarcode(scan.barcode);
        if (!mounted) return;
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              barcode: scan.barcode,
              existingProduct: result.localProduct,
              prefill: result.prefill,
            ),
          ),
        );
        if (saved == true) await queue.remove(scan);
      } on http.ClientException {
        // Still offline -- the rest will fail the same way, stop here.
        break;
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    final remaining = queue.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures > 0
              ? '$failures lookup(s) failed; $remaining still pending.'
              : remaining > 0
                  ? 'Stopped -- still offline. $remaining still pending.'
                  : 'All pending scans synced.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<ScanQueue>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pending scans')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _syncing || queue.pending.isEmpty ? null : () => _syncAll(queue),
              child: _syncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sync now'),
            ),
          ),
          Expanded(
            child: queue.pending.isEmpty
                ? const Center(child: Text('Nothing pending.'))
                : ListView.separated(
                    itemCount: queue.pending.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final scan = queue.pending[index];
                      return ListTile(
                        title: Text(scan.barcode),
                        subtitle: Text('Queued ${scan.queuedAt.toIso8601String().split('T').first}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Discard',
                          onPressed: _syncing ? null : () => queue.remove(scan),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
