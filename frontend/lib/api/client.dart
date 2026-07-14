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

  Future<List<Category>> listCategories() async {
    final res = await http.get(_uri('/api/categories'));
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Category.fromJson(e)).toList();
  }

  Future<Category> createCategory(String name) async {
    final res = await _postJson('/api/categories', {'name': name});
    return Category.fromJson(jsonDecode(res.body));
  }

  Future<Category> renameCategory(int id, String name) async {
    final res = await http.patch(
      _uri('/api/categories/$id'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    _checkOk(res);
    return Category.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteCategory(int id) async {
    final res = await http.delete(_uri('/api/categories/$id'));
    _checkOk(res);
  }

  Future<Product> createProduct(Map<String, dynamic> payload) async {
    final res = await _postJson('/api/products', payload);
    return Product.fromJson(jsonDecode(res.body));
  }

  Future<List<Product>> listProducts({String? search}) async {
    final query = <String, String>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    final res = await http.get(_uri('/api/products', query));
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> payload) async {
    final res = await http.patch(
      _uri('/api/products/$id'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    _checkOk(res);
    return Product.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteProduct(int id) async {
    final res = await http.delete(_uri('/api/products/$id'));
    _checkOk(res);
  }

  /// Re-fetches this product's Open Food Facts listing (bypassing the
  /// local-DB-first check [lookupBarcode] does) for the caller to review
  /// and apply via [updateProduct].
  Future<Map<String, dynamic>> refreshProductFromOff(int id) async {
    final res = await http.post(_uri('/api/products/$id/refresh-from-off'));
    _checkOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<StockItem>> listStock({
    int? locationId,
    int? productId,
    String? search,
    int? expiringWithinDays,
    int? categoryId,
  }) async {
    final query = <String, String>{};
    if (locationId != null) query['location_id'] = '$locationId';
    if (productId != null) query['product_id'] = '$productId';
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (expiringWithinDays != null) query['expiring_within_days'] = '$expiringWithinDays';
    if (categoryId != null) query['category_id'] = '$categoryId';
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

  Future<void> consumeStock(int id, double amount, {String reason = 'used'}) async {
    await _postJson('/api/stock/$id/consume', {'amount': amount, 'reason': reason});
  }

  /// Batches removed via [consumeStock] or [deleteStock] since [since] (if
  /// given), most-recent-first -- used for the "N wasted this month" summary.
  Future<List<ConsumptionLogEntry>> listConsumptionLog({DateTime? since, DateTime? until, String? reason}) async {
    final query = <String, String>{};
    if (since != null) query['since'] = since.toIso8601String().split('T').first;
    if (until != null) query['until'] = until.toIso8601String().split('T').first;
    if (reason != null) query['reason'] = reason;
    final res = await http.get(_uri('/api/consumption-log', query));
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => ConsumptionLogEntry.fromJson(e)).toList();
  }

  Future<void> markStockOpened(int id) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final res = await http.patch(
      _uri('/api/stock/$id'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'opened_at': today}),
    );
    _checkOk(res);
  }

  /// The stock CSV export is downloaded by opening this URL directly
  /// (server sets Content-Disposition) rather than fetched and saved here --
  /// no cross-platform file-save API is otherwise in this app's dependencies.
  /// Unlike the relative URIs [_uri] returns for plain http calls (which
  /// `package:http` resolves against the page location on web), url_launcher
  /// requires an absolute URI with a scheme, so resolve against Uri.base
  /// when there's no explicit server URL configured.
  Uri exportStockCsvUrl() {
    final uri = _uri('/api/stock/export.csv');
    return uri.hasScheme ? uri : Uri.base.resolveUri(uri);
  }

  /// Sends the raw CSV text as the request body -- matches how the backend
  /// reads it (no multipart parsing needed there) and is the simplest thing
  /// for `package:http` to send after reading a picked file as a string.
  Future<StockImportResult> importStockCsv(String csv) async {
    final res = await http.post(
      _uri('/api/stock/import.csv'),
      headers: {'content-type': 'text/csv'},
      body: csv,
    );
    _checkOk(res);
    return StockImportResult.fromJson(jsonDecode(res.body));
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

  Future<List<ShoppingListItem>> listShoppingList() async {
    final res = await http.get(_uri('/api/shopping-list'));
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => ShoppingListItem.fromJson(e)).toList();
  }

  Future<ShoppingListItem> createShoppingListItem({
    int? productId,
    String? name,
    double? amount,
    String? unit,
  }) async {
    final payload = <String, dynamic>{
      'product_id': ?productId,
      'name': ?name,
      'amount': ?amount,
      'unit': ?unit,
    };
    final res = await _postJson('/api/shopping-list', payload);
    return ShoppingListItem.fromJson(jsonDecode(res.body));
  }

  Future<ShoppingListItem> updateShoppingListItem(int id, Map<String, dynamic> payload) async {
    final res = await http.patch(
      _uri('/api/shopping-list/$id'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    _checkOk(res);
    return ShoppingListItem.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteShoppingListItem(int id) async {
    final res = await http.delete(_uri('/api/shopping-list/$id'));
    _checkOk(res);
  }

  /// Returns how many done items were removed.
  Future<int> clearDoneShoppingListItems() async {
    final res = await http.delete(_uri('/api/shopping-list/done'));
    _checkOk(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['deleted'] as int;
  }

  /// Queues one item per currently low-stock product that isn't already on
  /// the (open) list -- returns whatever was actually created, which may be
  /// empty if everything low-stock is already queued.
  Future<List<ShoppingListItem>> addLowStockToShoppingList() async {
    final res = await http.post(_uri('/api/shopping-list/add-low-stock'));
    _checkOk(res);
    final list = jsonDecode(res.body) as List;
    return list.map((e) => ShoppingListItem.fromJson(e)).toList();
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
