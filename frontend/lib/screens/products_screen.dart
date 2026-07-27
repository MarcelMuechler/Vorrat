import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/stock_provider.dart';
import '../widgets/refreshable_list.dart';
import 'product_batches_screen.dart';
import 'product_edit_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  int? _categoryFilter;

  List<Product> get _visibleProducts => _categoryFilter == null
      ? _products
      : _products.where((p) => p.categoryId == _categoryFilter).toList();

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<ApiClient>().listCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Filter dropdown just stays hidden -- the products list's own error
      // state already surfaces connectivity issues.
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await context.read<ApiClient>().listProducts(search: _searchController.text);
      if (!mounted) return;
      setState(() => _products = products);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProductTitle),
        content: Text(l10n.deleteProductConfirm(product.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.deleteButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiClient>().deleteProduct(product.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteProduct('$e'))));
      }
    }
  }

  /// Folds one product into another (#333). Until this existed there was no
  /// way back from a duplicate: delete_product refuses while stock exists, so
  /// the only route was deleting every batch by hand -- which logs waste that
  /// never happened -- and re-entering it against the other product.
  Future<void> _merge(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final candidates = _products.where((p) => p.id != product.id).toList();
    if (candidates.isEmpty) return;
    final target = await showDialog<Product>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.mergeProductPickTitle(product.name)),
        children: [
          for (final candidate in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, candidate),
              child: Text(candidate.name),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mergeProductAction),
        content: Text(l10n.mergeProductConfirm(product.name, target.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.mergeProductAction)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiClient>().mergeProduct(product.id, target.id);
      await _refresh();
      // Stock rows moved between products -- anything already loaded is stale.
      if (mounted) await context.read<StockProvider>().refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotMergeProduct('$e'))));
      }
    }
  }

  Future<void> _edit(Product product) async {
    final updated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => ProductEditScreen(product: product)));
    if (updated == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.productsTitle)),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
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
                                _refresh();
                                setState(() {});
                              },
                            ),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (_) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 350), _refresh);
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      _searchDebounce?.cancel();
                      _refresh();
                    },
                  ),
                ),
                if (_categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _categoryFilter,
                            hint: Text(l10n.allCategoriesLabel),
                            items: [
                              DropdownMenuItem<int?>(value: null, child: Text(l10n.allCategoriesLabel)),
                              for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                            ],
                            onChanged: (value) => setState(() => _categoryFilter = value),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshableList<Product>(
              loading: _loading,
              error: _error,
              errorText: (e) => l10n.couldNotLoadProducts('$e'),
              emptyIcon: Icons.inventory_2_outlined,
              emptyText: l10n.noProductsYet,
              items: _visibleProducts,
              onRefresh: _refresh,
              itemBuilder: (context, product) => ListTile(
                title: Text(product.name),
                subtitle: product.barcode != null ? Text(product.barcode!) : null,
                onTap: () => _edit(product),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.inventory_2_outlined),
                      tooltip: l10n.viewStockBatchesTooltip,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductBatchesScreen(productId: product.id, productName: product.name),
                        ),
                      ),
                    ),
                    // An overflow rather than a third icon: merging is rare
                    // enough not to earn a permanent slot, and the row is
                    // already tight on a phone.
                    PopupMenuButton<void Function()>(
                      onSelected: (action) => action(),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: () => _merge(product),
                          child: Text(l10n.mergeProductAction),
                        ),
                        PopupMenuItem(
                          value: () => _delete(product),
                          child: Text(l10n.deleteButton),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
