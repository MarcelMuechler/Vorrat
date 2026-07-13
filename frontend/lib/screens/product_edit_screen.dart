import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../widgets/category_field.dart';
import '../widgets/quantity_unit_field.dart';

class ProductEditScreen extends StatefulWidget {
  final Product product;

  const ProductEditScreen({super.key, required this.product});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  late final TextEditingController _nameController;
  final _categoryFieldKey = GlobalKey<CategoryFieldState>();
  int? _categoryId;
  String? _categoryName;
  late String _quantityUnit;
  late final TextEditingController _bestBeforeDaysController;
  late final TextEditingController _openShelfLifeDaysController;
  late final TextEditingController _lowStockThresholdController;
  List<Location> _locations = [];
  int? _selectedLocationId;
  String? _imageUrl;
  bool _loadingLocations = true;
  bool _saving = false;
  bool _refreshingFromOff = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _categoryId = p.categoryId;
    _categoryName = p.categoryName;
    _quantityUnit = p.quantityUnit;
    _bestBeforeDaysController = TextEditingController(
      text: p.defaultBestBeforeDays == null ? '' : '${p.defaultBestBeforeDays}',
    );
    _openShelfLifeDaysController = TextEditingController(
      text: p.defaultOpenShelfLifeDays == null ? '' : '${p.defaultOpenShelfLifeDays}',
    );
    _lowStockThresholdController = TextEditingController(
      text: p.lowStockThreshold == null ? '' : '${p.lowStockThreshold}',
    );
    _selectedLocationId = p.defaultLocationId;
    _imageUrl = p.imageUrl;
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bestBeforeDaysController.dispose();
    _openShelfLifeDaysController.dispose();
    _lowStockThresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final locations = await context.read<ApiClient>().listLocations();
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _loadingLocations = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Force-resolve whatever's currently typed first -- tapping Save right
    // after typing a brand-new category would otherwise race the field's
    // own async create-category call.
    await _categoryFieldKey.currentState?.resolve();
    if (!mounted) return;
    final api = context.read<ApiClient>();
    try {
      await api.updateProduct(widget.product.id, {
        'name': _nameController.text,
        'category_id': _categoryId,
        'quantity_unit': _quantityUnit.isEmpty ? 'pcs' : _quantityUnit,
        'default_location_id': _selectedLocationId,
        'default_best_before_days': int.tryParse(_bestBeforeDaysController.text),
        'default_open_shelf_life_days': int.tryParse(_openShelfLifeDaysController.text),
        'low_stock_threshold': double.tryParse(_lowStockThresholdController.text),
        'image_url': _imageUrl,
      });
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

  Future<void> _refreshFromOff() async {
    setState(() => _refreshingFromOff = true);
    final api = context.read<ApiClient>();
    try {
      final data = await api.refreshProductFromOff(widget.product.id);
      if (!mounted) return;
      final offCategory = data['category'] as String?;
      if (offCategory != null) {
        // Matches/creates the category the same way typing it in and
        // blurring would (#72/#73); updates _categoryId/_categoryName via
        // the field's own onChanged callback.
        _categoryFieldKey.currentState?.setText(offCategory);
        await _categoryFieldKey.currentState?.resolve();
        if (!mounted) return;
      }
      setState(() {
        _nameController.text = data['name'] as String? ?? _nameController.text;
        _imageUrl = data['image_url'] as String? ?? _imageUrl;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.fetchedFromOff)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotRefresh('$e'))));
      }
    } finally {
      if (mounted) setState(() => _refreshingFromOff = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProductTitle),
        actions: [
          if (widget.product.barcode != null)
            IconButton(
              icon: _refreshingFromOff
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              tooltip: l10n.refreshFromOffTooltip,
              onPressed: _refreshingFromOff ? null : _refreshFromOff,
            ),
        ],
      ),
      body: _loadingLocations
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_imageUrl != null) ...[
                  Center(
                    child: Image.network(_imageUrl!, height: 120, errorBuilder: (_, _, _) => const SizedBox()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.product.barcode != null) ...[
                  Text(l10n.barcodeLabel(widget.product.barcode!)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.nameLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                CategoryField(
                  key: _categoryFieldKey,
                  categoryId: _categoryId,
                  categoryName: _categoryName,
                  label: l10n.categoryLabel,
                  onChanged: (category) => setState(() {
                    _categoryId = category?.id;
                    _categoryName = category?.name;
                  }),
                ),
                const SizedBox(height: 12),
                QuantityUnitField(
                  value: _quantityUnit,
                  label: l10n.quantityUnitLabel,
                  onChanged: (value) => setState(() => _quantityUnit = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _selectedLocationId,
                  decoration: InputDecoration(
                    labelText: l10n.defaultLocationLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<int>(value: null, child: Text(l10n.noneLabel)),
                    for (final l in _locations) DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (value) => setState(() => _selectedLocationId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bestBeforeDaysController,
                  decoration: InputDecoration(
                    labelText: l10n.defaultBestBeforeDaysLabel,
                    hintText: l10n.defaultBestBeforeDaysHint,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _openShelfLifeDaysController,
                  decoration: InputDecoration(
                    labelText: l10n.openShelfLifeLabel,
                    hintText: l10n.openShelfLifeHint,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lowStockThresholdController,
                  decoration: InputDecoration(
                    labelText: l10n.lowStockThresholdLabel,
                    hintText: l10n.lowStockThresholdHint,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
