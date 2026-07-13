# Changelog

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
