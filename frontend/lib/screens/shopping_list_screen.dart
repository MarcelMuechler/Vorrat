import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../util/format.dart';
import '../state/stock_provider.dart';
import '../util/status.dart';
import '../widgets/edit_shopping_list_item_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/undo_snackbar.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<ShoppingListItem> _items = [];
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadProducts();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<ApiClient>().listShoppingList();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await context.read<ApiClient>().listProducts();
      if (mounted) setState(() => _products = products);
    } catch (_) {
      // The add field just has no suggestions -- free-text add still works.
    }
  }

  Product? _findProductByName(String name) {
    final trimmed = name.trim().toLowerCase();
    for (final p in _products) {
      if (p.name.toLowerCase() == trimmed) return p;
    }
    return null;
  }

  Future<void> _addItem({int? productId, String? name}) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<ApiClient>().createShoppingListItem(productId: productId, name: name);
      _addController.clear();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotAddShoppingListItem('$e'))));
      }
    }
  }

  void _submitAdd(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final match = _findProductByName(trimmed);
    if (match != null) {
      _addItem(productId: match.id);
    } else {
      _addItem(name: trimmed);
    }
  }

  Future<void> _toggleDone(ShoppingListItem item) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<ApiClient>().updateShoppingListItem(item.id, {'done': !item.done});
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotUpdateShoppingListItem('$e'))));
      }
    }
  }

  // Returns whether the delete actually happened -- Dismissible reverts the
  // swipe (restoring the item) when this returns false, so an API failure
  // here doesn't leave the UI showing a state the server doesn't have (#84).
  Future<bool> _delete(ShoppingListItem item) async {
    try {
      await context.read<ApiClient>().deleteShoppingListItem(item.id);
      if (mounted) setState(() => _items.removeWhere((i) => i.id == item.id));
      if (mounted) _showUndoDeleteSnackBar(item);
      return true;
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteShoppingListItem('$e'))));
      }
      return false;
    }
  }

  void _showUndoDeleteSnackBar(ShoppingListItem item) {
    final l10n = AppLocalizations.of(context)!;
    showUndoSnackBar(
      context,
      message: l10n.shoppingListItemDeleted(item.name),
      onUndo: () => _undoDelete(item),
    );
  }

  // Re-creates the item with its previous fields (#137) -- not a true undo:
  // it gets a new id and lands wherever a freshly-created item sorts (newest
  // open items first), so its position in the list may differ from before
  // the swipe, and a product-linked item's amount/unit are re-sent
  // explicitly even though they were originally inherited from the product.
  // categoryId is only ever non-null on a free-text item (#122), so passing
  // it through unconditionally is safe for product-linked items too.
  Future<void> _undoDelete(ShoppingListItem item) async {
    try {
      final api = context.read<ApiClient>();
      final restored = await api.createShoppingListItem(
        productId: item.productId,
        name: item.productId == null ? item.name : null,
        amount: item.amount,
        unit: item.unit,
        categoryId: item.categoryId,
      );
      if (item.done) {
        await api.updateShoppingListItem(restored.id, {'done': true});
      }
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotUndo('$e'))));
      }
    }
  }

  Future<void> _addLowStock() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final created = await context.read<ApiClient>().addLowStockToShoppingList();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.lowStockAddedCount(created.length))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotAddLowStock('$e'))));
      }
    }
  }

  // Only free-text items get an edit sheet -- a product-linked item's
  // name/unit come from the Product, and it can't have its own category
  // either (the backend rejects category_id alongside product_id), so
  // there's nothing on it for this form to edit.
  Future<void> _editItem(ShoppingListItem item) async {
    final updated = await EditShoppingListItemSheet.show(context, item);
    if (updated == true) await _refresh();
  }

  Future<void> _clearDone() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final deleted = await context.read<ApiClient>().clearDoneShoppingListItems();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.clearedDoneCount(deleted))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotClearDone('$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasDone = _items.any((i) => i.done);
    // Reads StockProvider's already-loaded data (no fetch of its own) --
    // only populated once the Stock tab has been visited at least once,
    // same as its "Low stock" stat card (#199 wireframe revamp).
    final lowStockGroups = context.watch<StockProvider>().groupedItems.where((g) => g.isLowStock).toList();
    // Product ids already queued: an open (not-done) item linked to that
    // product. Mirrors the backend's own "already listed" check in
    // add_low_stock_items (routers/shopping_list.py) so the banner's notion
    // of "already on the list" can't drift from what tapping the button
    // actually does (#254).
    final openListedProductIds = _items
        .where((i) => !i.done && i.productId != null)
        .map((i) => i.productId)
        .toSet();
    final lowStockCount = lowStockGroups.length;
    final lowStockPendingCount =
        lowStockGroups.where((g) => !openListedProductIds.contains(g.productId)).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shoppingListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: l10n.clearDoneTooltip,
            onPressed: hasDone ? _clearDone : null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (lowStockCount > 0) _buildLowStockBanner(context, l10n, lowStockCount, lowStockPendingCount),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildAddField(l10n),
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: _refresh, child: _buildBody(l10n)),
          ),
        ],
      ),
    );
  }

  // `pending` is `count` minus whatever's already queued as an open item on
  // the shopping list (#254) -- once it hits 0, every currently-low-stock
  // product already has an open item, so the button is disabled and the
  // label says so instead of staying indistinguishable from "nothing done
  // yet" after a tap.
  Widget _buildLowStockBanner(BuildContext context, AppLocalizations l10n, int count, int pending) {
    final colors = Theme.of(context).colorScheme;
    final allQueued = pending == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(allQueued ? l10n.lowStockAllQueuedText(count) : l10n.lowStockBannerText(count)),
            ),
            FilledButton.tonal(
              onPressed: allQueued ? null : _addLowStock,
              child: Text(l10n.addAllButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddField(AppLocalizations l10n) {
    return RawAutocomplete<Product>(
      textEditingController: _addController,
      focusNode: _addFocusNode,
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) {
        if (value.text.isEmpty) return const Iterable<Product>.empty();
        final query = value.text.toLowerCase();
        return _products.where((p) => p.name.toLowerCase().contains(query));
      },
      onSelected: (product) => _addItem(productId: product.id),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: l10n.shoppingListAddHint,
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.addButton,
              onPressed: () => _submitAdd(controller.text),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: _submitAdd,
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                return ListTile(title: Text(option.name), onTap: () => onSelected(option));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.couldNotLoadShoppingList('$_error')),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: EmptyState(icon: Icons.shopping_cart_outlined, message: l10n.shoppingListEmpty),
          ),
        ],
      );
    }
    // Pending items first, then a "Done" section (#199 wireframe revamp) --
    // partitioned client-side by .done instead of relying on sort order.
    // Within "pending", items are further grouped by category so shopping
    // aisle-by-aisle is easier (#293) -- "Done" stays a flat list since it's
    // no longer something you're actively shopping from.
    final pending = _items.where((i) => !i.done).toList();
    final done = _items.where((i) => i.done).toList();
    final categoryGroups = _groupByCategory(pending);
    return ListView(
      children: [
        for (final group in categoryGroups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              group.key ?? l10n.uncategorizedSectionLabel,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          for (final item in group.value) _buildItemTile(item),
        ],
        if (done.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.doneSectionLabel,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          for (final item in done) _buildItemTile(item),
        ],
      ],
    );
  }

  // Groups (not-done) items by categoryName, alphabetically (case-insensitive)
  // with items lacking a category (free-text items without one, or
  // product-linked items whose product also lacks one) bucketed under a null
  // key and sorted last as "Uncategorized" (#293).
  List<MapEntry<String?, List<ShoppingListItem>>> _groupByCategory(List<ShoppingListItem> items) {
    final groups = <String?, List<ShoppingListItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.categoryName, () => []).add(item);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) {
        if (a.key == null) return b.key == null ? 0 : 1;
        if (b.key == null) return -1;
        return a.key!.toLowerCase().compareTo(b.key!.toLowerCase());
      });
    return entries;
  }

  Widget _buildItemTile(ShoppingListItem item) {
    final l10n = AppLocalizations.of(context)!;
    final showAmount = item.amount != 1 || (item.unit != null && item.unit!.isNotEmpty);
    return Dismissible(
      key: ValueKey(item.id),
      background: Container(
        color: statusColor('expired'),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: statusColor('expired'),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _delete(item),
      // A plain ListTile, not CheckboxListTile -- CheckboxListTile merges its
      // *entire* row (including `secondary`) into one semantics node whose
      // only action is the checkbox toggle, which would swallow taps meant
      // for the edit button below and always toggle done instead. Wiring the
      // Checkbox explicitly as `leading` keeps it (and the trailing edit
      // button) as independent, individually tappable controls.
      child: ListTile(
        onTap: () => _toggleDone(item),
        leading: Checkbox(value: item.done, onChanged: (_) => _toggleDone(item)),
        trailing: item.productId == null
            ? IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editItemTooltip,
                onPressed: () => _editItem(item),
              )
            : null,
        title: Row(
          children: [
            Flexible(
              child: Text(
                item.name,
                style: item.done
                    ? TextStyle(decoration: TextDecoration.lineThrough, color: Theme.of(context).disabledColor)
                    : null,
              ),
            ),
            if (item.productId != null) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(l10n.fromStockTag),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            if (item.categoryName != null) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(item.categoryName!),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
        subtitle: showAmount
            ? Text('${formatAmount(item.amount)}${item.unit != null ? ' ${item.unit}' : ''}')
            : null,
      ),
    );
  }
}
