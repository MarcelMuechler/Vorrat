import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';
import '../state/stock_provider.dart';
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

class StockOverviewScreen extends StatefulWidget {
  const StockOverviewScreen({super.key});

  @override
  State<StockOverviewScreen> createState() => _StockOverviewScreenState();
}

class _StockOverviewScreenState extends State<StockOverviewScreen> {
  List<Location> _locations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockProvider>().refresh();
    });
    _loadLocations();
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
      appBar: AppBar(title: const Text('Stock')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Expiring soon'),
                  selected: stock.expiringWithinDaysFilter != null,
                  onSelected: (selected) => stock.setExpiringFilter(selected ? 3 : null),
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
    return ListView.separated(
      itemCount: stock.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = stock.items[index];
        return ListTile(
          leading: CircleAvatar(backgroundColor: _statusColor(item.status), radius: 6),
          title: Text(item.productName),
          subtitle: Text([
            if (item.locationName != null) item.locationName!,
            if (item.bestBeforeDate != null)
              'BBD: ${item.bestBeforeDate!.toIso8601String().split('T').first}',
            '${item.amount}',
          ].join(' · ')),
          onTap: () => _consumeDialog(context, stock, item),
          onLongPress: () => _confirmDelete(context, stock, item.id, item.productName),
        );
      },
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
