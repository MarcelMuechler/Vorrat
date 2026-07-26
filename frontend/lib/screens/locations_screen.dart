import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import 'named_crud_screen.dart';

class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final api = context.read<ApiClient>();
    return NamedCrudScreen(
      title: l10n.locationsTitle,
      emptyIcon: Icons.place_outlined,
      emptyText: l10n.noLocationsYet,
      addTooltip: l10n.addLocationTooltip,
      newTitle: l10n.newLocationTitle,
      renameTitle: l10n.renameLocationTitle,
      deleteTitle: l10n.deleteLocationTitle,
      deleteConfirm: l10n.deleteLocationConfirm,
      loadError: l10n.couldNotLoadLocations,
      addError: l10n.couldNotAddLocation,
      renameError: l10n.couldNotRenameLocation,
      deleteError: l10n.couldNotDeleteLocation,
      load: () async => (await api.listLocations()).map((l) => (id: l.id, name: l.name)).toList(),
      create: (name) => api.createLocation(name),
      rename: (id, name) => api.renameLocation(id, name),
      remove: api.deleteLocation,
    );
  }
}
