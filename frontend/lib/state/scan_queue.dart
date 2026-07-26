import 'persisted_list.dart';

class PendingScan {
  final String barcode;
  final DateTime queuedAt;

  PendingScan({required this.barcode, required this.queuedAt});

  Map<String, dynamic> toJson() => {'barcode': barcode, 'queuedAt': queuedAt.toIso8601String()};

  factory PendingScan.fromJson(Map<String, dynamic> json) =>
      PendingScan(barcode: json['barcode'], queuedAt: DateTime.parse(json['queuedAt']));
}

/// Barcodes scanned while the server was unreachable, persisted so they
/// survive an app restart -- see ScanScreen for where they're queued and
/// #28 for where they'll eventually get replayed.
class ScanQueue extends PersistedList<PendingScan> {
  ScanQueue()
    : super(
        prefsKey: 'pending_scans',
        fromJson: PendingScan.fromJson,
        toJson: (scan) => scan.toJson(),
      );

  List<PendingScan> get pending => entries;
  int get length => entries.length;

  Future<void> add(String barcode) =>
      replaceEntries([...entries, PendingScan(barcode: barcode, queuedAt: DateTime.now())]);

  Future<void> remove(PendingScan scan) =>
      replaceEntries(entries.where((s) => s != scan).toList());
}
