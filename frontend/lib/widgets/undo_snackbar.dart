import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shared shape for every "did a thing, here's an Undo" SnackBar in this app
/// (consume/spoil a batch, delete a shopping-list item) -- was duplicated
/// three times (#199) before centralizing here.
void showUndoSnackBar(BuildContext context, {required String message, required VoidCallback onUndo}) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(label: l10n.undoButton, onPressed: onUndo),
      // A SnackBar with an action defaults to `persist: true` (stays until
      // manually dismissed) -- opt back into the normal timeout (#178).
      persist: false,
    ),
  );
}
