import 'package:flutter_test/flutter_test.dart';
import 'package:vorrat/api/client.dart';
import 'package:vorrat/models/models.dart';
import 'package:vorrat/state/settings_provider.dart';
import 'package:vorrat/state/stock_provider.dart';

StockItem _item({required String name, DateTime? bbd}) => StockItem(
  id: name.hashCode,
  productId: 1,
  amount: 1,
  productName: name,
  bestBeforeDate: bbd,
  status: 'ok',
);

void main() {
  test('expiryBreakdown buckets by best-before date, skipping empty buckets', () {
    final provider = StockProvider(ApiClient(SettingsProvider()));
    final today = DateTime.now();
    provider.items = [
      _item(name: 'Old Milk', bbd: today.subtract(const Duration(days: 2))),
      _item(name: 'Todays Bread', bbd: DateTime(today.year, today.month, today.day)),
      _item(name: 'Soon Cheese', bbd: today.add(const Duration(days: 5))),
      _item(name: 'Far Rice', bbd: today.add(const Duration(days: 30))),
      _item(name: 'No Date Salt'),
    ];

    final buckets = {for (final b in provider.expiryBreakdown) b.label: b.items};

    expect(buckets['Expired']!.single.productName, 'Old Milk');
    expect(buckets['Today']!.single.productName, 'Todays Bread');
    expect(buckets['This week']!.single.productName, 'Soon Cheese');
    expect(buckets['Later']!.single.productName, 'Far Rice');
    expect(buckets['No best-before date']!.single.productName, 'No Date Salt');
  });

  test('omits buckets with no items', () {
    final provider = StockProvider(ApiClient(SettingsProvider()));
    provider.items = [_item(name: 'Only This', bbd: DateTime.now())];

    expect(provider.expiryBreakdown.map((b) => b.label).toList(), ['Today']);
  });
}
