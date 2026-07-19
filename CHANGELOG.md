# Changelog

## [0.21.2](https://github.com/MarcelMuechler/Vorrat/compare/v0.21.1...v0.21.2) (2026-07-19)


### Bug Fixes

* **backend:** harden /api/backup/restore validation and stop blocking the event loop ([592b718](https://github.com/MarcelMuechler/Vorrat/commit/592b718ff907ec39474345aefaf46c3d44b10f4e))
* **backend:** make CSV formula-injection escaping losslessly reversible ([e3e482d](https://github.com/MarcelMuechler/Vorrat/commit/e3e482d796209347de65a6f44ebebea74199c098))
* **backend:** prevent path traversal via product image_url deletion ([5f74c7b](https://github.com/MarcelMuechler/Vorrat/commit/5f74c7bb61884578c6fba06b7f8ac9b0ffb42176))
* **backend:** stream remote product image downloads to enforce the size cap ([4606b79](https://github.com/MarcelMuechler/Vorrat/commit/4606b79d8925264a1b51113c3064f8d425439331))
* **backend:** surface OFF outages from refresh-from-off as 503, not 500 ([51c5cac](https://github.com/MarcelMuechler/Vorrat/commit/51c5cacd0dd2b83a6ce75b0400897d4b680d59e7))
* **frontend:** map finite_number validation errors to a friendly message ([6c44c66](https://github.com/MarcelMuechler/Vorrat/commit/6c44c660cda77a62de3c16dbb0350ae6ad21ffef))

## [0.21.1](https://github.com/MarcelMuechler/Vorrat/compare/v0.21.0...v0.21.1) (2026-07-19)


### Bug Fixes

* **backend:** enable Alembic batch mode for safe SQLite schema changes ([#263](https://github.com/MarcelMuechler/Vorrat/issues/263)) ([dc9539f](https://github.com/MarcelMuechler/Vorrat/commit/dc9539f786fbfb19be748a12ead143ce744cf638))
* **frontend:** add bottom padding so FAB doesn't cover last list row ([#253](https://github.com/MarcelMuechler/Vorrat/issues/253)) ([1e556ba](https://github.com/MarcelMuechler/Vorrat/commit/1e556bae0fbedf9569c2425c8bf01de0097ba327))
* **frontend:** dedupe low-stock shopping list action and add persistent banner state ([#254](https://github.com/MarcelMuechler/Vorrat/issues/254)) ([3fad896](https://github.com/MarcelMuechler/Vorrat/commit/3fad896fa9098587510a103fbc62d1f00f134ea1))
* **frontend:** grouped stock total reflects true stock, not filtered subtotal ([#255](https://github.com/MarcelMuechler/Vorrat/issues/255)) ([057c3a7](https://github.com/MarcelMuechler/Vorrat/commit/057c3a7d4735942df84386db786d2b726fb20eec))

## [0.21.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.20.0...v0.21.0) (2026-07-19)


### Features

* **backend:** introduce pytest unit test suite with TestClient ([db40751](https://github.com/MarcelMuechler/Vorrat/commit/db40751bbfaa910e6d03cac82833aab53d252fd0)), closes [#261](https://github.com/MarcelMuechler/Vorrat/issues/261)


### Bug Fixes

* **backend,frontend:** surface OFF network failures as 503, not a false 404 ([dd273ab](https://github.com/MarcelMuechler/Vorrat/commit/dd273aba115126ef4837cafe13e869070da41e78)), closes [#260](https://github.com/MarcelMuechler/Vorrat/issues/260)
* **frontend:** localize scan screen's camera error fallback text ([d162fee](https://github.com/MarcelMuechler/Vorrat/commit/d162fee21ee904ce3a617861960b1203fa32d61c)), closes [#251](https://github.com/MarcelMuechler/Vorrat/issues/251)
* **frontend:** show a friendly, localized reason for save errors instead of raw backend JSON ([8cf8d71](https://github.com/MarcelMuechler/Vorrat/commit/8cf8d711bf2eec8a1fb8eea18fc21aec2e272565)), closes [#250](https://github.com/MarcelMuechler/Vorrat/issues/250)

## [0.20.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.19.0...v0.20.0) (2026-07-18)


### Features

* **products:** cache external product images locally instead of hotlinking ([#262](https://github.com/MarcelMuechler/Vorrat/issues/262)) ([185f527](https://github.com/MarcelMuechler/Vorrat/commit/185f5270aafc9a3899a7e6cd274e18cd1ded656b))

## [0.19.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.18.3...v0.19.0) (2026-07-18)


### Features

* **backend,frontend:** in-app SQLite backup/restore from Settings ([e1d063a](https://github.com/MarcelMuechler/Vorrat/commit/e1d063a2f95ad241b24bacced96dbf0640948e0e)), closes [#212](https://github.com/MarcelMuechler/Vorrat/issues/212)
* **products:** upload a custom product photo ([#210](https://github.com/MarcelMuechler/Vorrat/issues/210)) ([77b7cc1](https://github.com/MarcelMuechler/Vorrat/commit/77b7cc1a541015e30305eb51cfe98d3bd0a684b8))

## [0.18.3](https://github.com/MarcelMuechler/Vorrat/compare/v0.18.2...v0.18.3) (2026-07-18)


### Bug Fixes

* **backend:** escape CSV formula injection in stock and consumption log exports ([0568b14](https://github.com/MarcelMuechler/Vorrat/commit/0568b14e6a496a7f3412efb0e2f635d8e18d49f0)), closes [#226](https://github.com/MarcelMuechler/Vorrat/issues/226)

## [0.18.2](https://github.com/MarcelMuechler/Vorrat/compare/v0.18.1...v0.18.2) (2026-07-18)


### Bug Fixes

* **backend:** add location name validation and normalization ([6308cf7](https://github.com/MarcelMuechler/Vorrat/commit/6308cf70ec7c491a8f543f186477192c5debada3))
* **backend:** bound CSV import size and move it off the event loop ([e2c5eaa](https://github.com/MarcelMuechler/Vorrat/commit/e2c5eaaebad14415eb56fe13142aa2c9e9e82af8))
* **backend:** enforce global barcode uniqueness across primary and alternate codes ([34be439](https://github.com/MarcelMuechler/Vorrat/commit/34be43965334bf81829fa3046b99434d95f1d959)), closes [#223](https://github.com/MarcelMuechler/Vorrat/issues/223)
* **backend:** make stock undo server-authoritative ([b30f54a](https://github.com/MarcelMuechler/Vorrat/commit/b30f54a11cd92473787aede71846d8db5f631438)), closes [#224](https://github.com/MarcelMuechler/Vorrat/issues/224)
* **backend:** preserve purchased_date/opened_at/price/quantity_unit in stock CSV round-trip ([28bb425](https://github.com/MarcelMuechler/Vorrat/commit/28bb425aecae1124add17e875e27429131f7aeb6))
* **backend:** reject NaN and infinity in float request schemas ([095a3fc](https://github.com/MarcelMuechler/Vorrat/commit/095a3fc463806364b959f4d93450455af73178c9))
* **backend:** reject NaN and infinity in float request schemas ([ccaa60d](https://github.com/MarcelMuechler/Vorrat/commit/ccaa60db1cbbcf2e347ea17ee48bc13d4782cd4c))
* **backend:** use effective expiry consistently in filters and response ([3056fe3](https://github.com/MarcelMuechler/Vorrat/commit/3056fe3a1802e2f1e568e9361806ce00ac9b4d15)), closes [#225](https://github.com/MarcelMuechler/Vorrat/issues/225)
* **frontend:** apply a bounded timeout to every ApiClient request ([39c6747](https://github.com/MarcelMuechler/Vorrat/commit/39c67477a37f1b36698c5e6e81cfa1e539b7ffd2)), closes [#233](https://github.com/MarcelMuechler/Vorrat/issues/233)
* **frontend:** bucket and display expiry by effective_expiry_date ([1fa3820](https://github.com/MarcelMuechler/Vorrat/commit/1fa382032a90022e7ea7ba7dfcc4be8c3930c925)), closes [#225](https://github.com/MarcelMuechler/Vorrat/issues/225)
* **frontend:** drop client stock data from undo call ([d8f68b9](https://github.com/MarcelMuechler/Vorrat/commit/d8f68b9f4ff50816a0f900a9fd236b0157d8afd1)), closes [#224](https://github.com/MarcelMuechler/Vorrat/issues/224)
* **frontend:** guard StockProvider.refresh against stale slow responses ([4b40b13](https://github.com/MarcelMuechler/Vorrat/commit/4b40b13181ef9de55911894fbcd8af9500293af5))
* **frontend:** icon-only fallback for product batch action row ([d5ffbec](https://github.com/MarcelMuechler/Vorrat/commit/d5ffbece48ec68316d7309b2026b2e9818816903))
* **frontend:** icon-only fallback for stock item action row ([21ebe28](https://github.com/MarcelMuechler/Vorrat/commit/21ebe286dbc399897506893dd885eab04ed4225f))
* **frontend:** keep stock filter pills on one line ([bca877c](https://github.com/MarcelMuechler/Vorrat/commit/bca877c5d784ca216881c1bc5652d581b7570d8c))


### Performance Improvements

* **backend:** eliminate N+1 barcode queries in GET /api/products ([abb4d46](https://github.com/MarcelMuechler/Vorrat/commit/abb4d46aac750666227a924d2f48893ea44d9da3))
* **backend:** reuse a lifecycle-managed HTTP client for OFF lookups ([6d21c94](https://github.com/MarcelMuechler/Vorrat/commit/6d21c941125e19068d533715634ed0f50ef263ee))

## [0.18.1](https://github.com/MarcelMuechler/Vorrat/compare/v0.18.0...v0.18.1) (2026-07-18)


### Bug Fixes

* **frontend:** pin stock stat-strip labels to one line ([7fb11a3](https://github.com/MarcelMuechler/Vorrat/commit/7fb11a3cedb58c547183c27727e5328475d0d48f))
* **frontend:** wrap stock item action buttons instead of clipping them ([e30a5dc](https://github.com/MarcelMuechler/Vorrat/commit/e30a5dc30651c34c69422cfa2ba2fba02a43fa39))

## [0.18.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.17.1...v0.18.0) (2026-07-16)


### Features

* **backend:** add optional price tracking to stock entries ([742e294](https://github.com/MarcelMuechler/Vorrat/commit/742e294db5bc5608f6e3b81888ca42f4e3925046)), closes [#126](https://github.com/MarcelMuechler/Vorrat/issues/126)
* **shopping-list:** allow categorizing free-text shopping list items ([430afd1](https://github.com/MarcelMuechler/Vorrat/commit/430afd10e65ace4ffbbddb7f867ead6e529e6e2d))
* support multiple barcodes per product ([23b4224](https://github.com/MarcelMuechler/Vorrat/commit/23b42245b721e63f60ee1cdfe58c6238b4df23c0)), closes [#208](https://github.com/MarcelMuechler/Vorrat/issues/208)


### Bug Fixes

* **frontend:** guide native users to Settings when no server URL is set ([421b108](https://github.com/MarcelMuechler/Vorrat/commit/421b108e1dc3657f07acceb33871de06674f5d77))
* **frontend:** style SnackBars to match the app's light/dark theme ([d85ec87](https://github.com/MarcelMuechler/Vorrat/commit/d85ec8787bfc685624922bff9240602a8809ae68))
* **frontend:** update scan_mode_test for the new price field ([9b6cffc](https://github.com/MarcelMuechler/Vorrat/commit/9b6cffcce35752dde175bf312d8ec40973d2f519))

## [0.17.1](https://github.com/MarcelMuechler/Vorrat/compare/v0.17.0...v0.17.1) (2026-07-15)


### Bug Fixes

* **frontend:** check for a duplicate product name on barcode-scanned adds too ([e5ce6cb](https://github.com/MarcelMuechler/Vorrat/commit/e5ce6cbc555facbf15df702ae776e615872edd9e))

## [0.17.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.16.1...v0.17.0) (2026-07-15)


### Features

* **frontend:** revamp UI to match new wireframe design ([233ce57](https://github.com/MarcelMuechler/Vorrat/commit/233ce57c3bbb08d68d69fedfc1f9c0a0af171fe4))

## [0.16.1](https://github.com/MarcelMuechler/Vorrat/compare/v0.16.0...v0.16.1) (2026-07-15)


### Bug Fixes

* **backend:** no-cache static assets so add-on updates don't need a hard reload ([#179](https://github.com/MarcelMuechler/Vorrat/issues/179)) ([18d45b5](https://github.com/MarcelMuechler/Vorrat/commit/18d45b58be6bcb8aaace98b2fe5b02efa164bc2a))
* **frontend:** auto-dismiss Undo SnackBars instead of staying open forever ([#178](https://github.com/MarcelMuechler/Vorrat/issues/178)) ([8d7fa22](https://github.com/MarcelMuechler/Vorrat/commit/8d7fa22c458fc644e20b226527e3da88d8cd6129))
* **frontend:** visual polish pass for empty states, filter rows, and dark theme ([ce31809](https://github.com/MarcelMuechler/Vorrat/commit/ce31809e7fcf625a793f975c81698ededbd653c0)), closes [#199](https://github.com/MarcelMuechler/Vorrat/issues/199)

## [0.16.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.15.0...v0.16.0) (2026-07-15)


### Features

* **ci:** carry the release CHANGELOG.md into the HA add-on wrapper repo ([5899ec5](https://github.com/MarcelMuechler/Vorrat/commit/5899ec5a8964e603db28de46306ca0d42f8a6ea0)), closes [#193](https://github.com/MarcelMuechler/Vorrat/issues/193)


### Bug Fixes

* **frontend:** correct German l10n gender agreement and quote style ([beacaf7](https://github.com/MarcelMuechler/Vorrat/commit/beacaf79a5b6941b7ac9dd928efc2c43ab263c5b))

## [0.15.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.14.1...v0.15.0) (2026-07-15)


### Features

* **frontend:** add bulk consume/delete/move to StockProvider ([e207377](https://github.com/MarcelMuechler/Vorrat/commit/e207377dafe10ec5f2abc78d879b545010e4bae4))
* **frontend:** add selection-mode UI for bulk stock actions ([#123](https://github.com/MarcelMuechler/Vorrat/issues/123)) ([1eb8096](https://github.com/MarcelMuechler/Vorrat/commit/1eb809696601520e753c8e3d0c5e5ab3d29bd89a))

## [0.14.1](https://github.com/MarcelMuechler/Vorrat/compare/v0.14.0...v0.14.1) (2026-07-15)


### Bug Fixes

* **backend:** cache genuine OFF 404 responses as not-found instead of retrying ([5a8f1c6](https://github.com/MarcelMuechler/Vorrat/commit/5a8f1c63f1ce078ae726bfa713a9946c4d7b1b29)), closes [#183](https://github.com/MarcelMuechler/Vorrat/issues/183)
* **backend:** escape X-Ingress-Path before splicing into base href ([5919499](https://github.com/MarcelMuechler/Vorrat/commit/5919499ab4b7d714c1b7e5ef32a619946ef4472c))
* **backend:** make consumption log 'until' filter inclusive of the whole day ([9d5beab](https://github.com/MarcelMuechler/Vorrat/commit/9d5beab530a44340425163ed2b7412389cee6eab)), closes [#185](https://github.com/MarcelMuechler/Vorrat/issues/185)
* **backend:** treat default_open_shelf_life_days=0 as a real value, not unset ([ca2e85c](https://github.com/MarcelMuechler/Vorrat/commit/ca2e85c41573fdf8b235333432d3395fd8ceb0f1))
* **backend:** URL-encode barcode before building the OFF request URL ([a5902aa](https://github.com/MarcelMuechler/Vorrat/commit/a5902aafd081546f76893093b675afefce89afa5)), closes [#182](https://github.com/MarcelMuechler/Vorrat/issues/182)
* **ci:** guard fromJSON(pr) in release-please workflow, sync uv.lock ([798e143](https://github.com/MarcelMuechler/Vorrat/commit/798e1439fa7faef6242b6c5d6f5cc7f3629be3fb)), closes [#191](https://github.com/MarcelMuechler/Vorrat/issues/191)

## [0.14.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.13.0...v0.14.0) (2026-07-14)


### Features

* **android:** wire release signing config for Play Store builds ([4320646](https://github.com/MarcelMuechler/Vorrat/commit/4320646861a890385d9e5b693bcd01f854178c20))
* **backend:** add /api/stock/undo/{log_id} to reverse a consume atomically ([0cd9a43](https://github.com/MarcelMuechler/Vorrat/commit/0cd9a43097746ec3cebd64b8b93b469e528db8bc)), closes [#160](https://github.com/MarcelMuechler/Vorrat/issues/160)
* **frontend:** wire Undo through the new atomic /stock/undo endpoint ([#160](https://github.com/MarcelMuechler/Vorrat/issues/160)) ([9135704](https://github.com/MarcelMuechler/Vorrat/commit/913570480dc765b6b4de8cbb1d7a75054e9e2763))


### Bug Fixes

* add NSCameraUsageDescription for iOS camera access ([#161](https://github.com/MarcelMuechler/Vorrat/issues/161)) ([c694840](https://github.com/MarcelMuechler/Vorrat/commit/c694840d5dfc70379693f08bd0366811284305ae))
* **backend:** preserve shopping-list items when deleting a linked product ([0ab9b52](https://github.com/MarcelMuechler/Vorrat/commit/0ab9b525b03db1574b8c827c764779da9206e59d)), closes [#157](https://github.com/MarcelMuechler/Vorrat/issues/157)
* **backend:** reject PATCH that would drop shopping-list item's product_id and name ([18160ba](https://github.com/MarcelMuechler/Vorrat/commit/18160ba524bedaacf6ca64a09104a655afa4ae53)), closes [#158](https://github.com/MarcelMuechler/Vorrat/issues/158)
* **backend:** reject stock consumes that exceed an entry's remaining amount ([5b596c8](https://github.com/MarcelMuechler/Vorrat/commit/5b596c87ad2d31cb088cb83b581e1481d1a4c8bf)), closes [#156](https://github.com/MarcelMuechler/Vorrat/issues/156)
* **backend:** return clean 4xx instead of 500 for bad FK refs and duplicate barcodes ([256a30c](https://github.com/MarcelMuechler/Vorrat/commit/256a30c9324a1b43ba9ab98ca09318306befce0b)), closes [#159](https://github.com/MarcelMuechler/Vorrat/issues/159)
* **frontend:** validate consume amount against available stock ([7b226ad](https://github.com/MarcelMuechler/Vorrat/commit/7b226adb5dd873a04ca386cda0870e9d25a41a5c))
* remove unsupported armv7 architecture ([#165](https://github.com/MarcelMuechler/Vorrat/issues/165)) ([58a8fe0](https://github.com/MarcelMuechler/Vorrat/commit/58a8fe09cadf9aaaaea1ff9eb719a1ec11f6419e))
* update overconsume smoke test for the consume response shape from [#160](https://github.com/MarcelMuechler/Vorrat/issues/160) ([f58aa4c](https://github.com/MarcelMuechler/Vorrat/commit/f58aa4ce79d6efd855d48e2fc8419428bbf5283e))

## [0.13.0](https://github.com/MarcelMuechler/Vorrat/compare/v0.12.0...v0.13.0) (2026-07-14)


### Features

* **backend:** add target_stock_level to Product ([#117](https://github.com/MarcelMuechler/Vorrat/issues/117)) ([8dffb25](https://github.com/MarcelMuechler/Vorrat/commit/8dffb25014d1f4692c005781e9e68c64b0c832b1))
* **backend:** restock to target_stock_level in add-low-stock ([#117](https://github.com/MarcelMuechler/Vorrat/issues/117)) ([09f13da](https://github.com/MarcelMuechler/Vorrat/commit/09f13da66b77cf8ac4b1bbef8a5e90811f2a56ed))
* **frontend:** edit target_stock_level on the product screen ([#117](https://github.com/MarcelMuechler/Vorrat/issues/117)) ([73ac6c3](https://github.com/MarcelMuechler/Vorrat/commit/73ac6c382c23b2f9d48a85c377c4f054e445a038))
* roll out the new logo as favicon, app icon, and HA add-on icon ([5f16135](https://github.com/MarcelMuechler/Vorrat/commit/5f16135df49126c12fb0cfb0e14718854fc4c48e))

## [0.12.0](https://github.com/MarcelMuechler/vorrat/compare/v0.11.0...v0.12.0) (2026-07-14)


### Features

* add bulk consume/delete/move endpoints for stock entries ([#123](https://github.com/MarcelMuechler/vorrat/issues/123)) ([ebf2cf8](https://github.com/MarcelMuechler/vorrat/commit/ebf2cf8b5f3bcc6d0ba0bfb55880e44c892fa925))
* add bulkConsumeStock/bulkDeleteStock/bulkMoveStock to ApiClient ([#123](https://github.com/MarcelMuechler/vorrat/issues/123)) ([e69f1f6](https://github.com/MarcelMuechler/vorrat/commit/e69f1f6974b6f256056e2b1334c7f34f7855635f))
* add consumption-log CSV export endpoint ([#127](https://github.com/MarcelMuechler/vorrat/issues/127)) ([191ae00](https://github.com/MarcelMuechler/vorrat/commit/191ae00a56983683b8aa23b8dda471e6d9d399d2))
* add consumption-log CSV export to Settings ([#127](https://github.com/MarcelMuechler/vorrat/issues/127)) ([bb07cd1](https://github.com/MarcelMuechler/vorrat/commit/bb07cd185f29f9fcbdf81a52078a6432e3125d6d))
* add NavigationRail for wide-screen layout ([#135](https://github.com/MarcelMuechler/vorrat/issues/135)) ([405ed94](https://github.com/MarcelMuechler/vorrat/commit/405ed949a59da230c95918a012468acebc461dd8))
* add quantityUnit field to ConsumptionLogEntry model ([#118](https://github.com/MarcelMuechler/vorrat/issues/118)) ([da5ab2e](https://github.com/MarcelMuechler/vorrat/commit/da5ab2e532210fd8bcbad8e99f6793b289eed6ce))
* add undo to swipe consume/spoil and shopping-list delete ([#137](https://github.com/MarcelMuechler/vorrat/issues/137)) ([f66a1bb](https://github.com/MarcelMuechler/vorrat/commit/f66a1bb465cb0ce950e8c95ec4b1a7762aa278ed))
* **backend:** add limit/offset pagination to list endpoints ([#114](https://github.com/MarcelMuechler/vorrat/issues/114)) ([8524090](https://github.com/MarcelMuechler/vorrat/commit/8524090f72bc3f094cb0d839147a0ebc7f61fc67))
* cap and center shell content width on wide screens ([#135](https://github.com/MarcelMuechler/vorrat/issues/135)) ([640d1fe](https://github.com/MarcelMuechler/vorrat/commit/640d1fe332e984a2079e6a891fd6a7e71e6366ba))
* debounce live search on Products screen ([#140](https://github.com/MarcelMuechler/vorrat/issues/140)) ([d758528](https://github.com/MarcelMuechler/vorrat/commit/d758528f12d15fe1c5ba280c147111bbf384055a))
* debounce live search on Stock screen ([#140](https://github.com/MarcelMuechler/vorrat/issues/140)) ([919f336](https://github.com/MarcelMuechler/vorrat/commit/919f33694af62358cd2f5af2283504df25dad240))
* expose quantity_unit in consumption-log response and CSV export ([#118](https://github.com/MarcelMuechler/vorrat/issues/118)) ([3e45692](https://github.com/MarcelMuechler/vorrat/commit/3e456920bd7a2eea2aa7680d2cb4c883b8c1ca11))
* expose the consumption-log until param in the API client ([#121](https://github.com/MarcelMuechler/vorrat/issues/121)) ([c10e507](https://github.com/MarcelMuechler/vorrat/commit/c10e507200f19c0c739adf8cd4de4cc0896e74d2))
* **frontend:** add limit/offset params to paginated list client methods ([#114](https://github.com/MarcelMuechler/vorrat/issues/114)) ([cf2c0a5](https://github.com/MarcelMuechler/vorrat/commit/cf2c0a5c35e89b0429814bcb45865ada44a2a9c0))
* generate/show QR labels for products ([#105](https://github.com/MarcelMuechler/vorrat/issues/105)) ([f47a9c7](https://github.com/MarcelMuechler/vorrat/commit/f47a9c72bce5aff713f971dd08086cf37bb4cde4))
* retry off_client network calls with backoff ([#120](https://github.com/MarcelMuechler/vorrat/issues/120)) ([4f6db1d](https://github.com/MarcelMuechler/vorrat/commit/4f6db1d66c991ba0068b90a7e252c1a4746b0e07))
* snapshot quantity_unit onto ConsumptionLog at write time ([#118](https://github.com/MarcelMuechler/vorrat/issues/118)) ([35d168c](https://github.com/MarcelMuechler/vorrat/commit/35d168cfd4f0c286d801eed5e906405f229b0572))


### Bug Fixes

* add missing tooltip to the add-location button ([#139](https://github.com/MarcelMuechler/vorrat/issues/139)) ([e3d9518](https://github.com/MarcelMuechler/vorrat/commit/e3d95187162fc9e17a771ab130feee836063ce9c))
* add pull-to-refresh to Categories, Locations and Products screens ([#139](https://github.com/MarcelMuechler/vorrat/issues/139)) ([15bc40d](https://github.com/MarcelMuechler/vorrat/commit/15bc40ddc8cae6ab00f1e4bc30ecd5863ecf9deb))
* make the Settings screen scrollable ([#134](https://github.com/MarcelMuechler/vorrat/issues/134)) ([72f9749](https://github.com/MarcelMuechler/vorrat/commit/72f9749b5f1fc4098d037feb667d29060f404ed9))
* show inline validation instead of silently ignoring bad dialog input ([#139](https://github.com/MarcelMuechler/vorrat/issues/139)) ([b7fdee9](https://github.com/MarcelMuechler/vorrat/commit/b7fdee97f07b366671c1511a9c0561d8e5a2342e))
* strip trailing .0 from whole-number amount displays ([#133](https://github.com/MarcelMuechler/vorrat/issues/133)) ([f8b2a56](https://github.com/MarcelMuechler/vorrat/commit/f8b2a56b57d389dd9fb2d77f7c1091551bdea9a7))
* use decimal keyboard for the add-to-stock amount field ([#139](https://github.com/MarcelMuechler/vorrat/issues/139)) ([d591810](https://github.com/MarcelMuechler/vorrat/commit/d5918102be28371be244e0c2d2d3467eb2172b59))

## [0.11.0](https://github.com/MarcelMuechler/vorrat/compare/v0.10.0...v0.11.0) (2026-07-14)


### Features

* add AddBatchSheet widget for inline batch entry ([#98](https://github.com/MarcelMuechler/vorrat/issues/98)) ([241d177](https://github.com/MarcelMuechler/vorrat/commit/241d17718e77ab764efa156683794fb88ea377e4))
* add CSV bulk import endpoint for stock ([#95](https://github.com/MarcelMuechler/vorrat/issues/95)) ([4432718](https://github.com/MarcelMuechler/vorrat/commit/443271848f8c14669b2d446e8b150025a4998744))
* cache Open Food Facts lookups with a TTL ([#96](https://github.com/MarcelMuechler/vorrat/issues/96)) ([de774ff](https://github.com/MarcelMuechler/vorrat/commit/de774ffc214f66fea91f14b38b7c41c6a7e38dfd))
* import stock from CSV on the Settings screen ([#95](https://github.com/MarcelMuechler/vorrat/issues/95)) ([44221a9](https://github.com/MarcelMuechler/vorrat/commit/44221a9bf4c58ebb30e850eae6ef5158955801ea))
* keep Add mode on the scan screen for known products ([#98](https://github.com/MarcelMuechler/vorrat/issues/98)) ([44e212b](https://github.com/MarcelMuechler/vorrat/commit/44e212bab811d7258005a8d4384cb64894e31019))
* make the Open Food Facts base URL configurable ([#97](https://github.com/MarcelMuechler/vorrat/issues/97)) ([94e4565](https://github.com/MarcelMuechler/vorrat/commit/94e4565c453b2b7c4ee78adb37eb32d04f820029))


### Bug Fixes

* clamp float residue when consuming stock to zero ([#92](https://github.com/MarcelMuechler/vorrat/issues/92)) ([47c22cd](https://github.com/MarcelMuechler/vorrat/commit/47c22cd6c493ed1c7667a9bfe81929286772ac45))
* delete consumption log rows with their product ([#91](https://github.com/MarcelMuechler/vorrat/issues/91)) ([d9533c7](https://github.com/MarcelMuechler/vorrat/commit/d9533c759009bfab33e4b4f320e6ae7de40f3f89))
* don't cache OFF network errors as not-found ([#96](https://github.com/MarcelMuechler/vorrat/issues/96)) ([9c04959](https://github.com/MarcelMuechler/vorrat/commit/9c049590e6b3e0ad328fa8d5592f3104b49ea4de))
* handle location-load failure in the add-batch sheet ([#98](https://github.com/MarcelMuechler/vorrat/issues/98)) ([f95e43f](https://github.com/MarcelMuechler/vorrat/commit/f95e43f5c5a70448be5ccd2ded7b8133f59b8ab7))
* keep pending scans reachable when the Scan tab is hidden ([#94](https://github.com/MarcelMuechler/vorrat/issues/94)) ([d283368](https://github.com/MarcelMuechler/vorrat/commit/d283368525848f7068935ed50ce48c5f3c63051d))
* surface errors when deleting a stock entry ([#93](https://github.com/MarcelMuechler/vorrat/issues/93)) ([3adda0e](https://github.com/MarcelMuechler/vorrat/commit/3adda0ef972976946dcb445cf572cd5a9ba23ed3))

## [0.10.0](https://github.com/MarcelMuechler/vorrat/compare/v0.9.0...v0.10.0) (2026-07-14)


### Features

* add /api/stats summary endpoint for HA sensors ([#35](https://github.com/MarcelMuechler/vorrat/issues/35)) ([e6f5692](https://github.com/MarcelMuechler/vorrat/commit/e6f56921e7ecf491c8f72b90fe57d1dbf60b466d))
* add shopping list CRUD router ([#88](https://github.com/MarcelMuechler/vorrat/issues/88)) ([fdd0752](https://github.com/MarcelMuechler/vorrat/commit/fdd07529c55e57002953e0e211157a0895012f20))
* add shopping list model and API client methods ([#88](https://github.com/MarcelMuechler/vorrat/issues/88)) ([06250b7](https://github.com/MarcelMuechler/vorrat/commit/06250b74cb2a0d31e24d059774cb42af8a19c764))
* add shopping list screen and tab ([#88](https://github.com/MarcelMuechler/vorrat/issues/88)) ([c6eaa8a](https://github.com/MarcelMuechler/vorrat/commit/c6eaa8af5ec5f6f02a7c12587f22059a6cc469d4))
* add ShoppingListItem model and migration ([#88](https://github.com/MarcelMuechler/vorrat/issues/88)) ([de930c0](https://github.com/MarcelMuechler/vorrat/commit/de930c0cf78aa7205415ec0366cb0817a0bda001))


### Bug Fixes

* harden category resolution, swipe-consume, and scan-open against silent failures ([#84](https://github.com/MarcelMuechler/vorrat/issues/84)) ([385f53b](https://github.com/MarcelMuechler/vorrat/commit/385f53ba20fb3bbb4fd98cb92b5df1c48dd2c892))
* tolerate concurrent seeding of the singleton app_settings row ([#78](https://github.com/MarcelMuechler/vorrat/issues/78)) ([#86](https://github.com/MarcelMuechler/vorrat/issues/86)) ([8a432d9](https://github.com/MarcelMuechler/vorrat/commit/8a432d9f7b581a4d72e52c6317d587537ced79a2))

## [0.9.0](https://github.com/MarcelMuechler/vorrat/compare/v0.8.0...v0.9.0) (2026-07-13)


### Features

* add a setting to disable Open Food Facts category suggestions ([#79](https://github.com/MarcelMuechler/vorrat/issues/79)) ([493a2c2](https://github.com/MarcelMuechler/vorrat/commit/493a2c2fffb05f2c5d6349a9fe9c844429d6bebc))
* category becomes a real entity with an autocomplete field ([#77](https://github.com/MarcelMuechler/vorrat/issues/77)) ([4b033bf](https://github.com/MarcelMuechler/vorrat/commit/4b033bfe8b6437c0c12b458e675d9c717d023af9))
* choose the scan action up front instead of after each scan ([#82](https://github.com/MarcelMuechler/vorrat/issues/82)) ([c1e7211](https://github.com/MarcelMuechler/vorrat/commit/c1e7211ecc412fa1382bd39dc52f67d2b386124f))
* prefill the OFF category suggestion instead of just hinting it ([#80](https://github.com/MarcelMuechler/vorrat/issues/80)) ([f0f4357](https://github.com/MarcelMuechler/vorrat/commit/f0f4357546791a1372256a2404ac9b3478fcf082))
* quantity unit as a dropdown instead of free text ([#67](https://github.com/MarcelMuechler/vorrat/issues/67)) ([dcc33a3](https://github.com/MarcelMuechler/vorrat/commit/dcc33a3e6b3bcda3b0421be7e8a0a06732e7f5a0))
* quick use/spoil buttons and swipe actions on stock items ([#81](https://github.com/MarcelMuechler/vorrat/issues/81)) ([002c291](https://github.com/MarcelMuechler/vorrat/commit/002c291a43b8721a4ab0ac5382a91b7c42fd52ef))
* use a lock-open icon for the mark-as-opened action ([#76](https://github.com/MarcelMuechler/vorrat/issues/76)) ([b1784e6](https://github.com/MarcelMuechler/vorrat/commit/b1784e609969751454bb24cb4c8e96a3943ad3dd))

## [0.8.0](https://github.com/MarcelMuechler/vorrat/compare/v0.7.0...v0.8.0) (2026-07-13)


### Features

* category filtering plus a non-committal OFF prefill ([#64](https://github.com/MarcelMuechler/vorrat/issues/64)) ([f1e57e1](https://github.com/MarcelMuechler/vorrat/commit/f1e57e15ed55c3b83b62d6f0f21f2a242fa42b45))
* highlight low stock via a per-product threshold ([#65](https://github.com/MarcelMuechler/vorrat/issues/65)) ([818dca2](https://github.com/MarcelMuechler/vorrat/commit/818dca294d87040e56ea4372d8130df54175239b))
* let scanning a known barcode open/consume/discard existing stock ([#66](https://github.com/MarcelMuechler/vorrat/issues/66)) ([f508b9f](https://github.com/MarcelMuechler/vorrat/commit/f508b9f5df6b81da19dcdfc123da4b8286639b03))
* make barcode scanning a platform-defaulted setting ([#59](https://github.com/MarcelMuechler/vorrat/issues/59)) ([9e16c79](https://github.com/MarcelMuechler/vorrat/commit/9e16c79dc68be8ef657f80a6e7ae4bd92336d2c2))
* remove the Brand field ([#62](https://github.com/MarcelMuechler/vorrat/issues/62)) ([dae7949](https://github.com/MarcelMuechler/vorrat/commit/dae7949f74fb6cf17d9a38bf376b055a47b9ee07))
* warn on likely duplicate barcode-less product names ([#63](https://github.com/MarcelMuechler/vorrat/issues/63)) ([30b6e85](https://github.com/MarcelMuechler/vorrat/commit/30b6e857d9c7d67ee287a795db19def0ded2a7c5))


### Bug Fixes

* trim whitespace when storing/matching barcodes ([#61](https://github.com/MarcelMuechler/vorrat/issues/61)) ([955a974](https://github.com/MarcelMuechler/vorrat/commit/955a974c23b135c8f270b52e1c3db1e5be351017))

## [0.7.0](https://github.com/MarcelMuechler/vorrat/compare/v0.6.0...v0.7.0) (2026-07-13)


### Features

* add a per-product detail view showing all its batches ([#32](https://github.com/MarcelMuechler/vorrat/issues/32)) ([80eb0c3](https://github.com/MarcelMuechler/vorrat/commit/80eb0c323fab5fd09edf2489083828adc7e6ce8d))
* add a way to refresh a product's data from Open Food Facts ([#40](https://github.com/MarcelMuechler/vorrat/issues/40)) ([b9a61b5](https://github.com/MarcelMuechler/vorrat/commit/b9a61b5f9da44ca15d47b906e45befa5285bde9d))
* add an expiry breakdown view ([#34](https://github.com/MarcelMuechler/vorrat/issues/34)) ([4fd3bb7](https://github.com/MarcelMuechler/vorrat/commit/4fd3bb7774a5fd03a693a220ef43a58e3135fc95))
* add CSV export of current stock ([#51](https://github.com/MarcelMuechler/vorrat/issues/51)) ([339e76f](https://github.com/MarcelMuechler/vorrat/commit/339e76f6476d58ef7f3e721f3d06613e779d16b5))
* add manual barcode entry as a scan fallback ([#37](https://github.com/MarcelMuechler/vorrat/issues/37)) ([b767b44](https://github.com/MarcelMuechler/vorrat/commit/b767b445828910bb7ec7602d3764d1b171c1a899))
* add product management (list + edit) to the frontend ([#43](https://github.com/MarcelMuechler/vorrat/issues/43)) ([832bd27](https://github.com/MarcelMuechler/vorrat/commit/832bd2766da11353a4befc8d324361f5e21d4570))
* add scan history for quick re-scans ([#38](https://github.com/MarcelMuechler/vorrat/issues/38)) ([cf36cbc](https://github.com/MarcelMuechler/vorrat/commit/cf36cbc85d4dd0db4c4d071fe0c85f73f7db3e38))
* add search and sort controls to the Stock overview ([#30](https://github.com/MarcelMuechler/vorrat/issues/30)) ([fee1798](https://github.com/MarcelMuechler/vorrat/commit/fee1798bf402738a2049244eac25c96eb08a670b))
* group Stock overview by product with total quantity ([#29](https://github.com/MarcelMuechler/vorrat/issues/29)) ([e98b2e2](https://github.com/MarcelMuechler/vorrat/commit/e98b2e2c396f68f90fedd9302d2b57bf260162c0))
* make the 'expiring soon' threshold configurable ([#33](https://github.com/MarcelMuechler/vorrat/issues/33)) ([3723395](https://github.com/MarcelMuechler/vorrat/commit/372339549adcbc3f27647c65d487039ffc78bd31))
* prefill amount/unit from OFF's quantity data ([#42](https://github.com/MarcelMuechler/vorrat/issues/42)) ([c936424](https://github.com/MarcelMuechler/vorrat/commit/c9364247a83bf9521b77e57189939bb94ef87d91))
* set up Flutter i18n with English and German ([#48](https://github.com/MarcelMuechler/vorrat/issues/48)) ([5956b8c](https://github.com/MarcelMuechler/vorrat/commit/5956b8c821e5052912fe24ede82de8e2c9a56c72))
* show relative time for best-before and purchase dates ([#53](https://github.com/MarcelMuechler/vorrat/issues/53)) ([e454e0b](https://github.com/MarcelMuechler/vorrat/commit/e454e0b46fad1f1687774db07fd07b0fc65730cb))
* show the OFF product image and a review hint before saving ([#39](https://github.com/MarcelMuechler/vorrat/issues/39)) ([f994c67](https://github.com/MarcelMuechler/vorrat/commit/f994c67bc1992c3ccb7f5e6d54d0f8bcf7cdeca6))
* track used vs. spoiled stock, with a simple waste summary ([#52](https://github.com/MarcelMuechler/vorrat/issues/52)) ([73e4891](https://github.com/MarcelMuechler/vorrat/commit/73e4891afbcc6410eff7b4bc0c56b1a53794cb9c))
* track when a stock entry was opened ([#50](https://github.com/MarcelMuechler/vorrat/issues/50)) ([93b342b](https://github.com/MarcelMuechler/vorrat/commit/93b342baba4f11f403aa8bc38e32fd1d1e3a755c))
* validate barcode format before running a lookup ([#41](https://github.com/MarcelMuechler/vorrat/issues/41)) ([0d88341](https://github.com/MarcelMuechler/vorrat/commit/0d883418f7ba06c612eaa8a74157e35d90f6de60))


### Bug Fixes

* reject empty product names ([#45](https://github.com/MarcelMuechler/vorrat/issues/45)) ([013c32c](https://github.com/MarcelMuechler/vorrat/commit/013c32c0b0ff69b153c2e9afb250a4d143cc5b47))
* reject non-positive amounts in StockEntryCreate/Update ([#44](https://github.com/MarcelMuechler/vorrat/issues/44)) ([6b929e3](https://github.com/MarcelMuechler/vorrat/commit/6b929e3fd5567b317d2fe0ba5adb3af4db75329a))

## [0.6.0](https://github.com/MarcelMuechler/vorrat/compare/v0.5.0...v0.6.0) (2026-07-13)


### Features

* add a location filter to the Stock overview ([#25](https://github.com/MarcelMuechler/vorrat/issues/25)) ([58fff1a](https://github.com/MarcelMuechler/vorrat/commit/58fff1ad8a9bc9add5778580299eb0f18603bb6c))
* add a locations management screen with rename/delete ([#26](https://github.com/MarcelMuechler/vorrat/issues/26)) ([7bf06ce](https://github.com/MarcelMuechler/vorrat/commit/7bf06ce8cedfc70445f2cf0b4ebae396b868592f))
* add a manual add-product flow that skips barcode scanning ([#14](https://github.com/MarcelMuechler/vorrat/issues/14)) ([673b932](https://github.com/MarcelMuechler/vorrat/commit/673b93216e13700592a7b0ba3d14bbea9b705679))
* add GitHub Actions CI ([#18](https://github.com/MarcelMuechler/vorrat/issues/18)) ([48da208](https://github.com/MarcelMuechler/vorrat/commit/48da20820fa639f3f82dd60eb3c81ec29afb94ee))
* queue barcode scans locally when the server is unreachable ([#27](https://github.com/MarcelMuechler/vorrat/issues/27)) ([79cfdc2](https://github.com/MarcelMuechler/vorrat/commit/79cfdc23c9d81a1d9e37ecb80c30b065368c37c7))
* sync queued barcode scans once back online ([#28](https://github.com/MarcelMuechler/vorrat/issues/28)) ([cdb2d6f](https://github.com/MarcelMuechler/vorrat/commit/cdb2d6f3a8f986060de278a362ab8cb462a07ec4))


### Bug Fixes

* hint at the Settings server URL on scan lookup failure ([#17](https://github.com/MarcelMuechler/vorrat/issues/17)) ([e8768b1](https://github.com/MarcelMuechler/vorrat/commit/e8768b1e11fb9edd47c9f6ee690a6a6ddf8e41b8))
* keep backend/app/__init__.py's __version__ in sync with releases ([d579799](https://github.com/MarcelMuechler/vorrat/commit/d5797995e82e63c7dc3cb8c281f7bce042a39858))

## [0.5.0](https://github.com/MarcelMuechler/vorrat/compare/v0.4.0...v0.5.0) (2026-07-13)


### Features

* auto-sync vorrat-hassio-addon on release ([#19](https://github.com/MarcelMuechler/vorrat/issues/19)) ([70198a4](https://github.com/MarcelMuechler/vorrat/commit/70198a4b28d51e18025f89607f0e74c9f33ffd37))

## [0.4.0](https://github.com/MarcelMuechler/vorrat/compare/v0.3.0...v0.4.0) (2026-07-13)


### Features

* automate version bumps with release-please ([#21](https://github.com/MarcelMuechler/vorrat/issues/21)) ([8c4ec32](https://github.com/MarcelMuechler/vorrat/commit/8c4ec32239219ebc44c69355687c96e3ea2c22a3))
* show a pairing QR code in the web UI's Settings screen ([#12](https://github.com/MarcelMuechler/vorrat/issues/12)) ([9efb031](https://github.com/MarcelMuechler/vorrat/commit/9efb0313d8369b33b0b23433b16989323b838990))


### Bug Fixes

* use annotation-based generic updater for YAML version bumps ([#21](https://github.com/MarcelMuechler/vorrat/issues/21)) ([6ba1d10](https://github.com/MarcelMuechler/vorrat/commit/6ba1d10c654e8c20ea70e91c66691c859f7bf747))
