#!/usr/bin/env bash
# Grows across phases as a lightweight curl-based regression check.
# Requires: server running (uvicorn app.main:app), curl, jq.
set -euo pipefail

BASE="${BASE:-http://localhost:8000}"

echo "== health =="
curl -sf "$BASE/api/health" | jq .

echo "== locations: create =="
LOCATION_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' \
  -d '{"name": "Fridge"}' | jq -r .id)
echo "created location $LOCATION_ID"

echo "== locations: list =="
curl -sf "$BASE/api/locations" | jq .

echo "== products: create =="
PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Milk", "barcode": "1234567890123", "default_location_id": '"$LOCATION_ID"'}' \
  | jq -r .id)
echo "created product $PRODUCT_ID"

echo "== products: get =="
curl -sf "$BASE/api/products/$PRODUCT_ID" | jq .

echo "== categories: create =="
CATEGORY_ID=$(curl -sf -X POST "$BASE/api/categories" \
  -H 'content-type: application/json' \
  -d '{"name": "Dairy"}' | jq -r .id)
echo "created category $CATEGORY_ID"

echo "== products: patch =="
curl -sf -X PATCH "$BASE/api/products/$PRODUCT_ID" \
  -H 'content-type: application/json' \
  -d '{"category_id": '"$CATEGORY_ID"'}' | jq .

echo "== products: search =="
curl -sf "$BASE/api/products?search=milk" | jq .

PAST_DATE=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)
SOON_DATE=$(date -d "+2 days" +%Y-%m-%d 2>/dev/null || date -v+2d +%Y-%m-%d)
FAR_DATE=$(date -d "+30 days" +%Y-%m-%d 2>/dev/null || date -v+30d +%Y-%m-%d)

echo "== stock: add expired entry =="
EXPIRED_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "location_id": '"$LOCATION_ID"', "amount": 1, "best_before_date": "'"$PAST_DATE"'"}' \
  | jq -r .id)
echo "created expired stock entry $EXPIRED_ID"

echo "== stock: add expiring-soon entry =="
curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "location_id": '"$LOCATION_ID"', "amount": 2, "best_before_date": "'"$SOON_DATE"'"}' > /dev/null

echo "== stock: add ok (far future) entry =="
curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "location_id": '"$LOCATION_ID"', "amount": 3, "best_before_date": "'"$FAR_DATE"'"}' > /dev/null

echo "== stock: overview (expect 3 entries, statuses expired/expiring_soon/ok) =="
curl -sf "$BASE/api/stock" | jq '[.[] | {id, best_before_date, status}]'

echo "== stock: expiring_within_days=3 (expect 2: expired + expiring_soon) =="
COUNT=$(curl -sf "$BASE/api/stock?expiring_within_days=3" | jq 'length')
echo "count=$COUNT"
[ "$COUNT" = "2" ] || { echo "FAIL: expected 2 expiring entries, got $COUNT"; exit 1; }

echo "== stock: consume expired entry down to 0 (expect it to disappear) =="
curl -sf -X POST "$BASE/api/stock/$EXPIRED_ID/consume" \
  -H 'content-type: application/json' \
  -d '{"amount": 1}' | jq .
COUNT=$(curl -sf "$BASE/api/stock" | jq 'length')
[ "$COUNT" = "2" ] || { echo "FAIL: expected 2 remaining stock entries after consume, got $COUNT"; exit 1; }

echo "== stats: summary for HA sensors (expect 1 product, 2 stock entries, 0 expired, 1 expiring_soon) =="
STATS=$(curl -sf "$BASE/api/stats")
echo "$STATS" | jq .
for key in total_products total_stock_entries expired expiring_soon low_stock_products earliest_expiry; do
  echo "$STATS" | jq -e "has(\"$key\")" > /dev/null \
    || { echo "FAIL: /api/stats response missing key $key"; exit 1; }
done
[ "$(echo "$STATS" | jq -r .total_products)" = "1" ] || { echo "FAIL: expected total_products=1"; exit 1; }
[ "$(echo "$STATS" | jq -r .total_stock_entries)" = "2" ] || { echo "FAIL: expected total_stock_entries=2"; exit 1; }
[ "$(echo "$STATS" | jq -r .expired)" = "0" ] || { echo "FAIL: expected expired=0"; exit 1; }
[ "$(echo "$STATS" | jq -r .expiring_soon)" = "1" ] || { echo "FAIL: expected expiring_soon=1"; exit 1; }
[ "$(echo "$STATS" | jq -r .earliest_expiry)" = "$SOON_DATE" ] || { echo "FAIL: expected earliest_expiry=$SOON_DATE"; exit 1; }

echo "== shopping-list: create by product_id =="
ITEM_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"'}' | jq -r .id)
echo "created shopping list item $ITEM_PRODUCT_ID (product-linked)"

echo "== shopping-list: create by free text =="
ITEM_TEXT_ID=$(curl -sf -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"name": "Birthday candles", "amount": 2, "unit": "pcs"}' | jq -r .id)
echo "created shopping list item $ITEM_TEXT_ID (free-text)"

echo "== shopping-list: create with neither product_id nor name (expect 422) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' -d '{}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 creating item without product_id/name, got $STATUS"; exit 1; }

echo "== shopping-list: create with unknown product_id (expect 404) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' -d '{"product_id": 999999}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 creating item with unknown product_id, got $STATUS"; exit 1; }

echo "== shopping-list: patch free-text item done=true =="
curl -sf -X PATCH "$BASE/api/shopping-list/$ITEM_TEXT_ID" \
  -H 'content-type: application/json' -d '{"done": true}' | jq .

echo "== shopping-list: list order (open items first, then done; newest-first within each) =="
ORDER=$(curl -sf "$BASE/api/shopping-list" | jq -c '[.[] | {id, done}]')
echo "$ORDER"
[ "$(echo "$ORDER" | jq -r '.[0].id')" = "$ITEM_PRODUCT_ID" ] \
  || { echo "FAIL: expected open item $ITEM_PRODUCT_ID first, got $ORDER"; exit 1; }
[ "$(echo "$ORDER" | jq -r '.[0].done')" = "false" ] || { echo "FAIL: expected first item to be open"; exit 1; }
[ "$(echo "$ORDER" | jq -r '.[-1].id')" = "$ITEM_TEXT_ID" ] \
  || { echo "FAIL: expected done item $ITEM_TEXT_ID last, got $ORDER"; exit 1; }
[ "$(echo "$ORDER" | jq -r '.[-1].done')" = "true" ] || { echo "FAIL: expected last item to be done"; exit 1; }

echo "== shopping-list: patch missing item (expect 404) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/shopping-list/999999" \
  -H 'content-type: application/json' -d '{"done": true}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 patching missing item, got $STATUS"; exit 1; }

echo "== shopping-list: add-low-stock is a no-op while product already has an open item =="
RESULT=$(curl -sf -X POST "$BASE/api/shopping-list/add-low-stock")
echo "$RESULT" | jq .
[ "$(echo "$RESULT" | jq 'length')" = "0" ] \
  || { echo "FAIL: expected no items added (product already has an open item), got $RESULT"; exit 1; }

echo "== shopping-list: set low_stock_threshold so product qualifies as low-stock =="
curl -sf -X PATCH "$BASE/api/products/$PRODUCT_ID" \
  -H 'content-type: application/json' -d '{"low_stock_threshold": 10}' | jq -c '{id, low_stock_threshold}'

echo "== shopping-list: mark the existing open item done, then add-low-stock should create a new one =="
curl -sf -X PATCH "$BASE/api/shopping-list/$ITEM_PRODUCT_ID" \
  -H 'content-type: application/json' -d '{"done": true}' > /dev/null
RESULT=$(curl -sf -X POST "$BASE/api/shopping-list/add-low-stock")
echo "$RESULT" | jq .
[ "$(echo "$RESULT" | jq 'length')" = "1" ] \
  || { echo "FAIL: expected 1 item added by add-low-stock, got $RESULT"; exit 1; }
NEW_ITEM_ID=$(echo "$RESULT" | jq -r '.[0].id')
[ "$(echo "$RESULT" | jq -r '.[0].product_id')" = "$PRODUCT_ID" ] \
  || { echo "FAIL: expected add-low-stock item to link product $PRODUCT_ID"; exit 1; }

echo "== shopping-list: add-low-stock again is now a no-op (no duplicate) =="
RESULT=$(curl -sf -X POST "$BASE/api/shopping-list/add-low-stock")
echo "$RESULT" | jq .
[ "$(echo "$RESULT" | jq 'length')" = "0" ] \
  || { echo "FAIL: expected no duplicate item on second add-low-stock call, got $RESULT"; exit 1; }

echo "== shopping-list: clear done items =="
CLEARED=$(curl -sf -X DELETE "$BASE/api/shopping-list/done")
echo "$CLEARED" | jq .
[ "$(echo "$CLEARED" | jq -r .deleted)" = "2" ] \
  || { echo "FAIL: expected 2 done items cleared, got $CLEARED"; exit 1; }

echo "== shopping-list: list after clearing done (expect only the add-low-stock item) =="
COUNT=$(curl -sf "$BASE/api/shopping-list" | jq 'length')
[ "$COUNT" = "1" ] || { echo "FAIL: expected 1 remaining shopping list item, got $COUNT"; exit 1; }

echo "== shopping-list: delete remaining item =="
curl -sf -o /dev/null -w '%{http_code}\n' -X DELETE "$BASE/api/shopping-list/$NEW_ITEM_ID"
COUNT=$(curl -sf "$BASE/api/shopping-list" | jq 'length')
[ "$COUNT" = "0" ] || { echo "FAIL: expected 0 shopping list items after delete, got $COUNT"; exit 1; }

echo "== shopping-list: delete missing item (expect 404) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/shopping-list/999999")
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 deleting missing item, got $STATUS"; exit 1; }

echo "== products: create a second product for the float-residue/delete-history checks =="
FLOAT_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Float Residue Test"}' | jq -r .id)
echo "created product $FLOAT_PRODUCT_ID"

echo "== stock: add 1.0 unit of it =="
FLOAT_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$FLOAT_PRODUCT_ID"', "amount": 1.0}' | jq -r .id)
echo "created stock entry $FLOAT_ENTRY_ID"

echo "== stock: consume it via ten 0.1 partial consumes (float residue after the last one) =="
for i in $(seq 1 10); do
  RESPONSE=$(curl -sf -X POST "$BASE/api/stock/$FLOAT_ENTRY_ID/consume" \
    -H 'content-type: application/json' \
    -d '{"amount": 0.1}')
  echo "consume #$i -> $RESPONSE"
done
[ "$RESPONSE" = "null" ] \
  || { echo "FAIL: expected final consume to clear the entry (null response), got $RESPONSE"; exit 1; }

echo "== stock: entry should be gone despite float residue =="
COUNT=$(curl -sf "$BASE/api/stock?product_id=$FLOAT_PRODUCT_ID" | jq 'length')
[ "$COUNT" = "0" ] || { echo "FAIL: expected 0 stock entries after consuming to zero, got $COUNT"; exit 1; }

echo "== products: delete it now that it has consumption-log history but no stock (expect success) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/products/$FLOAT_PRODUCT_ID")
[ "$STATUS" = "204" ] || { echo "FAIL: expected 204 deleting product with consumption history, got $STATUS"; exit 1; }

echo "== consumption-log: its rows should be gone along with the product =="
COUNT=$(curl -sf "$BASE/api/consumption-log" | jq --argjson pid "$FLOAT_PRODUCT_ID" '[.[] | select(.product_id == $pid)] | length')
[ "$COUNT" = "0" ] || { echo "FAIL: expected 0 consumption-log rows for deleted product, got $COUNT"; exit 1; }

echo "== consumption-log/export.csv: row count matches JSON list, header + Milk's 'used' entry present =="
LOG_COUNT=$(curl -sf "$BASE/api/consumption-log" | jq 'length')
EXPORTED_LOG_CSV=$(curl -sf "$BASE/api/consumption-log/export.csv")
LOG_CSV_LINES=$(echo "$EXPORTED_LOG_CSV" | wc -l)
[ "$LOG_CSV_LINES" = "$((LOG_COUNT + 1))" ] \
  || { echo "FAIL: expected $((LOG_COUNT + 1)) CSV lines (header + $LOG_COUNT rows), got $LOG_CSV_LINES"; exit 1; }
echo "$EXPORTED_LOG_CSV" | tr -d '\r' | head -1 | grep -qx 'created_at,product_name,amount,reason' \
  || { echo "FAIL: unexpected export.csv header: $(echo "$EXPORTED_LOG_CSV" | head -1)"; exit 1; }
echo "$EXPORTED_LOG_CSV" | tr -d '\r' | grep -q ',Milk,1.0,used$' \
  || { echo "FAIL: expected a Milk/1.0/used row in consumption-log export.csv, got: $EXPORTED_LOG_CSV"; exit 1; }

echo "== consumption-log/export.csv: reason filter excludes it =="
FILTERED_LOG_CSV=$(curl -sf "$BASE/api/consumption-log/export.csv?reason=spoiled")
[ "$(echo "$FILTERED_LOG_CSV" | wc -l)" = "1" ] \
  || { echo "FAIL: expected only the header row for reason=spoiled, got: $FILTERED_LOG_CSV"; exit 1; }

echo "== stock/import.csv: import a mix of matched-by-barcode, new-product+new-location, and a broken row =="
BEFORE_COUNT=$(curl -sf "$BASE/api/stock" | jq 'length')
IMPORT_CSV=$(cat <<EOF
product_name,barcode,location,amount,best_before_date
Milk,1234567890123,Fridge,5,$FAR_DATE
New Import Product,,New Import Location,2,$SOON_DATE
Broken Row,,Fridge,notanumber,$SOON_DATE
EOF
)
IMPORT_RESULT=$(curl -sf -X POST "$BASE/api/stock/import.csv" -H 'content-type: text/csv' --data-binary "$IMPORT_CSV")
echo "$IMPORT_RESULT" | jq .
[ "$(echo "$IMPORT_RESULT" | jq -r .imported)" = "2" ] \
  || { echo "FAIL: expected imported=2, got $IMPORT_RESULT"; exit 1; }
[ "$(echo "$IMPORT_RESULT" | jq '.errors | length')" = "1" ] \
  || { echo "FAIL: expected 1 error, got $IMPORT_RESULT"; exit 1; }
[ "$(echo "$IMPORT_RESULT" | jq -r '.errors[0].row')" = "3" ] \
  || { echo "FAIL: expected error on row 3, got $IMPORT_RESULT"; exit 1; }

echo "== stock/import.csv: resulting stock reflects both imported rows =="
AFTER_COUNT=$(curl -sf "$BASE/api/stock" | jq 'length')
[ "$AFTER_COUNT" = "$((BEFORE_COUNT + 2))" ] \
  || { echo "FAIL: expected $((BEFORE_COUNT + 2)) stock entries after import, got $AFTER_COUNT"; exit 1; }
MATCHED_COUNT=$(curl -sf "$BASE/api/stock?product_id=$PRODUCT_ID" | jq '[.[] | select(.amount == 5)] | length')
[ "$MATCHED_COUNT" = "1" ] \
  || { echo "FAIL: expected imported row matched Milk by barcode with amount 5"; exit 1; }
NEW_PRODUCT_COUNT=$(curl -sf "$BASE/api/stock?search=New%20Import%20Product" \
  | jq '[.[] | select(.location_name == "New Import Location" and .amount == 2)] | length')
[ "$NEW_PRODUCT_COUNT" = "1" ] \
  || { echo "FAIL: expected new product+location to be created from import"; exit 1; }

echo "== stock/export.csv -> stock/import.csv: round-trip should re-import with zero errors =="
EXPORT_COUNT=$(curl -sf "$BASE/api/stock" | jq 'length')
EXPORTED_CSV=$(curl -sf "$BASE/api/stock/export.csv")
ROUNDTRIP_RESULT=$(curl -sf -X POST "$BASE/api/stock/import.csv" -H 'content-type: text/csv' --data-binary "$EXPORTED_CSV")
echo "$ROUNDTRIP_RESULT" | jq .
[ "$(echo "$ROUNDTRIP_RESULT" | jq -r .imported)" = "$EXPORT_COUNT" ] \
  || { echo "FAIL: expected round-trip import=$EXPORT_COUNT, got $ROUNDTRIP_RESULT"; exit 1; }
[ "$(echo "$ROUNDTRIP_RESULT" | jq '.errors | length')" = "0" ] \
  || { echo "FAIL: expected zero errors round-tripping export.csv, got $ROUNDTRIP_RESULT"; exit 1; }

echo "OK"
