import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'scan_history';
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
class ScanHistory extends ChangeNotifier {
  List<ScanHistoryEntry> _entries = [];

  List<ScanHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    _entries = list.map((e) => ScanHistoryEntry.fromJson(e)).toList();
    notifyListeners();
  }

  /// Records a lookup, moving an existing entry for the same barcode to the
  /// front (with the latest name) instead of duplicating it.
  Future<void> add(String barcode, String name) async {
    _entries = [
      ScanHistoryEntry(barcode: barcode, name: name, scannedAt: DateTime.now()),
      ..._entries.where((e) => e.barcode != barcode),
    ].take(_maxEntries).toList();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }
}
