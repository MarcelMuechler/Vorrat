import 'persisted_list.dart';

const _maxEntries = 20;

class ScanHistoryEntry {
  final String barcode;
  final String name;
  final DateTime scannedAt;

  ScanHistoryEntry({required this.barcode, required this.name, required this.scannedAt});

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'scannedAt': scannedAt.toIso8601String(),
  };

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) => ScanHistoryEntry(
    barcode: json['barcode'],
    name: json['name'],
    scannedAt: DateTime.parse(json['scannedAt']),
  );
}

/// Barcodes that were successfully looked up before (whether or not the user
/// went on to save a product), most-recent-first, so re-adding something
/// bought regularly doesn't mean scanning it from scratch every time.
class ScanHistory extends PersistedList<ScanHistoryEntry> {
  ScanHistory()
    : super(
        prefsKey: 'scan_history',
        fromJson: ScanHistoryEntry.fromJson,
        toJson: (entry) => entry.toJson(),
      );

  /// Records a lookup, moving an existing entry for the same barcode to the
  /// front (with the latest name) instead of duplicating it.
  Future<void> add(String barcode, String name) => replaceEntries(
    [
      ScanHistoryEntry(barcode: barcode, name: name, scannedAt: DateTime.now()),
      ...entries.where((e) => e.barcode != barcode),
    ].take(_maxEntries).toList(),
  );
}
