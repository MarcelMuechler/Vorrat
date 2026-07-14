import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Single-field text-entry dialog that re-validates on each tap of the
/// action button, showing [invalidMessage] inline instead of popping until
/// [parse] succeeds. Covers both name prompts (parse: non-empty string) and
/// amount prompts (parse: positive double) with one dialog.
Future<T?> promptValidated<T>(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String? initialText,
  TextInputType? keyboardType,
  String? labelText,
  required T? Function(String text) parse,
  required String invalidMessage,
}) {
  final controller = TextEditingController(text: initialText);
  String? errorText;
  return showDialog<T>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: labelText, errorText: errorText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancelButton),
          ),
          FilledButton(
            onPressed: () {
              final value = parse(controller.text);
              if (value == null) {
                setState(() => errorText = invalidMessage);
                return;
              }
              Navigator.pop(context, value);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
