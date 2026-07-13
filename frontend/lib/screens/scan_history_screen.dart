import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/scan_history.dart';

/// Pops with the tapped entry's barcode, so ScanScreen can re-run its own
/// lookup flow -- keeps that logic in one place instead of duplicating it
/// here with possibly-stale cached product data.
class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<ScanHistory>().entries;
    return Scaffold(
      appBar: AppBar(title: const Text('Recently scanned')),
      body: entries.isEmpty
          ? const Center(child: Text('Nothing scanned yet.'))
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  title: Text(entry.name),
                  subtitle: Text(entry.barcode),
                  onTap: () => Navigator.of(context).pop(entry.barcode),
                );
              },
            ),
    );
  }
}
