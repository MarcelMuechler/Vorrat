import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../util/format.dart';
import '../util/status.dart';
import 'prompt_validated.dart';

/// Wraps a stock batch's list tile with the shared interaction model (#75):
/// tapping reveals Open/Use/Spoil buttons beneath it (Open only shown while
/// [canOpen]); Use and Spoil each prompt for an amount. Swiping either
/// direction acts on the whole batch at once, no prompt -- swipe right to
/// use it all, left to spoil it all (mirrors #56's scan-triggered shortcut,
/// which also acts on a whole batch by default; matches the visible
/// "Spoiled" swipe background rather than opening a delete confirmation).
/// Deleting outright is still reachable via long-press.
class StockItemActions extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final double amount;
  final String productName;
  final bool canOpen;
  final VoidCallback onOpen;
  // Returns whether the consume actually succeeded -- e.g. false on an API
  // error -- so a swipe-triggered consume can snap back instead of
  // dismissing a batch that's still there server-side.
  final Future<bool> Function(double amount, String reason) onConsume;
  // Long-press only (swipe-left spoils instead of deleting -- see class
  // doc). Returns whether the batch was actually deleted -- e.g. false if
  // its confirmation dialog was cancelled.
  final Future<bool> Function() onDelete;
  final Object dismissibleKey;
  // When set, renders as a colored-left-border/tinted card instead of a
  // plain row -- the Stock overview's "needs attention" section (#199 wireframe
  // revamp) uses this to make expired/expiring batches visually stand out from
  // the plain "in stock" rows below them. Batch lists elsewhere (product
  // detail, selection mode) leave this null and keep today's plain look.
  final String? emphasizeStatus;

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
    this.emphasizeStatus,
  });

  @override
  State<StockItemActions> createState() => _StockItemActionsState();
}

class _StockItemActionsState extends State<StockItemActions> {
  bool _expanded = false;

  Future<double?> _promptAmount(String title) {
    final l10n = AppLocalizations.of(context)!;
    return promptValidated<double>(
      context,
      title: title,
      actionLabel: l10n.saveButton,
      initialText: formatAmount(widget.amount),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      labelText: l10n.amountInStockLabel(formatAmount(widget.amount)),
      // Also rejects anything above what's actually left on this batch --
      // otherwise the dialog would let you submit e.g. 2 against a 1-unit
      // entry, which the backend now rejects too (#156).
      parse: (text) {
        final amount = double.tryParse(text);
        return (amount == null || amount <= 0 || amount > widget.amount) ? null : amount;
      },
      invalidMessage: l10n.amountExceedsStock(formatAmount(widget.amount)),
    );
  }

  Future<void> _promptAndConsume(String title, String reason) async {
    final amount = await _promptAmount(title);
    if (amount == null || !mounted) return;
    setState(() => _expanded = false);
    await widget.onConsume(amount, reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final row = Dismissible(
      key: ValueKey(widget.dismissibleKey),
      background: Container(
        color: statusColor('ok'),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(l10n.usedLabel, style: const TextStyle(color: Colors.white)),
      ),
      secondaryBackground: Container(
        color: statusColor('expired'),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(l10n.spoiledLabel, style: const TextStyle(color: Colors.white)),
      ),
      confirmDismiss: (direction) => widget.onConsume(
        widget.amount,
        direction == DismissDirection.startToEnd ? 'used' : 'spoiled',
      ),
      child: ListTile(
        leading: widget.leading,
        title: widget.title,
        subtitle: widget.subtitle,
        onTap: () => setState(() => _expanded = !_expanded),
        onLongPress: widget.onDelete,
      ),
    );
    final emphasizeStatus = widget.emphasizeStatus;
    return Column(
      children: [
        if (emphasizeStatus == null)
          row
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor(emphasizeStatus).withValues(alpha: 0.08),
              border: Border(left: BorderSide(color: statusColor(emphasizeStatus), width: 4)),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
            ),
            child: row,
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
