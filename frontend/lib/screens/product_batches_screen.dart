import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/stock_provider.dart';
import '../util/format.dart';
import '../util/status.dart';
import '../widgets/add_batch_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/stock_item_actions.dart';
import '../widgets/undo_snackbar.dart';
import 'product_edit_screen.dart';

/// Unified "product detail" screen (#199 wireframe revamp) -- the drill-in
/// target once the Stock overview groups by product (#29), also reached
/// directly, and where scanning a barcode with existing stock lands (#56).
/// Shows the product's own info (image/category/barcode) plus a summary of
/// its soonest-expiring batch with quick actions, then every batch below,
/// then a link to its rarely-touched metadata (ProductEditScreen). Keeps its
/// original constructor (productId/productName only) so no call site needs
/// to change -- the full Product is fetched internally.
class ProductBatchesScreen extends StatefulWidget {
  final int productId;
  final String productName;

  const ProductBatchesScreen({super.key, required this.productId, required this.productName});

  @override
  State<ProductBatchesScreen> createState() => _ProductBatchesScreenState();
}

class _ProductBatchesScreenState extends State<ProductBatchesScreen> {
  List<StockItem> _items = [];
  Product? _product;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadProduct();
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

  // Degrades gracefully (header just falls back to the name-only look) if
  // this fails -- same fail-soft convention as _loadLocations elsewhere in
  // this app; the batch list above already has its own error state.
  Future<void> _loadProduct() async {
    try {
      final product = await context.read<ApiClient>().getProduct(widget.productId);
      if (mounted) setState(() => _product = product);
    } catch (_) {
      // No header details -- name-only title still works fine.
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
    showUndoSnackBar(
      context,
      message: reason == 'spoiled' ? l10n.scannedDiscarded(item.productName) : l10n.scannedUsed(item.productName),
      onUndo: () => _undoConsume(item, amount, consumptionLogId),
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

  // The soonest-expiring batch's quick Consume/Spoiled row acts on this one
  // directly -- batches are already listed soonest-best-before-date first
  // (the API's default order), so no separate "which one" selection is
  // needed here, same reasoning the class doc used to note about scans.
  StockItem? get _soonestBatch => _items.isEmpty ? null : _items.first;

  // Opens the lightweight AddBatchSheet (a bottom sheet, not a full-page
  // form) since the product already exists -- that sheet was built for
  // exactly this and previously only reachable from the Scan tab.
  Future<void> _addBatch() async {
    final product = _product ?? Product(id: widget.productId, name: widget.productName);
    final added = await AddBatchSheet.show(context, product);
    if (added == true) await _refresh();
  }

  Future<void> _editProduct() async {
    final product = _product;
    if (product == null) return;
    final updated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => ProductEditScreen(product: product)));
    if (updated == true) await _loadProduct();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productName),
        actions: [
          if (_product != null)
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: l10n.editProductTitle, onPressed: _editProduct),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addNewBatchTooltip,
        onPressed: _addBatch,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_refresh(), _loadProduct()]),
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
                : ListView(
                    children: [
                      _buildHeader(context),
                      if (_soonestBatch != null) _buildExpiryBanner(context, _soonestBatch!),
                      _buildActionRow(context, l10n),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          l10n.batchesHeading,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_items.isEmpty)
                        EmptyState(icon: Icons.inventory_2_outlined, message: l10n.noBatchesLeft)
                      else
                        for (final item in _items) _buildBatchTile(item),
                      const Divider(height: 24),
                      ListTile(
                        title: Text(l10n.defaultsLabel),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _product == null ? null : _editProduct,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final product = _product;
    if (product == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                product.imageUrl!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 64, height: 64),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.categoryName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Chip(
                      label: Text(product.categoryName!),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (product.barcode != null)
                  Text(
                    AppLocalizations.of(context)!.barcodeLabel(product.barcode!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryBanner(BuildContext context, StockItem soonest) {
    final l10n = AppLocalizations.of(context)!;
    final color = statusColor(soonest.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soonest.bestBeforeDate != null
                        ? relativeLabel(context, soonest.bestBeforeDate!, RelativeDateKind.expiry)
                        : l10n.statusOk,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(
                    [
                      formatAmount(soonest.amount),
                      if (soonest.locationName != null) soonest.locationName!,
                    ].join(' · '),
                    style: TextStyle(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, AppLocalizations l10n) {
    final soonest = _soonestBatch;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: soonest == null ? null : () => _consume(soonest, soonest.amount, 'used'),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(l10n.usedLabel),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: soonest == null ? null : () => _consume(soonest, soonest.amount, 'spoiled'),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.spoiledLabel),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _addBatch,
              icon: const Icon(Icons.add),
              label: Text(l10n.addButton),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchTile(StockItem item) {
    final l10n = AppLocalizations.of(context)!;
    return StockItemActions(
      key: ValueKey(item.id),
      leading: statusDot(context, item.status),
      title: Text(formatAmount(item.amount)),
      subtitle: Text([
        if (item.locationName != null) item.locationName!,
        if (item.bestBeforeDate != null) l10n.bbdLabel(item.bestBeforeDate!.toIso8601String().split('T').first),
      ].join(' · ')),
      amount: item.amount,
      productName: widget.productName,
      canOpen: item.openedAt == null,
      dismissibleKey: item.id,
      onOpen: () => _markOpened(item),
      onConsume: (amount, reason) => _consume(item, amount, reason),
      onDelete: () => _confirmDelete(item),
    );
  }
}
