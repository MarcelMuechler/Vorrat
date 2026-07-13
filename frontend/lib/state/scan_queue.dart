import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'pending_scans';

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
class ScanQueue extends ChangeNotifier {
  List<PendingScan> _pending = [];

  List<PendingScan> get pending => List.unmodifiable(_pending);
  int get length => _pending.length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    _pending = list.map((e) => PendingScan.fromJson(e)).toList();
    notifyListeners();
  }

  Future<void> add(String barcode) async {
    _pending = [..._pending, PendingScan(barcode: barcode, queuedAt: DateTime.now())];
    await _save();
    notifyListeners();
  }

  Future<void> remove(PendingScan scan) async {
    _pending = _pending.where((s) => s != scan).toList();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_pending.map((e) => e.toJson()).toList()));
  }
}
