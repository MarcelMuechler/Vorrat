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
  final String? brand;
  final String? imageUrl;
  final String? category;
  final String quantityUnit;
  final int? defaultLocationId;
  final int? defaultBestBeforeDays;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.category,
    this.quantityUnit = 'pcs',
    this.defaultLocationId,
    this.defaultBestBeforeDays,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        barcode: json['barcode'],
        name: json['name'],
        brand: json['brand'],
        imageUrl: json['image_url'],
        category: json['category'],
        quantityUnit: json['quantity_unit'] ?? 'pcs',
        defaultLocationId: json['default_location_id'],
        defaultBestBeforeDays: json['default_best_before_days'],
      );
}

/// Prefill data returned from a barcode lookup that hasn't been saved as a
/// Product yet (source == "off"), so it has no id.
class ProductPrefill {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? category;

  ProductPrefill({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.category,
  });

  factory ProductPrefill.fromJson(Map<String, dynamic> json) => ProductPrefill(
        barcode: json['barcode'],
        name: json['name'],
        brand: json['brand'],
        imageUrl: json['image_url'],
        category: json['category'],
      );
}

class StockItem {
  final int id;
  final int productId;
  final int? locationId;
  final double amount;
  final DateTime? bestBeforeDate;
  final DateTime? purchasedDate;
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
        productName: json['product_name'],
        productBarcode: json['product_barcode'],
        locationName: json['location_name'],
        status: json['status'],
      );
}
