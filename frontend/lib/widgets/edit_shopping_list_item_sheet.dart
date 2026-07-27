import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../util/format.dart';
import 'named_entity_field.dart';

/// Edit form for a free-text shopping list item (#122) -- product-linked
/// items already get their name/unit from the Product and can't have their
/// own category (the backend rejects category_id alongside product_id), so
/// this sheet is only ever shown for items without a productId.
class EditShoppingListItemSheet extends StatefulWidget {
  final ShoppingListItem item;

  const EditShoppingListItemSheet({super.key, required this.item});

  /// Returns true once the item was actually updated, or null if the sheet
  /// was cancelled/dismissed without saving.
  static Future<bool?> show(BuildContext context, ShoppingListItem item) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: EditShoppingListItemSheet(item: item),
      ),
    );
  }

  @override
  State<EditShoppingListItemSheet> createState() => _EditShoppingListItemSheetState();
}

class _EditShoppingListItemSheetState extends State<EditShoppingListItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  final _categoryFieldKey = GlobalKey<NamedEntityFieldState<Category>>();
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _amountController = TextEditingController(text: formatAmount(widget.item.amount));
    _unitController = TextEditingController(text: widget.item.unit ?? '');
    _categoryId = widget.item.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    // Resolve whatever's currently typed in the category field into a real
    // category (matching/creating it) before reading _categoryId -- same
    // race the product edit screen guards against.
    await _categoryFieldKey.currentState?.resolve();
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.nameRequired)));
      return;
    }
    final amount = double.tryParse(_amountController.text) ?? 1;
    final unit = _unitController.text.trim();
    setState(() => _saving = true);
    try {
      await context.read<ApiClient>().updateShoppingListItem(widget.item.id, {
        'name': name,
        'amount': amount,
        'unit': unit.isEmpty ? null : unit,
        'category_id': _categoryId,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotSave(apiFailureReason(e, l10n)))));
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
            Text(l10n.editShoppingListItemTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.nameLabel),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    decoration: InputDecoration(labelText: l10n.amountFieldLabel),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: InputDecoration(labelText: l10n.unitFieldLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NamedEntityField<Category>(
              key: _categoryFieldKey,
              initialName: widget.item.categoryName,
              label: l10n.categoryLabel,
              clearTooltip: l10n.clearCategoryTooltip,
              load: (api) => api.listCategories(),
              create: (api, name) => api.createCategory(name),
              errorMessage: (e) => l10n.couldNotAddCategory('$e'),
              onChanged: (category) => setState(() => _categoryId = category?.id),
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
                        : Text(l10n.saveButton),
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
