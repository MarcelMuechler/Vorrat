import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../util/format.dart';
import '../util/status.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.shoppingListItemDeleted(item.name)),
        action: SnackBarAction(label: l10n.undoButton, onPressed: () => _undoDelete(item)),
      ),
    );
  }

  // Re-creates the item with its previous fields (#137) -- not a true undo:
  // it gets a new id and lands wherever a freshly-created item sorts (newest
  // open items first), so its position in the list may differ from before
  // the swipe, and a product-linked item's amount/unit are re-sent
  // explicitly even though they were originally inherited from the product.
  Future<void> _undoDelete(ShoppingListItem item) async {
    try {
      final api = context.read<ApiClient>();
      final restored = await api.createShoppingListItem(
        productId: item.productId,
        name: item.productId == null ? item.name : null,
        amount: item.amount,
        unit: item.unit,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shoppingListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: l10n.addLowStockTooltip,
            onPressed: _addLowStock,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: l10n.clearDoneTooltip,
            onPressed: hasDone ? _clearDone : null,
          ),
        ],
      ),
      body: Column(
        children: [
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
            border: const OutlineInputBorder(),
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
            child: Center(child: Text(l10n.shoppingListEmpty)),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _buildItemTile(_items[index]),
    );
  }

  Widget _buildItemTile(ShoppingListItem item) {
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
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: item.done,
        onChanged: (_) => _toggleDone(item),
        title: Text(
          item.name,
          style: item.done
              ? TextStyle(decoration: TextDecoration.lineThrough, color: Theme.of(context).disabledColor)
              : null,
        ),
        subtitle: showAmount
            ? Text('${formatAmount(item.amount)}${item.unit != null ? ' ${item.unit}' : ''}')
            : null,
      ),
    );
  }
}
