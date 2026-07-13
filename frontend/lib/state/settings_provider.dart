import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _serverUrlKey = 'server_url';
const _scanEnabledKey = 'scan_enabled';

class SettingsProvider extends ChangeNotifier {
  String _serverUrl = '';
  // ponytail: platform default is the only "capability check" -- no runtime
  // camera probing. Web starts off (browsers vary too much in camera
  // support), native starts on; either can be flipped in Settings.
  bool _scanEnabled = !kIsWeb;

  String get serverUrl => _serverUrl;
  bool get scanEnabled => _scanEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_serverUrlKey) ?? '';
    _scanEnabled = prefs.getBool(_scanEnabledKey) ?? !kIsWeb;
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url.trim().replaceFirst(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, _serverUrl);
    notifyListeners();
  }

  Future<void> setScanEnabled(bool enabled) async {
    _scanEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scanEnabledKey, enabled);
    notifyListeners();
  }
}
