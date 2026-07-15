import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Canonical stored values -- what actually goes in `Product.quantity_unit`.
/// Kept as plain English tokens (not localized) so the data model doesn't
/// depend on locale; only their *display* is localized, via
/// [quantityUnitLabel].
const List<String> commonQuantityUnits = ['pcs', 'g', 'kg', 'ml', 'l', 'pack'];

const _otherValue = '__other__';

String quantityUnitLabel(AppLocalizations l10n, String unit) {
  switch (unit) {
    case 'pcs':
      return l10n.unitPcsLabel;
    case 'g':
      return l10n.unitGramsLabel;
    case 'kg':
      return l10n.unitKilogramsLabel;
    case 'ml':
      return l10n.unitMillilitersLabel;
    case 'l':
      return l10n.unitLitersLabel;
    case 'pack':
      return l10n.unitPackLabel;
    default:
      // Not one of the common units -- e.g. an OFF-provided value like "cl",
      // or something typed into the "Other" fallback previously. Show as-is
      // rather than losing it.
      return unit;
  }
}

/// A dropdown of [commonQuantityUnits] (#55) with an "Other..." fallback that
/// reveals a free-text field -- values already in the data (from OFF, or
/// entered before this dropdown existed) that aren't in the fixed list still
/// round-trip correctly instead of silently changing on save.
class QuantityUnitField extends StatefulWidget {
  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  const QuantityUnitField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  State<QuantityUnitField> createState() => _QuantityUnitFieldState();
}

class _QuantityUnitFieldState extends State<QuantityUnitField> {
  late bool _isOther;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _isOther = widget.value.isNotEmpty && !commonQuantityUnits.contains(widget.value);
    _customController = TextEditingController(text: _isOther ? widget.value : '');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _isOther ? _otherValue : widget.value,
          decoration: InputDecoration(labelText: widget.label),
          items: [
            for (final unit in commonQuantityUnits)
              DropdownMenuItem(value: unit, child: Text(quantityUnitLabel(l10n, unit))),
            DropdownMenuItem(value: _otherValue, child: Text(l10n.unitOtherLabel)),
          ],
          onChanged: (selected) {
            if (selected == null) return;
            setState(() => _isOther = selected == _otherValue);
            widget.onChanged(selected == _otherValue ? _customController.text : selected);
          },
        ),
        if (_isOther) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customController,
            decoration: InputDecoration(
              labelText: l10n.unitCustomLabel,
            ),
            onChanged: widget.onChanged,
          ),
        ],
      ],
    );
  }
}
