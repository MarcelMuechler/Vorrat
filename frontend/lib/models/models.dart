class Location {
  final int id;
  final String name;

  Location({required this.id, required this.name});

  factory Location.fromJson(Map<String, dynamic> json) =>
      Location(id: json['id'], name: json['name']);
}

class Product {
  final int id;
  final String? barcode;
  final String name;
  final String? imageUrl;
  final String? category;
  final String quantityUnit;
  final int? defaultLocationId;
  final int? defaultBestBeforeDays;
  final int? defaultOpenShelfLifeDays;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.imageUrl,
    this.category,
    this.quantityUnit = 'pcs',
    this.defaultLocationId,
    this.defaultBestBeforeDays,
    this.defaultOpenShelfLifeDays,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        barcode: json['barcode'],
        name: json['name'],
        imageUrl: json['image_url'],
        category: json['category'],
        quantityUnit: json['quantity_unit'] ?? 'pcs',
        defaultLocationId: json['default_location_id'],
        defaultBestBeforeDays: json['default_best_before_days'],
        defaultOpenShelfLifeDays: json['default_open_shelf_life_days'],
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
        locationName: json['location_name'],
        status: json['status'],
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
