import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
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
  late final TextEditingController _brandController;
  late final TextEditingController _amountController;
  List<Location> _locations = [];
  int? _selectedLocationId;
  DateTime? _bestBeforeDate;
  bool _loadingLocations = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingProduct?.name ?? widget.prefill?.name ?? '',
    );
    _brandController = TextEditingController(
      text: widget.existingProduct?.brand ?? widget.prefill?.brand ?? '',
    );
    _amountController = TextEditingController(text: '1');
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New location'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add location: $e')));
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
          'brand': _brandController.text.isEmpty ? null : _brandController.text,
          'image_url': widget.prefill?.imageUrl,
          'category': widget.prefill?.category,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to stock')),
      body: _loadingLocations
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.barcode != null) ...[
                  Text('Barcode: ${widget.barcode}'),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _brandController,
                  decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedLocationId,
                        decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
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
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _bestBeforeDate == null
                        ? 'No best-before date'
                        : 'Best before: ${_bestBeforeDate!.toIso8601String().split('T').first}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickBestBeforeDate,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
    );
  }
}
