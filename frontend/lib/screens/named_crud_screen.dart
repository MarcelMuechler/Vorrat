import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/prompt_validated.dart';
import '../widgets/refreshable_list.dart';

/// An `{id, name}` row, the only shape this screen renders. Both [Location]
/// and [Category] destructure to it, so neither model needs a shared base
/// class just to be listed here.
typedef NamedItem = ({int id, String name});

/// The list + add/rename/delete screen shared by Categories and Locations.
///
/// The two screens were identical apart from one icon: same load/refresh
/// state machine, same validated-name prompt, same delete confirmation, same
/// error snackbars. Everything that genuinely differs is passed in -- the
/// localized strings and the four API calls.
class NamedCrudScreen extends StatefulWidget {
  const NamedCrudScreen({
    super.key,
    required this.title,
    required this.emptyIcon,
    required this.emptyText,
    required this.addTooltip,
    required this.newTitle,
    required this.renameTitle,
    required this.deleteTitle,
    required this.deleteConfirm,
    required this.loadError,
    required this.addError,
    required this.renameError,
    required this.deleteError,
    required this.load,
    required this.create,
    required this.rename,
    required this.remove,
  });

  final String title;
  final IconData emptyIcon;
  final String emptyText;
  final String addTooltip;
  final String newTitle;
  final String renameTitle;
  final String deleteTitle;
  final String Function(String name) deleteConfirm;
  final String Function(String error) loadError;
  final String Function(String error) addError;
  final String Function(String error) renameError;
  final String Function(String error) deleteError;

  final Future<List<NamedItem>> Function() load;
  final Future<void> Function(String name) create;
  final Future<void> Function(int id, String name) rename;
  final Future<void> Function(int id) remove;

  @override
  State<NamedCrudScreen> createState() => _NamedCrudScreenState();
}

class _NamedCrudScreenState extends State<NamedCrudScreen> {
  List<NamedItem> _items = [];
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
      final items = await widget.load();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs [action], refreshes on success, and surfaces any failure as a
  /// snackbar built by [errorText] -- the add/rename/delete handlers differed
  /// only in those two things.
  Future<void> _mutate(Future<void> Function() action, String Function(String) errorText) async {
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText('$e'))));
      }
    }
  }

  Future<void> _add() async {
    final name = await _promptName(context, title: widget.newTitle);
    if (name == null || !mounted) return;
    await _mutate(() => widget.create(name), widget.addError);
  }

  Future<void> _rename(NamedItem item) async {
    final name = await _promptName(context, title: widget.renameTitle, initialValue: item.name);
    if (name == null || !mounted) return;
    await _mutate(() => widget.rename(item.id, name), widget.renameError);
  }

  Future<void> _delete(NamedItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.deleteTitle),
        content: Text(widget.deleteConfirm(item.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.deleteButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(() => widget.remove(item.id), widget.deleteError);
  }

  static Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String? initialValue,
  }) {
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
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshableList<NamedItem>(
        loading: _loading,
        error: _error,
        errorText: (e) => widget.loadError('$e'),
        emptyIcon: widget.emptyIcon,
        emptyText: widget.emptyText,
        items: _items,
        onRefresh: _refresh,
        itemBuilder: (context, item) => ListTile(
          title: Text(item.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: l10n.renameTooltip,
                onPressed: () => _rename(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.deleteButton,
                onPressed: () => _delete(item),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: widget.addTooltip,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
