import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/stock_provider.dart';
import '../util/format.dart';

/// Inline "add a batch" form for a product that's already known, shown as a
/// modal bottom sheet over the scan screen (#98) so unloading a grocery haul
/// in Add mode doesn't require a full-screen round trip per item the way
/// ProductDetailScreen does. Deliberately a stripped-down subset of that
/// screen's fields -- no name/category/quantity-unit, since those belong to
/// the Product, not this stock entry, and the product already exists.
class AddBatchSheet extends StatefulWidget {
  final Product product;

  const AddBatchSheet({super.key, required this.product});

  /// Returns true once a batch was actually added, or null if the sheet was
  /// cancelled/dismissed without saving.
  static Future<bool?> show(BuildContext context, Product product) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AddBatchSheet(product: product),
      ),
    );
  }

  @override
  State<AddBatchSheet> createState() => _AddBatchSheetState();
}

class _AddBatchSheetState extends State<AddBatchSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _priceController;
  List<Location> _locations = [];
  int? _selectedLocationId;
  DateTime? _bestBeforeDate;
  bool _loadingLocations = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '1');
    _priceController = TextEditingController();
    _selectedLocationId = widget.product.defaultLocationId;
    final defaultDays = widget.product.defaultBestBeforeDays;
    if (defaultDays != null) {
      _bestBeforeDate = DateTime.now().add(Duration(days: defaultDays));
    }
    _loadLocations();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await context.read<ApiClient>().listLocations();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _loadingLocations = false;
      });
    } catch (e) {
      // Don't leave the dropdown spinning forever on an unhandled error --
      // location is optional on a stock entry, so degrade to an empty
      // dropdown (saving without one is fine) and say what happened.
      if (!mounted) return;
      setState(() => _loadingLocations = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldNotLoadLocations('$e'))),
      );
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

  void _setBestBeforeOffset(int days) {
    setState(() => _bestBeforeDate = DateTime.now().add(Duration(days: days)));
  }

  void _stepAmount(double delta) {
    final current = double.tryParse(_amountController.text) ?? 0;
    final next = current + delta;
    if (next <= 0) return;
    _amountController.text = formatAmount(next);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text) ?? 1;
    final price = double.tryParse(_priceController.text);
    setState(() => _saving = true);
    final api = context.read<ApiClient>();
    try {
      await api.addStock({
        'product_id': widget.product.id,
        'location_id': _selectedLocationId,
        'amount': amount,
        'best_before_date': _bestBeforeDate?.toIso8601String().split('T').first,
        'price': price,
      });
      if (!mounted) return;
      await context.read<StockProvider>().refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotSave('$e'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.product.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      widget.product.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(width: 48, height: 48),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(widget.product.name, style: Theme.of(context).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.amountFieldLabel, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(onPressed: () => _stepAmount(-1), icon: const Icon(Icons.remove)),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _amountController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                IconButton.outlined(onPressed: () => _stepAmount(1), icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: InputDecoration(labelText: l10n.priceFieldLabel, isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Text(l10n.locationLabel, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            _loadingLocations
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Wrap(
                    spacing: 8,
                    children: [
                      for (final location in _locations)
                        ChoiceChip(
                          label: Text(location.name),
                          selected: _selectedLocationId == location.id,
                          onSelected: (_) => setState(() => _selectedLocationId = location.id),
                        ),
                    ],
                  ),
            const SizedBox(height: 16),
            Text(l10n.bestBeforeSectionLabel, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in [3, 7, 30])
                  ActionChip(
                    label: Text(l10n.inDaysChipLabel(days)),
                    onPressed: () => _setBestBeforeOffset(days),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _bestBeforeDate == null
                        ? l10n.pickDateLabel
                        : _bestBeforeDate!.toIso8601String().split('T').first,
                  ),
                  onPressed: _pickBestBeforeDate,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n.cancelButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.addButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
