import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/stock_provider.dart';

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

/// All batches of a single product -- the drill-in target once the Stock
/// overview groups by product (#29), but useful to reach directly too.
class ProductBatchesScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductBatchesScreen({super.key, required this.productId, required this.productName});

  @override
  State<ProductBatchesScreen> createState() => _ProductBatchesScreenState();
}

class _ProductBatchesScreenState extends State<ProductBatchesScreen> {
  List<StockItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<ApiClient>().listStock(productId: widget.productId);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _consumeDialog(StockItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: '1');
    var reason = 'used';
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.useSomeOfTitle(widget.productName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.amountInStockLabel('${item.amount}')),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'used', label: Text(l10n.usedLabel)),
                  ButtonSegment(value: 'spoiled', label: Text(l10n.spoiledLabel)),
                ],
                selected: {reason},
                onSelectionChanged: (value) => setState(() => reason = value.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelButton)),
            FilledButton(
              onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
              child: Text(l10n.consumeButton),
            ),
          ],
        ),
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;
    try {
      await context.read<ApiClient>().consumeStock(item.id, amount, reason: reason);
      await _refresh();
      if (mounted) await context.read<StockProvider>().refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotConsume('$e'))));
      }
    }
  }

  Future<void> _confirmDelete(StockItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeStockTitle),
        content: Text(l10n.deleteBatchConfirm(widget.productName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.removeButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<ApiClient>().deleteStock(item.id);
    await _refresh();
    if (mounted) await context.read<StockProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.productName)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.couldNotLoadBatches('$_error')),
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? Center(child: Text(l10n.noBatchesLeft))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: _statusColor(item.status), radius: 6),
                            title: Text('${item.amount}'),
                            subtitle: Text([
                              if (item.locationName != null) item.locationName!,
                              if (item.bestBeforeDate != null)
                                l10n.bbdLabel(item.bestBeforeDate!.toIso8601String().split('T').first),
                            ].join(' · ')),
                            onTap: () => _consumeDialog(item),
                            onLongPress: () => _confirmDelete(item),
                          );
                        },
                      ),
      ),
    );
  }
}
