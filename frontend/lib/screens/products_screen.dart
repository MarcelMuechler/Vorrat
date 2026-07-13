import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import 'product_batches_screen.dart';
import 'product_edit_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
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
                          _searchController.clear();
                          _refresh();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _refresh(),
            ),
          ),
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l10n.couldNotLoadProducts('$_error')),
                      )
                    : _visibleProducts.isEmpty
                        ? Center(child: Text(l10n.noProductsYet))
                        : ListView.separated(
                            itemCount: _visibleProducts.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = _visibleProducts[index];
                              return ListTile(
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
                                          builder: (_) => ProductBatchesScreen(
                                            productId: product.id,
                                            productName: product.name,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: l10n.deleteButton,
                                      onPressed: () => _delete(product),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
