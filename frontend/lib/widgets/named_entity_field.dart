import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../models/models.dart';

/// An autocomplete over an existing name-only entity (Category, Location)
/// where typing a name that matches nothing creates it (#73/#338), rather
/// than restricting input to a fixed list. Without it a form is a dead end
/// whenever the value you want doesn't exist yet -- the most-repeated
/// concrete UX complaint about grocy.
///
/// Generic over the entity because Category and Location are the same shape
/// on both sides (they even share `named_crud.py` on the backend, and
/// [NamedEntity] on this one); the caller supplies how to list and create.
///
/// State is public (`NamedEntityFieldState`) so a save button can hold a
/// `GlobalKey<NamedEntityFieldState<T>>` and call [resolve] right before
/// reading the result -- simply tapping Save right after typing a brand-new
/// name is a real race against this field's own async blur/submit-triggered
/// resolution (which calls the backend to create it) otherwise.
class NamedEntityField<T extends NamedEntity> extends StatefulWidget {
  final String? initialName;
  /// Prefill by id instead, for the common case where the owning record
  /// stores only the id (a Product's `default_location_id`) -- the name is
  /// filled in from the list this field loads anyway, so the form doesn't
  /// have to fetch the same list itself just to resolve one name.
  final int? initialId;
  final String label;
  final String clearTooltip;
  final Future<List<T>> Function(ApiClient api) load;
  final Future<T> Function(ApiClient api, String name) create;
  /// Localized message for a failed create -- built by the caller, which has
  /// the right l10n string for its entity.
  final String Function(Object error) errorMessage;
  final ValueChanged<T?> onChanged;

  const NamedEntityField({
    super.key,
    this.initialName,
    this.initialId,
    required this.label,
    required this.clearTooltip,
    required this.load,
    required this.create,
    required this.errorMessage,
    required this.onChanged,
  });

  @override
  State<NamedEntityField<T>> createState() => NamedEntityFieldState<T>();
}

class NamedEntityFieldState<T extends NamedEntity> extends State<NamedEntityField<T>> {
  List<T> _options = [];
  bool _loaded = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _focusNode = FocusNode();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final options = await widget.load(context.read<ApiClient>());
      if (!mounted) return;
      setState(() {
        _options = options;
        _loaded = true;
        // Only if nothing has been typed in the meantime -- the list arrives
        // asynchronously and must never overwrite the user.
        if (widget.initialId != null && _controller.text.isEmpty) {
          _controller.text =
              options.where((o) => o.id == widget.initialId).map((o) => o.name).firstOrNull ?? '';
        }
      });
    } catch (_) {
      // Autocomplete just has no suggestions -- typing still works and can
      // still create a new entry on submit.
    }
  }

  T? _findByName(String name) {
    final trimmed = name.trim().toLowerCase();
    for (final option in _options) {
      if (option.name.toLowerCase() == trimmed) return option;
    }
    return null;
  }

  /// Overwrites the displayed text programmatically (e.g. an OFF refresh),
  /// without resolving it -- call [resolve] afterwards to also match/create
  /// the entity and report it via [NamedEntityField.onChanged].
  void setText(String? name) {
    _controller.text = name ?? '';
  }

  /// Resolves whatever's currently typed into a real entity -- an existing
  /// match, a newly-created one, or null if left blank -- and reports it via
  /// [NamedEntityField.onChanged].
  Future<T?> resolve() async {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      // An empty [initialId] field whose list never arrived is showing blank
      // because the load failed, not because anything was cleared -- report
      // nothing rather than letting a save wipe the existing selection.
      // Tapping the clear button reports null directly, so this doesn't get
      // in the way of clearing it on purpose.
      if (widget.initialId != null && !_loaded) return null;
      widget.onChanged(null);
      return null;
    }
    final existing = _findByName(trimmed);
    if (existing != null) {
      widget.onChanged(existing);
      return existing;
    }
    try {
      final created = await widget.create(context.read<ApiClient>(), trimmed);
      if (!mounted) return null;
      setState(() => _options = [..._options, created]);
      widget.onChanged(created);
      return created;
    } catch (e) {
      // Leave the typed text as-is if creation fails (e.g. offline) -- better
      // than silently discarding what the user typed. But the caller's save
      // flow still reads a stale/null id at this point, so surface the
      // failure rather than letting the product save with a value that
      // silently doesn't match what's visibly in the field.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.errorMessage(e))));
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<T>(
      textEditingController: _controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (value) {
        if (value.text.isEmpty) return _options;
        final query = value.text.toLowerCase();
        return _options.where((o) => o.name.toLowerCase().contains(query));
      },
      onSelected: widget.onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: widget.clearTooltip,
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
