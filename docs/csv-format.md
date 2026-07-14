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
| `location` | string | No | Location where the stock is stored (e.g., "Kitchen", "Pantry"). If a location with this name already exists, it is reused; otherwise a new location is created. |
| `amount` | float | Yes | Quantity of the item. Must be greater than 0. |
| `best_before_date` | date | No | Expiration/best-before date in ISO 8601 format (`YYYY-MM-DD`). |
| `status` | string | No | **Export only** — derived field showing `ok`, `expiring_soon`, or `expired`. This column is ignored on import. |

### Example CSV

```csv
product_name,barcode,location,amount,best_before_date
Milk,3017620425035,Kitchen,1.0,2025-01-20
Bread,,Pantry,2.0,
Cheese,5010477007856,Kitchen,0.5,2025-02-15
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

Exported CSV includes an additional `status` column (derived from `best_before_date` and settings) for reference:

```csv
product_name,barcode,location,amount,best_before_date,status
Milk,3017620425035,Kitchen,1.0,2025-01-20,ok
Bread,,Pantry,2.0,,ok
```

The `status` column is computed based on the item's best-before date:
- `ok` — No expiration date or not expiring soon
- `expiring_soon` — Best-before date is within the configured "expiring soon" threshold (default: 3 days)
- `expired` — Best-before date is in the past

## Tips

- **Round-trip**: Export, edit, and re-import to bulk update stock. The `status` column from export is ignored on import, so no special cleanup is needed.
- **Date format**: Always use ISO 8601 format (`YYYY-MM-DD`) for best-before dates. Other formats will be rejected.
- **Empty locations**: Leave the `location` column empty to create stock entries without assigning a location.
- **Curl example**:
  ```sh
  curl -X POST http://localhost:8000/api/stock/import.csv \
    --data-binary @stock.csv \
    -H "Content-Type: text/csv"
  ```
