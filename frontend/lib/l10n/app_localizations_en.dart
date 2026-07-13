// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vorrat';

  @override
  String get stockTitle => 'Stock';

  @override
  String get scanTitle => 'Scan';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get locationsTitle => 'Locations';

  @override
  String get productsTitle => 'Products';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get saveButton => 'Save';

  @override
  String get deleteButton => 'Delete';

  @override
  String get addButton => 'Add';

  @override
  String get removeButton => 'Remove';

  @override
  String get consumeButton => 'Consume';

  @override
  String get lookUpButton => 'Look up';

  @override
  String get usedLabel => 'Used';

  @override
  String get spoiledLabel => 'Spoiled';

  @override
  String get nameLabel => 'Name';

  @override
  String get brandLabel => 'Brand';

  @override
  String get categoryLabel => 'Category';

  @override
  String get amountFieldLabel => 'Amount';

  @override
  String get unitLabel => 'Unit';

  @override
  String get quantityUnitLabel => 'Quantity unit';

  @override
  String get locationLabel => 'Location';

  @override
  String get defaultLocationLabel => 'Default location';

  @override
  String get noneLabel => 'None';

  @override
  String get searchLabel => 'Search';

  @override
  String barcodeLabel(String code) {
    return 'Barcode: $code';
  }

  @override
  String get viewTooltip => 'View';

  @override
  String get viewModeFlat => 'Every batch';

  @override
  String get viewModeGrouped => 'Grouped by product';

  @override
  String get viewModeBreakdown => 'Expiry breakdown';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get sortBestBeforeDateLabel => 'Best-before date';

  @override
  String get expiringSoonChip => 'Expiring soon';

  @override
  String get allLocationsLabel => 'All locations';

  @override
  String stockLoadError(String error) {
    return 'Could not load stock: $error\n\nCheck the server URL in Settings.';
  }

  @override
  String get noStockYet => 'No stock yet. Scan something to add it.';

  @override
  String get addProductManuallyTooltip => 'Add product manually';

  @override
  String groupTotalAmount(String amount) {
    return '$amount total';
  }

  @override
  String get markAsOpenedTooltip => 'Mark as opened';

  @override
  String useSomeOfTitle(String name) {
    return 'Use some of \"$name\"';
  }

  @override
  String amountInStockLabel(String amount) {
    return 'Amount (of $amount in stock)';
  }

  @override
  String get removeStockTitle => 'Remove from stock?';

  @override
  String deleteBatchConfirm(String name) {
    return 'This deletes this batch of \"$name\".';
  }

  @override
  String couldNotConsume(String error) {
    return 'Could not consume: $error';
  }

  @override
  String get expiryToday => 'Expires today';

  @override
  String get expiryTomorrow => 'Expires tomorrow';

  @override
  String get expiredYesterday => 'Expired yesterday';

  @override
  String expiryInDays(int days) {
    return 'Expires in $days days';
  }

  @override
  String expiredDaysAgo(int days) {
    return 'Expired $days days ago';
  }

  @override
  String get purchasedToday => 'Purchased today';

  @override
  String get purchasedTomorrow => 'Purchased tomorrow';

  @override
  String get purchasedYesterday => 'Purchased yesterday';

  @override
  String purchasedInDays(int days) {
    return 'Purchased in $days days';
  }

  @override
  String purchasedDaysAgo(int days) {
    return 'Purchased $days days ago';
  }

  @override
  String get openedToday => 'Opened today';

  @override
  String get openedTomorrow => 'Opened tomorrow';

  @override
  String get openedYesterday => 'Opened yesterday';

  @override
  String openedInDays(int days) {
    return 'Opened in $days days';
  }

  @override
  String openedDaysAgo(int days) {
    return 'Opened $days days ago';
  }

  @override
  String get invalidBarcodeMessage =>
      'That doesn\'t look like a valid barcode.';

  @override
  String get enterBarcodeTitle => 'Enter barcode';

  @override
  String savedForLater(int count) {
    return 'No connection — saved for later ($count pending).';
  }

  @override
  String lookupFailed(String error) {
    return 'Lookup failed: $error\n\nCheck the server URL in Settings.';
  }

  @override
  String get enterManuallyTooltip => 'Enter barcode manually';

  @override
  String get recentlyScanned => 'Recently scanned';

  @override
  String get pendingScans => 'Pending scans';

  @override
  String get nothingScannedYet => 'Nothing scanned yet.';

  @override
  String get newLocationTitle => 'New location';

  @override
  String couldNotAddLocation(String error) {
    return 'Could not add location: $error';
  }

  @override
  String couldNotSave(String error) {
    return 'Could not save: $error';
  }

  @override
  String get addToStockTitle => 'Add to stock';

  @override
  String get offReviewHint => 'From Open Food Facts — check before saving.';

  @override
  String get noBestBeforeDate => 'No best-before date';

  @override
  String bestBeforeLabel(String date) {
    return 'Best before: $date';
  }

  @override
  String get fetchedFromOff =>
      'Fetched from Open Food Facts — review, then Save.';

  @override
  String couldNotRefresh(String error) {
    return 'Could not refresh: $error';
  }

  @override
  String get editProductTitle => 'Edit product';

  @override
  String get refreshFromOffTooltip => 'Refresh from Open Food Facts';

  @override
  String get defaultBestBeforeDaysLabel => 'Default best-before days';

  @override
  String get defaultBestBeforeDaysHint =>
      'e.g. 7 — prefilled when adding this product to stock';

  @override
  String get openShelfLifeLabel => 'Use within (days after opening)';

  @override
  String get openShelfLifeHint =>
      'e.g. 3 — for products that spoil faster once opened';

  @override
  String get deleteProductTitle => 'Delete product?';

  @override
  String deleteProductConfirm(String name) {
    return 'This deletes \"$name\". Products still in stock can\'t be deleted.';
  }

  @override
  String couldNotDeleteProduct(String error) {
    return 'Could not delete product: $error';
  }

  @override
  String couldNotLoadProducts(String error) {
    return 'Could not load products: $error';
  }

  @override
  String get noProductsYet => 'No products yet.';

  @override
  String get viewStockBatchesTooltip => 'View stock batches';

  @override
  String couldNotLoadBatches(String error) {
    return 'Could not load batches: $error';
  }

  @override
  String get noBatchesLeft => 'No batches left.';

  @override
  String bbdLabel(String date) {
    return 'BBD: $date';
  }

  @override
  String get renameLocationTitle => 'Rename location';

  @override
  String couldNotRenameLocation(String error) {
    return 'Could not rename location: $error';
  }

  @override
  String get deleteLocationTitle => 'Delete location?';

  @override
  String deleteLocationConfirm(String name) {
    return 'This deletes \"$name\".';
  }

  @override
  String couldNotDeleteLocation(String error) {
    return 'Could not delete location: $error';
  }

  @override
  String couldNotLoadLocations(String error) {
    return 'Could not load locations: $error';
  }

  @override
  String get noLocationsYet => 'No locations yet.';

  @override
  String get renameTooltip => 'Rename';

  @override
  String get addLocationTooltip => 'Add location';

  @override
  String get locationsSubtitle => 'Rename or delete storage locations';

  @override
  String get productsSubtitle => 'Browse, edit, or delete products';

  @override
  String lookupsFailedPending(int failures, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      failures,
      locale: localeName,
      other: '$failures lookups failed',
      one: '1 lookup failed',
    );
    return '$_temp0; $remaining still pending.';
  }

  @override
  String stoppedStillOffline(int remaining) {
    return 'Stopped -- still offline. $remaining still pending.';
  }

  @override
  String get allSynced => 'All pending scans synced.';

  @override
  String get syncNowButton => 'Sync now';

  @override
  String get nothingPending => 'Nothing pending.';

  @override
  String queuedLabel(String date) {
    return 'Queued $date';
  }

  @override
  String get discardTooltip => 'Discard';

  @override
  String get enterWholeNumber => 'Enter a whole number greater than 0.';

  @override
  String connectedVersion(String version) {
    return 'Connected — server v$version';
  }

  @override
  String get couldNotReachServer => 'Could not reach server';

  @override
  String couldNotExport(String error) {
    return 'Could not export: $error';
  }

  @override
  String get serverUrlDescription =>
      'Server URL. Leave blank when running inside Home Assistant (same-origin via Ingress). Native apps and local dev need the full URL, e.g. http://192.168.1.20:8099';

  @override
  String get serverUrlLabel => 'Server URL';

  @override
  String get barcodeScanningTitle => 'Barcode scanning';

  @override
  String get barcodeScanningSubtitle =>
      'Show the Scan tab and camera scan buttons';

  @override
  String get scanToConnectTooltip => 'Scan to connect';

  @override
  String get saveTestConnectionButton => 'Save & test connection';

  @override
  String get expiringSoonDescription =>
      '\"Expiring soon\" applies to items due within this many days.';

  @override
  String get exportCsvTitle => 'Export stock (CSV)';

  @override
  String get exportCsvSubtitle => 'Download current stock as a spreadsheet';

  @override
  String spoiledThisMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count batches marked spoiled this month.',
      one: '1 batch marked spoiled this month.',
      zero: 'Nothing marked spoiled this month.',
    );
    return '$_temp0';
  }

  @override
  String get pairDeviceHint =>
      'Pair another device: open Settings → Scan to connect on it, then scan this code.';

  @override
  String get scanQrTitle => 'Scan server QR code';
}
