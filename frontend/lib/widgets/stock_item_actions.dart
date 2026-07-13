import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Wraps a stock batch's list tile with the shared interaction model (#75):
/// tapping reveals Open/Use/Spoil buttons beneath it (Open only shown while
/// [canOpen]); Use and Spoil each prompt for an amount. Swiping either
/// direction acts on the whole batch at once, no prompt -- swipe right to
/// use it all, left to discard it (mirrors #56's scan-triggered shortcut,
/// which also acts on a whole batch by default).
class StockItemActions extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final double amount;
  final String productName;
  final bool canOpen;
  final VoidCallback onOpen;
  final Future<void> Function(double amount, String reason) onConsume;
  // Returns whether the batch was actually deleted -- e.g. false if a
  // confirmation dialog was shown and cancelled, so a swipe-triggered
  // delete can snap back instead of completing.
  final Future<bool> Function() onDelete;
  final Object dismissibleKey;

  const StockItemActions({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.productName,
    required this.canOpen,
    required this.onOpen,
    required this.onConsume,
    required this.onDelete,
    required this.dismissibleKey,
  });

  @override
  State<StockItemActions> createState() => _StockItemActionsState();
}

class _StockItemActionsState extends State<StockItemActions> {
  bool _expanded = false;

  Future<double?> _promptAmount(String title) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: '${widget.amount}');
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.amountInStockLabel('${widget.amount}')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelButton)),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAndConsume(String title, String reason) async {
    final amount = await _promptAmount(title);
    if (amount == null || amount <= 0 || !mounted) return;
    setState(() => _expanded = false);
    await widget.onConsume(amount, reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Dismissible(
          key: ValueKey(widget.dismissibleKey),
          background: Container(
            color: Colors.green,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.usedLabel, style: const TextStyle(color: Colors.white)),
          ),
          secondaryBackground: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.spoiledLabel, style: const TextStyle(color: Colors.white)),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              await widget.onConsume(widget.amount, 'used');
              return true;
            }
            return widget.onDelete();
          },
          child: ListTile(
            leading: widget.leading,
            title: widget.title,
            subtitle: widget.subtitle,
            onTap: () => setState(() => _expanded = !_expanded),
            onLongPress: widget.onDelete,
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.canOpen)
                  TextButton.icon(
                    onPressed: () {
                      widget.onOpen();
                      setState(() => _expanded = false);
                    },
                    icon: const Icon(Icons.lock_open),
                    label: Text(l10n.markAsOpenedTooltip),
                  ),
                TextButton.icon(
                  onPressed: () => _promptAndConsume(l10n.useSomeOfTitle(widget.productName), 'used'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l10n.usedLabel),
                ),
                TextButton.icon(
                  onPressed: () => _promptAndConsume(l10n.spoilSomeOfTitle(widget.productName), 'spoiled'),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.spoiledLabel),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
