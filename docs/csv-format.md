# Stock CSV Import/Export Format

Vorrat supports importing and exporting stock data as CSV, allowing bulk operations and integration with other tools.

## Endpoints

- `GET /api/stock/export.csv` — Export all current stock entries as CSV
- `POST /api/stock/import.csv` — Import stock entries from a CSV file

## CSV Format

### Headers

The CSV must have a header row with the following columns:

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| `product_name` | string | Yes | Name of the product. If a product with this name already exists and no barcode is specified, the existing product is reused. |
| `barcode` | string | No | Product barcode. If present and a product with this barcode exists, the existing product is reused; otherwise a new product is created with this barcode. |
| `quantity_unit` | string | No | Unit the product is tracked in (e.g., "pcs", "kg"). Only applied when the row creates a brand-new product; if the product already exists (matched by barcode or name), its existing unit is kept unchanged. |
| `location` | string | No | Location where the stock is stored (e.g., "Kitchen", "Pantry"). If a location with this name already exists, it is reused; otherwise a new location is created. |
| `amount` | float | Yes | Quantity of the item. Must be greater than 0. |
| `best_before_date` | date | No | Expiration/best-before date in ISO 8601 format (`YYYY-MM-DD`). |
| `purchased_date` | date | No | Date the stock entry was purchased, in ISO 8601 format (`YYYY-MM-DD`). |
| `opened_at` | date | No | Date the item was opened, in ISO 8601 format (`YYYY-MM-DD`). Combined with the product's open-shelf-life setting, this can bring the effective expiry earlier than `best_before_date` — losing this value on a round-trip could turn an already-expired opened item into one that no longer looks expired. |
| `price` | float | No | Per-unit price paid for the entry (in `quantity_unit`, not a total for the whole entry). Must not be negative. |
| `status` | string | No | **Export only** — derived field showing `ok`, `expiring_soon`, or `expired`. This column is ignored on import. |

All columns beyond `product_name`/`barcode`/`amount` are optional on import and read by name, not position — a CSV from before a column existed (or missing one entirely) still imports fine, with those fields simply left null on the created stock entry.

### Example CSV

```csv
product_name,barcode,quantity_unit,location,amount,best_before_date,purchased_date,opened_at,price
Milk,3017620425035,l,Kitchen,1.0,2025-01-20,2025-01-10,2025-01-15,1.29
Bread,,pcs,Pantry,2.0,,,,
Cheese,5010477007856,kg,Kitchen,0.5,2025-02-15,2025-01-05,,4.50
```

## Import Behavior

- **Row-by-row processing**: Each row is processed independently. If a row contains an error, it is recorded in the error list but does not prevent subsequent rows from being imported.
- **Product matching**: If a barcode is provided, it takes precedence over the product name. Products are matched by barcode first, then by name (case-insensitive).
- **Location matching**: Locations are matched by name (case-insensitive). If a location doesn't exist, it is created.
- **Validation**: All rows are validated before being imported. The response includes the count of successfully imported rows and a list of any errors encountered.

### Response

The import endpoint returns a JSON response with the following structure:

```json
{
  "imported": 3,
  "errors": [
    {
      "row": 2,
      "error": "product_name is required"
    }
  ]
}
```

## Export Format

Exported CSV includes `quantity_unit`, `purchased_date`, `opened_at`, and `price` alongside the importable columns, plus an additional `status` column (derived from `best_before_date` and settings) for reference:

```csv
product_name,barcode,quantity_unit,location,amount,best_before_date,purchased_date,opened_at,price,status
Milk,3017620425035,l,Kitchen,1.0,2025-01-20,2025-01-10,2025-01-15,1.29,ok
Bread,,pcs,Pantry,2.0,,,,,ok
```

The `status` column is computed based on the item's best-before date:
- `ok` — No expiration date or not expiring soon
- `expiring_soon` — Best-before date is within the configured "expiring soon" threshold (default: 3 days)
- `expired` — Best-before date is in the past

### What is and isn't preserved

Export/import round-trips every `StockEntry` field that affects correctness: `amount`, `best_before_date`, `purchased_date`, `opened_at`, and `price`, plus `quantity_unit` for newly-created products. Losing `opened_at` in particular would be harmful, since it feeds the effective-expiry calculation alongside a product's open-shelf-life setting — dropping it on a round-trip could turn an already-expired opened item into one that no longer looks expired.

This CSV is **not** a full backup/restore format. It deliberately does **not** export or restore:
- Product defaults (`default_best_before_days`, `default_open_shelf_life_days`, `low_stock_threshold`, `target_stock_level`)
- Categories
- Product images

Those live on `Product`, not `StockEntry`, and are shared across every stock entry for that product — round-tripping them through a per-entry stock file would mean silently rewriting shared product data every time someone edits and re-imports a CSV. Manage them via the product screens instead.

## Consumption log export

`GET /api/consumption-log/export.csv` (export only — there is no import counterpart) writes one
row per consumed or spoiled batch, accepting the same `since`/`until`/`reason` query parameters
as `GET /api/consumption-log`:

| Column | Description |
|--------|-------------|
| `created_at` | When the batch was consumed or discarded (UTC). |
| `product_name` | Name of the product at export time. |
| `amount` | How much left stock. |
| `quantity_unit` | Unit the amount is in. |
| `reason` | `used` or `spoiled`. |
| `price` | Per-unit price snapshotted from the stock entry at consume time, so later price changes don't rewrite history. Empty when the entry had no price. |

`amount * price` is what that row was worth; `GET /api/consumption-log/summary` returns the same
sum server-side (`used_value` / `spoiled_value`, plus entry counts) over an optional
`since`/`until` window. Unpriced rows are counted but add nothing to the value, so both are
lower bounds whenever some stock was never priced.

## Tips

- **Round-trip**: Export, edit, and re-import to bulk update stock. The `status` column from export is ignored on import, so no special cleanup is needed. Note that import always creates new stock entries rather than updating existing ones by id, so re-importing an unedited export duplicates every row.
- **Date format**: Always use ISO 8601 format (`YYYY-MM-DD`) for `best_before_date`, `purchased_date`, and `opened_at`. Other formats will be rejected.
- **Empty locations**: Leave the `location` column empty to create stock entries without assigning a location.
- **Backward compatibility**: `quantity_unit`, `purchased_date`, `opened_at`, and `price` are all optional on import and matched by header name, not column position — a CSV from before these columns existed still imports fine, with those fields simply left null.
- **Curl example**:
  ```sh
  curl -X POST http://localhost:8000/api/stock/import.csv \
    --data-binary @stock.csv \
    -H "Content-Type: text/csv"
  ```
