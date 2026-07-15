import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../widgets/prompt_validated.dart';
import '../widgets/refreshable_list.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await context.read<ApiClient>().listCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCategory() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptName(context, title: l10n.newCategoryTitle);
    if (name == null || !mounted) return;
    try {
      await context.read<ApiClient>().createCategory(name);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotAddCategory('$e'))));
      }
    }
  }

  Future<void> _rename(Category category) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptName(context, title: l10n.renameCategoryTitle, initialValue: category.name);
    if (name == null || !mounted) return;
    try {
      await context.read<ApiClient>().renameCategory(category.id, name);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotRenameCategory('$e'))));
      }
    }
  }

  Future<void> _delete(Category category) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCategoryTitle),
        content: Text(l10n.deleteCategoryConfirm(category.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.deleteButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiClient>().deleteCategory(category.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteCategory('$e'))));
      }
    }
  }

  static Future<String?> _promptName(BuildContext context, {required String title, String? initialValue}) {
    final l10n = AppLocalizations.of(context)!;
    return promptValidated<String>(
      context,
      title: title,
      actionLabel: l10n.saveButton,
      initialText: initialValue,
      parse: (text) => text.trim().isEmpty ? null : text.trim(),
      invalidMessage: l10n.nameRequired,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.categoriesTitle)),
      body: RefreshableList<Category>(
        loading: _loading,
        error: _error,
        errorText: (e) => l10n.couldNotLoadCategories('$e'),
        emptyIcon: Icons.sell_outlined,
        emptyText: l10n.noCategoriesYet,
        items: _categories,
        onRefresh: _refresh,
        itemBuilder: (context, category) => ListTile(
          title: Text(category.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: l10n.renameTooltip,
                onPressed: () => _rename(category),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.deleteButton,
                onPressed: () => _delete(category),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addCategoryTooltip,
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}
