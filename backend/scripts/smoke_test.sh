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

echo "OK"
