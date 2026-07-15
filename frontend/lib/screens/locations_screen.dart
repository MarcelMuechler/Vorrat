import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../widgets/prompt_validated.dart';
import '../widgets/refreshable_list.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  List<Location> _locations = [];
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
      final locations = await context.read<ApiClient>().listLocations();
      if (!mounted) return;
      setState(() => _locations = locations);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addLocation() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptName(context, title: l10n.newLocationTitle);
    if (name == null || !mounted) return;
    try {
      await context.read<ApiClient>().createLocation(name);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotAddLocation('$e'))));
      }
    }
  }

  Future<void> _rename(Location location) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptName(context, title: l10n.renameLocationTitle, initialValue: location.name);
    if (name == null || !mounted) return;
    try {
      await context.read<ApiClient>().renameLocation(location.id, name);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotRenameLocation('$e'))));
      }
    }
  }

  Future<void> _delete(Location location) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLocationTitle),
        content: Text(l10n.deleteLocationConfirm(location.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.deleteButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ApiClient>().deleteLocation(location.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteLocation('$e'))));
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
      appBar: AppBar(title: Text(l10n.locationsTitle)),
      body: RefreshableList<Location>(
        loading: _loading,
        error: _error,
        errorText: (e) => l10n.couldNotLoadLocations('$e'),
        emptyIcon: Icons.place_outlined,
        emptyText: l10n.noLocationsYet,
        items: _locations,
        onRefresh: _refresh,
        itemBuilder: (context, location) => ListTile(
          title: Text(location.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: l10n.renameTooltip,
                onPressed: () => _rename(location),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.deleteButton,
                onPressed: () => _delete(location),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addLocationTooltip,
        onPressed: _addLocation,
        child: const Icon(Icons.add),
      ),
    );
  }
}
