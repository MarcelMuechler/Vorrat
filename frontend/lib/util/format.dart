import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum RelativeDateKind { expiry, purchased, opened }

/// Relative day label ("today"/"tomorrow"/"in N days"/"N days ago"), so
/// scanning a list doesn't require doing date math against a raw ISO string.
/// [kind] picks which localized phrase set applies (expiry uses
/// "Expires"/"Expired", purchased/opened use the same word both ways). Shared
/// between the stock list and the product detail screen (#199).
String relativeLabel(BuildContext context, DateTime date, RelativeDateKind kind) {
  final l10n = AppLocalizations.of(context)!;
  final today = DateTime.now();
  final days = DateTime(date.year, date.month, date.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  switch (kind) {
    case RelativeDateKind.expiry:
      if (days == 0) return l10n.expiryToday;
      if (days == 1) return l10n.expiryTomorrow;
      if (days == -1) return l10n.expiredYesterday;
      if (days > 0) return l10n.expiryInDays(days);
      return l10n.expiredDaysAgo(-days);
    case RelativeDateKind.purchased:
      if (days == 0) return l10n.purchasedToday;
      if (days == 1) return l10n.purchasedTomorrow;
      if (days == -1) return l10n.purchasedYesterday;
      if (days > 0) return l10n.purchasedInDays(days);
      return l10n.purchasedDaysAgo(-days);
    case RelativeDateKind.opened:
      if (days == 0) return l10n.openedToday;
      if (days == 1) return l10n.openedTomorrow;
      if (days == -1) return l10n.openedYesterday;
      if (days > 0) return l10n.openedInDays(days);
      return l10n.openedDaysAgo(-days);
  }
}

/// Formats a stock/shopping-list amount for display: whole numbers are shown
/// without a decimal point ("3" rather than "3.0"), while fractional amounts
/// keep up to 2 decimal places with trailing zeros trimmed ("1.5", "0.25").
String formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  var text = amount.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}
