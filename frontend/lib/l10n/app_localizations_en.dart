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
  String get nameRequired => 'Please enter a name.';

  @override
  String get amountInvalid => 'Enter an amount greater than zero.';

  @override
  String amountExceedsStock(String amount) {
    return 'Enter an amount greater than zero and at most $amount (what\'s in stock).';
  }

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
  String get closeButton => 'Close';

  @override
  String get undoButton => 'Undo';

  @override
  String get usedLabel => 'Used';

  @override
  String get spoiledLabel => 'Spoiled';

  @override
  String get nameLabel => 'Name';

  @override
  String get categoryLabel => 'Category';

  @override
  String get clearCategoryTooltip => 'Clear category';

  @override
  String get amountFieldLabel => 'Amount';

  @override
  String get unitLabel => 'Unit';

  @override
  String get quantityUnitLabel => 'Quantity unit';

  @override
  String get unitPcsLabel => 'pcs';

  @override
  String get unitGramsLabel => 'g';

  @override
  String get unitKilogramsLabel => 'kg';

  @override
  String get unitMillilitersLabel => 'ml';

  @override
  String get unitLitersLabel => 'l';

  @override
  String get unitPackLabel => 'pack';

  @override
  String get unitOtherLabel => 'Other…';

  @override
  String get unitCustomLabel => 'Custom unit';

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
  String get expiryBucketExpired => 'Expired';

  @override
  String get expiryBucketToday => 'Today';

  @override
  String get expiryBucketThisWeek => 'This week';

  @override
  String get expiryBucketLater => 'Later';

  @override
  String get expiryBucketNoDate => 'No best-before date';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get sortBestBeforeDateLabel => 'Best-before date';

  @override
  String get expiringSoonChip => 'Expiring soon';

  @override
  String get statusOk => 'OK';

  @override
  String get statusExpiringSoon => 'Expiring soon';

  @override
  String get statusExpired => 'Expired';

  @override
  String get allLocationsLabel => 'All locations';

  @override
  String get allCategoriesLabel => 'All categories';

  @override
  String stockLoadError(String error) {
    return 'Could not load stock: $error\n\nCheck the server URL in Settings.';
  }

  @override
  String get noStockYet => 'No stock yet. Scan something to add it.';

  @override
  String get serverUrlNotSetTitle => 'No server configured';

  @override
  String get serverUrlNotSetMessage =>
      'Set a server URL in Settings so this app can connect to your Vorrat instance.';

  @override
  String get goToSettingsButton => 'Go to Settings';

  @override
  String get addProductManuallyTooltip => 'Add product manually';

  @override
  String get addNewBatchTooltip => 'Add new batch';

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
  String spoilSomeOfTitle(String name) {
    return 'Mark some of \"$name\" as spoiled';
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
  String couldNotDeleteStockEntry(String error) {
    return 'Could not delete: $error';
  }

  @override
  String couldNotUndo(String error) {
    return 'Could not undo: $error';
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
  String get nothingScannedYet =>
      'Nothing scanned yet. Scan a barcode to see it here.';

  @override
  String get scanModeAdd => 'Add';

  @override
  String get scanModeOpen => 'Open';

  @override
  String get scanModeUse => 'Use';

  @override
  String get scanModeDiscard => 'Discard';

  @override
  String get nothingToActOn =>
      'Nothing to act on -- unknown barcode or no stock for it.';

  @override
  String scannedOpened(String name) {
    return 'Marked \"$name\" as opened.';
  }

  @override
  String scannedUsed(String name) {
    return 'Used \"$name\".';
  }

  @override
  String scannedDiscarded(String name) {
    return 'Discarded \"$name\".';
  }

  @override
  String addedToStockMessage(String name) {
    return 'Added \"$name\" to stock.';
  }

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
  String get duplicateProductTitle => 'Similar product exists';

  @override
  String duplicateProductMessage(String name) {
    return 'A product named \"$name\" already exists — use it instead?';
  }

  @override
  String get duplicateProductCreateNew => 'Create new';

  @override
  String get duplicateProductUseExisting => 'Use existing';

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
  String get generateQrLabelTooltip => 'Generate QR label';

  @override
  String get showQrLabelTooltip => 'Show QR label';

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
  String get lowStockThresholdLabel => 'Low stock threshold';

  @override
  String get lowStockThresholdHint =>
      'e.g. 0.2 — flag the Stock tab when total on hand drops to this or below';

  @override
  String get lowStockChip => 'Low stock';

  @override
  String get targetStockLevelLabel => 'Target stock level';

  @override
  String get targetStockLevelHint =>
      'e.g. 5 — add-low-stock restocks up to this amount instead of just 1';

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
  String get noProductsYet => 'No products yet. Scan something to add one.';

  @override
  String get viewStockBatchesTooltip => 'View stock batches';

  @override
  String couldNotLoadBatches(String error) {
    return 'Could not load batches: $error';
  }

  @override
  String get noBatchesLeft => 'No batches left. Tap + to add one.';

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
  String get noLocationsYet => 'No locations yet. Tap + to add one.';

  @override
  String get renameTooltip => 'Rename';

  @override
  String get addLocationTooltip => 'Add location';

  @override
  String get locationsSubtitle => 'Rename or delete storage locations';

  @override
  String get productsSubtitle => 'Browse, edit, or delete products';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesSubtitle => 'Add, rename, or delete categories';

  @override
  String get newCategoryTitle => 'New category';

  @override
  String couldNotAddCategory(String error) {
    return 'Could not add category: $error';
  }

  @override
  String get renameCategoryTitle => 'Rename category';

  @override
  String couldNotRenameCategory(String error) {
    return 'Could not rename category: $error';
  }

  @override
  String get deleteCategoryTitle => 'Delete category?';

  @override
  String deleteCategoryConfirm(String name) {
    return 'This clears \"$name\" from every product using it -- those products aren\'t deleted.';
  }

  @override
  String couldNotDeleteCategory(String error) {
    return 'Could not delete category: $error';
  }

  @override
  String couldNotLoadCategories(String error) {
    return 'Could not load categories: $error';
  }

  @override
  String get noCategoriesYet => 'No categories yet. Tap + to add one.';

  @override
  String get addCategoryTooltip => 'Add category';

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
  String pendingScansSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count barcodes waiting to be looked up',
      one: '1 barcode waiting to be looked up',
    );
    return '$_temp0';
  }

  @override
  String get syncNowButton => 'Sync now';

  @override
  String get nothingPending =>
      'Nothing pending. Offline scans will show up here automatically.';

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
  String couldNotImport(String error) {
    return 'Could not import: $error';
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
  String get offCategorySuggestionsTitle =>
      'Open Food Facts category suggestions';

  @override
  String get offCategorySuggestionsSubtitle =>
      'Suggest a category when adding a product from a scan';

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
  String get importCsvTitle => 'Import stock (CSV)';

  @override
  String get importCsvSubtitle =>
      'Add stock from a spreadsheet in the same format as the export';

  @override
  String get exportConsumptionLogCsvTitle =>
      'Export consumption/waste log (CSV)';

  @override
  String get exportConsumptionLogCsvSubtitle =>
      'Download usage and waste history as a spreadsheet';

  @override
  String get importResultTitle => 'Import complete';

  @override
  String importedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows imported.',
      one: '1 row imported.',
      zero: 'No rows imported.',
    );
    return '$_temp0';
  }

  @override
  String importErrorsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows could not be imported:',
      one: '1 row could not be imported:',
    );
    return '$_temp0';
  }

  @override
  String importRowError(int row, String error) {
    return 'Row $row: $error';
  }

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

  @override
  String get shoppingListTitle => 'Shopping list';

  @override
  String get shoppingListAddHint => 'Add an item…';

  @override
  String get shoppingListEmpty =>
      'Your shopping list is empty. Add an item using the field above.';

  @override
  String couldNotLoadShoppingList(String error) {
    return 'Could not load shopping list: $error';
  }

  @override
  String couldNotAddShoppingListItem(String error) {
    return 'Could not add: $error';
  }

  @override
  String couldNotUpdateShoppingListItem(String error) {
    return 'Could not update: $error';
  }

  @override
  String couldNotDeleteShoppingListItem(String error) {
    return 'Could not delete: $error';
  }

  @override
  String shoppingListItemDeleted(String name) {
    return 'Deleted \"$name\".';
  }

  @override
  String get addLowStockTooltip => 'Add low stock';

  @override
  String lowStockAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count items.',
      one: 'Added 1 item.',
      zero: 'No low-stock items to add.',
    );
    return '$_temp0';
  }

  @override
  String couldNotAddLowStock(String error) {
    return 'Could not add low-stock items: $error';
  }

  @override
  String get clearDoneTooltip => 'Clear done';

  @override
  String clearedDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cleared $count items.',
      one: 'Cleared 1 item.',
      zero: 'Nothing to clear.',
    );
    return '$_temp0';
  }

  @override
  String couldNotClearDone(Object error) {
    return 'Could not clear done items: $error';
  }

  @override
  String get selectItemsTooltip => 'Select items';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get consumeSelectedTooltip => 'Consume selected';

  @override
  String get deleteSelectedTooltip => 'Delete selected';

  @override
  String get moveSelectedTooltip => 'Move selected';

  @override
  String get moveButton => 'Move';

  @override
  String get moveToLocationTitle => 'Move to location';

  @override
  String get bulkDeleteConfirmTitle => 'Remove selected batches?';

  @override
  String bulkDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This deletes $count selected batches.',
      one: 'This deletes 1 selected batch.',
    );
    return '$_temp0';
  }

  @override
  String bulkConsumedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Consumed $count batches.',
      one: 'Consumed 1 batch.',
    );
    return '$_temp0';
  }

  @override
  String bulkDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count batches.',
      one: 'Deleted 1 batch.',
    );
    return '$_temp0';
  }

  @override
  String bulkMovedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved $count batches.',
      one: 'Moved 1 batch.',
    );
    return '$_temp0';
  }

  @override
  String couldNotBulkConsume(String error) {
    return 'Could not consume selected items: $error';
  }

  @override
  String couldNotBulkDelete(String error) {
    return 'Could not delete selected items: $error';
  }

  @override
  String couldNotBulkMove(String error) {
    return 'Could not move selected items: $error';
  }

  @override
  String get needsAttentionHeader => 'Needs attention';

  @override
  String get inStockHeader => 'In stock';

  @override
  String get defaultsLabel => 'Defaults';

  @override
  String lowStockBannerText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items low on stock',
      one: '1 item low on stock',
    );
    return '$_temp0';
  }

  @override
  String get addAllButton => 'Add all';

  @override
  String get fromStockTag => 'From stock';

  @override
  String get doneSectionLabel => 'Done';

  @override
  String get settingsConnectionSection => 'Connection';

  @override
  String get settingsPreferencesSection => 'Preferences';

  @override
  String get settingsManageSection => 'Manage';

  @override
  String get settingsDataSection => 'Data';

  @override
  String get pickDateLabel => 'Pick date';

  @override
  String get bestBeforeSectionLabel => 'Best-before';

  @override
  String get batchesHeading => 'Batches';

  @override
  String inDaysChipLabel(int days) {
    return '+${days}d';
  }
}
