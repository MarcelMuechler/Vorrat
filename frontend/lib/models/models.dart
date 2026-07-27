class Location {
  final int id;
  final String name;

  Location({required this.id, required this.name});

  factory Location.fromJson(Map<String, dynamic> json) =>
      Location(id: json['id'], name: json['name']);
}

class Category {
  final int id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(id: json['id'], name: json['name']);
}

class Product {
  final int id;
  final String? barcode;
  // Alternate/extra scannable codes for this product (#208) -- e.g. a
  // different pack size or a regional/reprinted barcode for the same item --
  // beyond the single primary [barcode] above.
  final List<String> extraBarcodes;
  final String name;
  final String? imageUrl;
  final int? categoryId;
  final String? categoryName;
  final String quantityUnit;
  final int? defaultLocationId;
  final int? defaultBestBeforeDays;
  final int? defaultOpenShelfLifeDays;
  final double? lowStockThreshold;
  final double? targetStockLevel;
  // #292: shelf-stable goods (rice, canned food, spices) opt out of
  // expiry-based status entirely -- stock.py's _status always reports "ok"
  // for this product's entries regardless of best_before_date.
  final bool doesNotSpoil;
  // #292: optional per-product override of the global
  // Settings.expiring_soon_days threshold (e.g. fresh fish wants a tighter
  // window than the household default). Null falls back to the global value.
  final int? expiringSoonDays;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.extraBarcodes = const [],
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.quantityUnit = 'pcs',
    this.defaultLocationId,
    this.defaultBestBeforeDays,
    this.defaultOpenShelfLifeDays,
    this.lowStockThreshold,
    this.targetStockLevel,
    this.doesNotSpoil = false,
    this.expiringSoonDays,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        barcode: json['barcode'],
        extraBarcodes: (json['extra_barcodes'] as List?)?.cast<String>() ?? const [],
        name: json['name'],
        imageUrl: json['image_url'],
        categoryId: json['category_id'],
        categoryName: json['category_name'],
        quantityUnit: json['quantity_unit'] ?? 'pcs',
        defaultLocationId: json['default_location_id'],
        defaultBestBeforeDays: json['default_best_before_days'],
        defaultOpenShelfLifeDays: json['default_open_shelf_life_days'],
        lowStockThreshold: (json['low_stock_threshold'] as num?)?.toDouble(),
        targetStockLevel: (json['target_stock_level'] as num?)?.toDouble(),
        doesNotSpoil: json['does_not_spoil'] as bool? ?? false,
        expiringSoonDays: json['expiring_soon_days'],
      );
}

/// Prefill data returned from a barcode lookup that hasn't been saved as a
/// Product yet (source == "off"), so it has no id.
class ProductPrefill {
  final String barcode;
  final String name;
  final String? imageUrl;
  final String? category;
  final double? amount;
  final String? quantityUnit;

  ProductPrefill({
    required this.barcode,
    required this.name,
    this.imageUrl,
    this.category,
    this.amount,
    this.quantityUnit,
  });

  factory ProductPrefill.fromJson(Map<String, dynamic> json) => ProductPrefill(
        barcode: json['barcode'],
        name: json['name'],
        imageUrl: json['image_url'],
        category: json['category'],
        amount: (json['amount'] as num?)?.toDouble(),
        quantityUnit: json['quantity_unit'],
      );
}

class StockItem {
  final int id;
  final int productId;
  final int? locationId;
  final double amount;
  final DateTime? bestBeforeDate;
  final DateTime? purchasedDate;
  final DateTime? openedAt;
  // Per-unit price (see the backend's StockEntry.price docstring for why
  // per-unit rather than a total for the whole entry) -- null if this
  // entry's cost was never recorded.
  final double? price;
  final String productName;
  final String? productBarcode;
  final String? category;
  final double? lowStockThreshold;
  final String? locationName;
  final String status; // ok | expiring_soon | expired
  // Canonical expiry the backend derives [status] from (#225): the earlier
  // of bestBeforeDate and openedAt + the product's open shelf life, or just
  // bestBeforeDate if the batch was never opened/has no BBD. Use this (not
  // bestBeforeDate) for anything that buckets/sorts/labels by expiry, so an
  // opened batch with no best-before date isn't dropped into a "no date"
  // bucket its own status already disagrees with.
  final DateTime? effectiveExpiryDate;

  StockItem({
    required this.id,
    required this.productId,
    required this.amount,
    required this.productName,
    required this.status,
    this.locationId,
    this.bestBeforeDate,
    this.purchasedDate,
    this.openedAt,
    this.price,
    this.productBarcode,
    this.category,
    this.lowStockThreshold,
    this.locationName,
    this.effectiveExpiryDate,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
        id: json['id'],
        productId: json['product_id'],
        locationId: json['location_id'],
        amount: (json['amount'] as num).toDouble(),
        bestBeforeDate: json['best_before_date'] != null
            ? DateTime.parse(json['best_before_date'])
            : null,
        purchasedDate: json['purchased_date'] != null
            ? DateTime.parse(json['purchased_date'])
            : null,
        openedAt: json['opened_at'] != null ? DateTime.parse(json['opened_at']) : null,
        price: (json['price'] as num?)?.toDouble(),
        productName: json['product_name'],
        productBarcode: json['product_barcode'],
        category: json['product_category'],
        lowStockThreshold: (json['product_low_stock_threshold'] as num?)?.toDouble(),
        locationName: json['location_name'],
        status: json['status'],
        effectiveExpiryDate: json['effective_expiry_date'] != null
            ? DateTime.parse(json['effective_expiry_date'])
            : null,
      );
}

class ShoppingListItem {
  final int id;
  final int? productId;
  final String name;
  final double amount;
  final String? unit;
  final bool done;
  // Only ever set on a free-text item (product-linked items inherit their
  // category from the product instead, see categoryName) -- #122.
  final int? categoryId;
  // Effective/display category: the item's own for a free-text item, falling
  // back to the linked product's category otherwise. Matches the backend's
  // ShoppingListItem.category_name property.
  final String? categoryName;
  final DateTime createdAt;

  ShoppingListItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.done,
    required this.createdAt,
    this.productId,
    this.unit,
    this.categoryId,
    this.categoryName,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) => ShoppingListItem(
        id: json['id'],
        productId: json['product_id'],
        name: json['name'],
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'],
        done: json['done'],
        categoryId: json['category_id'],
        categoryName: json['category_name'],
        createdAt: DateTime.parse(json['created_at']),
      );
}

class ConsumptionLogEntry {
  final int id;
  final int productId;
  final String productName;
  final double amount;
  final String reason; // used | spoiled
  // Snapshotted on the backend at write time, so it reflects the unit the
  // product had *then* -- not its current quantityUnit, which may have
  // changed since. Null for rows written before this field existed and
  // never backfilled.
  final String? quantityUnit;
  // Per-unit price snapshotted at consume time, same reasoning as
  // [quantityUnit]. Null when the batch was never priced.
  final double? price;
  final DateTime createdAt;

  ConsumptionLogEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.amount,
    required this.reason,
    this.quantityUnit,
    this.price,
    required this.createdAt,
  });

  factory ConsumptionLogEntry.fromJson(Map<String, dynamic> json) => ConsumptionLogEntry(
        id: json['id'],
        productId: json['product_id'],
        productName: json['product_name'],
        amount: (json['amount'] as num).toDouble(),
        reason: json['reason'],
        quantityUnit: json['quantity_unit'],
        price: (json['price'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at']),
      );
}

/// Totals for a consumption-log window (#321's /summary endpoint): entry
/// counts and what they were worth at their snapshotted prices. Unpriced
/// entries are counted but add nothing, so the values are lower bounds.
class ConsumptionSummary {
  final int usedEntries;
  final double usedValue;
  final int spoiledEntries;
  final double spoiledValue;

  ConsumptionSummary({
    required this.usedEntries,
    required this.usedValue,
    required this.spoiledEntries,
    required this.spoiledValue,
  });

  factory ConsumptionSummary.fromJson(Map<String, dynamic> json) => ConsumptionSummary(
        usedEntries: json['used_entries'],
        usedValue: (json['used_value'] as num).toDouble(),
        spoiledEntries: json['spoiled_entries'],
        spoiledValue: (json['spoiled_value'] as num).toDouble(),
      );
}

class StockImportRowError {
  final int row;
  final String error;

  StockImportRowError({required this.row, required this.error});

  factory StockImportRowError.fromJson(Map<String, dynamic> json) =>
      StockImportRowError(row: json['row'], error: json['error']);
}

class StockImportResult {
  final int imported;
  final List<StockImportRowError> errors;

  StockImportResult({required this.imported, required this.errors});

  factory StockImportResult.fromJson(Map<String, dynamic> json) => StockImportResult(
        imported: json['imported'],
        errors: (json['errors'] as List).map((e) => StockImportRowError.fromJson(e)).toList(),
      );
}
