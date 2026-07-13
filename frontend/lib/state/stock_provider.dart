import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../models/models.dart';

class StockProvider extends ChangeNotifier {
  final ApiClient api;

  StockProvider(this.api);

  List<StockItem> items = [];
  bool loading = false;
  String? error;
  int? expiringWithinDaysFilter;
  int? locationIdFilter;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await api.listStock(
        expiringWithinDays: expiringWithinDaysFilter,
        locationId: locationIdFilter,
      );
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setExpiringFilter(int? days) async {
    expiringWithinDaysFilter = days;
    await refresh();
  }

  Future<void> setLocationFilter(int? locationId) async {
    locationIdFilter = locationId;
    await refresh();
  }

  Future<void> delete(int id) async {
    await api.deleteStock(id);
    await refresh();
  }

  Future<void> consume(int id, double amount) async {
    await api.consumeStock(id, amount);
    await refresh();
  }
}
