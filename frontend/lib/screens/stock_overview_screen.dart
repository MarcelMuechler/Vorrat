import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
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
  List<String> _categories = [];
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
    _loadCategories();
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

  // No dedicated "distinct categories" endpoint -- category is free text
  // maintained by the user (#57), so the full product list is the only
  // source of the values actually in use.
  Future<void> _loadCategories() async {
    try {
      final products = await context.read<ApiClient>().listProducts();
      if (!mounted) return;
      final categories = {for (final p in products) if (p.category != null && p.category!.isNotEmpty) p.category!}.toList()
        ..sort();
      setState(() => _categories = categories);
    } catch (_) {
      // Filter dropdown just stays hidden, same as _loadLocations above.
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stockTitle),
        actions: [
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
              PopupMenuItem(
                value: StockSort.bestBeforeDate,
                child: Text(l10n.sortBestBeforeDateLabel),
              ),
              PopupMenuItem(value: StockSort.name, child: Text(l10n.nameLabel)),
              PopupMenuItem(value: StockSort.amount, child: Text(l10n.amountFieldLabel)),
              PopupMenuItem(value: StockSort.location, child: Text(l10n.locationLabel)),
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
              decoration: InputDecoration(
                labelText: l10n.searchLabel,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (value) => stock.setSearchFilter(value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text(l10n.expiringSoonChip),
                    selected: stock.expiringWithinDaysFilter != null,
                    onSelected: (selected) =>
                        stock.setExpiringFilter(selected ? stock.expiringSoonDays : null),
                  ),
                  const SizedBox(width: 12),
                  if (_locations.isNotEmpty)
                    DropdownButton<int?>(
                      value: stock.locationIdFilter,
                      hint: Text(l10n.allLocationsLabel),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text(l10n.allLocationsLabel)),
                        for (final l in _locations) DropdownMenuItem(value: l.id, child: Text(l.name)),
                      ],
                      onChanged: (value) => stock.setLocationFilter(value),
                    ),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: stock.categoryFilter,
                      hint: Text(l10n.allCategoriesLabel),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text(l10n.allCategoriesLabel)),
                        for (final c in _categories) DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (value) => stock.setCategoryFilter(value),
                    ),
                  ],
                ],
              ),
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
        tooltip: l10n.addProductManuallyTooltip,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductDetailScreen()),
        ),
        child: const Icon(Icons.add),
      ),
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
      return Center(child: Text(l10n.noStockYet));
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
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: CircleAvatar(backgroundColor: _statusColor(group.status), radius: 6),
      title: Text(group.productName),
      subtitle: Text([
        if (group.locationNames.isNotEmpty) group.locationNames.join(', '),
        l10n.groupTotalAmount('${group.totalAmount}'),
      ].join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (group.isLowStock) ...[
            Tooltip(
              message: l10n.lowStockChip,
              child: const Icon(Icons.production_quantity_limits, color: Colors.orange, size: 20),
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

  Widget _buildItemTile(BuildContext context, StockProvider stock, StockItem item) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: CircleAvatar(backgroundColor: _statusColor(item.status), radius: 6),
      title: Text(item.productName),
      subtitle: Text([
        if (item.locationName != null) item.locationName!,
        if (item.bestBeforeDate != null)
          _relativeLabel(context, item.bestBeforeDate!, _RelativeKind.expiry),
        if (item.purchasedDate != null)
          _relativeLabel(context, item.purchasedDate!, _RelativeKind.purchased),
        if (item.openedAt != null) _relativeLabel(context, item.openedAt!, _RelativeKind.opened),
        '${item.amount}',
      ].join(' · ')),
      trailing: item.openedAt == null
          ? IconButton(
              icon: const Icon(Icons.lock_open),
              tooltip: l10n.markAsOpenedTooltip,
              onPressed: () => stock.markOpened(item.id),
            )
          : null,
      onTap: () => _consumeDialog(context, stock, item),
      onLongPress: () => _confirmDelete(context, stock, item.id, item.productName),
    );
  }

  Future<void> _consumeDialog(BuildContext context, StockProvider stock, StockItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: '1');
    var reason = 'used';
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.useSomeOfTitle(item.productName)),
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
    if (amount == null || amount <= 0 || !context.mounted) return;
    try {
      await stock.consume(item.id, amount, reason: reason);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotConsume('$e'))));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, StockProvider stock, int id, String name) async {
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
    if (confirmed == true) await stock.delete(id);
  }
}
