import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/settings_provider.dart';
import '../state/stock_provider.dart';
import '../util/format.dart';
import '../widgets/category_field.dart';
import '../widgets/quantity_unit_field.dart';

class ProductDetailScreen extends StatefulWidget {
  final String? barcode;
  final Product? existingProduct;
  final ProductPrefill? prefill;

  const ProductDetailScreen({super.key, this.barcode, this.existingProduct, this.prefill});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final TextEditingController _nameController;
  final _categoryFieldKey = GlobalKey<CategoryFieldState>();
  int? _categoryId;
  late final TextEditingController _amountController;
  late String _quantityUnit;
  List<Location> _locations = [];
  int? _selectedLocationId;
  DateTime? _bestBeforeDate;
  bool _loadingLocations = true;
  bool _saving = false;

  String? get _imageUrl => widget.existingProduct?.imageUrl ?? widget.prefill?.imageUrl;

  /// OFF's suggested category, unless the setting to suggest one is off
  /// (#71) -- gates both the hint shown while adding and the "leave it
  /// blank to accept the suggestion" fallback on save.
  String? get _offCategorySuggestion => context.read<SettingsProvider>().offCategorySuggestionsEnabled
      ? widget.prefill?.category
      : null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingProduct?.name ?? widget.prefill?.name ?? '',
    );
    _amountController = TextEditingController(
      text: widget.prefill?.amount != null ? formatAmount(widget.prefill!.amount!) : '1',
    );
    _quantityUnit = widget.existingProduct?.quantityUnit ?? widget.prefill?.quantityUnit ?? 'pcs';
    _selectedLocationId = widget.existingProduct?.defaultLocationId;
    final defaultDays = widget.existingProduct?.defaultBestBeforeDays;
    if (defaultDays != null) {
      _bestBeforeDate = DateTime.now().add(Duration(days: defaultDays));
    }
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final api = context.read<ApiClient>();
    final locations = await api.listLocations();
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _loadingLocations = false;
    });
  }

  Future<void> _addLocation() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newLocationTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.addButton),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final api = context.read<ApiClient>();
    try {
      final location = await api.createLocation(name);
      if (!mounted) return;
      setState(() {
        _locations = [..._locations, location];
        _selectedLocationId = location.id;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotAddLocation('$e'))));
      }
    }
  }

  Future<void> _pickBestBeforeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _bestBeforeDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _bestBeforeDate = picked);
  }

  /// Barcode-less products have no uniqueness constraint at all (unlike
  /// barcoded ones, protected by the DB's unique barcode column) -- a typo'd
  /// re-entry of an existing name would otherwise silently create a second,
  /// separate product. Only an exact case-insensitive match after trimming;
  /// no fuzzy matching (#47).
  Future<Product?> _findExactNameMatch(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final api = context.read<ApiClient>();
    final candidates = await api.listProducts(search: trimmed);
    for (final p in candidates) {
      if (p.name.trim().toLowerCase() == trimmed.toLowerCase()) return p;
    }
    return null;
  }

  /// Force-resolves the category field's current text (rather than trusting
  /// whatever onChanged last reported) -- tapping Save right after typing a
  /// brand-new category would otherwise race the field's own async
  /// create-category call. The OFF suggestion is already sitting in the
  /// field as real, editable text by the time this runs (#70), and an
  /// empty field (the user cleared it) correctly resolves to no category --
  /// no separate "accept the suggestion" fallback needed.
  Future<int?> _resolveCategoryId() async {
    await _categoryFieldKey.currentState?.resolve();
    return _categoryId;
  }

  Future<bool> _confirmUseExisting(Product existing) async {
    final l10n = AppLocalizations.of(context)!;
    final useExisting = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.duplicateProductTitle),
        content: Text(l10n.duplicateProductMessage(existing.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.duplicateProductCreateNew),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.duplicateProductUseExisting),
          ),
        ],
      ),
    );
    return useExisting ?? false;
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text) ?? 1;
    setState(() => _saving = true);
    final api = context.read<ApiClient>();
    try {
      int productId;
      if (widget.existingProduct != null) {
        productId = widget.existingProduct!.id;
      } else {
        Product? useExisting;
        if (widget.barcode == null) {
          final match = await _findExactNameMatch(_nameController.text);
          if (match != null && mounted && await _confirmUseExisting(match)) {
            useExisting = match;
          }
        }
        if (useExisting != null) {
          productId = useExisting.id;
        } else {
          final created = await api.createProduct({
            'barcode': widget.barcode,
            'name': _nameController.text,
            'image_url': widget.prefill?.imageUrl,
            'category_id': await _resolveCategoryId(),
            'quantity_unit': _quantityUnit.isEmpty ? 'pcs' : _quantityUnit,
          });
          productId = created.id;
        }
      }
      await api.addStock({
        'product_id': productId,
        'location_id': _selectedLocationId,
        'amount': amount,
        'best_before_date': _bestBeforeDate?.toIso8601String().split('T').first,
      });
      if (!mounted) return;
      await context.read<StockProvider>().refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotSave('$e'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addToStockTitle)),
      body: _loadingLocations
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.prefill != null) ...[
                  Text(l10n.offReviewHint, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                ],
                if (_imageUrl != null) ...[
                  Center(
                    child: Image.network(_imageUrl!, height: 120, errorBuilder: (_, _, _) => const SizedBox()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.barcode != null) ...[
                  Text(l10n.barcodeLabel(widget.barcode!)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.nameLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (widget.existingProduct == null) ...[
                  CategoryField(
                    key: _categoryFieldKey,
                    categoryId: _categoryId,
                    // OFF's suggestion is prefilled as real, editable text
                    // (not just a hint) -- the field's own clear button
                    // removes it in one tap if unwanted (#70). Suppressed
                    // entirely if the setting to suggest one is off (#71).
                    categoryName: _offCategorySuggestion,
                    label: l10n.categoryLabel,
                    onChanged: (category) => setState(() => _categoryId = category?.id),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedLocationId,
                        decoration: InputDecoration(
                          labelText: l10n.locationLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: _locations
                            .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedLocationId = value),
                      ),
                    ),
                    IconButton(onPressed: _addLocation, icon: const Icon(Icons.add)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: l10n.amountFieldLabel,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    // The unit belongs to the Product, not this stock entry --
                    // only settable at first creation. Editing it afterwards
                    // is ProductEditScreen's job (#43).
                    if (widget.existingProduct == null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: QuantityUnitField(
                          value: _quantityUnit,
                          label: l10n.unitLabel,
                          onChanged: (value) => setState(() => _quantityUnit = value),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _bestBeforeDate == null
                        ? l10n.noBestBeforeDate
                        : l10n.bestBeforeLabel(_bestBeforeDate!.toIso8601String().split('T').first),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickBestBeforeDate,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.saveButton),
                ),
              ],
            ),
    );
  }
}
