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

echo "== products: create with nonexistent category_id (expect 404 not 500) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Bad Category Product", "category_id": 999999}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 creating product with unknown category_id, got $STATUS"; exit 1; }

echo "== products: create with nonexistent default_location_id (expect 404 not 500) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Bad Location Product", "default_location_id": 999999}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 creating product with unknown default_location_id, got $STATUS"; exit 1; }

echo "== products: patch with nonexistent category_id (expect 404 not 500) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/products/$PRODUCT_ID" \
  -H 'content-type: application/json' -d '{"category_id": 999999}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 patching product with unknown category_id, got $STATUS"; exit 1; }

echo "== products: create a second product with a duplicate barcode (expect 409 not 500) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Duplicate Barcode Product", "barcode": "1234567890123"}')
[ "$STATUS" = "409" ] || { echo "FAIL: expected 409 creating product with duplicate barcode, got $STATUS"; exit 1; }

echo "== products: patch another product to the same duplicate barcode (expect 409 not 500) =="
OTHER_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "Barcode-less Product"}' | jq -r .id)
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/products/$OTHER_PRODUCT_ID" \
  -H 'content-type: application/json' -d '{"barcode": "1234567890123"}')
[ "$STATUS" = "409" ] || { echo "FAIL: expected 409 patching product to a duplicate barcode, got $STATUS"; exit 1; }
curl -sf -o /dev/null -X DELETE "$BASE/api/products/$OTHER_PRODUCT_ID"

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

echo "== stock: patch entry with nonexistent location_id (expect 404 not 500) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/stock/$EXPIRED_ID" \
  -H 'content-type: application/json' -d '{"location_id": 999999}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 patching stock entry with unknown location_id, got $STATUS"; exit 1; }

echo "== stock: consume expired entry down to 0 (expect it to disappear) =="
curl -sf -X POST "$BASE/api/stock/$EXPIRED_ID/consume" \
  -H 'content-type: application/json' \
  -d '{"amount": 1}' | jq .
COUNT=$(curl -sf "$BASE/api/stock" | jq 'length')
[ "$COUNT" = "2" ] || { echo "FAIL: expected 2 remaining stock entries after consume, got $COUNT"; exit 1; }

echo "== consumption-log: the consume above snapshotted Milk's quantity_unit (default 'pcs') onto the log row =="
LOG_UNIT=$(curl -sf "$BASE/api/consumption-log?reason=used" \
  | jq -r --argjson pid "$PRODUCT_ID" '[.[] | select(.product_id == $pid)][0].quantity_unit')
[ "$LOG_UNIT" = "pcs" ] || { echo "FAIL: expected consumption-log quantity_unit=pcs, got $LOG_UNIT"; exit 1; }

echo "== consumption-log: until=today still includes an entry logged today (inclusive of the whole day, not just up to midnight) =="
TODAY=$(date +%Y-%m-%d)
COUNT=$(curl -sf "$BASE/api/consumption-log?until=$TODAY" \
  | jq --argjson pid "$PRODUCT_ID" '[.[] | select(.product_id == $pid)] | length')
[ "$COUNT" = "1" ] || { echo "FAIL: expected 1 consumption-log row for product with until=today, got $COUNT"; exit 1; }

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

echo "== shopping-list: create name-only item for merged-invariant patch checks =="
INVARIANT_ITEM_ID=$(curl -sf -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"name": "temporary"}' | jq -r .id)
echo "created shopping list item $INVARIANT_ITEM_ID (name-only)"

echo "== shopping-list: patch that would null out both product_id and name (expect 4xx, not 200) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/shopping-list/$INVARIANT_ITEM_ID" \
  -H 'content-type: application/json' -d '{"product_id": null, "name": null}')
case "$STATUS" in
  4??) ;;
  *) echo "FAIL: expected a 4xx nulling out both product_id and name, got $STATUS"; exit 1 ;;
esac

echo "== shopping-list: verify the rejected patch left the item unchanged =="
UNCHANGED=$(curl -sf "$BASE/api/shopping-list" | jq -c --argjson id "$INVARIANT_ITEM_ID" '.[] | select(.id == $id)')
echo "$UNCHANGED"
[ "$(echo "$UNCHANGED" | jq -r .name)" = "temporary" ] \
  || { echo "FAIL: expected name still 'temporary' after rejected patch, got $UNCHANGED"; exit 1; }
[ "$(echo "$UNCHANGED" | jq -r .product_id)" = "null" ] \
  || { echo "FAIL: expected product_id still null after rejected patch, got $UNCHANGED"; exit 1; }

echo "== shopping-list: valid transition from name-based to product_id-based succeeds =="
curl -sf -X PATCH "$BASE/api/shopping-list/$INVARIANT_ITEM_ID" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "name": null}' | jq .
SWITCHED=$(curl -sf "$BASE/api/shopping-list" | jq -c --argjson id "$INVARIANT_ITEM_ID" '.[] | select(.id == $id)')
[ "$(echo "$SWITCHED" | jq -r .product_id)" = "$PRODUCT_ID" ] \
  || { echo "FAIL: expected product_id=$PRODUCT_ID after valid transition, got $SWITCHED"; exit 1; }

echo "== shopping-list: clean up invariant-check item =="
curl -sf -o /dev/null -X DELETE "$BASE/api/shopping-list/$INVARIANT_ITEM_ID"

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

echo "== shopping-list: target_stock_level -- product with threshold+target and some stock queues the deficit =="
TARGET_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Target Stock Product", "low_stock_threshold": 3, "target_stock_level": 5}' | jq -r .id)
curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$TARGET_PRODUCT_ID"', "amount": 2}' > /dev/null
RESULT=$(curl -sf -X POST "$BASE/api/shopping-list/add-low-stock")
echo "$RESULT" | jq .
MATCHED_COUNT=$(echo "$RESULT" | jq --argjson pid "$TARGET_PRODUCT_ID" '[.[] | select(.product_id == $pid and .amount == 3)] | length')
[ "$MATCHED_COUNT" = "1" ] \
  || { echo "FAIL: expected target_stock_level product to queue amount=3 (5 target - 2 stock), got $RESULT"; exit 1; }
TARGET_ITEM_ID=$(echo "$RESULT" | jq -r --argjson pid "$TARGET_PRODUCT_ID" '[.[] | select(.product_id == $pid)][0].id')

echo "== shopping-list: target_stock_level -- product without a target keeps queuing exactly 1 (existing behavior) =="
NO_TARGET_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "No Target Stock Product", "low_stock_threshold": 3}' | jq -r .id)
curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$NO_TARGET_PRODUCT_ID"', "amount": 1}' > /dev/null
RESULT=$(curl -sf -X POST "$BASE/api/shopping-list/add-low-stock")
echo "$RESULT" | jq .
MATCHED_COUNT=$(echo "$RESULT" | jq --argjson pid "$NO_TARGET_PRODUCT_ID" '[.[] | select(.product_id == $pid and .amount == 1)] | length')
[ "$MATCHED_COUNT" = "1" ] \
  || { echo "FAIL: expected no-target product to queue amount=1, got $RESULT"; exit 1; }
NO_TARGET_ITEM_ID=$(echo "$RESULT" | jq -r --argjson pid "$NO_TARGET_PRODUCT_ID" '[.[] | select(.product_id == $pid)][0].id')

echo "== shopping-list: clean up the target_stock_level test items =="
curl -sf -o /dev/null -X DELETE "$BASE/api/shopping-list/$TARGET_ITEM_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/shopping-list/$NO_TARGET_ITEM_ID"

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
[ "$(echo "$RESPONSE" | jq -r .entry)" = "null" ] \
  || { echo "FAIL: expected final consume to clear the entry (entry=null), got $RESPONSE"; exit 1; }

echo "== stock: entry should be gone despite float residue =="
COUNT=$(curl -sf "$BASE/api/stock?product_id=$FLOAT_PRODUCT_ID" | jq 'length')
[ "$COUNT" = "0" ] || { echo "FAIL: expected 0 stock entries after consuming to zero, got $COUNT"; exit 1; }

echo "== products: delete it now that it has consumption-log history but no stock (expect success) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/products/$FLOAT_PRODUCT_ID")
[ "$STATUS" = "204" ] || { echo "FAIL: expected 204 deleting product with consumption history, got $STATUS"; exit 1; }

echo "== consumption-log: its rows should be gone along with the product =="
COUNT=$(curl -sf "$BASE/api/consumption-log" | jq --argjson pid "$FLOAT_PRODUCT_ID" '[.[] | select(.product_id == $pid)] | length')
[ "$COUNT" = "0" ] || { echo "FAIL: expected 0 consumption-log rows for deleted product, got $COUNT"; exit 1; }

echo "== products: create a third product for the undo-consume checks (#160) =="
UNDO_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Undo Consume Test"}' | jq -r .id)
echo "created product $UNDO_PRODUCT_ID"

echo "== stock: add a batch to undo-consume-test (amount=4, with location + best_before_date) =="
UNDO_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$UNDO_PRODUCT_ID"', "location_id": '"$LOCATION_ID"', "amount": 4, "best_before_date": "'"$FAR_DATE"'"}' \
  | jq -r .id)
echo "created stock entry $UNDO_ENTRY_ID"

echo "== stock: consume the whole batch (expect entry=null in response, plus a consumption_log_id) =="
CONSUME_RESPONSE=$(curl -sf -X POST "$BASE/api/stock/$UNDO_ENTRY_ID/consume" \
  -H 'content-type: application/json' \
  -d '{"amount": 4}')
echo "$CONSUME_RESPONSE" | jq .
[ "$(echo "$CONSUME_RESPONSE" | jq -r .entry)" = "null" ] \
  || { echo "FAIL: expected entry=null after fully consuming the undo-test batch, got $CONSUME_RESPONSE"; exit 1; }
UNDO_LOG_ID=$(echo "$CONSUME_RESPONSE" | jq -r .consumption_log_id)
[ "$UNDO_LOG_ID" != "null" ] \
  || { echo "FAIL: expected a consumption_log_id in the consume response, got $CONSUME_RESPONSE"; exit 1; }

echo "== stock: confirm the batch is gone and its consumption-log row exists, before undo =="
COUNT=$(curl -sf "$BASE/api/stock?product_id=$UNDO_PRODUCT_ID" | jq 'length')
[ "$COUNT" = "0" ] || { echo "FAIL: expected 0 stock entries for undo-test product before undo, got $COUNT"; exit 1; }
LOG_COUNT=$(curl -sf "$BASE/api/consumption-log" | jq --argjson id "$UNDO_LOG_ID" '[.[] | select(.id == $id)] | length')
[ "$LOG_COUNT" = "1" ] \
  || { echo "FAIL: expected consumption-log row $UNDO_LOG_ID to exist before undo, got $LOG_COUNT"; exit 1; }

echo "== stock/undo: undo the consume (expect the batch restored, log row deleted) (#160) =="
UNDO_RESPONSE=$(curl -sf -X POST "$BASE/api/stock/undo/$UNDO_LOG_ID" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$UNDO_PRODUCT_ID"', "location_id": '"$LOCATION_ID"', "amount": 4, "best_before_date": "'"$FAR_DATE"'"}')
echo "$UNDO_RESPONSE" | jq .
echo "$UNDO_RESPONSE" | jq -e '.amount == 4' > /dev/null \
  || { echo "FAIL: expected undo to recreate a stock entry with amount=4, got $UNDO_RESPONSE"; exit 1; }
[ "$(echo "$UNDO_RESPONSE" | jq -r .product_id)" = "$UNDO_PRODUCT_ID" ] \
  || { echo "FAIL: expected undo to recreate an entry for product $UNDO_PRODUCT_ID, got $UNDO_RESPONSE"; exit 1; }
[ "$(echo "$UNDO_RESPONSE" | jq -r .location_id)" = "$LOCATION_ID" ] \
  || { echo "FAIL: expected undo to preserve location_id $LOCATION_ID, got $UNDO_RESPONSE"; exit 1; }

echo "== stock: the batch is back after undo =="
COUNT=$(curl -sf "$BASE/api/stock?product_id=$UNDO_PRODUCT_ID" | jq 'length')
[ "$COUNT" = "1" ] || { echo "FAIL: expected 1 stock entry for undo-test product after undo, got $COUNT"; exit 1; }

echo "== consumption-log: the undone log row is gone (usage stats no longer overstated) =="
LOG_COUNT=$(curl -sf "$BASE/api/consumption-log" | jq --argjson id "$UNDO_LOG_ID" '[.[] | select(.id == $id)] | length')
[ "$LOG_COUNT" = "0" ] \
  || { echo "FAIL: expected consumption-log row $UNDO_LOG_ID to be gone after undo, got $LOG_COUNT"; exit 1; }

echo "== stock/undo: undoing the same log a second time fails cleanly (expect 404, already gone) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/undo/$UNDO_LOG_ID" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$UNDO_PRODUCT_ID"', "location_id": '"$LOCATION_ID"', "amount": 4, "best_before_date": "'"$FAR_DATE"'"}')
[ "$STATUS" = "404" ] \
  || { echo "FAIL: expected 404 undoing an already-undone consumption log id, got $STATUS"; exit 1; }

echo "== stock/undo: unknown log id (expect 404, nothing created) =="
BEFORE_UNDO_TEST_COUNT=$(curl -sf "$BASE/api/stock?product_id=$UNDO_PRODUCT_ID" | jq 'length')
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/undo/999999" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$UNDO_PRODUCT_ID"', "amount": 1}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 undoing unknown consumption log id, got $STATUS"; exit 1; }
AFTER_UNDO_TEST_COUNT=$(curl -sf "$BASE/api/stock?product_id=$UNDO_PRODUCT_ID" | jq 'length')
[ "$AFTER_UNDO_TEST_COUNT" = "$BEFORE_UNDO_TEST_COUNT" ] \
  || { echo "FAIL: expected undo with unknown log id to change nothing, got $BEFORE_UNDO_TEST_COUNT -> $AFTER_UNDO_TEST_COUNT"; exit 1; }

echo "== products: create a product to test shopping-list FK handling on delete (#157) =="
FK_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "FK Test Product", "quantity_unit": "kg"}' | jq -r .id)
echo "created product $FK_PRODUCT_ID"

echo "== shopping-list: link it to an open item (no name/unit override) =="
FK_OPEN_ITEM_ID=$(curl -sf -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$FK_PRODUCT_ID"'}' | jq -r .id)
echo "created open shopping list item $FK_OPEN_ITEM_ID"

echo "== shopping-list: link it to a second item, then mark that one done =="
FK_DONE_ITEM_ID=$(curl -sf -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$FK_PRODUCT_ID"'}' | jq -r .id)
curl -sf -X PATCH "$BASE/api/shopping-list/$FK_DONE_ITEM_ID" \
  -H 'content-type: application/json' -d '{"done": true}' > /dev/null
echo "created done shopping list item $FK_DONE_ITEM_ID"

echo "== products: delete it despite still being referenced by shopping-list items (expect 204, not a raw 500 from the FK constraint) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/products/$FK_PRODUCT_ID")
[ "$STATUS" = "204" ] || { echo "FAIL: expected 204 deleting product referenced by shopping-list items, got $STATUS"; exit 1; }

echo "== shopping-list: both items (open and done) survive with product_id nulled and name/unit snapshotted from the deleted product =="
FK_ITEMS=$(curl -sf "$BASE/api/shopping-list" | jq -c '[.[] | select(.id == '"$FK_OPEN_ITEM_ID"' or .id == '"$FK_DONE_ITEM_ID"')]')
echo "$FK_ITEMS"
[ "$(echo "$FK_ITEMS" | jq 'length')" = "2" ] \
  || { echo "FAIL: expected both shopping-list items to survive product deletion, got $FK_ITEMS"; exit 1; }
[ "$(echo "$FK_ITEMS" | jq '[.[] | select(.product_id == null)] | length')" = "2" ] \
  || { echo "FAIL: expected product_id to be nulled on both surviving items, got $FK_ITEMS"; exit 1; }
[ "$(echo "$FK_ITEMS" | jq '[.[] | select(.name == "FK Test Product")] | length')" = "2" ] \
  || { echo "FAIL: expected name snapshotted to 'FK Test Product' on both surviving items, got $FK_ITEMS"; exit 1; }
[ "$(echo "$FK_ITEMS" | jq '[.[] | select(.unit == "kg")] | length')" = "2" ] \
  || { echo "FAIL: expected unit snapshotted to 'kg' on both surviving items, got $FK_ITEMS"; exit 1; }

echo "== shopping-list: clean up the FK test items =="
curl -sf -o /dev/null -X DELETE "$BASE/api/shopping-list/$FK_OPEN_ITEM_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/shopping-list/$FK_DONE_ITEM_ID"

echo "== products: create a third product for the over-consume guard (#156) =="
OVERCONSUME_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Overconsume Guard Test"}' | jq -r .id)
echo "created product $OVERCONSUME_PRODUCT_ID"

echo "== stock: add a 1.0 unit entry =="
OVERCONSUME_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$OVERCONSUME_PRODUCT_ID"', "amount": 1.0}' | jq -r .id)
echo "created stock entry $OVERCONSUME_ENTRY_ID"

echo "== consumption-log: baseline row count for this product (expect 0) =="
LOG_COUNT_BEFORE=$(curl -sf "$BASE/api/consumption-log" \
  | jq --argjson pid "$OVERCONSUME_PRODUCT_ID" '[.[] | select(.product_id == $pid)] | length')
[ "$LOG_COUNT_BEFORE" = "0" ] || { echo "FAIL: expected 0 consumption-log rows before any consume, got $LOG_COUNT_BEFORE"; exit 1; }

echo "== stock: attempt to consume 2 from a 1.0 entry (expect 4xx, no mutation) =="
STATUS=$(curl -s -o /tmp/overconsume_response.json -w '%{http_code}' -X POST "$BASE/api/stock/$OVERCONSUME_ENTRY_ID/consume" \
  -H 'content-type: application/json' \
  -d '{"amount": 2}')
cat /tmp/overconsume_response.json
echo "status=$STATUS"
case "$STATUS" in
  4??) : ;;
  *) echo "FAIL: expected a 4xx status consuming more than available, got $STATUS"; exit 1 ;;
esac

echo "== stock: entry must still exist with amount 1 (rejection left it untouched) =="
ENTRY_AMOUNT=$(curl -sf "$BASE/api/stock?product_id=$OVERCONSUME_PRODUCT_ID" | jq -r '.[0].amount')
[ "$ENTRY_AMOUNT" = "1.0" ] || { echo "FAIL: expected entry amount to stay 1.0 after rejected over-consume, got $ENTRY_AMOUNT"; exit 1; }

echo "== consumption-log: no row should have been written by the rejected over-consume =="
LOG_COUNT_AFTER=$(curl -sf "$BASE/api/consumption-log" \
  | jq --argjson pid "$OVERCONSUME_PRODUCT_ID" '[.[] | select(.product_id == $pid)] | length')
[ "$LOG_COUNT_AFTER" = "0" ] || { echo "FAIL: expected 0 consumption-log rows after rejected over-consume, got $LOG_COUNT_AFTER"; exit 1; }

echo "== stock: partial consume (0.4 of 1.0) still works =="
curl -sf -X POST "$BASE/api/stock/$OVERCONSUME_ENTRY_ID/consume" \
  -H 'content-type: application/json' \
  -d '{"amount": 0.4}' | jq .
PARTIAL_AMOUNT=$(curl -sf "$BASE/api/stock?product_id=$OVERCONSUME_PRODUCT_ID" | jq -r '.[0].amount')
[ "$PARTIAL_AMOUNT" = "0.6" ] || { echo "FAIL: expected 0.6 remaining after partial consume, got $PARTIAL_AMOUNT"; exit 1; }

echo "== stock: exact consume of the remaining 0.6 clears the entry =="
EXACT_RESPONSE=$(curl -sf -X POST "$BASE/api/stock/$OVERCONSUME_ENTRY_ID/consume" \
  -H 'content-type: application/json' \
  -d '{"amount": 0.6}')
[ "$(echo "$EXACT_RESPONSE" | jq -r .entry)" = "null" ] \
  || { echo "FAIL: expected exact consume-to-zero to clear the entry (entry=null), got $EXACT_RESPONSE"; exit 1; }
FINAL_COUNT=$(curl -sf "$BASE/api/stock?product_id=$OVERCONSUME_PRODUCT_ID" | jq 'length')
[ "$FINAL_COUNT" = "0" ] || { echo "FAIL: expected 0 stock entries after exact consume, got $FINAL_COUNT"; exit 1; }

echo "== stock: concurrent over-consume can't together log more than was ever there (#156) =="
RACE_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$OVERCONSUME_PRODUCT_ID"', "amount": 1.0}' | jq -r .id)
echo "created race entry $RACE_ENTRY_ID"
curl -s -o /tmp/race_1.json -w '%{http_code}' -X POST "$BASE/api/stock/$RACE_ENTRY_ID/consume" \
  -H 'content-type: application/json' -d '{"amount": 0.6}' > /tmp/race_1_status.txt &
curl -s -o /tmp/race_2.json -w '%{http_code}' -X POST "$BASE/api/stock/$RACE_ENTRY_ID/consume" \
  -H 'content-type: application/json' -d '{"amount": 0.6}' > /tmp/race_2_status.txt &
wait
echo "race #1 -> $(cat /tmp/race_1_status.txt): $(cat /tmp/race_1.json)"
echo "race #2 -> $(cat /tmp/race_2_status.txt): $(cat /tmp/race_2.json)"
RACE_STATUSES="$(cat /tmp/race_1_status.txt) $(cat /tmp/race_2_status.txt)"
case "$RACE_STATUSES" in
  "200 200") echo "FAIL: both concurrent 0.6-of-1.0 consumes succeeded -- over-consumed"; exit 1 ;;
esac
RACE_LOG_TOTAL=$(curl -sf "$BASE/api/consumption-log" \
  | jq --argjson pid "$OVERCONSUME_PRODUCT_ID" '[.[] | select(.product_id == $pid)] | map(.amount) | add')
# 0.4 (partial) + 0.6 (exact-to-zero) from the checks above, plus exactly one
# 0.6 from whichever of the two concurrent requests won the race -- never
# both, which would double-log to 2.2.
[ "$RACE_LOG_TOTAL" = "1.6" ] \
  || { echo "FAIL: expected total logged consumption for this product to be 1.6 (0.4 + 0.6 from above, plus 0.6 from the race winner), got $RACE_LOG_TOTAL"; exit 1; }

echo "== consumption-log/export.csv: row count matches JSON list, header + Milk's 'used' entry present =="
LOG_COUNT=$(curl -sf "$BASE/api/consumption-log" | jq 'length')
EXPORTED_LOG_CSV=$(curl -sf "$BASE/api/consumption-log/export.csv")
LOG_CSV_LINES=$(echo "$EXPORTED_LOG_CSV" | wc -l)
[ "$LOG_CSV_LINES" = "$((LOG_COUNT + 1))" ] \
  || { echo "FAIL: expected $((LOG_COUNT + 1)) CSV lines (header + $LOG_COUNT rows), got $LOG_CSV_LINES"; exit 1; }
echo "$EXPORTED_LOG_CSV" | tr -d '\r' | head -1 | grep -qx 'created_at,product_name,amount,quantity_unit,reason' \
  || { echo "FAIL: unexpected export.csv header: $(echo "$EXPORTED_LOG_CSV" | head -1)"; exit 1; }
echo "$EXPORTED_LOG_CSV" | tr -d '\r' | grep -q ',Milk,1.0,pcs,used$' \
  || { echo "FAIL: expected a Milk/1.0/pcs/used row in consumption-log export.csv, got: $EXPORTED_LOG_CSV"; exit 1; }

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

echo "== stock/bulk: create a fresh product + location and three stock entries for bulk ops =="
BULK_LOCATION_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' \
  -d '{"name": "Bulk Test Pantry"}' | jq -r .id)
BULK_DEST_LOCATION_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' \
  -d '{"name": "Bulk Test Freezer"}' | jq -r .id)
BULK_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Bulk Test Product", "quantity_unit": "g"}' | jq -r .id)
BULK_ID_1=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$BULK_PRODUCT_ID"', "location_id": '"$BULK_LOCATION_ID"', "amount": 1}' | jq -r .id)
BULK_ID_2=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$BULK_PRODUCT_ID"', "location_id": '"$BULK_LOCATION_ID"', "amount": 2}' | jq -r .id)
BULK_ID_3=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$BULK_PRODUCT_ID"', "location_id": '"$BULK_LOCATION_ID"', "amount": 3}' | jq -r .id)
echo "created bulk stock entries $BULK_ID_1 $BULK_ID_2 $BULK_ID_3"

echo "== stock/bulk/move: atomicity check -- one bogus id among real ones changes nothing =="
STATUS=$(curl -s -o /tmp/bulk_move_fail_body.json -w '%{http_code}' -X POST "$BASE/api/stock/bulk/move" \
  -H 'content-type: application/json' \
  -d '{"entry_ids": ['"$BULK_ID_1"', '"$BULK_ID_2"', 999999], "location_id": '"$BULK_DEST_LOCATION_ID"'}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 for bulk move with a bogus id, got $STATUS: $(cat /tmp/bulk_move_fail_body.json)"; exit 1; }
UNCHANGED_LOCATION=$(curl -sf "$BASE/api/stock?product_id=$BULK_PRODUCT_ID" | jq -r --argjson id "$BULK_ID_1" '.[] | select(.id == $id) | .location_id')
[ "$UNCHANGED_LOCATION" = "$BULK_LOCATION_ID" ] \
  || { echo "FAIL: expected entry $BULK_ID_1 to remain in original location after failed bulk move, got $UNCHANGED_LOCATION"; exit 1; }

echo "== stock/bulk/move: unknown location_id (expect 404, nothing changed) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/bulk/move" \
  -H 'content-type: application/json' \
  -d '{"entry_ids": ['"$BULK_ID_1"'], "location_id": 999999}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 for bulk move to unknown location, got $STATUS"; exit 1; }

echo "== stock/bulk/move: move entries 1 and 2 to the freezer =="
MOVE_RESULT=$(curl -sf -X POST "$BASE/api/stock/bulk/move" \
  -H 'content-type: application/json' \
  -d '{"entry_ids": ['"$BULK_ID_1"', '"$BULK_ID_2"'], "location_id": '"$BULK_DEST_LOCATION_ID"'}')
echo "$MOVE_RESULT" | jq .
[ "$(echo "$MOVE_RESULT" | jq -r .moved)" = "2" ] || { echo "FAIL: expected moved=2, got $MOVE_RESULT"; exit 1; }
[ "$(echo "$MOVE_RESULT" | jq '[.entries[] | select(.location_id == '"$BULK_DEST_LOCATION_ID"')] | length')" = "2" ] \
  || { echo "FAIL: expected both returned entries to carry the new location_id, got $MOVE_RESULT"; exit 1; }

echo "== stock/bulk/consume: fully consume entries 1 and 2 with reason=spoiled =="
CONSUME_RESULT=$(curl -sf -X POST "$BASE/api/stock/bulk/consume" \
  -H 'content-type: application/json' \
  -d '{"entry_ids": ['"$BULK_ID_1"', '"$BULK_ID_2"'], "reason": "spoiled"}')
echo "$CONSUME_RESULT" | jq .
[ "$(echo "$CONSUME_RESULT" | jq -r .consumed)" = "2" ] || { echo "FAIL: expected consumed=2, got $CONSUME_RESULT"; exit 1; }
REMAINING=$(curl -sf "$BASE/api/stock?product_id=$BULK_PRODUCT_ID" | jq 'length')
[ "$REMAINING" = "1" ] || { echo "FAIL: expected 1 remaining bulk stock entry after bulk consume, got $REMAINING"; exit 1; }
SPOILED_LOG_COUNT=$(curl -sf "$BASE/api/consumption-log?reason=spoiled" \
  | jq --argjson pid "$BULK_PRODUCT_ID" '[.[] | select(.product_id == $pid)] | length')
[ "$SPOILED_LOG_COUNT" = "2" ] || { echo "FAIL: expected 2 spoiled consumption-log rows for bulk product, got $SPOILED_LOG_COUNT"; exit 1; }
LOG_UNIT=$(curl -sf "$BASE/api/consumption-log?reason=spoiled" \
  | jq -r --argjson pid "$BULK_PRODUCT_ID" '[.[] | select(.product_id == $pid)][0].quantity_unit')
[ "$LOG_UNIT" = "g" ] || { echo "FAIL: expected bulk-consume log quantity_unit=g (snapshotted from product), got $LOG_UNIT"; exit 1; }

echo "== stock/bulk/delete: atomicity check -- one bogus id changes nothing =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/bulk/delete" \
  -H 'content-type: application/json' \
  -d '{"entry_ids": ['"$BULK_ID_3"', 999999]}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 for bulk delete with a bogus id, got $STATUS"; exit 1; }
REMAINING=$(curl -sf "$BASE/api/stock?product_id=$BULK_PRODUCT_ID" | jq 'length')
[ "$REMAINING" = "1" ] || { echo "FAIL: expected bulk delete with a bogus id to leave entry $BULK_ID_3 untouched, got $REMAINING remaining"; exit 1; }

echo "== stock/bulk/delete: delete entry 3 (expect it logged as spoiled, matching single delete) =="
DELETE_RESULT=$(curl -sf -X POST "$BASE/api/stock/bulk/delete" \
  -H 'content-type: application/json' \
  -d '{"entry_ids": ['"$BULK_ID_3"']}')
echo "$DELETE_RESULT" | jq .
[ "$(echo "$DELETE_RESULT" | jq -r .deleted)" = "1" ] || { echo "FAIL: expected deleted=1, got $DELETE_RESULT"; exit 1; }
REMAINING=$(curl -sf "$BASE/api/stock?product_id=$BULK_PRODUCT_ID" | jq 'length')
[ "$REMAINING" = "0" ] || { echo "FAIL: expected 0 remaining bulk stock entries after bulk delete, got $REMAINING"; exit 1; }
SPOILED_LOG_COUNT=$(curl -sf "$BASE/api/consumption-log?reason=spoiled" \
  | jq --argjson pid "$BULK_PRODUCT_ID" '[.[] | select(.product_id == $pid)] | length')
[ "$SPOILED_LOG_COUNT" = "3" ] || { echo "FAIL: expected 3 spoiled consumption-log rows for bulk product (2 consumed + 1 deleted), got $SPOILED_LOG_COUNT"; exit 1; }

echo "== products: pagination (limit/offset) =="
for name in "PagTest A" "PagTest B" "PagTest C"; do
  curl -sf -X POST "$BASE/api/products" \
    -H 'content-type: application/json' \
    -d '{"name": "'"$name"'"}' > /dev/null
done
ALL_COUNT=$(curl -sf "$BASE/api/products?search=PagTest" | jq 'length')
[ "$ALL_COUNT" = "3" ] || { echo "FAIL: expected 3 PagTest products with no limit/offset, got $ALL_COUNT"; exit 1; }
LIMIT_COUNT=$(curl -sf "$BASE/api/products?search=PagTest&limit=2" | jq 'length')
[ "$LIMIT_COUNT" = "2" ] || { echo "FAIL: expected limit=2 to return 2 products, got $LIMIT_COUNT"; exit 1; }
OFFSET_COUNT=$(curl -sf "$BASE/api/products?search=PagTest&offset=2" | jq 'length')
[ "$OFFSET_COUNT" = "1" ] || { echo "FAIL: expected offset=2 to return the remaining 1 product, got $OFFSET_COUNT"; exit 1; }

echo "OK"
