import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [ChangeNotifier] holding a list of JSON-serializable entries, persisted
/// as one `shared_preferences` string key so it survives an app restart.
///
/// Factored out of [ScanQueue] and [ScanHistory], which had the same load /
/// save / decode plumbing twice over and differed only in their mutators.
/// Subclasses supply the key and the codec, then mutate through [entries]'
/// setter, which persists and notifies in one step.
abstract class PersistedList<T> extends ChangeNotifier {
  PersistedList({
    required String prefsKey,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T entry) toJson,
  }) : _prefsKey = prefsKey,
       _fromJson = fromJson,
       _toJson = toJson;

  final String _prefsKey;
  final T Function(Map<String, dynamic> json) _fromJson;
  final Map<String, dynamic> Function(T entry) _toJson;

  List<T> _entries = [];

  List<T> get entries => List.unmodifiable(_entries);

  /// Replaces the list, persists it, and notifies -- the single mutation
  /// path, so no subclass can change the list without saving it. Awaits the
  /// write (rather than firing it off) so a caller awaiting a mutator still
  /// knows the value actually reached disk.
  @protected
  Future<void> replaceEntries(List<T> value) async {
    _entries = value;
    await _save();
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    _entries = (jsonDecode(raw) as List).map((e) => _fromJson(e)).toList();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_entries.map(_toJson).toList()));
  }
}
