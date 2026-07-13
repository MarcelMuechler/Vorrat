import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';

/// An autocomplete of existing categories (#73), backed by the Category
/// entity (#72) -- typing a name that doesn't match anything existing
/// creates a new category on submit/blur rather than restricting input to
/// a fixed list, matching how #57 originally kept category as free-form and
/// user-maintained rather than a rigid taxonomy.
///
/// State is public (`CategoryFieldState`) so a save button can hold a
/// `GlobalKey<CategoryFieldState>` and call [resolve] right before reading
/// the result -- simply tapping Save right after typing a brand-new
/// category is a real race against this field's own async
/// blur/submit-triggered resolution (which calls the backend to create the
/// category) otherwise.
class CategoryField extends StatefulWidget {
  final int? categoryId;
  final String? categoryName;
  final String label;
  final String? hintText;
  final ValueChanged<Category?> onChanged;

  const CategoryField({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.label,
    this.hintText,
    required this.onChanged,
  });

  @override
  State<CategoryField> createState() => CategoryFieldState();
}

class CategoryFieldState extends State<CategoryField> {
  List<Category> _categories = [];
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.categoryName ?? '');
    _focusNode = FocusNode();
    _loadCategories();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<ApiClient>().listCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Autocomplete just has no suggestions -- typing still works and can
      // still create a new category on submit.
    }
  }

  Category? _findByName(String name) {
    final trimmed = name.trim().toLowerCase();
    for (final c in _categories) {
      if (c.name.toLowerCase() == trimmed) return c;
    }
    return null;
  }

  /// Overwrites the displayed text programmatically (e.g. an OFF refresh),
  /// without resolving it -- call [resolve] afterwards to also match/create
  /// the category and report it via [CategoryField.onChanged].
  void setText(String? name) {
    _controller.text = name ?? '';
  }

  /// Resolves whatever's currently typed into a real category -- an
  /// existing match, a newly-created one, or null if left blank -- and
  /// reports it via [CategoryField.onChanged].
  Future<Category?> resolve() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      return null;
    }
    final existing = _findByName(trimmed);
    if (existing != null) {
      widget.onChanged(existing);
      return existing;
    }
    try {
      final created = await context.read<ApiClient>().createCategory(trimmed);
      if (!mounted) return null;
      setState(() => _categories = [..._categories, created]);
      widget.onChanged(created);
      return created;
    } catch (_) {
      // Leave the typed text as-is if creation fails (e.g. offline) --
      // better than silently discarding what the user typed.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RawAutocomplete<Category>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (c) => c.name,
      optionsBuilder: (value) {
        if (value.text.isEmpty) return _categories;
        final query = value.text.toLowerCase();
        return _categories.where((c) => c.name.toLowerCase().contains(query));
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: l10n.clearCategoryTooltip,
                    onPressed: () {
                      controller.clear();
                      widget.onChanged(null);
                    },
                  ),
          ),
          onSubmitted: (_) => resolve(),
          onTapOutside: (_) => resolve(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                return ListTile(title: Text(option.name), onTap: () => onSelected(option));
              },
            ),
          ),
        ),
      ),
    );
  }
}
