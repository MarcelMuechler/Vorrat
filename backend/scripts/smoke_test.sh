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

echo "== locations: create with whitespace-only name (expect 422) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' \
  -d '{"name": "   "}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 creating location with whitespace-only name, got $STATUS"; exit 1; }

echo "== locations: create case-variant duplicate (expect 409) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' \
  -d '{"name": "fridge"}')
[ "$STATUS" = "409" ] || { echo "FAIL: expected 409 creating location with case-variant duplicate name, got $STATUS"; exit 1; }

echo "== locations: create a second location for rename test =="
LOCATION_ID_2=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' \
  -d '{"name": "Cellar"}' | jq -r .id)
echo "created location $LOCATION_ID_2"

echo "== locations: rename location to case-variant of another (expect 409) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/locations/$LOCATION_ID_2" \
  -H 'content-type: application/json' \
  -d '{"name": "FRIDGE"}')
[ "$STATUS" = "409" ] || { echo "FAIL: expected 409 renaming location to case-variant duplicate, got $STATUS"; exit 1; }

echo "== locations: rename location to itself (case-variant, should succeed) =="
curl -sf -X PATCH "$BASE/api/locations/$LOCATION_ID" \
  -H 'content-type: application/json' \
  -d '{"name": "FRIDGE"}' | jq .

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

echo "== products/image: upload a real image (#210) sets image_url under /uploads =="
# Smallest possible valid PNG (1x1 red pixel) -- decoded from a literal
# base64 blob so this test has no dependency on an external fixture file.
IMAGE_FILE="$(mktemp --suffix=.png)"
trap 'rm -f "$IMAGE_FILE"' EXIT
base64 -d > "$IMAGE_FILE" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGP4z8AARwgWXg4ArpMP8aaUSCMAAAAASUVORK5CYII=
PNG
UPLOADED_IMAGE_URL=$(curl -sf -X POST "$BASE/api/products/$PRODUCT_ID/image" \
  -F "file=@$IMAGE_FILE;type=image/png" | jq -r .image_url)
case "$UPLOADED_IMAGE_URL" in
  /uploads/*) : ;;
  *) echo "FAIL: expected image_url under /uploads/, got $UPLOADED_IMAGE_URL"; exit 1 ;;
esac

echo "== products/image: the uploaded file is actually served back (expect 200) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE$UPLOADED_IMAGE_URL")
[ "$STATUS" = "200" ] || { echo "FAIL: expected 200 fetching uploaded image, got $STATUS"; exit 1; }

echo "== products/image: re-uploading replaces image_url and removes the old file (expect old path 404) =="
SECOND_UPLOADED_IMAGE_URL=$(curl -sf -X POST "$BASE/api/products/$PRODUCT_ID/image" \
  -F "file=@$IMAGE_FILE;type=image/png" | jq -r .image_url)
[ "$SECOND_UPLOADED_IMAGE_URL" != "$UPLOADED_IMAGE_URL" ] \
  || { echo "FAIL: expected a new filename on re-upload, got the same $UPLOADED_IMAGE_URL"; exit 1; }
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE$UPLOADED_IMAGE_URL")
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 for the replaced upload's old path, got $STATUS"; exit 1; }
rm -f "$IMAGE_FILE"
trap - EXIT

echo "== products/image: rejects a non-image content type (expect 415) =="
TEXT_FILE="$(mktemp)"
trap 'rm -f "$TEXT_FILE"' EXIT
printf 'not an image' > "$TEXT_FILE"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products/$PRODUCT_ID/image" \
  -F "file=@$TEXT_FILE;type=text/plain")
[ "$STATUS" = "415" ] || { echo "FAIL: expected 415 uploading a non-image content type, got $STATUS"; exit 1; }
rm -f "$TEXT_FILE"
trap - EXIT

echo "== products/image: rejects an empty file (expect 422) =="
EMPTY_FILE="$(mktemp)"
trap 'rm -f "$EMPTY_FILE"' EXIT
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products/$PRODUCT_ID/image" \
  -F "file=@$EMPTY_FILE;type=image/png")
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 uploading an empty file, got $STATUS"; exit 1; }
rm -f "$EMPTY_FILE"
trap - EXIT

echo "== products/image: upload for a nonexistent product (expect 404 not 500) =="
IMAGE_FILE="$(mktemp --suffix=.png)"
trap 'rm -f "$IMAGE_FILE"' EXIT
base64 -d > "$IMAGE_FILE" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGP4z8AARwgWXg4ArpMP8aaUSCMAAAAASUVORK5CYII=
PNG
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products/999999/image" \
  -F "file=@$IMAGE_FILE;type=image/png")
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 uploading an image for a nonexistent product, got $STATUS"; exit 1; }
rm -f "$IMAGE_FILE"
trap - EXIT

echo "== products: create with an external image_url caches it locally instead of hotlinking (#262) =="
# No real network dependency: point at our own already-uploaded image (served
# absolute via $BASE) as a stand-in "external" host -- exercises the exact
# same download+cache code path a real Open Food Facts image_url would. Must
# be SECOND_UPLOADED_IMAGE_URL, not the first -- that one was already deleted
# by the re-upload test above.
EXTERNAL_IMAGE_URL="$BASE$SECOND_UPLOADED_IMAGE_URL"
CACHED_PRODUCT=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Cheese", "image_url": "'"$EXTERNAL_IMAGE_URL"'"}')
CACHED_IMAGE_URL=$(echo "$CACHED_PRODUCT" | jq -r .image_url)
case "$CACHED_IMAGE_URL" in
  /uploads/*) : ;;
  *) echo "FAIL: expected external image_url to be cached under /uploads/, got $CACHED_IMAGE_URL"; exit 1 ;;
esac
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE$CACHED_IMAGE_URL")
[ "$STATUS" = "200" ] || { echo "FAIL: expected 200 fetching the cached image, got $STATUS"; exit 1; }
# Cleanup: keep the product count downstream (stats/HA sensors) assertions
# below unaffected by these scratch products.
curl -sf -X DELETE "$BASE/api/products/$(echo "$CACHED_PRODUCT" | jq -r .id)" -o /dev/null

echo "== products: create with an unreachable image_url drops it rather than failing the save (expect 201, image_url null) =="
BROKEN_PRODUCT=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Broken Image Product", "image_url": "http://127.0.0.1:1/nope.jpg"}')
DROPPED_IMAGE_URL=$(echo "$BROKEN_PRODUCT" | jq -r .image_url)
[ "$DROPPED_IMAGE_URL" = "null" ] || { echo "FAIL: expected image_url to be dropped (null), got $DROPPED_IMAGE_URL"; exit 1; }
curl -sf -X DELETE "$BASE/api/products/$(echo "$BROKEN_PRODUCT" | jq -r .id)" -o /dev/null

echo "== products: patch with an external image_url also caches it locally (#262) =="
PATCHED_IMAGE_URL=$(curl -sf -X PATCH "$BASE/api/products/$PRODUCT_ID" \
  -H 'content-type: application/json' \
  -d '{"image_url": "'"$EXTERNAL_IMAGE_URL"'"}' | jq -r .image_url)
case "$PATCHED_IMAGE_URL" in
  /uploads/*) : ;;
  *) echo "FAIL: expected patched external image_url to be cached under /uploads/, got $PATCHED_IMAGE_URL"; exit 1 ;;
esac

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

echo "== products/barcodes: add an alternate barcode (#208) =="
curl -sf -X POST "$BASE/api/products/$PRODUCT_ID/barcodes" \
  -H 'content-type: application/json' \
  -d '{"code": "9998887776665"}' | jq .
EXTRA_BARCODES=$(curl -sf "$BASE/api/products/$PRODUCT_ID" | jq -r '.extra_barcodes | join(",")')
[ "$EXTRA_BARCODES" = "9998887776665" ] || { echo "FAIL: expected extra_barcodes to include 9998887776665, got $EXTRA_BARCODES"; exit 1; }

echo "== barcode: lookup by the alternate code resolves to the same product, not a duplicate (#208) =="
LOOKUP=$(curl -sf "$BASE/api/barcode/9998887776665")
echo "$LOOKUP" | jq .
[ "$(echo "$LOOKUP" | jq -r .source)" = "local" ] || { echo "FAIL: expected source local for alternate barcode lookup"; exit 1; }
[ "$(echo "$LOOKUP" | jq -r .product.id)" = "$PRODUCT_ID" ] || { echo "FAIL: expected alternate barcode lookup to resolve to product $PRODUCT_ID"; exit 1; }

echo "== products/barcodes: adding a code that duplicates another product's barcode (expect 409 not 500) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products/$PRODUCT_ID/barcodes" \
  -H 'content-type: application/json' -d '{"code": "1234567890123"}')
[ "$STATUS" = "409" ] || { echo "FAIL: expected 409 adding an extra barcode that duplicates the primary barcode, got $STATUS"; exit 1; }

echo "== products/barcodes: removing an unknown code (expect 404 not 500) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/api/products/$PRODUCT_ID/barcodes/0000000000000")
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 removing an unknown extra barcode, got $STATUS"; exit 1; }

echo "== products/barcodes: remove the alternate barcode =="
curl -sf -X DELETE "$BASE/api/products/$PRODUCT_ID/barcodes/9998887776665" | jq .
EXTRA_BARCODES=$(curl -sf "$BASE/api/products/$PRODUCT_ID" | jq -r '.extra_barcodes | length')
[ "$EXTRA_BARCODES" = "0" ] || { echo "FAIL: expected extra_barcodes to be empty after removal, got $EXTRA_BARCODES"; exit 1; }

echo "== barcode: the removed alternate code no longer resolves locally (expect source none, 404) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/barcode/9998887776665")
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 looking up a removed alternate barcode, got $STATUS"; exit 1; }

echo "== barcode uniqueness (#223): primary and alternate codes share one global namespace =="
UNIQ_A_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "Uniq A", "barcode": "111"}' | jq -r .id)
UNIQ_B_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "Uniq B", "barcode": "222"}' | jq -r .id)

echo "== #223 direction 1: adding B's primary (222) as an alternate of A must 409, not shadow B =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products/$UNIQ_A_ID/barcodes" \
  -H 'content-type: application/json' -d '{"code": "222"}')
[ "$STATUS" = "409" ] || { echo "FAIL: expected 409 adding another product's primary barcode as an alternate, got $STATUS"; exit 1; }

echo "== #223: lookup of 222 still resolves to its real owner B, not A =="
LOOKUP_OWNER=$(curl -sf "$BASE/api/barcode/222" | jq -r .product.id)
[ "$LOOKUP_OWNER" = "$UNIQ_B_ID" ] \
  || { echo "FAIL: expected 222 to resolve to B ($UNIQ_B_ID), got $LOOKUP_OWNER"; exit 1; }

echo "== #223 direction 2: PATCH A's primary to a code that's already an alternate of B must 409 =="
curl -sf -o /dev/null -X POST "$BASE/api/products/$UNIQ_B_ID/barcodes" \
  -H 'content-type: application/json' -d '{"code": "333"}'
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/products/$UNIQ_A_ID" \
  -H 'content-type: application/json' -d '{"barcode": "333"}')
[ "$STATUS" = "409" ] \
  || { echo "FAIL: expected 409 patching a primary barcode to another product's alternate code, got $STATUS"; exit 1; }

echo "== #223: A's primary is unchanged (still 111) after the rejected patch =="
A_BARCODE=$(curl -sf "$BASE/api/products/$UNIQ_A_ID" | jq -r .barcode)
[ "$A_BARCODE" = "111" ] || { echo "FAIL: expected A's barcode to stay 111 after rejected patch, got $A_BARCODE"; exit 1; }

echo "== #223: re-saving A's own unchanged primary (111) is still allowed (self-collision excluded) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/products/$UNIQ_A_ID" \
  -H 'content-type: application/json' -d '{"barcode": "111"}')
[ "$STATUS" = "200" ] || { echo "FAIL: expected 200 re-saving a product's own unchanged barcode, got $STATUS"; exit 1; }

echo "== #223: creating a new product whose primary equals an existing alternate (333) must 409 =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "Uniq C", "barcode": "333"}')
[ "$STATUS" = "409" ] \
  || { echo "FAIL: expected 409 creating a product whose primary duplicates an existing alternate code, got $STATUS"; exit 1; }

echo "== #223: lookup of 333 resolves to its owner B (alternate never shadowed by a colliding primary) =="
LOOKUP_OWNER=$(curl -sf "$BASE/api/barcode/333" | jq -r .product.id)
[ "$LOOKUP_OWNER" = "$UNIQ_B_ID" ] \
  || { echo "FAIL: expected 333 to resolve to B ($UNIQ_B_ID), got $LOOKUP_OWNER"; exit 1; }

echo "== #223: clean up uniqueness-test products =="
curl -sf -o /dev/null -X DELETE "$BASE/api/products/$UNIQ_A_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/products/$UNIQ_B_ID"

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
for key in total_products total_stock_entries expired expiring_soon low_stock_products earliest_expiry total_value; do
  echo "$STATS" | jq -e "has(\"$key\")" > /dev/null \
    || { echo "FAIL: /api/stats response missing key $key"; exit 1; }
done
[ "$(echo "$STATS" | jq -r .total_products)" = "1" ] || { echo "FAIL: expected total_products=1"; exit 1; }
[ "$(echo "$STATS" | jq -r .total_stock_entries)" = "2" ] || { echo "FAIL: expected total_stock_entries=2"; exit 1; }
[ "$(echo "$STATS" | jq -r .expired)" = "0" ] || { echo "FAIL: expected expired=0"; exit 1; }
[ "$(echo "$STATS" | jq -r .expiring_soon)" = "1" ] || { echo "FAIL: expected expiring_soon=1"; exit 1; }
[ "$(echo "$STATS" | jq -r .earliest_expiry)" = "$SOON_DATE" ] || { echo "FAIL: expected earliest_expiry=$SOON_DATE"; exit 1; }

echo "== stock: price tracking (per-unit price) round-trips via the API =="
PRICE_LOCATION_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' -d '{"name": "Pantry"}' | jq -r .id)
PRICE_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "Olive Oil"}' | jq -r .id)

TOTAL_VALUE_BEFORE=$(curl -sf "$BASE/api/stats" | jq -r .total_value)

PRICE_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRICE_PRODUCT_ID"', "location_id": '"$PRICE_LOCATION_ID"', "amount": 2, "price": 3.5}' \
  | jq -r .id)
echo "created priced stock entry $PRICE_ENTRY_ID"

RETURNED_PRICE=$(curl -sf "$BASE/api/stock?product_id=$PRICE_PRODUCT_ID" | jq -r '.[0].price')
[ "$RETURNED_PRICE" = "3.5" ] || { echo "FAIL: expected price=3.5 to round-trip, got $RETURNED_PRICE"; exit 1; }

echo "== stock: add a second, unpriced entry for the same product (must be skipped by total_value, not treated as free) =="
NOPRICE_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRICE_PRODUCT_ID"', "location_id": '"$PRICE_LOCATION_ID"', "amount": 100}' \
  | jq -r .id)

echo "== stats: total_value reflects only the priced entry (amount 2 * price 3.5 = 7) =="
TOTAL_VALUE_AFTER=$(curl -sf "$BASE/api/stats" | jq -r .total_value)
DELTA=$(python3 -c "print($TOTAL_VALUE_AFTER - $TOTAL_VALUE_BEFORE)")
[ "$DELTA" = "7.0" ] \
  || { echo "FAIL: expected total_value to increase by 7.0, got delta=$DELTA (before=$TOTAL_VALUE_BEFORE after=$TOTAL_VALUE_AFTER)"; exit 1; }

echo "== consumption-log: consuming a priced entry snapshots its per-unit price onto the log row =="
curl -sf -X POST "$BASE/api/stock/$PRICE_ENTRY_ID/consume" \
  -H 'content-type: application/json' -d '{"amount": 1, "reason": "spoiled"}' | jq .
LOG_PRICE=$(curl -sf "$BASE/api/consumption-log?reason=spoiled" \
  | jq -r --argjson pid "$PRICE_PRODUCT_ID" '[.[] | select(.product_id == $pid)][0].price')
[ "$LOG_PRICE" = "3.5" ] \
  || { echo "FAIL: expected consumption-log price=3.5 snapshotted from stock entry, got $LOG_PRICE"; exit 1; }

curl -sf -o /dev/null -X DELETE "$BASE/api/stock/$PRICE_ENTRY_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/stock/$NOPRICE_ENTRY_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/products/$PRICE_PRODUCT_ID"

echo "== stock: default_open_shelf_life_days=0 must count as a real value, not unset (#184) =="
ZERO_SHELF_LOCATION_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' -d '{"name": "Counter"}' | jq -r .id)
ZERO_SHELF_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Cut Fruit", "default_open_shelf_life_days": 0, "default_location_id": '"$ZERO_SHELF_LOCATION_ID"'}' \
  | jq -r .id)
ZERO_SHELF_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$ZERO_SHELF_PRODUCT_ID"', "location_id": '"$ZERO_SHELF_LOCATION_ID"', "amount": 1, "best_before_date": "'"$FAR_DATE"'"}' \
  | jq -r .id)
curl -sf -X PATCH "$BASE/api/stock/$ZERO_SHELF_ENTRY_ID" \
  -H 'content-type: application/json' -d '{"opened_at": "'"$PAST_DATE"'"}' > /dev/null
ZERO_SHELF_STATUS=$(curl -sf "$BASE/api/stock?product_id=$ZERO_SHELF_PRODUCT_ID" | jq -r '.[0].status')
[ "$ZERO_SHELF_STATUS" = "expired" ] \
  || { echo "FAIL: expected status=expired for opened item with default_open_shelf_life_days=0, got $ZERO_SHELF_STATUS"; exit 1; }
curl -sf -o /dev/null -X DELETE "$BASE/api/stock/$ZERO_SHELF_ENTRY_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/products/$ZERO_SHELF_PRODUCT_ID"

echo "== stock: opened, no-BBD entry exposes effective_expiry_date and is caught by expiring_within_days (#225) =="
NOBBD_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Opened Yogurt", "default_open_shelf_life_days": 0}' \
  | jq -r .id)
NOBBD_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$NOBBD_PRODUCT_ID"', "location_id": '"$LOCATION_ID"', "amount": 1}' \
  | jq -r .id)
curl -sf -X PATCH "$BASE/api/stock/$NOBBD_ENTRY_ID" \
  -H 'content-type: application/json' -d '{"opened_at": "'"$TODAY"'"}' > /dev/null

NOBBD_ITEM=$(curl -sf "$BASE/api/stock?product_id=$NOBBD_PRODUCT_ID")
echo "$NOBBD_ITEM" | jq .
[ "$(echo "$NOBBD_ITEM" | jq -r '.[0].best_before_date')" = "null" ] \
  || { echo "FAIL: expected best_before_date to stay null for the opened no-BBD entry"; exit 1; }
[ "$(echo "$NOBBD_ITEM" | jq -r '.[0].effective_expiry_date')" = "$TODAY" ] \
  || { echo "FAIL: expected effective_expiry_date=$TODAY for the opened no-BBD entry, got $(echo "$NOBBD_ITEM" | jq -r '.[0].effective_expiry_date')"; exit 1; }
[ "$(echo "$NOBBD_ITEM" | jq -r '.[0].status')" = "expiring_soon" ] \
  || { echo "FAIL: expected status=expiring_soon for the opened no-BBD entry, got $(echo "$NOBBD_ITEM" | jq -r '.[0].status')"; exit 1; }

NOBBD_IN_FILTER=$(curl -sf "$BASE/api/stock?expiring_within_days=0" \
  | jq --argjson eid "$NOBBD_ENTRY_ID" '[.[] | select(.id == $eid)] | length')
[ "$NOBBD_IN_FILTER" = "1" ] \
  || { echo "FAIL: expected expiring_within_days=0 to include the opened no-BBD entry (it has no best_before_date to filter on), got count=$NOBBD_IN_FILTER"; exit 1; }

echo "== stock: open-shelf-life expiry earlier than best_before_date wins, best_before_date itself is untouched (#225) =="
EARLY_OPEN_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Opened Jam", "default_open_shelf_life_days": 1}' \
  | jq -r .id)
EARLY_OPEN_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$EARLY_OPEN_PRODUCT_ID"', "location_id": '"$LOCATION_ID"', "amount": 1, "best_before_date": "'"$FAR_DATE"'"}' \
  | jq -r .id)
curl -sf -X PATCH "$BASE/api/stock/$EARLY_OPEN_ENTRY_ID" \
  -H 'content-type: application/json' -d '{"opened_at": "'"$PAST_DATE"'"}' > /dev/null

EARLY_OPEN_ITEM=$(curl -sf "$BASE/api/stock?product_id=$EARLY_OPEN_PRODUCT_ID")
echo "$EARLY_OPEN_ITEM" | jq .
[ "$(echo "$EARLY_OPEN_ITEM" | jq -r '.[0].best_before_date')" = "$FAR_DATE" ] \
  || { echo "FAIL: expected best_before_date to remain $FAR_DATE, untouched by opening the item"; exit 1; }
[ "$(echo "$EARLY_OPEN_ITEM" | jq -r '.[0].effective_expiry_date')" = "$TODAY" ] \
  || { echo "FAIL: expected effective_expiry_date=$TODAY (opened_at=yesterday + 1 day open shelf life), got $(echo "$EARLY_OPEN_ITEM" | jq -r '.[0].effective_expiry_date')"; exit 1; }
[ "$(echo "$EARLY_OPEN_ITEM" | jq -r '.[0].status')" = "expiring_soon" ] \
  || { echo "FAIL: expected status=expiring_soon (driven by the open-shelf-life date, not the far-future best_before_date), got $(echo "$EARLY_OPEN_ITEM" | jq -r '.[0].status')"; exit 1; }

curl -sf -o /dev/null -X DELETE "$BASE/api/stock/$NOBBD_ENTRY_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/products/$NOBBD_PRODUCT_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/stock/$EARLY_OPEN_ENTRY_ID"
curl -sf -o /dev/null -X DELETE "$BASE/api/products/$EARLY_OPEN_PRODUCT_ID"

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

echo "== categories: create a second category for free-text shopping list items (#122) =="
SHOPPING_CATEGORY_ID=$(curl -sf -X POST "$BASE/api/categories" \
  -H 'content-type: application/json' \
  -d '{"name": "Party Supplies"}' | jq -r .id)
echo "created category $SHOPPING_CATEGORY_ID"

echo "== shopping-list: create free-text item with category_id =="
CATEGORIZED_ITEM=$(curl -sf -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"name": "Balloons", "category_id": '"$SHOPPING_CATEGORY_ID"'}')
echo "$CATEGORIZED_ITEM"
CATEGORIZED_ITEM_ID=$(echo "$CATEGORIZED_ITEM" | jq -r .id)
[ "$(echo "$CATEGORIZED_ITEM" | jq -r .category_id)" = "$SHOPPING_CATEGORY_ID" ] \
  || { echo "FAIL: expected category_id $SHOPPING_CATEGORY_ID on created item, got $CATEGORIZED_ITEM"; exit 1; }
[ "$(echo "$CATEGORIZED_ITEM" | jq -r .category_name)" = "Party Supplies" ] \
  || { echo "FAIL: expected category_name 'Party Supplies' on created item, got $CATEGORIZED_ITEM"; exit 1; }

echo "== shopping-list: category_id round-trips via GET =="
FETCHED=$(curl -sf "$BASE/api/shopping-list" | jq -c --argjson id "$CATEGORIZED_ITEM_ID" '.[] | select(.id == $id)')
[ "$(echo "$FETCHED" | jq -r .category_id)" = "$SHOPPING_CATEGORY_ID" ] \
  || { echo "FAIL: expected category_id to persist across GET, got $FETCHED"; exit 1; }
[ "$(echo "$FETCHED" | jq -r .category_name)" = "Party Supplies" ] \
  || { echo "FAIL: expected category_name to persist across GET, got $FETCHED"; exit 1; }

echo "== shopping-list: create with unknown category_id (expect 404) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' -d '{"name": "Streamers", "category_id": 999999}')
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 creating item with unknown category_id, got $STATUS"; exit 1; }

echo "== shopping-list: create with both product_id and category_id (expect 422) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "category_id": '"$SHOPPING_CATEGORY_ID"'}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 creating product-linked item with category_id, got $STATUS"; exit 1; }

echo "== shopping-list: product-linked item resolves category_name from its product (no category_id of its own) =="
PRODUCT_LINKED=$(curl -sf "$BASE/api/shopping-list" | jq -c --argjson id "$ITEM_PRODUCT_ID" '.[] | select(.id == $id)')
[ "$(echo "$PRODUCT_LINKED" | jq -r .category_id)" = "null" ] \
  || { echo "FAIL: expected null category_id on product-linked item, got $PRODUCT_LINKED"; exit 1; }
[ "$(echo "$PRODUCT_LINKED" | jq -r .category_name)" = "Dairy" ] \
  || { echo "FAIL: expected category_name 'Dairy' (inherited from product) on product-linked item, got $PRODUCT_LINKED"; exit 1; }

echo "== shopping-list: patch to set category_id on a product-linked item (expect 422) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/shopping-list/$ITEM_PRODUCT_ID" \
  -H 'content-type: application/json' -d '{"category_id": '"$SHOPPING_CATEGORY_ID"'}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 patching category_id onto a product-linked item, got $STATUS"; exit 1; }

echo "== shopping-list: clean up categorized free-text item =="
curl -sf -o /dev/null -X DELETE "$BASE/api/shopping-list/$CATEGORIZED_ITEM_ID"

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

echo "== products: create a decoy product for the undo tampering check (#224) =="
TAMPER_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Undo Tamper Target"}' | jq -r .id)
echo "created product $TAMPER_PRODUCT_ID"

echo "== stock/undo: undo is server-authoritative -- a tampering body is ignored (#224) =="
# The reproduction from #224: try to erase product B's log while fabricating
# 999 units of a different product A. Undo must restore exactly the
# snapshotted batch (product B, amount 4) and never the client-supplied
# values.
UNDO_RESPONSE=$(curl -sf -X POST "$BASE/api/stock/undo/$UNDO_LOG_ID" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$TAMPER_PRODUCT_ID"', "amount": 999}')
echo "$UNDO_RESPONSE" | jq .
echo "$UNDO_RESPONSE" | jq -e '.amount == 4' > /dev/null \
  || { echo "FAIL: expected undo to restore amount=4 from the snapshot (not the tampering 999), got $UNDO_RESPONSE"; exit 1; }
[ "$(echo "$UNDO_RESPONSE" | jq -r .product_id)" = "$UNDO_PRODUCT_ID" ] \
  || { echo "FAIL: expected undo to restore product $UNDO_PRODUCT_ID from the snapshot (not the tampering product), got $UNDO_RESPONSE"; exit 1; }
[ "$(echo "$UNDO_RESPONSE" | jq -r .location_id)" = "$LOCATION_ID" ] \
  || { echo "FAIL: expected undo to preserve location_id $LOCATION_ID from the snapshot, got $UNDO_RESPONSE"; exit 1; }

echo "== stock: the tampering body created no stock for the decoy product (#224) =="
TAMPER_COUNT=$(curl -sf "$BASE/api/stock?product_id=$TAMPER_PRODUCT_ID" | jq 'length')
[ "$TAMPER_COUNT" = "0" ] \
  || { echo "FAIL: expected 0 stock entries for the tampering decoy product, got $TAMPER_COUNT"; exit 1; }

echo "== stock: the batch is back after undo =="
COUNT=$(curl -sf "$BASE/api/stock?product_id=$UNDO_PRODUCT_ID" | jq 'length')
[ "$COUNT" = "1" ] || { echo "FAIL: expected 1 stock entry for undo-test product after undo, got $COUNT"; exit 1; }

echo "== consumption-log: the undone log row is gone (usage stats no longer overstated) =="
LOG_COUNT=$(curl -sf "$BASE/api/consumption-log" | jq --argjson id "$UNDO_LOG_ID" '[.[] | select(.id == $id)] | length')
[ "$LOG_COUNT" = "0" ] \
  || { echo "FAIL: expected consumption-log row $UNDO_LOG_ID to be gone after undo, got $LOG_COUNT"; exit 1; }

echo "== stock/undo: undoing the same log a second time fails cleanly (expect 404, already gone) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/undo/$UNDO_LOG_ID")
[ "$STATUS" = "404" ] \
  || { echo "FAIL: expected 404 undoing an already-undone consumption log id, got $STATUS"; exit 1; }

echo "== stock/undo: unknown log id (expect 404, nothing created) =="
BEFORE_UNDO_TEST_COUNT=$(curl -sf "$BASE/api/stock?product_id=$UNDO_PRODUCT_ID" | jq 'length')
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/undo/999999")
[ "$STATUS" = "404" ] || { echo "FAIL: expected 404 undoing unknown consumption log id, got $STATUS"; exit 1; }
AFTER_UNDO_TEST_COUNT=$(curl -sf "$BASE/api/stock?product_id=$UNDO_PRODUCT_ID" | jq 'length')
[ "$AFTER_UNDO_TEST_COUNT" = "$BEFORE_UNDO_TEST_COUNT" ] \
  || { echo "FAIL: expected undo with unknown log id to change nothing, got $BEFORE_UNDO_TEST_COUNT -> $AFTER_UNDO_TEST_COUNT"; exit 1; }

echo "== stock/undo: a bulk-action log is not undoable (expect 409, no stock fabricated) (#224) =="
# Bulk/delete actions never offered Undo; their log rows carry no snapshot
# and must be rejected rather than reconstructed from a client body.
NONUNDO_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Non-Undoable Bulk Test"}' | jq -r .id)
NONUNDO_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$NONUNDO_PRODUCT_ID"', "amount": 2}' | jq -r .id)
curl -sf -X POST "$BASE/api/stock/bulk/consume" \
  -H 'content-type: application/json' \
  -d '{"entry_ids": ['"$NONUNDO_ENTRY_ID"']}' -o /dev/null
NONUNDO_LOG_ID=$(curl -sf "$BASE/api/consumption-log" \
  | jq --argjson pid "$NONUNDO_PRODUCT_ID" 'map(select(.product_id == $pid)) | .[0].id')
[ "$NONUNDO_LOG_ID" != "null" ] \
  || { echo "FAIL: expected a consumption-log row for the bulk-consumed entry, got none"; exit 1; }
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/undo/$NONUNDO_LOG_ID" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$NONUNDO_PRODUCT_ID"', "amount": 999}')
[ "$STATUS" = "409" ] \
  || { echo "FAIL: expected 409 undoing a non-undoable (bulk-created) log, got $STATUS"; exit 1; }
NONUNDO_STOCK_COUNT=$(curl -sf "$BASE/api/stock?product_id=$NONUNDO_PRODUCT_ID" | jq 'length')
[ "$NONUNDO_STOCK_COUNT" = "0" ] \
  || { echo "FAIL: expected rejected non-undoable undo to fabricate no stock, got $NONUNDO_STOCK_COUNT entries"; exit 1; }
NONUNDO_LOG_STILL=$(curl -sf "$BASE/api/consumption-log" \
  | jq --argjson id "$NONUNDO_LOG_ID" '[.[] | select(.id == $id)] | length')
[ "$NONUNDO_LOG_STILL" = "1" ] \
  || { echo "FAIL: expected the rejected non-undoable log row to be left intact, got $NONUNDO_LOG_STILL"; exit 1; }

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

echo "== stock/import.csv: old-format CSV (no purchased_date/opened_at/price/quantity_unit columns) still imports fine, those fields left null (#227 backward compatibility) =="
NEW_IMPORT_FIELDS=$(curl -sf "$BASE/api/stock?search=New%20Import%20Product" \
  | jq -r '.[0] | [.purchased_date, .opened_at, .price] | @csv')
[ "$NEW_IMPORT_FIELDS" = ",," ] \
  || { echo "FAIL: expected purchased_date/opened_at/price to be null for a row imported from an old-format CSV, got $NEW_IMPORT_FIELDS"; exit 1; }

echo "== stock/export.csv -> stock/import.csv: round-trip should re-import with zero errors =="
EXPORT_COUNT=$(curl -sf "$BASE/api/stock" | jq 'length')
EXPORTED_CSV=$(curl -sf "$BASE/api/stock/export.csv")
ROUNDTRIP_RESULT=$(curl -sf -X POST "$BASE/api/stock/import.csv" -H 'content-type: text/csv' --data-binary "$EXPORTED_CSV")
echo "$ROUNDTRIP_RESULT" | jq .
[ "$(echo "$ROUNDTRIP_RESULT" | jq -r .imported)" = "$EXPORT_COUNT" ] \
  || { echo "FAIL: expected round-trip import=$EXPORT_COUNT, got $ROUNDTRIP_RESULT"; exit 1; }
[ "$(echo "$ROUNDTRIP_RESULT" | jq '.errors | length')" = "0" ] \
  || { echo "FAIL: expected zero errors round-tripping export.csv, got $ROUNDTRIP_RESULT"; exit 1; }

echo "== CSV formula injection protection: create products with formula-injection prefixes (#226) =="
FORMULA_LOCATION_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' -d '{"name": "=Injection Location"}' | jq -r .id)
FORMULA_EQUALS_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "=SUM(A1:A10)", "barcode": "=1234567"}' | jq -r .id)
FORMULA_PLUS_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "+1+1"}' | jq -r .id)
FORMULA_MINUS_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "-2"}' | jq -r .id)
FORMULA_AT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' -d '{"name": "@SUM(A1:A10)"}' | jq -r .id)

curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$FORMULA_EQUALS_ID"', "location_id": '"$FORMULA_LOCATION_ID"', "amount": 1}' > /dev/null
curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$FORMULA_PLUS_ID"', "location_id": '"$FORMULA_LOCATION_ID"', "amount": 2}' > /dev/null
curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$FORMULA_MINUS_ID"', "location_id": '"$FORMULA_LOCATION_ID"', "amount": 3}' > /dev/null
curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$FORMULA_AT_ID"', "location_id": '"$FORMULA_LOCATION_ID"', "amount": 4}' > /dev/null

echo "== CSV formula injection: verify export.csv escapes formula-prefix cells with apostrophe (#226) =="
FORMULA_EXPORT=$(curl -sf "$BASE/api/stock/export.csv")
# Check that equals sign is escaped
echo "$FORMULA_EXPORT" | tr -d '\r' | grep -q "^'=SUM" || { echo "FAIL: expected '=SUM in stock export.csv"; exit 1; }
# Check that plus sign is escaped
echo "$FORMULA_EXPORT" | tr -d '\r' | grep -q "^'+1+1" || { echo "FAIL: expected '+1+1 in stock export.csv"; exit 1; }
# Check that minus sign is escaped
echo "$FORMULA_EXPORT" | tr -d '\r' | grep -q "^'-2" || { echo "FAIL: expected '-2 in stock export.csv"; exit 1; }
# Check that at sign is escaped
echo "$FORMULA_EXPORT" | tr -d '\r' | grep -q "^'@SUM" || { echo "FAIL: expected '@SUM in stock export.csv"; exit 1; }
# Check that location with formula prefix is escaped
echo "$FORMULA_EXPORT" | tr -d '\r' | grep -q ",'=Injection Location," || { echo "FAIL: expected location '=Injection Location in stock export.csv"; exit 1; }
# Check that barcode with formula prefix is escaped
echo "$FORMULA_EXPORT" | tr -d '\r' | grep -q ",'=1234567" || { echo "FAIL: expected barcode '=1234567 in stock export.csv"; exit 1; }

echo "== CSV formula injection: round-trip formula-prefix products through export->import (#226) =="
FORMULA_ROUNDTRIP=$(curl -sf -X POST "$BASE/api/stock/import.csv" \
  -H 'content-type: text/csv' --data-binary "$FORMULA_EXPORT")
[ "$(echo "$FORMULA_ROUNDTRIP" | jq '.errors | length')" = "0" ] \
  || { echo "FAIL: expected zero errors round-tripping formula export.csv, got $FORMULA_ROUNDTRIP"; exit 1; }
# Verify the product names were restored correctly (without the apostrophe escape)
RESTORED_EQUALS=$(curl -sf "$BASE/api/products/$FORMULA_EQUALS_ID" | jq -r .name)
[ "$RESTORED_EQUALS" = "=SUM(A1:A10)" ] || { echo "FAIL: expected product name '=SUM(A1:A10)' after round-trip, got '$RESTORED_EQUALS'"; exit 1; }
RESTORED_PLUS=$(curl -sf "$BASE/api/products/$FORMULA_PLUS_ID" | jq -r .name)
[ "$RESTORED_PLUS" = "+1+1" ] || { echo "FAIL: expected product name '+1+1' after round-trip, got '$RESTORED_PLUS'"; exit 1; }

echo "== CSV formula injection: test consumption-log export escapes formula-prefix cells (#226) =="
# reason is a fixed literal (used/spoiled), so the injectable cells in this
# export are the snapshotted product name and quantity_unit. Give the product
# a formula-prefixed unit, then consume a fresh entry of it.
curl -sf -X PATCH "$BASE/api/products/$FORMULA_PLUS_ID" \
  -H 'content-type: application/json' -d '{"quantity_unit": "=EVILUNIT"}' > /dev/null
FORMULA_UNIT_ENTRY=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$FORMULA_PLUS_ID"', "location_id": '"$FORMULA_LOCATION_ID"', "amount": 1}' | jq -r .id)
curl -sf -X POST "$BASE/api/stock/$FORMULA_UNIT_ENTRY/consume" \
  -H 'content-type: application/json' \
  -d '{"amount": 1, "reason": "used"}' > /dev/null

# Verify the log export escapes the snapshotted name and unit
CONSUMPTION_EXPORT=$(curl -sf "$BASE/api/consumption-log/export.csv")
echo "$CONSUMPTION_EXPORT" | tr -d '\r' | grep -q "^[^,]*,'+1+1," || { echo "FAIL: expected escaped product name in consumption-log export"; exit 1; }
echo "$CONSUMPTION_EXPORT" | tr -d '\r' | grep -q "'=EVILUNIT" || { echo "FAIL: expected escaped quantity_unit '=EVILUNIT in consumption-log export"; exit 1; }

echo "== stock/import.csv: upload over the 5 MB size limit is rejected with 413 (not buffered/parsed) =="
OVERSIZED_CSV_FILE="$(mktemp)"
trap 'rm -f "$OVERSIZED_CSV_FILE"' EXIT
head -c 6000000 /dev/zero | tr '\0' 'x' > "$OVERSIZED_CSV_FILE"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/import.csv" \
  -H 'content-type: text/csv' --data-binary "@$OVERSIZED_CSV_FILE")
[ "$STATUS" = "413" ] \
  || { echo "FAIL: expected 413 for a 6 MB import.csv upload, got $STATUS"; exit 1; }
rm -f "$OVERSIZED_CSV_FILE"
trap - EXIT

echo "== stock/import.csv: malformed CSV (field over the parser limit) is rejected with 4xx and rolls back cleanly =="
BEFORE_MALFORMED_COUNT=$(curl -sf "$BASE/api/stock" | jq 'length')
MALFORMED_CSV_FILE="$(mktemp)"
trap 'rm -f "$MALFORMED_CSV_FILE"' EXIT
{
  printf 'product_name,barcode,location,amount,best_before_date\n'
  printf 'Milk,1234567890123,Fridge,1,%s\n' "$FAR_DATE"
  head -c 200000 /dev/zero | tr '\0' 'x'
  printf ',,Fridge,1,%s\n' "$SOON_DATE"
} > "$MALFORMED_CSV_FILE"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/import.csv" \
  -H 'content-type: text/csv' --data-binary "@$MALFORMED_CSV_FILE")
case "$STATUS" in
  4??) : ;;
  *) echo "FAIL: expected a 4xx rejecting malformed CSV, got $STATUS"; exit 1 ;;
esac
rm -f "$MALFORMED_CSV_FILE"
trap - EXIT
AFTER_MALFORMED_COUNT=$(curl -sf "$BASE/api/stock" | jq 'length')
[ "$AFTER_MALFORMED_COUNT" = "$BEFORE_MALFORMED_COUNT" ] \
  || { echo "FAIL: expected no rows committed from a rejected malformed import (before=$BEFORE_MALFORMED_COUNT, after=$AFTER_MALFORMED_COUNT)"; exit 1; }

echo "== stock/import.csv: a subsequent well-formed import still works after the malformed-input rollback =="
RECOVERY_RESULT=$(curl -sf -X POST "$BASE/api/stock/import.csv" -H 'content-type: text/csv' --data-binary "$(printf 'product_name,barcode,location,amount,best_before_date\nMilk,1234567890123,Fridge,1,%s\n' "$FAR_DATE")")
[ "$(echo "$RECOVERY_RESULT" | jq -r .imported)" = "1" ] \
  || { echo "FAIL: expected imported=1 on the recovery import after a rolled-back malformed request, got $RECOVERY_RESULT"; exit 1; }

echo "== stock/export.csv: purchased_date/opened_at/price survive round-trip, preserving an opened item's effective expiry (#227) =="
RT_LOCATION_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' -d '{"name": "Roundtrip Shelf"}' | jq -r .id)
RT_PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Roundtrip Yogurt", "default_open_shelf_life_days": 0}' | jq -r .id)
RT_ENTRY_ID=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$RT_PRODUCT_ID"', "location_id": '"$RT_LOCATION_ID"', "amount": 1, "best_before_date": "'"$FAR_DATE"'", "purchased_date": "'"$PAST_DATE"'", "price": 9.99}' \
  | jq -r .id)
curl -sf -X PATCH "$BASE/api/stock/$RT_ENTRY_ID" \
  -H 'content-type: application/json' -d '{"opened_at": "'"$PAST_DATE"'"}' > /dev/null

# best_before_date is far in the future, but a 1-day open shelf life plus
# opened_at=yesterday brings the *effective* expiry into the past -- this is
# exactly the scenario #227 warns about: if opened_at is lost on export ->
# import, this entry would wrongly stop reading as expired.
RT_STATUS_BEFORE=$(curl -sf "$BASE/api/stock?product_id=$RT_PRODUCT_ID" | jq -r '.[0].status')
[ "$RT_STATUS_BEFORE" = "expired" ] \
  || { echo "FAIL: expected opened item (1-day open shelf life, opened_at=yesterday) to already read expired, got $RT_STATUS_BEFORE"; exit 1; }

RT_EXPORTED_CSV=$(curl -sf "$BASE/api/stock/export.csv")
echo "$RT_EXPORTED_CSV" | tr -d '\r' | head -1 \
  | grep -qx 'product_name,barcode,quantity_unit,location,amount,best_before_date,purchased_date,opened_at,price,status' \
  || { echo "FAIL: unexpected export.csv header: $(echo "$RT_EXPORTED_CSV" | head -1)"; exit 1; }
RT_EXPORTED_ROW=$(echo "$RT_EXPORTED_CSV" | tr -d '\r' | grep "Roundtrip Yogurt")
echo "$RT_EXPORTED_ROW" \
  | grep -qx "Roundtrip Yogurt,,pcs,Roundtrip Shelf,1.0,$FAR_DATE,$PAST_DATE,$PAST_DATE,9.99,expired" \
  || { echo "FAIL: expected exported row to carry purchased_date/opened_at/price, got: $RT_EXPORTED_ROW"; exit 1; }

# Re-import just this one exported row (not the whole file) to keep the
# blast radius scoped to this product.
RT_SCOPED_CSV=$(printf '%s\n%s\n' "$(echo "$RT_EXPORTED_CSV" | head -1)" "$RT_EXPORTED_ROW")
RT_REIMPORT_RESULT=$(curl -sf -X POST "$BASE/api/stock/import.csv" -H 'content-type: text/csv' --data-binary "$RT_SCOPED_CSV")
[ "$(echo "$RT_REIMPORT_RESULT" | jq -r .imported)" = "1" ] \
  || { echo "FAIL: expected the scoped Roundtrip Yogurt row to import cleanly, got $RT_REIMPORT_RESULT"; exit 1; }

RT_ALL_STATUSES=$(curl -sf "$BASE/api/stock?product_id=$RT_PRODUCT_ID" | jq -r '[.[].status] | unique | join(",")')
[ "$RT_ALL_STATUSES" = "expired" ] \
  || { echo "FAIL: expected both the original and re-imported Roundtrip Yogurt entries to read expired, got $RT_ALL_STATUSES"; exit 1; }
RT_REIMPORTED_FIELDS=$(curl -sf "$BASE/api/stock?product_id=$RT_PRODUCT_ID" \
  | jq -r '[.[] | select(.id != '"$RT_ENTRY_ID"')][0] | [.purchased_date, .opened_at, .price] | @csv')
[ "$RT_REIMPORTED_FIELDS" = "\"$PAST_DATE\",\"$PAST_DATE\",9.99" ] \
  || { echo "FAIL: expected re-imported entry's purchased_date/opened_at/price to match the original, got $RT_REIMPORTED_FIELDS"; exit 1; }

echo "== stock/import.csv: quantity_unit is applied when a row creates a brand-new product (#227) =="
NEW_UNIT_CSV=$(printf 'product_name,barcode,quantity_unit,location,amount,best_before_date,purchased_date,opened_at,price\nCsvNewUnitProduct227,,kg,,3,,,,\n')
NEW_UNIT_IMPORT_RESULT=$(curl -sf -X POST "$BASE/api/stock/import.csv" -H 'content-type: text/csv' --data-binary "$NEW_UNIT_CSV")
[ "$(echo "$NEW_UNIT_IMPORT_RESULT" | jq -r .imported)" = "1" ] \
  || { echo "FAIL: expected the new-product quantity_unit row to import cleanly, got $NEW_UNIT_IMPORT_RESULT"; exit 1; }
NEW_UNIT_PRODUCT_QU=$(curl -sf "$BASE/api/products?search=CsvNewUnitProduct227" | jq -r '.[0].quantity_unit')
[ "$NEW_UNIT_PRODUCT_QU" = "kg" ] \
  || { echo "FAIL: expected CSV-created product to pick up quantity_unit=kg, got $NEW_UNIT_PRODUCT_QU"; exit 1; }

echo "== stock/import.csv: quantity_unit column does not override an already-existing product's unit (#227) =="
EXISTING_UNIT_BEFORE=$(curl -sf "$BASE/api/products/$PRODUCT_ID" | jq -r .quantity_unit)
OVERRIDE_UNIT_CSV=$(printf 'product_name,barcode,quantity_unit,location,amount\nMilk,1234567890123,l,,1\n')
curl -sf -X POST "$BASE/api/stock/import.csv" -H 'content-type: text/csv' --data-binary "$OVERRIDE_UNIT_CSV" > /dev/null
EXISTING_UNIT_AFTER=$(curl -sf "$BASE/api/products/$PRODUCT_ID" | jq -r .quantity_unit)
[ "$EXISTING_UNIT_AFTER" = "$EXISTING_UNIT_BEFORE" ] \
  || { echo "FAIL: expected importing quantity_unit=l for an existing product (Milk) to leave its unit ($EXISTING_UNIT_BEFORE) unchanged, got $EXISTING_UNIT_AFTER"; exit 1; }

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

echo "== security: X-Ingress-Path header must be HTML-escaped before it's spliced into <base href> (#181) =="
INGRESS_BODY=$(curl -s -H 'X-Ingress-Path: "><script>alert(1)</script>' "$BASE/")
if echo "$INGRESS_BODY" | grep -q '<base href'; then
  echo "$INGRESS_BODY" | grep -q '<script>alert(1)</script>' \
    && { echo "FAIL: raw <script> tag from X-Ingress-Path leaked unescaped into the response (XSS)"; exit 1; }
  echo "OK: X-Ingress-Path was HTML-escaped, no raw <script> tag in response"
else
  echo "skip: no Flutter static build bundled locally (index route only exists once vorrat/Dockerfile copies app/static/ in)"
fi

echo "== stock: reject Infinity as amount (expect 422) (#228) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "amount": "Infinity"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 rejecting Infinity as amount, got $STATUS"; exit 1; }

echo "== stock: reject -Infinity as price (expect 422) (#228) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "amount": 1.5, "price": "-Infinity"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 rejecting -Infinity as price, got $STATUS"; exit 1; }

echo "== stock: reject NaN as amount (expect 422) (#228) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "amount": "NaN"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 rejecting NaN as amount, got $STATUS"; exit 1; }

echo "== stock: patch entry rejecting Infinity as amount (expect 422) (#228) =="
PRICE_ENTRY_FOR_NONFINITE=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "amount": 2.0}' | jq -r .id)
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/stock/$PRICE_ENTRY_FOR_NONFINITE" \
  -H 'content-type: application/json' \
  -d '{"amount": "Infinity"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 patching stock entry with Infinity amount, got $STATUS"; exit 1; }
curl -sf -o /dev/null -X DELETE "$BASE/api/stock/$PRICE_ENTRY_FOR_NONFINITE"

echo "== stock: consume rejecting NaN as amount (expect 422) (#228) =="
CONSUME_ENTRY_FOR_NONFINITE=$(curl -sf -X POST "$BASE/api/stock" \
  -H 'content-type: application/json' \
  -d '{"product_id": '"$PRODUCT_ID"', "amount": 3.0}' | jq -r .id)
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock/$CONSUME_ENTRY_FOR_NONFINITE/consume" \
  -H 'content-type: application/json' \
  -d '{"amount": "NaN"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 consuming with NaN amount, got $STATUS"; exit 1; }
curl -sf -o /dev/null -X DELETE "$BASE/api/stock/$CONSUME_ENTRY_FOR_NONFINITE"

echo "== products: reject Infinity as low_stock_threshold (expect 422) (#228) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "NonfiniteTest", "low_stock_threshold": "Infinity"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 rejecting Infinity as low_stock_threshold, got $STATUS"; exit 1; }

echo "== products: reject NaN as target_stock_level (expect 422) (#228) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "NonfiniteTest", "target_stock_level": "NaN"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 rejecting NaN as target_stock_level, got $STATUS"; exit 1; }

echo "== products: patch rejecting -Infinity as low_stock_threshold (expect 422) (#228) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/products/$PRODUCT_ID" \
  -H 'content-type: application/json' \
  -d '{"low_stock_threshold": "-Infinity"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 patching product with -Infinity as low_stock_threshold, got $STATUS"; exit 1; }

echo "== shopping-list: reject Infinity as amount (expect 422) (#228) =="
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"name": "ShoppingTest", "amount": "Infinity"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 rejecting Infinity as shopping list amount, got $STATUS"; exit 1; }

echo "== shopping-list: patch rejecting NaN as amount (expect 422) (#228) =="
SHOPPING_ENTRY_FOR_NONFINITE=$(curl -sf -X POST "$BASE/api/shopping-list" \
  -H 'content-type: application/json' \
  -d '{"name": "ShoppingTest", "amount": 1.5}' | jq -r .id)
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/api/shopping-list/$SHOPPING_ENTRY_FOR_NONFINITE" \
  -H 'content-type: application/json' \
  -d '{"amount": "NaN"}')
[ "$STATUS" = "422" ] || { echo "FAIL: expected 422 patching shopping list item with NaN amount, got $STATUS"; exit 1; }
curl -sf -o /dev/null -X DELETE "$BASE/api/shopping-list/$SHOPPING_ENTRY_FOR_NONFINITE"

echo "== backup: download a snapshot (expect a valid SQLite file, #212) =="
BACKUP_FILE=$(mktemp /tmp/vorrat-smoke-backup.XXXXXX.db)
curl -sf -o "$BACKUP_FILE" "$BASE/api/backup"
# grep -a (not a bash command-substitution capture) so the binary content's
# null bytes don't trip bash's "ignored null byte in input" warning.
head -c 16 "$BACKUP_FILE" | grep -aq "^SQLite format 3" \
  || { echo "FAIL: downloaded backup is not a valid SQLite file"; exit 1; }

echo "== backup: restore rejects a non-SQLite upload (expect 400, live data untouched) =="
BAD_FILE=$(mktemp /tmp/vorrat-smoke-bad.XXXXXX.db)
echo "not a database" > "$BAD_FILE"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/backup/restore" -F "file=@$BAD_FILE")
[ "$STATUS" = "400" ] || { echo "FAIL: expected 400 restoring a non-SQLite file, got $STATUS"; exit 1; }
rm -f "$BAD_FILE"

echo "== backup: round trip -- data created after the snapshot disappears once it's restored =="
MARKER_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' -d '{"name": "BackupRoundTripMarker"}' | jq -r .id)
curl -sf -X POST "$BASE/api/backup/restore" -F "file=@$BACKUP_FILE" | jq .
rm -f "$BACKUP_FILE"
MARKER_COUNT=$(curl -sf "$BASE/api/locations" | jq --argjson id "$MARKER_ID" '[.[] | select(.id == $id)] | length')
[ "$MARKER_COUNT" = "0" ] \
  || { echo "FAIL: expected marker location $MARKER_ID to be gone after restoring the pre-marker snapshot, got count=$MARKER_COUNT"; exit 1; }

echo "== backup: server still serves normally after the restore (engine reconnected to the swapped file) =="
curl -sf "$BASE/api/health" | jq .

echo "OK"
