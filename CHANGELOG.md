# Changelog

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
