import 'dart:async';

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
import 'product_batches_screen.dart';
import 'product_detail_screen.dart';

String _bucketLabel(AppLocalizations l10n, ExpiryBucketKey key) {
  switch (key) {
    case ExpiryBucketKey.expired:
      return l10n.expiryBucketExpired;
    case ExpiryBucketKey.today:
      return l10n.expiryBucketToday;
    case ExpiryBucketKey.thisWeek:
      return l10n.expiryBucketThisWeek;
    case ExpiryBucketKey.later:
      return l10n.expiryBucketLater;
    case ExpiryBucketKey.noDate:
      return l10n.expiryBucketNoDate;
  }
}

enum _RelativeKind { expiry, purchased, opened }

/// Relative day label ("today"/"tomorrow"/"in N days"/"N days ago"), so
/// scanning the list doesn't require doing date math against a raw ISO
/// string. [kind] picks which localized phrase set applies (expiry uses
/// "Expires"/"Expired", purchased/opened use the same word both ways).
String _relativeLabel(BuildContext context, DateTime date, _RelativeKind kind) {
  final l10n = AppLocalizations.of(context)!;
  final today = DateTime.now();
  final days = DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  switch (kind) {
    case _RelativeKind.expiry:
      if (days == 0) return l10n.expiryToday;
      if (days == 1) return l10n.expiryTomorrow;
      if (days == -1) return l10n.expiredYesterday;
      if (days > 0) return l10n.expiryInDays(days);
      return l10n.expiredDaysAgo(-days);
    case _RelativeKind.purchased:
      if (days == 0) return l10n.purchasedToday;
      if (days == 1) return l10n.purchasedTomorrow;
      if (days == -1) return l10n.purchasedYesterday;
      if (days > 0) return l10n.purchasedInDays(days);
      return l10n.purchasedDaysAgo(-days);
    case _RelativeKind.opened:
      if (days == 0) return l10n.openedToday;
      if (days == 1) return l10n.openedTomorrow;
      if (days == -1) return l10n.openedYesterday;
      if (days > 0) return l10n.openedInDays(days);
      return l10n.openedDaysAgo(-days);
  }
}

class StockOverviewScreen extends StatefulWidget {
  const StockOverviewScreen({super.key});

  @override
  State<StockOverviewScreen> createState() => _StockOverviewScreenState();
}

class _StockOverviewScreenState extends State<StockOverviewScreen> {
  List<Location> _locations = [];
  List<Category> _categories = [];
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Selection mode for bulk consume/delete/move (#123). Entered via a
  // toolbar toggle rather than long-press, since long-press on an item is
  // already taken by StockItemActions' single-entry delete. Only offered in
  // the flat/breakdown views (see the AppBar action below) -- the grouped
  // view aggregates several stock entries into one row and doesn't expose
  // their individual ids, so there's nothing to select there.
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  void _enterSelectionMode() => setState(() => _selectionMode = true);

  void _exitSelectionMode() => setState(() {
    _selectionMode = false;
    _selectedIds.clear();
  });

  void _toggleItemSelected(int id) => setState(() {
    if (!_selectedIds.add(id)) _selectedIds.remove(id);
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockProvider>()
        ..loadExpiringSoonDays()
        ..refresh();
    });
    _loadLocations();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<ApiClient>().listCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
      // A category selected as a filter before this screen was last torn
      // down and rebuilt may have been deleted elsewhere (Settings >
      // Categories) since -- DropdownButton asserts if its value isn't
      // among its items, so drop a filter that no longer resolves.
      final stock = context.read<StockProvider>();
      if (stock.categoryIdFilter != null && !categories.any((c) => c.id == stock.categoryIdFilter)) {
        await stock.setCategoryFilter(null);
      }
    } catch (_) {
      // Filter dropdown just stays hidden, same as _loadLocations above.
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockProvider>();
    final l10n = AppLocalizations.of(context)!;

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: _selectionMode ? _buildSelectionAppBar(context, stock, l10n) : _buildDefaultAppBar(stock, l10n),
      body: Column(
        children: [
          // A distinct tonal panel (#199) so the search/filter toolbar reads
          // as a deliberate surface instead of floating directly on the
          // near-black scaffold background.
          Container(
            color: colors.surfaceContainer,
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: l10n.searchLabel,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _searchController.clear();
                                stock.setSearchFilter('');
                                setState(() {});
                              },
                            ),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                        stock.setSearchFilter(value);
                      });
                      setState(() {});
                    },
                    onSubmitted: (value) {
                      _searchDebounce?.cancel();
                      stock.setSearchFilter(value);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  // Wrap, not a horizontally-scrolling Row (#199) -- on a
                  // narrow phone a scrolling row clips the last filter off
                  // the edge with no visible affordance that more exists.
                  // Wrapping to a second line keeps every control reachable
                  // by a plain tap regardless of screen width or locale.
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l10n.expiringSoonChip),
                        selected: stock.expiringWithinDaysFilter != null,
                        onSelected: (selected) =>
                            stock.setExpiringFilter(selected ? stock.expiringSoonDays : null),
                      ),
                      if (_locations.isNotEmpty)
                        _pillDropdown(
                          value: stock.locationIdFilter,
                          hint: l10n.allLocationsLabel,
                          items: [
                            DropdownMenuItem<int?>(value: null, child: Text(l10n.allLocationsLabel)),
                            for (final l in _locations) DropdownMenuItem(value: l.id, child: Text(l.name)),
                          ],
                          onChanged: (value) => stock.setLocationFilter(value),
                        ),
                      if (_categories.isNotEmpty)
                        _pillDropdown(
                          value: stock.categoryIdFilter,
                          hint: l10n.allCategoriesLabel,
                          items: [
                            DropdownMenuItem<int?>(value: null, child: Text(l10n.allCategoriesLabel)),
                            for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ],
                          onChanged: (value) => stock.setCategoryFilter(value),
                        ),
                    ],
                  ),
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
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              tooltip: l10n.addProductManuallyTooltip,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductDetailScreen()),
              ),
              child: const Icon(Icons.add),
            ),
    );
  }

  // A plain DropdownButton has no fill/border and disappears against the
  // dark scaffold background (#199) -- give it the same pill shape as the
  // FilterChip next to it so the whole toolbar reads as one control group.
  Widget _pillDropdown({
    required int? value,
    required String hint,
    required List<DropdownMenuItem<int?>> items,
    required ValueChanged<int?> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(value: value, hint: Text(hint), items: items, onChanged: onChanged),
      ),
    );
  }

  AppBar _buildDefaultAppBar(StockProvider stock, AppLocalizations l10n) {
    return AppBar(
      title: Text(l10n.stockTitle),
      actions: [
        // Grouped rows aggregate multiple stock entries with no per-entry
        // ids exposed (see ProductGroup) -- selection only makes sense in
        // the flat/breakdown views, which render individual entries.
        if (stock.viewMode != StockViewMode.grouped && stock.items.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: l10n.selectItemsTooltip,
            onPressed: _enterSelectionMode,
          ),
        PopupMenuButton<StockViewMode>(
          icon: const Icon(Icons.view_agenda),
          tooltip: l10n.viewTooltip,
          initialValue: stock.viewMode,
          onSelected: stock.setViewMode,
          itemBuilder: (context) => [
            PopupMenuItem(value: StockViewMode.flat, child: Text(l10n.viewModeFlat)),
            PopupMenuItem(value: StockViewMode.grouped, child: Text(l10n.viewModeGrouped)),
            PopupMenuItem(value: StockViewMode.breakdown, child: Text(l10n.viewModeBreakdown)),
          ],
        ),
        PopupMenuButton<StockSort>(
          icon: const Icon(Icons.sort),
          tooltip: l10n.sortTooltip,
          initialValue: stock.sort,
          onSelected: stock.setSort,
          itemBuilder: (context) => [
            PopupMenuItem(value: StockSort.bestBeforeDate, child: Text(l10n.sortBestBeforeDateLabel)),
            PopupMenuItem(value: StockSort.name, child: Text(l10n.nameLabel)),
            PopupMenuItem(value: StockSort.amount, child: Text(l10n.amountFieldLabel)),
            PopupMenuItem(value: StockSort.location, child: Text(l10n.locationLabel)),
          ],
        ),
      ],
    );
  }

  // Replaces the normal AppBar while selecting (#123): shows the current
  // selection count and the three bulk actions, plus a close button that
  // exits selection mode and clears the selection with no other side
  // effects. View/sort switching is deliberately unavailable here -- it's
  // simpler to just not let the underlying list reshuffle mid-selection.
  AppBar _buildSelectionAppBar(BuildContext context, StockProvider stock, AppLocalizations l10n) {
    final hasSelection = _selectedIds.isNotEmpty;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.cancelButton,
        onPressed: _exitSelectionMode,
      ),
      title: Text(l10n.selectedCount(_selectedIds.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          tooltip: l10n.consumeSelectedTooltip,
          onPressed: hasSelection ? () => _bulkConsume(context, stock) : null,
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_outline),
          tooltip: l10n.moveSelectedTooltip,
          onPressed: hasSelection ? () => _bulkMove(context, stock) : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.deleteSelectedTooltip,
          onPressed: hasSelection ? () => _bulkDelete(context, stock) : null,
        ),
      ],
    );
  }

  Widget _buildBody(StockProvider stock) {
    final l10n = AppLocalizations.of(context)!;
    if (stock.loading && stock.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stock.error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.stockLoadError('${stock.error}')),
          ),
        ],
      );
    }
    if (stock.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: EmptyState(
              icon: Icons.kitchen_outlined,
              message: l10n.noStockYet,
              actionLabel: l10n.addProductManuallyTooltip,
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductDetailScreen()),
              ),
            ),
          ),
        ],
      );
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
                  child: Text(
                    _bucketLabel(l10n, bucket.key),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: statusDot(context, group.status),
      title: Text(group.productName),
      subtitle: Text([
        if (group.locationNames.isNotEmpty) group.locationNames.join(', '),
        l10n.groupTotalAmount(formatAmount(group.totalAmount)),
      ].join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (group.isLowStock) ...[
            Tooltip(
              message: l10n.lowStockChip,
              child: Icon(Icons.production_quantity_limits, color: statusColor('expiring_soon'), size: 20),
            ),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductBatchesScreen(productId: group.productId, productName: group.productName),
        ),
      ),
    );
  }

  Widget _itemSubtitle(BuildContext context, StockItem item) {
    return Text([
      if (item.locationName != null) item.locationName!,
      if (item.bestBeforeDate != null)
        _relativeLabel(context, item.bestBeforeDate!, _RelativeKind.expiry),
      if (item.purchasedDate != null)
        _relativeLabel(context, item.purchasedDate!, _RelativeKind.purchased),
      if (item.openedAt != null) _relativeLabel(context, item.openedAt!, _RelativeKind.opened),
      formatAmount(item.amount),
    ].join(' · '));
  }

  Widget _buildItemTile(BuildContext context, StockProvider stock, StockItem item) {
    if (_selectionMode) {
      return CheckboxListTile(
        key: ValueKey(item.id),
        value: _selectedIds.contains(item.id),
        onChanged: (_) => _toggleItemSelected(item.id),
        controlAffinity: ListTileControlAffinity.leading,
        secondary: statusDot(context, item.status),
        title: Text(item.productName),
        subtitle: _itemSubtitle(context, item),
      );
    }
    return StockItemActions(
      key: ValueKey(item.id),
      leading: statusDot(context, item.status),
      title: Text(item.productName),
      subtitle: _itemSubtitle(context, item),
      amount: item.amount,
      productName: item.productName,
      canOpen: item.openedAt == null,
      dismissibleKey: item.id,
      onOpen: () => stock.markOpened(item.id),
      onConsume: (amount, reason) => _consume(context, stock, item, amount, reason),
      onDelete: () => _confirmDelete(context, stock, item.id, item.productName),
    );
  }

  Future<bool> _consume(
    BuildContext context,
    StockProvider stock,
    StockItem item,
    double amount,
    String reason,
  ) async {
    try {
      final logId = await stock.consume(item.id, amount, reason: reason);
      if (context.mounted) _showUndoConsumeSnackBar(context, stock, item, amount, reason, logId);
      return true;
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotConsume('$e'))));
      }
      return false;
    }
  }

  // A swipe (or the Use/Spoil buttons) consumes/discards a whole batch with
  // no confirmation dialog (#75/#137) -- give it an Undo instead, which
  // atomically reverses the consume via StockProvider.undoConsume (#160).
  void _showUndoConsumeSnackBar(
    BuildContext context,
    StockProvider stock,
    StockItem item,
    double amount,
    String reason,
    int consumptionLogId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reason == 'spoiled' ? l10n.scannedDiscarded(item.productName) : l10n.scannedUsed(item.productName),
        ),
        action: SnackBarAction(
          label: l10n.undoButton,
          onPressed: () => _undoConsume(context, stock, item, amount, consumptionLogId),
        ),
        // A SnackBar with an action defaults to `persist: true` (stays until
        // manually dismissed) -- opt back into the normal timeout (#178).
        persist: false,
      ),
    );
  }

  Future<void> _undoConsume(
    BuildContext context,
    StockProvider stock,
    StockItem item,
    double amount,
    int consumptionLogId,
  ) async {
    try {
      await stock.undoConsume(item, amount, consumptionLogId);
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotUndo('$e'))));
      }
    }
  }

  Future<bool> _confirmDelete(BuildContext context, StockProvider stock, int id, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeStockTitle),
        content: Text(l10n.deleteBatchConfirm(name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.removeButton)),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await stock.delete(id);
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteStockEntry('$e'))));
      }
      return false;
    }
  }

  // Bulk actions (#123) -- each exits selection mode only on success, so a
  // failure (e.g. a selected entry was already removed elsewhere, tripping
  // the backend's all-or-nothing check) leaves the selection in place for
  // the user to retry or adjust instead of silently dropping it.
  Future<void> _bulkConsume(BuildContext context, StockProvider stock) async {
    final l10n = AppLocalizations.of(context)!;
    final ids = _selectedIds.toList();
    try {
      final count = await stock.bulkConsume(ids);
      if (!context.mounted) return;
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.bulkConsumedCount(count))));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotBulkConsume('$e'))));
      }
    }
  }

  Future<void> _bulkDelete(BuildContext context, StockProvider stock) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bulkDeleteConfirmTitle),
        content: Text(l10n.bulkDeleteConfirm(_selectedIds.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.removeButton)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ids = _selectedIds.toList();
    try {
      final count = await stock.bulkDelete(ids);
      if (!context.mounted) return;
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.bulkDeletedCount(count))));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotBulkDelete('$e'))));
      }
    }
  }

  Future<void> _bulkMove(BuildContext context, StockProvider stock) async {
    final l10n = AppLocalizations.of(context)!;
    final locationId = await _promptMoveLocation(context);
    if (locationId == null || !context.mounted) return;
    final ids = _selectedIds.toList();
    try {
      final count = await stock.bulkMove(ids, locationId);
      if (!context.mounted) return;
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.bulkMovedCount(count))));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotBulkMove('$e'))));
      }
    }
  }

  // Location picker for bulk move -- same DropdownButtonFormField pattern
  // AddBatchSheet uses for a single new batch's location, just wrapped in a
  // dialog instead of a bottom sheet since there's no other field to show
  // alongside it. Reuses _locations, already loaded for the filter row.
  Future<int?> _promptMoveLocation(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    int? selected = _locations.isNotEmpty ? _locations.first.id : null;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.moveToLocationTitle),
          content: DropdownButtonFormField<int>(
            initialValue: selected,
            decoration: InputDecoration(labelText: l10n.locationLabel),
            items: [for (final l in _locations) DropdownMenuItem(value: l.id, child: Text(l.name))],
            onChanged: (value) => setDialogState(() => selected = value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelButton)),
            FilledButton(
              onPressed: selected == null ? null : () => Navigator.pop(context, selected),
              child: Text(l10n.moveButton),
            ),
          ],
        ),
      ),
    );
  }
}
