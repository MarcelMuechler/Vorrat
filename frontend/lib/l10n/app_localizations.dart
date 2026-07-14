import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Vorrat'**
  String get appTitle;

  /// No description provided for @stockTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stockTitle;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @locationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get locationsTitle;

  /// No description provided for @productsTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTitle;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @removeButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeButton;

  /// No description provided for @consumeButton.
  ///
  /// In en, this message translates to:
  /// **'Consume'**
  String get consumeButton;

  /// No description provided for @lookUpButton.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get lookUpButton;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @usedLabel.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get usedLabel;

  /// No description provided for @spoiledLabel.
  ///
  /// In en, this message translates to:
  /// **'Spoiled'**
  String get spoiledLabel;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @clearCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear category'**
  String get clearCategoryTooltip;

  /// No description provided for @amountFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountFieldLabel;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @quantityUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity unit'**
  String get quantityUnitLabel;

  /// No description provided for @unitPcsLabel.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get unitPcsLabel;

  /// No description provided for @unitGramsLabel.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitGramsLabel;

  /// No description provided for @unitKilogramsLabel.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKilogramsLabel;

  /// No description provided for @unitMillilitersLabel.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unitMillilitersLabel;

  /// No description provided for @unitLitersLabel.
  ///
  /// In en, this message translates to:
  /// **'l'**
  String get unitLitersLabel;

  /// No description provided for @unitPackLabel.
  ///
  /// In en, this message translates to:
  /// **'pack'**
  String get unitPackLabel;

  /// No description provided for @unitOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Other…'**
  String get unitOtherLabel;

  /// No description provided for @unitCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom unit'**
  String get unitCustomLabel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @defaultLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Default location'**
  String get defaultLocationLabel;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @searchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLabel;

  /// No description provided for @barcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode: {code}'**
  String barcodeLabel(String code);

  /// No description provided for @viewTooltip.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewTooltip;

  /// No description provided for @viewModeFlat.
  ///
  /// In en, this message translates to:
  /// **'Every batch'**
  String get viewModeFlat;

  /// No description provided for @viewModeGrouped.
  ///
  /// In en, this message translates to:
  /// **'Grouped by product'**
  String get viewModeGrouped;

  /// No description provided for @viewModeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Expiry breakdown'**
  String get viewModeBreakdown;

  /// No description provided for @expiryBucketExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expiryBucketExpired;

  /// No description provided for @expiryBucketToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get expiryBucketToday;

  /// No description provided for @expiryBucketThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get expiryBucketThisWeek;

  /// No description provided for @expiryBucketLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get expiryBucketLater;

  /// No description provided for @expiryBucketNoDate.
  ///
  /// In en, this message translates to:
  /// **'No best-before date'**
  String get expiryBucketNoDate;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @sortBestBeforeDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Best-before date'**
  String get sortBestBeforeDateLabel;

  /// No description provided for @expiringSoonChip.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get expiringSoonChip;

  /// No description provided for @allLocationsLabel.
  ///
  /// In en, this message translates to:
  /// **'All locations'**
  String get allLocationsLabel;

  /// No description provided for @allCategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategoriesLabel;

  /// No description provided for @stockLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load stock: {error}\n\nCheck the server URL in Settings.'**
  String stockLoadError(String error);

  /// No description provided for @noStockYet.
  ///
  /// In en, this message translates to:
  /// **'No stock yet. Scan something to add it.'**
  String get noStockYet;

  /// No description provided for @addProductManuallyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add product manually'**
  String get addProductManuallyTooltip;

  /// No description provided for @addNewBatchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add new batch'**
  String get addNewBatchTooltip;

  /// No description provided for @groupTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} total'**
  String groupTotalAmount(String amount);

  /// No description provided for @markAsOpenedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mark as opened'**
  String get markAsOpenedTooltip;

  /// No description provided for @useSomeOfTitle.
  ///
  /// In en, this message translates to:
  /// **'Use some of \"{name}\"'**
  String useSomeOfTitle(String name);

  /// No description provided for @spoilSomeOfTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark some of \"{name}\" as spoiled'**
  String spoilSomeOfTitle(String name);

  /// No description provided for @amountInStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (of {amount} in stock)'**
  String amountInStockLabel(String amount);

  /// No description provided for @removeStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from stock?'**
  String get removeStockTitle;

  /// No description provided for @deleteBatchConfirm.
  ///
  /// In en, this message translates to:
  /// **'This deletes this batch of \"{name}\".'**
  String deleteBatchConfirm(String name);

  /// No description provided for @couldNotConsume.
  ///
  /// In en, this message translates to:
  /// **'Could not consume: {error}'**
  String couldNotConsume(String error);

  /// No description provided for @couldNotDeleteStockEntry.
  ///
  /// In en, this message translates to:
  /// **'Could not delete: {error}'**
  String couldNotDeleteStockEntry(String error);

  /// No description provided for @expiryToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get expiryToday;

  /// No description provided for @expiryTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Expires tomorrow'**
  String get expiryTomorrow;

  /// No description provided for @expiredYesterday.
  ///
  /// In en, this message translates to:
  /// **'Expired yesterday'**
  String get expiredYesterday;

  /// No description provided for @expiryInDays.
  ///
  /// In en, this message translates to:
  /// **'Expires in {days} days'**
  String expiryInDays(int days);

  /// No description provided for @expiredDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Expired {days} days ago'**
  String expiredDaysAgo(int days);

  /// No description provided for @purchasedToday.
  ///
  /// In en, this message translates to:
  /// **'Purchased today'**
  String get purchasedToday;

  /// No description provided for @purchasedTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Purchased tomorrow'**
  String get purchasedTomorrow;

  /// No description provided for @purchasedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Purchased yesterday'**
  String get purchasedYesterday;

  /// No description provided for @purchasedInDays.
  ///
  /// In en, this message translates to:
  /// **'Purchased in {days} days'**
  String purchasedInDays(int days);

  /// No description provided for @purchasedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Purchased {days} days ago'**
  String purchasedDaysAgo(int days);

  /// No description provided for @openedToday.
  ///
  /// In en, this message translates to:
  /// **'Opened today'**
  String get openedToday;

  /// No description provided for @openedTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Opened tomorrow'**
  String get openedTomorrow;

  /// No description provided for @openedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Opened yesterday'**
  String get openedYesterday;

  /// No description provided for @openedInDays.
  ///
  /// In en, this message translates to:
  /// **'Opened in {days} days'**
  String openedInDays(int days);

  /// No description provided for @openedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Opened {days} days ago'**
  String openedDaysAgo(int days);

  /// No description provided for @invalidBarcodeMessage.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a valid barcode.'**
  String get invalidBarcodeMessage;

  /// No description provided for @enterBarcodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter barcode'**
  String get enterBarcodeTitle;

  /// No description provided for @savedForLater.
  ///
  /// In en, this message translates to:
  /// **'No connection — saved for later ({count} pending).'**
  String savedForLater(int count);

  /// No description provided for @lookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Lookup failed: {error}\n\nCheck the server URL in Settings.'**
  String lookupFailed(String error);

  /// No description provided for @enterManuallyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter barcode manually'**
  String get enterManuallyTooltip;

  /// No description provided for @recentlyScanned.
  ///
  /// In en, this message translates to:
  /// **'Recently scanned'**
  String get recentlyScanned;

  /// No description provided for @pendingScans.
  ///
  /// In en, this message translates to:
  /// **'Pending scans'**
  String get pendingScans;

  /// No description provided for @nothingScannedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing scanned yet. Scan a barcode to see it here.'**
  String get nothingScannedYet;

  /// No description provided for @scanModeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get scanModeAdd;

  /// No description provided for @scanModeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get scanModeOpen;

  /// No description provided for @scanModeUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get scanModeUse;

  /// No description provided for @scanModeDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get scanModeDiscard;

  /// No description provided for @nothingToActOn.
  ///
  /// In en, this message translates to:
  /// **'Nothing to act on -- unknown barcode or no stock for it.'**
  String get nothingToActOn;

  /// No description provided for @scannedOpened.
  ///
  /// In en, this message translates to:
  /// **'Marked \"{name}\" as opened.'**
  String scannedOpened(String name);

  /// No description provided for @scannedUsed.
  ///
  /// In en, this message translates to:
  /// **'Used \"{name}\".'**
  String scannedUsed(String name);

  /// No description provided for @scannedDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Discarded \"{name}\".'**
  String scannedDiscarded(String name);

  /// No description provided for @addedToStockMessage.
  ///
  /// In en, this message translates to:
  /// **'Added \"{name}\" to stock.'**
  String addedToStockMessage(String name);

  /// No description provided for @newLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'New location'**
  String get newLocationTitle;

  /// No description provided for @couldNotAddLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not add location: {error}'**
  String couldNotAddLocation(String error);

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String couldNotSave(String error);

  /// No description provided for @duplicateProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Similar product exists'**
  String get duplicateProductTitle;

  /// No description provided for @duplicateProductMessage.
  ///
  /// In en, this message translates to:
  /// **'A product named \"{name}\" already exists — use it instead?'**
  String duplicateProductMessage(String name);

  /// No description provided for @duplicateProductCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get duplicateProductCreateNew;

  /// No description provided for @duplicateProductUseExisting.
  ///
  /// In en, this message translates to:
  /// **'Use existing'**
  String get duplicateProductUseExisting;

  /// No description provided for @addToStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to stock'**
  String get addToStockTitle;

  /// No description provided for @offReviewHint.
  ///
  /// In en, this message translates to:
  /// **'From Open Food Facts — check before saving.'**
  String get offReviewHint;

  /// No description provided for @noBestBeforeDate.
  ///
  /// In en, this message translates to:
  /// **'No best-before date'**
  String get noBestBeforeDate;

  /// No description provided for @bestBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'Best before: {date}'**
  String bestBeforeLabel(String date);

  /// No description provided for @fetchedFromOff.
  ///
  /// In en, this message translates to:
  /// **'Fetched from Open Food Facts — review, then Save.'**
  String get fetchedFromOff;

  /// No description provided for @couldNotRefresh.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh: {error}'**
  String couldNotRefresh(String error);

  /// No description provided for @editProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProductTitle;

  /// No description provided for @refreshFromOffTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh from Open Food Facts'**
  String get refreshFromOffTooltip;

  /// No description provided for @defaultBestBeforeDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Default best-before days'**
  String get defaultBestBeforeDaysLabel;

  /// No description provided for @defaultBestBeforeDaysHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 7 — prefilled when adding this product to stock'**
  String get defaultBestBeforeDaysHint;

  /// No description provided for @openShelfLifeLabel.
  ///
  /// In en, this message translates to:
  /// **'Use within (days after opening)'**
  String get openShelfLifeLabel;

  /// No description provided for @openShelfLifeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3 — for products that spoil faster once opened'**
  String get openShelfLifeHint;

  /// No description provided for @lowStockThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Low stock threshold'**
  String get lowStockThresholdLabel;

  /// No description provided for @lowStockThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 0.2 — flag the Stock tab when total on hand drops to this or below'**
  String get lowStockThresholdHint;

  /// No description provided for @lowStockChip.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get lowStockChip;

  /// No description provided for @deleteProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete product?'**
  String get deleteProductTitle;

  /// No description provided for @deleteProductConfirm.
  ///
  /// In en, this message translates to:
  /// **'This deletes \"{name}\". Products still in stock can\'t be deleted.'**
  String deleteProductConfirm(String name);

  /// No description provided for @couldNotDeleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Could not delete product: {error}'**
  String couldNotDeleteProduct(String error);

  /// No description provided for @couldNotLoadProducts.
  ///
  /// In en, this message translates to:
  /// **'Could not load products: {error}'**
  String couldNotLoadProducts(String error);

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet. Scan something to add one.'**
  String get noProductsYet;

  /// No description provided for @viewStockBatchesTooltip.
  ///
  /// In en, this message translates to:
  /// **'View stock batches'**
  String get viewStockBatchesTooltip;

  /// No description provided for @couldNotLoadBatches.
  ///
  /// In en, this message translates to:
  /// **'Could not load batches: {error}'**
  String couldNotLoadBatches(String error);

  /// No description provided for @noBatchesLeft.
  ///
  /// In en, this message translates to:
  /// **'No batches left. Tap + to add one.'**
  String get noBatchesLeft;

  /// No description provided for @bbdLabel.
  ///
  /// In en, this message translates to:
  /// **'BBD: {date}'**
  String bbdLabel(String date);

  /// No description provided for @renameLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename location'**
  String get renameLocationTitle;

  /// No description provided for @couldNotRenameLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not rename location: {error}'**
  String couldNotRenameLocation(String error);

  /// No description provided for @deleteLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete location?'**
  String get deleteLocationTitle;

  /// No description provided for @deleteLocationConfirm.
  ///
  /// In en, this message translates to:
  /// **'This deletes \"{name}\".'**
  String deleteLocationConfirm(String name);

  /// No description provided for @couldNotDeleteLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not delete location: {error}'**
  String couldNotDeleteLocation(String error);

  /// No description provided for @couldNotLoadLocations.
  ///
  /// In en, this message translates to:
  /// **'Could not load locations: {error}'**
  String couldNotLoadLocations(String error);

  /// No description provided for @noLocationsYet.
  ///
  /// In en, this message translates to:
  /// **'No locations yet. Tap + to add one.'**
  String get noLocationsYet;

  /// No description provided for @renameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameTooltip;

  /// No description provided for @addLocationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addLocationTooltip;

  /// No description provided for @locationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rename or delete storage locations'**
  String get locationsSubtitle;

  /// No description provided for @productsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse, edit, or delete products'**
  String get productsSubtitle;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, rename, or delete categories'**
  String get categoriesSubtitle;

  /// No description provided for @newCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategoryTitle;

  /// No description provided for @couldNotAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Could not add category: {error}'**
  String couldNotAddCategory(String error);

  /// No description provided for @renameCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename category'**
  String get renameCategoryTitle;

  /// No description provided for @couldNotRenameCategory.
  ///
  /// In en, this message translates to:
  /// **'Could not rename category: {error}'**
  String couldNotRenameCategory(String error);

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get deleteCategoryTitle;

  /// No description provided for @deleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'This clears \"{name}\" from every product using it -- those products aren\'t deleted.'**
  String deleteCategoryConfirm(String name);

  /// No description provided for @couldNotDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Could not delete category: {error}'**
  String couldNotDeleteCategory(String error);

  /// No description provided for @couldNotLoadCategories.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories: {error}'**
  String couldNotLoadCategories(String error);

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet. Tap + to add one.'**
  String get noCategoriesYet;

  /// No description provided for @addCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get addCategoryTooltip;

  /// No description provided for @lookupsFailedPending.
  ///
  /// In en, this message translates to:
  /// **'{failures, plural, =1{1 lookup failed} other{{failures} lookups failed}}; {remaining} still pending.'**
  String lookupsFailedPending(int failures, int remaining);

  /// No description provided for @stoppedStillOffline.
  ///
  /// In en, this message translates to:
  /// **'Stopped -- still offline. {remaining} still pending.'**
  String stoppedStillOffline(int remaining);

  /// No description provided for @allSynced.
  ///
  /// In en, this message translates to:
  /// **'All pending scans synced.'**
  String get allSynced;

  /// No description provided for @pendingScansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 barcode waiting to be looked up} other{{count} barcodes waiting to be looked up}}'**
  String pendingScansSubtitle(int count);

  /// No description provided for @syncNowButton.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNowButton;

  /// No description provided for @nothingPending.
  ///
  /// In en, this message translates to:
  /// **'Nothing pending. Offline scans will show up here automatically.'**
  String get nothingPending;

  /// No description provided for @queuedLabel.
  ///
  /// In en, this message translates to:
  /// **'Queued {date}'**
  String queuedLabel(String date);

  /// No description provided for @discardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardTooltip;

  /// No description provided for @enterWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number greater than 0.'**
  String get enterWholeNumber;

  /// No description provided for @connectedVersion.
  ///
  /// In en, this message translates to:
  /// **'Connected — server v{version}'**
  String connectedVersion(String version);

  /// No description provided for @couldNotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach server'**
  String get couldNotReachServer;

  /// No description provided for @couldNotExport.
  ///
  /// In en, this message translates to:
  /// **'Could not export: {error}'**
  String couldNotExport(String error);

  /// No description provided for @couldNotImport.
  ///
  /// In en, this message translates to:
  /// **'Could not import: {error}'**
  String couldNotImport(String error);

  /// No description provided for @serverUrlDescription.
  ///
  /// In en, this message translates to:
  /// **'Server URL. Leave blank when running inside Home Assistant (same-origin via Ingress). Native apps and local dev need the full URL, e.g. http://192.168.1.20:8099'**
  String get serverUrlDescription;

  /// No description provided for @serverUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrlLabel;

  /// No description provided for @barcodeScanningTitle.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanning'**
  String get barcodeScanningTitle;

  /// No description provided for @barcodeScanningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the Scan tab and camera scan buttons'**
  String get barcodeScanningSubtitle;

  /// No description provided for @offCategorySuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Food Facts category suggestions'**
  String get offCategorySuggestionsTitle;

  /// No description provided for @offCategorySuggestionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest a category when adding a product from a scan'**
  String get offCategorySuggestionsSubtitle;

  /// No description provided for @scanToConnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan to connect'**
  String get scanToConnectTooltip;

  /// No description provided for @saveTestConnectionButton.
  ///
  /// In en, this message translates to:
  /// **'Save & test connection'**
  String get saveTestConnectionButton;

  /// No description provided for @expiringSoonDescription.
  ///
  /// In en, this message translates to:
  /// **'\"Expiring soon\" applies to items due within this many days.'**
  String get expiringSoonDescription;

  /// No description provided for @exportCsvTitle.
  ///
  /// In en, this message translates to:
  /// **'Export stock (CSV)'**
  String get exportCsvTitle;

  /// No description provided for @exportCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download current stock as a spreadsheet'**
  String get exportCsvSubtitle;

  /// No description provided for @importCsvTitle.
  ///
  /// In en, this message translates to:
  /// **'Import stock (CSV)'**
  String get importCsvTitle;

  /// No description provided for @importCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add stock from a spreadsheet in the same format as the export'**
  String get importCsvSubtitle;

  /// No description provided for @exportConsumptionLogCsvTitle.
  ///
  /// In en, this message translates to:
  /// **'Export consumption/waste log (CSV)'**
  String get exportConsumptionLogCsvTitle;

  /// No description provided for @exportConsumptionLogCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download usage and waste history as a spreadsheet'**
  String get exportConsumptionLogCsvSubtitle;

  /// No description provided for @importResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get importResultTitle;

  /// No description provided for @importedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No rows imported.} =1{1 row imported.} other{{count} rows imported.}}'**
  String importedCount(int count);

  /// No description provided for @importErrorsHeading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row could not be imported:} other{{count} rows could not be imported:}}'**
  String importErrorsHeading(int count);

  /// No description provided for @importRowError.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: {error}'**
  String importRowError(int row, String error);

  /// No description provided for @spoiledThisMonth.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing marked spoiled this month.} =1{1 batch marked spoiled this month.} other{{count} batches marked spoiled this month.}}'**
  String spoiledThisMonth(int count);

  /// No description provided for @pairDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Pair another device: open Settings → Scan to connect on it, then scan this code.'**
  String get pairDeviceHint;

  /// No description provided for @scanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan server QR code'**
  String get scanQrTitle;

  /// No description provided for @shoppingListTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get shoppingListTitle;

  /// No description provided for @shoppingListAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add an item…'**
  String get shoppingListAddHint;

  /// No description provided for @shoppingListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your shopping list is empty. Add an item using the field above.'**
  String get shoppingListEmpty;

  /// No description provided for @couldNotLoadShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Could not load shopping list: {error}'**
  String couldNotLoadShoppingList(String error);

  /// No description provided for @couldNotAddShoppingListItem.
  ///
  /// In en, this message translates to:
  /// **'Could not add: {error}'**
  String couldNotAddShoppingListItem(String error);

  /// No description provided for @couldNotUpdateShoppingListItem.
  ///
  /// In en, this message translates to:
  /// **'Could not update: {error}'**
  String couldNotUpdateShoppingListItem(String error);

  /// No description provided for @couldNotDeleteShoppingListItem.
  ///
  /// In en, this message translates to:
  /// **'Could not delete: {error}'**
  String couldNotDeleteShoppingListItem(String error);

  /// No description provided for @addLowStockTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add low stock'**
  String get addLowStockTooltip;

  /// No description provided for @lowStockAddedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No low-stock items to add.} =1{Added 1 item.} other{Added {count} items.}}'**
  String lowStockAddedCount(int count);

  /// No description provided for @couldNotAddLowStock.
  ///
  /// In en, this message translates to:
  /// **'Could not add low-stock items: {error}'**
  String couldNotAddLowStock(String error);

  /// No description provided for @clearDoneTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear done'**
  String get clearDoneTooltip;

  /// No description provided for @clearedDoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to clear.} =1{Cleared 1 item.} other{Cleared {count} items.}}'**
  String clearedDoneCount(int count);

  /// No description provided for @couldNotClearDone.
  ///
  /// In en, this message translates to:
  /// **'Could not clear done items: {error}'**
  String couldNotClearDone(Object error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
