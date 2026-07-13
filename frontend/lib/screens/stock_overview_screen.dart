import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../state/stock_provider.dart';
import 'product_batches_screen.dart';
import 'product_detail_screen.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'expired':
      return Colors.red;
    case 'expiring_soon':
      return Colors.orange;
    default:
      return Colors.green;
  }
}

/// Relative day label ("today"/"tomorrow"/"in N days"/"N days ago"), so
/// scanning the list doesn't require doing date math against a raw ISO
/// string. [presentVerb] is used for today/future ("Expires"), [pastVerb]
/// for anything already in the past ("Expired").
String _relativeLabel(DateTime date, {required String presentVerb, required String pastVerb}) {
  final today = DateTime.now();
  final days = DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  if (days == 0) return '$presentVerb today';
  if (days == 1) return '$presentVerb tomorrow';
  if (days == -1) return '$pastVerb yesterday';
  if (days > 0) return '$presentVerb in $days days';
  return '$pastVerb ${-days} days ago';
}

class StockOverviewScreen extends StatefulWidget {
  const StockOverviewScreen({super.key});

  @override
  State<StockOverviewScreen> createState() => _StockOverviewScreenState();
}

class _StockOverviewScreenState extends State<StockOverviewScreen> {
  List<Location> _locations = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockProvider>()
        ..loadExpiringSoonDays()
        ..refresh();
    });
    _loadLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await context.read<ApiClient>().listLocations();
      if (mounted) setState(() => _locations = locations);
    } catch (_) {
      // Filter dropdown just stays hidden (see _locations.isNotEmpty below) --
      // the stock list's own error state already surfaces connectivity issues.
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          PopupMenuButton<StockViewMode>(
            icon: const Icon(Icons.view_agenda),
            tooltip: 'View',
            initialValue: stock.viewMode,
            onSelected: stock.setViewMode,
            itemBuilder: (context) => const [
              PopupMenuItem(value: StockViewMode.flat, child: Text('Every batch')),
              PopupMenuItem(value: StockViewMode.grouped, child: Text('Grouped by product')),
              PopupMenuItem(value: StockViewMode.breakdown, child: Text('Expiry breakdown')),
            ],
          ),
          PopupMenuButton<StockSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: stock.sort,
            onSelected: stock.setSort,
            itemBuilder: (context) => const [
              PopupMenuItem(value: StockSort.bestBeforeDate, child: Text('Best-before date')),
              PopupMenuItem(value: StockSort.name, child: Text('Name')),
              PopupMenuItem(value: StockSort.amount, child: Text('Amount')),
              PopupMenuItem(value: StockSort.location, child: Text('Location')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (value) => stock.setSearchFilter(value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Expiring soon'),
                  selected: stock.expiringWithinDaysFilter != null,
                  onSelected: (selected) =>
                      stock.setExpiringFilter(selected ? stock.expiringSoonDays : null),
                ),
                const SizedBox(width: 12),
                if (_locations.isNotEmpty)
                  DropdownButton<int?>(
                    value: stock.locationIdFilter,
                    hint: const Text('All locations'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All locations')),
                      for (final l in _locations) DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (value) => stock.setLocationFilter(value),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: stock.refresh,
              child: _buildBody(stock),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add product manually',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductDetailScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(StockProvider stock) {
    if (stock.loading && stock.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stock.error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load stock: ${stock.error}\n\nCheck the server URL in Settings.'),
          ),
        ],
      );
    }
    if (stock.items.isEmpty) {
      return const Center(child: Text('No stock yet. Scan something to add it.'));
    }
    switch (stock.viewMode) {
      case StockViewMode.grouped:
        final groups = stock.groupedItems;
        return ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => _buildGroupTile(context, groups[index]),
        );
      case StockViewMode.breakdown:
        final buckets = stock.expiryBreakdown;
        return ListView.builder(
          itemCount: buckets.length,
          itemBuilder: (context, index) {
            final bucket = buckets[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(bucket.label, style: Theme.of(context).textTheme.titleSmall),
                ),
                for (final item in bucket.items) _buildItemTile(context, stock, item),
                const Divider(height: 1),
              ],
            );
          },
        );
      case StockViewMode.flat:
        final items = stock.sortedItems;
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => _buildItemTile(context, stock, items[index]),
        );
    }
  }

  Widget _buildGroupTile(BuildContext context, ProductGroup group) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: _statusColor(group.status), radius: 6),
      title: Text(group.productName),
      subtitle: Text([
        if (group.locationNames.isNotEmpty) group.locationNames.join(', '),
        '${group.totalAmount} total',
      ].join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductBatchesScreen(productId: group.productId, productName: group.productName),
        ),
      ),
    );
  }

  Widget _buildItemTile(BuildContext context, StockProvider stock, StockItem item) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: _statusColor(item.status), radius: 6),
      title: Text(item.productName),
      subtitle: Text([
        if (item.locationName != null) item.locationName!,
        if (item.bestBeforeDate != null)
          _relativeLabel(item.bestBeforeDate!, presentVerb: 'Expires', pastVerb: 'Expired'),
        if (item.purchasedDate != null)
          _relativeLabel(item.purchasedDate!, presentVerb: 'Purchased', pastVerb: 'Purchased'),
        '${item.amount}',
      ].join(' · ')),
      onTap: () => _consumeDialog(context, stock, item),
      onLongPress: () => _confirmDelete(context, stock, item.id, item.productName),
    );
  }

  Future<void> _consumeDialog(BuildContext context, StockProvider stock, StockItem item) async {
    final controller = TextEditingController(text: '1');
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use some of "${item.productName}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount (of ${item.amount} in stock)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Consume'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0 || !context.mounted) return;
    try {
      await stock.consume(item.id, amount);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not consume: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, StockProvider stock, int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from stock?'),
        content: Text('This deletes this batch of "$name".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) await stock.delete(id);
  }
}
