import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/stock_provider.dart';
import '../util/format.dart';
import '../util/status.dart';
import '../widgets/empty_state.dart';
import '../widgets/stock_item_actions.dart';
import 'product_detail_screen.dart';

/// All batches of a single product -- the drill-in target once the Stock
/// overview groups by product (#29), but useful to reach directly too, and
/// also where scanning a barcode with existing stock lands (#56): tapping a
/// batch consumes/discards it (existing dialog below already supports both
/// reasons), the leading "Open" button marks it opened, and the FAB adds a
/// new one. Batches are already listed soonest-best-before-date first (the
/// API's default order), so that's the one a scan-triggered action should
/// default to -- no separate "preselected batch" state needed.
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

  Future<bool> _consume(StockItem item, double amount, String reason) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final logId = await context.read<ApiClient>().consumeStock(item.id, amount, reason: reason);
      await _refresh();
      if (mounted) await context.read<StockProvider>().refresh();
      if (mounted) _showUndoConsumeSnackBar(item, amount, reason, logId);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotConsume('$e'))));
      }
      return false;
    }
  }

  // Same rationale as StockOverviewScreen's identically-named method (#137):
  // a swipe (or Use/Spoil) consumes/discards a whole batch with no
  // confirmation, so it gets an Undo (atomic reversal, #160).
  void _showUndoConsumeSnackBar(StockItem item, double amount, String reason, int consumptionLogId) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reason == 'spoiled' ? l10n.scannedDiscarded(item.productName) : l10n.scannedUsed(item.productName),
        ),
        action: SnackBarAction(
          label: l10n.undoButton,
          onPressed: () => _undoConsume(item, amount, consumptionLogId),
        ),
        // A SnackBar with an action defaults to `persist: true` (stays until
        // manually dismissed) -- opt back into the normal timeout (#178).
        persist: false,
      ),
    );
  }

  Future<void> _undoConsume(StockItem item, double amount, int consumptionLogId) async {
    try {
      await context.read<StockProvider>().undoConsume(item, amount, consumptionLogId);
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotUndo('$e'))));
      }
    }
  }

  Future<bool> _confirmDelete(StockItem item) async {
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
    if (confirmed != true || !mounted) return false;
    await context.read<ApiClient>().deleteStock(item.id);
    await _refresh();
    if (mounted) await context.read<StockProvider>().refresh();
    return true;
  }

  Future<void> _markOpened(StockItem item) async {
    await context.read<StockProvider>().markOpened(item.id);
    await _refresh();
  }

  Future<void> _addBatch() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          existingProduct: Product(id: widget.productId, name: widget.productName),
        ),
      ),
    );
    if (added == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.productName)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addNewBatchTooltip,
        onPressed: _addBatch,
        child: const Icon(Icons.add),
      ),
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
                    ? EmptyState(icon: Icons.inventory_2_outlined, message: l10n.noBatchesLeft)
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return StockItemActions(
                            key: ValueKey(item.id),
                            leading: statusDot(context, item.status),
                            title: Text(formatAmount(item.amount)),
                            subtitle: Text([
                              if (item.locationName != null) item.locationName!,
                              if (item.bestBeforeDate != null)
                                l10n.bbdLabel(item.bestBeforeDate!.toIso8601String().split('T').first),
                            ].join(' · ')),
                            amount: item.amount,
                            productName: widget.productName,
                            canOpen: item.openedAt == null,
                            dismissibleKey: item.id,
                            onOpen: () => _markOpened(item),
                            onConsume: (amount, reason) => _consume(item, amount, reason),
                            onDelete: () => _confirmDelete(item),
                          );
                        },
                      ),
      ),
    );
  }
}
