import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import 'named_crud_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final api = context.read<ApiClient>();
    return NamedCrudScreen(
      title: l10n.categoriesTitle,
      emptyIcon: Icons.sell_outlined,
      emptyText: l10n.noCategoriesYet,
      addTooltip: l10n.addCategoryTooltip,
      newTitle: l10n.newCategoryTitle,
      renameTitle: l10n.renameCategoryTitle,
      deleteTitle: l10n.deleteCategoryTitle,
      deleteConfirm: l10n.deleteCategoryConfirm,
      loadError: l10n.couldNotLoadCategories,
      addError: l10n.couldNotAddCategory,
      renameError: l10n.couldNotRenameCategory,
      deleteError: l10n.couldNotDeleteCategory,
      load: () async =>
          (await api.listCategories()).map((c) => (id: c.id, name: c.name)).toList(),
      create: (name) => api.createCategory(name),
      rename: (id, name) => api.renameCategory(id, name),
      remove: api.deleteCategory,
    );
  }
}
