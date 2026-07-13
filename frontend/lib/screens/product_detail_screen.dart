import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/stock_provider.dart';

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
  late final TextEditingController _amountController;
  late final TextEditingController _quantityUnitController;
  List<Location> _locations = [];
  int? _selectedLocationId;
  DateTime? _bestBeforeDate;
  bool _loadingLocations = true;
  bool _saving = false;

  String? get _imageUrl => widget.existingProduct?.imageUrl ?? widget.prefill?.imageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingProduct?.name ?? widget.prefill?.name ?? '',
    );
    _amountController = TextEditingController(
      text: widget.prefill?.amount != null ? '${widget.prefill!.amount}' : '1',
    );
    _quantityUnitController = TextEditingController(
      text: widget.existingProduct?.quantityUnit ?? widget.prefill?.quantityUnit ?? 'pcs',
    );
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

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text) ?? 1;
    setState(() => _saving = true);
    final api = context.read<ApiClient>();
    try {
      int productId;
      if (widget.existingProduct != null) {
        productId = widget.existingProduct!.id;
      } else {
        final created = await api.createProduct({
          'barcode': widget.barcode,
          'name': _nameController.text,
          'image_url': widget.prefill?.imageUrl,
          'category': widget.prefill?.category,
          'quantity_unit': _quantityUnitController.text.isEmpty ? 'pcs' : _quantityUnitController.text,
        });
        productId = created.id;
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
                        child: TextField(
                          controller: _quantityUnitController,
                          decoration: InputDecoration(
                            labelText: l10n.unitLabel,
                            border: const OutlineInputBorder(),
                          ),
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
