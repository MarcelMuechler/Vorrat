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
