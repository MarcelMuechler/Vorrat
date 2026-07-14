// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Vorrat';

  @override
  String get stockTitle => 'Bestand';

  @override
  String get scanTitle => 'Scannen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get locationsTitle => 'Standorte';

  @override
  String get productsTitle => 'Produkte';

  @override
  String get cancelButton => 'Abbrechen';

  @override
  String get nameRequired => 'Bitte gib einen Namen ein.';

  @override
  String get amountInvalid => 'Gib eine Menge größer als null ein.';

  @override
  String get saveButton => 'Speichern';

  @override
  String get deleteButton => 'Löschen';

  @override
  String get addButton => 'Hinzufügen';

  @override
  String get removeButton => 'Entfernen';

  @override
  String get consumeButton => 'Verbrauchen';

  @override
  String get lookUpButton => 'Nachschlagen';

  @override
  String get closeButton => 'Schließen';

  @override
  String get undoButton => 'Rückgängig';

  @override
  String get usedLabel => 'Verbraucht';

  @override
  String get spoiledLabel => 'Verdorben';

  @override
  String get nameLabel => 'Name';

  @override
  String get categoryLabel => 'Kategorie';

  @override
  String get clearCategoryTooltip => 'Kategorie entfernen';

  @override
  String get amountFieldLabel => 'Menge';

  @override
  String get unitLabel => 'Einheit';

  @override
  String get quantityUnitLabel => 'Mengeneinheit';

  @override
  String get unitPcsLabel => 'Stück';

  @override
  String get unitGramsLabel => 'g';

  @override
  String get unitKilogramsLabel => 'kg';

  @override
  String get unitMillilitersLabel => 'ml';

  @override
  String get unitLitersLabel => 'l';

  @override
  String get unitPackLabel => 'Packung';

  @override
  String get unitOtherLabel => 'Andere…';

  @override
  String get unitCustomLabel => 'Eigene Einheit';

  @override
  String get locationLabel => 'Standort';

  @override
  String get defaultLocationLabel => 'Standardort';

  @override
  String get noneLabel => 'Keine';

  @override
  String get searchLabel => 'Suche';

  @override
  String barcodeLabel(String code) {
    return 'Barcode: $code';
  }

  @override
  String get viewTooltip => 'Ansicht';

  @override
  String get viewModeFlat => 'Jede Charge';

  @override
  String get viewModeGrouped => 'Nach Produkt gruppiert';

  @override
  String get viewModeBreakdown => 'Ablaufübersicht';

  @override
  String get expiryBucketExpired => 'Abgelaufen';

  @override
  String get expiryBucketToday => 'Heute';

  @override
  String get expiryBucketThisWeek => 'Diese Woche';

  @override
  String get expiryBucketLater => 'Später';

  @override
  String get expiryBucketNoDate => 'Ohne Mindesthaltbarkeitsdatum';

  @override
  String get sortTooltip => 'Sortieren';

  @override
  String get sortBestBeforeDateLabel => 'Mindesthaltbarkeitsdatum';

  @override
  String get expiringSoonChip => 'Bald ablaufend';

  @override
  String get statusOk => 'OK';

  @override
  String get statusExpiringSoon => 'Bald ablaufend';

  @override
  String get statusExpired => 'Abgelaufen';

  @override
  String get allLocationsLabel => 'Alle Standorte';

  @override
  String get allCategoriesLabel => 'Alle Kategorien';

  @override
  String stockLoadError(String error) {
    return 'Bestand konnte nicht geladen werden: $error\n\nServer-URL in den Einstellungen prüfen.';
  }

  @override
  String get noStockYet =>
      'Noch kein Bestand. Scanne etwas, um es hinzuzufügen.';

  @override
  String get addProductManuallyTooltip => 'Produkt manuell hinzufügen';

  @override
  String get addNewBatchTooltip => 'Neue Charge hinzufügen';

  @override
  String groupTotalAmount(String amount) {
    return '$amount insgesamt';
  }

  @override
  String get markAsOpenedTooltip => 'Als geöffnet markieren';

  @override
  String useSomeOfTitle(String name) {
    return 'Etwas von \"$name\" verbrauchen';
  }

  @override
  String spoilSomeOfTitle(String name) {
    return 'Etwas von \"$name\" als verdorben markieren';
  }

  @override
  String amountInStockLabel(String amount) {
    return 'Menge (von $amount auf Lager)';
  }

  @override
  String get removeStockTitle => 'Aus dem Bestand entfernen?';

  @override
  String deleteBatchConfirm(String name) {
    return 'Dies löscht diese Charge von \"$name\".';
  }

  @override
  String couldNotConsume(String error) {
    return 'Verbrauch fehlgeschlagen: $error';
  }

  @override
  String couldNotDeleteStockEntry(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String couldNotUndo(String error) {
    return 'Rückgängig machen fehlgeschlagen: $error';
  }

  @override
  String get expiryToday => 'Läuft heute ab';

  @override
  String get expiryTomorrow => 'Läuft morgen ab';

  @override
  String get expiredYesterday => 'Gestern abgelaufen';

  @override
  String expiryInDays(int days) {
    return 'Läuft in $days Tagen ab';
  }

  @override
  String expiredDaysAgo(int days) {
    return 'Vor $days Tagen abgelaufen';
  }

  @override
  String get purchasedToday => 'Heute gekauft';

  @override
  String get purchasedTomorrow => 'Morgen gekauft';

  @override
  String get purchasedYesterday => 'Gestern gekauft';

  @override
  String purchasedInDays(int days) {
    return 'In $days Tagen gekauft';
  }

  @override
  String purchasedDaysAgo(int days) {
    return 'Vor $days Tagen gekauft';
  }

  @override
  String get openedToday => 'Heute geöffnet';

  @override
  String get openedTomorrow => 'Morgen geöffnet';

  @override
  String get openedYesterday => 'Gestern geöffnet';

  @override
  String openedInDays(int days) {
    return 'In $days Tagen geöffnet';
  }

  @override
  String openedDaysAgo(int days) {
    return 'Vor $days Tagen geöffnet';
  }

  @override
  String get invalidBarcodeMessage =>
      'Das sieht nicht wie ein gültiger Barcode aus.';

  @override
  String get enterBarcodeTitle => 'Barcode eingeben';

  @override
  String savedForLater(int count) {
    return 'Keine Verbindung — für später gespeichert ($count ausstehend).';
  }

  @override
  String lookupFailed(String error) {
    return 'Abfrage fehlgeschlagen: $error\n\nServer-URL in den Einstellungen prüfen.';
  }

  @override
  String get enterManuallyTooltip => 'Barcode manuell eingeben';

  @override
  String get recentlyScanned => 'Zuletzt gescannt';

  @override
  String get pendingScans => 'Ausstehende Scans';

  @override
  String get nothingScannedYet =>
      'Noch nichts gescannt. Scanne einen Barcode, um ihn hier zu sehen.';

  @override
  String get scanModeAdd => 'Hinzufügen';

  @override
  String get scanModeOpen => 'Öffnen';

  @override
  String get scanModeUse => 'Verbrauchen';

  @override
  String get scanModeDiscard => 'Verwerfen';

  @override
  String get nothingToActOn =>
      'Nichts zu tun -- unbekannter Barcode oder kein Bestand dafür.';

  @override
  String scannedOpened(String name) {
    return '\"$name\" als geöffnet markiert.';
  }

  @override
  String scannedUsed(String name) {
    return '\"$name\" verbraucht.';
  }

  @override
  String scannedDiscarded(String name) {
    return '\"$name\" verworfen.';
  }

  @override
  String addedToStockMessage(String name) {
    return '\"$name\" zum Bestand hinzugefügt.';
  }

  @override
  String get newLocationTitle => 'Neuer Standort';

  @override
  String couldNotAddLocation(String error) {
    return 'Standort konnte nicht hinzugefügt werden: $error';
  }

  @override
  String couldNotSave(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get duplicateProductTitle => 'Ähnliches Produkt vorhanden';

  @override
  String duplicateProductMessage(String name) {
    return 'Ein Produkt namens \"$name\" existiert bereits — stattdessen verwenden?';
  }

  @override
  String get duplicateProductCreateNew => 'Neu anlegen';

  @override
  String get duplicateProductUseExisting => 'Vorhandenes verwenden';

  @override
  String get addToStockTitle => 'Zum Bestand hinzufügen';

  @override
  String get offReviewHint => 'Von Open Food Facts — vor dem Speichern prüfen.';

  @override
  String get noBestBeforeDate => 'Kein Mindesthaltbarkeitsdatum';

  @override
  String bestBeforeLabel(String date) {
    return 'Mindestens haltbar bis: $date';
  }

  @override
  String get fetchedFromOff =>
      'Von Open Food Facts abgerufen — prüfen und dann speichern.';

  @override
  String couldNotRefresh(String error) {
    return 'Aktualisieren fehlgeschlagen: $error';
  }

  @override
  String get editProductTitle => 'Produkt bearbeiten';

  @override
  String get refreshFromOffTooltip => 'Von Open Food Facts aktualisieren';

  @override
  String get defaultBestBeforeDaysLabel => 'Standard-Haltbarkeitstage';

  @override
  String get defaultBestBeforeDaysHint =>
      'z. B. 7 — wird beim Hinzufügen zum Bestand vorausgefüllt';

  @override
  String get openShelfLifeLabel =>
      'Verbrauchen innerhalb (Tage nach dem Öffnen)';

  @override
  String get openShelfLifeHint =>
      'z. B. 3 — für Produkte, die nach dem Öffnen schneller verderben';

  @override
  String get lowStockThresholdLabel => 'Mindestbestand';

  @override
  String get lowStockThresholdHint =>
      'z. B. 0,2 — markiert im Bestand, wenn die Gesamtmenge darauf oder darunter fällt';

  @override
  String get lowStockChip => 'Bestand niedrig';

  @override
  String get deleteProductTitle => 'Produkt löschen?';

  @override
  String deleteProductConfirm(String name) {
    return 'Dies löscht \"$name\". Produkte, die noch im Bestand sind, können nicht gelöscht werden.';
  }

  @override
  String couldNotDeleteProduct(String error) {
    return 'Produkt konnte nicht gelöscht werden: $error';
  }

  @override
  String couldNotLoadProducts(String error) {
    return 'Produkte konnten nicht geladen werden: $error';
  }

  @override
  String get noProductsYet =>
      'Noch keine Produkte. Scanne etwas, um eines hinzuzufügen.';

  @override
  String get viewStockBatchesTooltip => 'Bestandschargen anzeigen';

  @override
  String couldNotLoadBatches(String error) {
    return 'Chargen konnten nicht geladen werden: $error';
  }

  @override
  String get noBatchesLeft =>
      'Keine Chargen mehr. Tippe auf +, um eine hinzuzufügen.';

  @override
  String bbdLabel(String date) {
    return 'MHD: $date';
  }

  @override
  String get renameLocationTitle => 'Standort umbenennen';

  @override
  String couldNotRenameLocation(String error) {
    return 'Standort konnte nicht umbenannt werden: $error';
  }

  @override
  String get deleteLocationTitle => 'Standort löschen?';

  @override
  String deleteLocationConfirm(String name) {
    return 'Dies löscht \"$name\".';
  }

  @override
  String couldNotDeleteLocation(String error) {
    return 'Standort konnte nicht gelöscht werden: $error';
  }

  @override
  String couldNotLoadLocations(String error) {
    return 'Standorte konnten nicht geladen werden: $error';
  }

  @override
  String get noLocationsYet =>
      'Noch keine Standorte. Tippe auf +, um einen hinzuzufügen.';

  @override
  String get renameTooltip => 'Umbenennen';

  @override
  String get addLocationTooltip => 'Standort hinzufügen';

  @override
  String get locationsSubtitle => 'Standorte umbenennen oder löschen';

  @override
  String get productsSubtitle =>
      'Produkte durchsuchen, bearbeiten oder löschen';

  @override
  String get categoriesTitle => 'Kategorien';

  @override
  String get categoriesSubtitle =>
      'Kategorien hinzufügen, umbenennen oder löschen';

  @override
  String get newCategoryTitle => 'Neue Kategorie';

  @override
  String couldNotAddCategory(String error) {
    return 'Kategorie konnte nicht hinzugefügt werden: $error';
  }

  @override
  String get renameCategoryTitle => 'Kategorie umbenennen';

  @override
  String couldNotRenameCategory(String error) {
    return 'Kategorie konnte nicht umbenannt werden: $error';
  }

  @override
  String get deleteCategoryTitle => 'Kategorie löschen?';

  @override
  String deleteCategoryConfirm(String name) {
    return 'Dies entfernt \"$name\" von allen Produkten, die sie verwenden -- diese Produkte werden nicht gelöscht.';
  }

  @override
  String couldNotDeleteCategory(String error) {
    return 'Kategorie konnte nicht gelöscht werden: $error';
  }

  @override
  String couldNotLoadCategories(String error) {
    return 'Kategorien konnten nicht geladen werden: $error';
  }

  @override
  String get noCategoriesYet =>
      'Noch keine Kategorien. Tippe auf +, um eine hinzuzufügen.';

  @override
  String get addCategoryTooltip => 'Kategorie hinzufügen';

  @override
  String lookupsFailedPending(int failures, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      failures,
      locale: localeName,
      other: '$failures Abfragen fehlgeschlagen',
      one: '1 Abfrage fehlgeschlagen',
    );
    return '$_temp0; $remaining noch ausstehend.';
  }

  @override
  String stoppedStillOffline(int remaining) {
    return 'Angehalten -- weiterhin offline. $remaining noch ausstehend.';
  }

  @override
  String get allSynced => 'Alle ausstehenden Scans synchronisiert.';

  @override
  String pendingScansSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Barcodes warten auf Abgleich',
      one: '1 Barcode wartet auf Abgleich',
    );
    return '$_temp0';
  }

  @override
  String get syncNowButton => 'Jetzt synchronisieren';

  @override
  String get nothingPending =>
      'Nichts ausstehend. Offline-Scans erscheinen hier automatisch.';

  @override
  String queuedLabel(String date) {
    return 'Eingereiht am $date';
  }

  @override
  String get discardTooltip => 'Verwerfen';

  @override
  String get enterWholeNumber => 'Bitte eine ganze Zahl größer als 0 eingeben.';

  @override
  String connectedVersion(String version) {
    return 'Verbunden — Server v$version';
  }

  @override
  String get couldNotReachServer => 'Server nicht erreichbar';

  @override
  String couldNotExport(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String couldNotImport(String error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get serverUrlDescription =>
      'Server-URL. Leer lassen, wenn innerhalb von Home Assistant (gleicher Ursprung via Ingress) ausgeführt. Native Apps und lokale Entwicklung benötigen die vollständige URL, z. B. http://192.168.1.20:8099';

  @override
  String get serverUrlLabel => 'Server-URL';

  @override
  String get barcodeScanningTitle => 'Barcode-Scannen';

  @override
  String get barcodeScanningSubtitle =>
      'Scan-Tab und Kamera-Scan-Buttons anzeigen';

  @override
  String get offCategorySuggestionsTitle =>
      'Open-Food-Facts-Kategorievorschläge';

  @override
  String get offCategorySuggestionsSubtitle =>
      'Beim Hinzufügen eines gescannten Produkts eine Kategorie vorschlagen';

  @override
  String get scanToConnectTooltip => 'Zum Verbinden scannen';

  @override
  String get saveTestConnectionButton => 'Speichern & Verbindung testen';

  @override
  String get expiringSoonDescription =>
      '„Bald ablaufend\" gilt für Artikel, die innerhalb dieser Anzahl von Tagen fällig sind.';

  @override
  String get exportCsvTitle => 'Bestand exportieren (CSV)';

  @override
  String get exportCsvSubtitle => 'Aktuellen Bestand als Tabelle herunterladen';

  @override
  String get importCsvTitle => 'Bestand importieren (CSV)';

  @override
  String get importCsvSubtitle =>
      'Bestand aus einer Tabelle im Format des Exports hinzufügen';

  @override
  String get exportConsumptionLogCsvTitle =>
      'Verbrauchs-/Verlustprotokoll exportieren (CSV)';

  @override
  String get exportConsumptionLogCsvSubtitle =>
      'Verbrauchs- und Verlustverlauf als Tabelle herunterladen';

  @override
  String get importResultTitle => 'Import abgeschlossen';

  @override
  String importedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen importiert.',
      one: '1 Zeile importiert.',
      zero: 'Keine Zeilen importiert.',
    );
    return '$_temp0';
  }

  @override
  String importErrorsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen konnten nicht importiert werden:',
      one: '1 Zeile konnte nicht importiert werden:',
    );
    return '$_temp0';
  }

  @override
  String importRowError(int row, String error) {
    return 'Zeile $row: $error';
  }

  @override
  String spoiledThisMonth(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Chargen diesen Monat als verdorben markiert.',
      one: '1 Charge diesen Monat als verdorben markiert.',
      zero: 'Nichts als verdorben markiert diesen Monat.',
    );
    return '$_temp0';
  }

  @override
  String get pairDeviceHint =>
      'Weiteres Gerät koppeln: Einstellungen → Scannen zum Verbinden öffnen und diesen Code scannen.';

  @override
  String get scanQrTitle => 'Server-QR-Code scannen';

  @override
  String get shoppingListTitle => 'Einkaufsliste';

  @override
  String get shoppingListAddHint => 'Artikel hinzufügen…';

  @override
  String get shoppingListEmpty =>
      'Die Einkaufsliste ist leer. Über das Feld oben einen Artikel hinzufügen.';

  @override
  String couldNotLoadShoppingList(String error) {
    return 'Einkaufsliste konnte nicht geladen werden: $error';
  }

  @override
  String couldNotAddShoppingListItem(String error) {
    return 'Konnte nicht hinzugefügt werden: $error';
  }

  @override
  String couldNotUpdateShoppingListItem(String error) {
    return 'Konnte nicht aktualisiert werden: $error';
  }

  @override
  String couldNotDeleteShoppingListItem(String error) {
    return 'Konnte nicht gelöscht werden: $error';
  }

  @override
  String shoppingListItemDeleted(String name) {
    return '\"$name\" gelöscht.';
  }

  @override
  String get addLowStockTooltip => 'Niedrigen Bestand hinzufügen';

  @override
  String lowStockAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel hinzugefügt.',
      one: '1 Artikel hinzugefügt.',
      zero: 'Keine Artikel mit niedrigem Bestand hinzuzufügen.',
    );
    return '$_temp0';
  }

  @override
  String couldNotAddLowStock(String error) {
    return 'Artikel mit niedrigem Bestand konnten nicht hinzugefügt werden: $error';
  }

  @override
  String get clearDoneTooltip => 'Erledigte entfernen';

  @override
  String clearedDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel entfernt.',
      one: '1 Artikel entfernt.',
      zero: 'Nichts zu entfernen.',
    );
    return '$_temp0';
  }

  @override
  String couldNotClearDone(Object error) {
    return 'Erledigte Artikel konnten nicht entfernt werden: $error';
  }
}
