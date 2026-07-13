import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../state/settings_provider.dart';

class BarcodeLookupResult {
  final String source; // local | off | none
  final Product? localProduct;
  final ProductPrefill? prefill;

  BarcodeLookupResult({required this.source, this.localProduct, this.prefill});
}

/// Thrown for any non-2xx response so callers' try/catch actually sees
/// backend errors instead of silently treating them as success.
class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'Request failed ($statusCode): $body';
}

void _checkOk(http.Response res) {
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw ApiException(res.statusCode, res.body);
  }
}

class ApiClient {
  final SettingsProvider settings;

  ApiClient(this.settings);

  // Empty serverUrl means "relative to current origin" — correct for the
  // web build served by the backend itself (direct or via HA Ingress, which
  // forwards API paths the same way it forwards the HTML/JS). Native builds
  // and local web dev (served from a different origin than uvicorn) need an
  // explicit LAN/localhost URL configured once in Settings.
  String get _baseUrl => settings.serverUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    // path is written as '/api/...' at call sites for readability, but the
    // leading slash must be dropped when there's no explicit baseUrl: a
    // root-relative reference ("/api/...") resolves against the origin root
    // and ignores <base href>'s path, which breaks HA Ingress (served under
    // a dynamic per-session path prefix). A base-relative reference
    // ("api/...", no leading slash) resolves against <base href> correctly
    // in every mode: standalone, Ingress, and native/local-dev (explicit
    // baseUrl, joined with a slash below).
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    final full = _baseUrl.isEmpty ? relativePath : '$_baseUrl/$relativePath';
    return Uri.parse(full).replace(queryParameters: query);
  }

  Future<http.Response> _postJson(String path, Object body) async {
    final res = await http.post(
      _uri(path),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    _checkOk(res);
    return res;
  }

  /// Returns the decoded /api/health body (includes "version"), or null if
  /// the server couldn't be reached — lets callers show which version is
  /// actually running instead of just a yes/no reachability check.
  Future<Map<String, dynamic>?> checkHealth() async {
    try {
      final res = await http.get(_uri('/api/health')).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Location>> listLocations() async {
    final res = await http.get(_uri('/api/locations'));
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Location.fromJson(e)).toList();
  }

  Future<Location> createLocation(String name) async {
    final res = await _postJson('/api/locations', {'name': name});
    return Location.fromJson(jsonDecode(res.body));
  }

  Future<Location> renameLocation(int id, String name) async {
    final res = await http.patch(
      _uri('/api/locations/$id'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    _checkOk(res);
    return Location.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteLocation(int id) async {
    final res = await http.delete(_uri('/api/locations/$id'));
    _checkOk(res);
  }

  Future<Product> createProduct(Map<String, dynamic> payload) async {
    final res = await _postJson('/api/products', payload);
    return Product.fromJson(jsonDecode(res.body));
  }

  Future<List<StockItem>> listStock({int? locationId, String? search, int? expiringWithinDays}) async {
    final query = <String, String>{};
    if (locationId != null) query['location_id'] = '$locationId';
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (expiringWithinDays != null) query['expiring_within_days'] = '$expiringWithinDays';
    final res = await http.get(_uri('/api/stock', query));
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => StockItem.fromJson(e)).toList();
  }

  Future<void> addStock(Map<String, dynamic> payload) async {
    await _postJson('/api/stock', payload);
  }

  Future<void> deleteStock(int id) async {
    final res = await http.delete(_uri('/api/stock/$id'));
    _checkOk(res);
  }

  Future<void> consumeStock(int id, double amount) async {
    await _postJson('/api/stock/$id/consume', {'amount': amount});
  }

  Future<int> getExpiringSoonDays() async {
    final res = await http.get(_uri('/api/settings'));
    _checkOk(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['expiring_soon_days'] as int;
  }

  Future<int> setExpiringSoonDays(int days) async {
    final res = await http.patch(
      _uri('/api/settings'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'expiring_soon_days': days}),
    );
    _checkOk(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['expiring_soon_days'] as int;
  }

  Future<BarcodeLookupResult> lookupBarcode(String code) async {
    final res = await http.get(_uri('/api/barcode/$code'));
    if (res.statusCode == 404) {
      return BarcodeLookupResult(source: 'none');
    }
    _checkOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final source = body['source'] as String;
    if (source == 'local') {
      return BarcodeLookupResult(source: source, localProduct: Product.fromJson(body['product']));
    }
    return BarcodeLookupResult(source: source, prefill: ProductPrefill.fromJson(body['product']));
  }
}
