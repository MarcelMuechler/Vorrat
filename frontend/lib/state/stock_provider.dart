import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../models/models.dart';

enum StockSort { bestBeforeDate, name, amount, location }

enum StockViewMode { flat, grouped, breakdown }

/// A date-based bucket of stock items ("Expired", "Today", "This week", ...)
/// for [StockProvider.expiryBreakdown].
class ExpiryBucket {
  final String label;
  final List<StockItem> items;

  ExpiryBucket(this.label, this.items);
}

/// Same product, summed across however many batches/locations it's spread
/// across -- one row instead of one per StockOverviewScreen.groupedItems /
/// batch.
class ProductGroup {
  final int productId;
  final String productName;
  final double totalAmount;
  final String status;
  final Set<String> locationNames;

  ProductGroup({
    required this.productId,
    required this.productName,
    required this.totalAmount,
    required this.status,
    required this.locationNames,
  });
}

const _statusSeverity = {'expired': 0, 'expiring_soon': 1, 'ok': 2};

class StockProvider extends ChangeNotifier {
  final ApiClient api;

  StockProvider(this.api);

  List<StockItem> items = [];
  bool loading = false;
  String? error;
  int? expiringWithinDaysFilter;
  int? locationIdFilter;
  String searchFilter = '';
  StockSort sort = StockSort.bestBeforeDate;
  StockViewMode viewMode = StockViewMode.flat;
  int expiringSoonDays = 3;

  /// [items] sorted client-side -- the list is already fully fetched, and
  /// re-querying the API just to change ordering would be wasteful.
  List<StockItem> get sortedItems {
    final sorted = [...items];
    switch (sort) {
      case StockSort.bestBeforeDate:
        break; // already the API's default order
      case StockSort.name:
        sorted.sort((a, b) => a.productName.compareTo(b.productName));
      case StockSort.amount:
        sorted.sort((a, b) => a.amount.compareTo(b.amount));
      case StockSort.location:
        sorted.sort((a, b) => (a.locationName ?? '').compareTo(b.locationName ?? ''));
    }
    return sorted;
  }

  void setSort(StockSort value) {
    sort = value;
    notifyListeners();
  }

  /// [sortedItems] collapsed to one row per product -- summed amount, the
  /// worst status among its batches (expired beats expiring_soon beats ok),
  /// and every distinct location it's spread across.
  List<ProductGroup> get groupedItems {
    final byProduct = <int, List<StockItem>>{};
    for (final item in sortedItems) {
      byProduct.putIfAbsent(item.productId, () => []).add(item);
    }
    return byProduct.values.map((batches) {
      final worstStatus = batches
          .map((b) => b.status)
          .reduce((a, b) => (_statusSeverity[a] ?? 2) <= (_statusSeverity[b] ?? 2) ? a : b);
      return ProductGroup(
        productId: batches.first.productId,
        productName: batches.first.productName,
        totalAmount: batches.fold(0, (sum, b) => sum + b.amount),
        status: worstStatus,
        locationNames: {for (final b in batches) if (b.locationName != null) b.locationName!},
      );
    }).toList();
  }

  /// [sortedItems] bucketed by best-before date -- expired / today / this
  /// week (2-7 days out) / later / no best-before date at all. Only
  /// non-empty buckets are included.
  List<ExpiryBucket> get expiryBreakdown {
    final expired = <StockItem>[];
    final today = <StockItem>[];
    final thisWeek = <StockItem>[];
    final later = <StockItem>[];
    final noDate = <StockItem>[];
    final todayDate = DateTime.now();
    final todayOnly = DateTime(todayDate.year, todayDate.month, todayDate.day);
    for (final item in sortedItems) {
      final bbd = item.bestBeforeDate;
      if (bbd == null) {
        noDate.add(item);
        continue;
      }
      final days = DateTime(bbd.year, bbd.month, bbd.day).difference(todayOnly).inDays;
      if (days < 0) {
        expired.add(item);
      } else if (days == 0) {
        today.add(item);
      } else if (days <= 7) {
        thisWeek.add(item);
      } else {
        later.add(item);
      }
    }
    return [
      if (expired.isNotEmpty) ExpiryBucket('Expired', expired),
      if (today.isNotEmpty) ExpiryBucket('Today', today),
      if (thisWeek.isNotEmpty) ExpiryBucket('This week', thisWeek),
      if (later.isNotEmpty) ExpiryBucket('Later', later),
      if (noDate.isNotEmpty) ExpiryBucket('No best-before date', noDate),
    ];
  }

  void setViewMode(StockViewMode mode) {
    viewMode = mode;
    notifyListeners();
  }

  Future<void> loadExpiringSoonDays() async {
    try {
      expiringSoonDays = await api.getExpiringSoonDays();
      notifyListeners();
    } catch (_) {
      // Keep the built-in default (matches the backend's own fallback) --
      // the stock list's own error state already surfaces connectivity
      // issues, no need for a second one here.
    }
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      items = await api.listStock(
        expiringWithinDays: expiringWithinDaysFilter,
        locationId: locationIdFilter,
        search: searchFilter.isEmpty ? null : searchFilter,
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

  Future<void> setSearchFilter(String value) async {
    searchFilter = value;
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
