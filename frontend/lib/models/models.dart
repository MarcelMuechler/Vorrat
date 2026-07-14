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
  final String name;
  final String? imageUrl;
  final int? categoryId;
  final String? categoryName;
  final String quantityUnit;
  final int? defaultLocationId;
  final int? defaultBestBeforeDays;
  final int? defaultOpenShelfLifeDays;
  final double? lowStockThreshold;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.quantityUnit = 'pcs',
    this.defaultLocationId,
    this.defaultBestBeforeDays,
    this.defaultOpenShelfLifeDays,
    this.lowStockThreshold,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        barcode: json['barcode'],
        name: json['name'],
        imageUrl: json['image_url'],
        categoryId: json['category_id'],
        categoryName: json['category_name'],
        quantityUnit: json['quantity_unit'] ?? 'pcs',
        defaultLocationId: json['default_location_id'],
        defaultBestBeforeDays: json['default_best_before_days'],
        defaultOpenShelfLifeDays: json['default_open_shelf_life_days'],
        lowStockThreshold: (json['low_stock_threshold'] as num?)?.toDouble(),
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
  final String productName;
  final String? productBarcode;
  final String? category;
  final double? lowStockThreshold;
  final String? locationName;
  final String status; // ok | expiring_soon | expired

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
    this.productBarcode,
    this.category,
    this.lowStockThreshold,
    this.locationName,
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
        productName: json['product_name'],
        productBarcode: json['product_barcode'],
        category: json['product_category'],
        lowStockThreshold: (json['product_low_stock_threshold'] as num?)?.toDouble(),
        locationName: json['location_name'],
        status: json['status'],
      );
}

class ShoppingListItem {
  final int id;
  final int? productId;
  final String name;
  final double amount;
  final String? unit;
  final bool done;
  final DateTime createdAt;

  ShoppingListItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.done,
    required this.createdAt,
    this.productId,
    this.unit,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) => ShoppingListItem(
        id: json['id'],
        productId: json['product_id'],
        name: json['name'],
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'],
        done: json['done'],
        createdAt: DateTime.parse(json['created_at']),
      );
}

class ConsumptionLogEntry {
  final int id;
  final int productId;
  final String productName;
  final double amount;
  final String reason; // used | spoiled
  final DateTime createdAt;

  ConsumptionLogEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory ConsumptionLogEntry.fromJson(Map<String, dynamic> json) => ConsumptionLogEntry(
        id: json['id'],
        productId: json['product_id'],
        productName: json['product_name'],
        amount: (json['amount'] as num).toDouble(),
        reason: json['reason'],
        createdAt: DateTime.parse(json['created_at']),
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
