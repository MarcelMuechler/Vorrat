#!/usr/bin/env bash
# Live end-to-end checks against a running server (uvicorn, or the Docker
# image in CI). Requires: server running, curl, jq.
#
# Deliberately NOT an API-semantics suite. Status codes, validation rules and
# business logic are covered by `uv run pytest` (backend/tests/), which is
# faster, isolated, and runs on every PR. What stays here is only what a real
# process and a real HTTP stack can exercise: static file serving, the
# ingress rewrite, uploads served back off disk, the error responses
# TestClient can't reproduce, and swapping the SQLite file underneath a live
# engine.
set -euo pipefail

BASE="${BASE:-http://localhost:8000}"

fail() { echo "FAIL: $*"; exit 1; }

echo "== health =="
curl -sf "$BASE/api/health" | jq .

echo "== CORS: preflight is answered for a browser origin =="
# Wide-open CORS is deliberate (v1 has no auth, trusted network only) -- this
# checks the middleware is actually mounted, which only a real request shows.
ALLOW_ORIGIN=$(curl -s -D - -o /dev/null -X OPTIONS "$BASE/api/health" \
  -H 'Origin: http://example.invalid' \
  -H 'Access-Control-Request-Method: GET' \
  | tr -d '\r' | awk -F': ' 'tolower($1) == "access-control-allow-origin" {print $2}')
[ -n "$ALLOW_ORIGIN" ] || fail "no Access-Control-Allow-Origin on a preflight response"
echo "OK: preflight allowed origin '$ALLOW_ORIGIN'"

echo "== uploads: an uploaded photo is actually served back off disk =="
# Smallest possible valid PNG (1x1), decoded from a literal base64 blob so
# this has no dependency on an external fixture file.
PRODUCT_ID=$(curl -sf -X POST "$BASE/api/products" \
  -H 'content-type: application/json' \
  -d '{"name": "Smoke Upload Test"}' | jq -r .id)
IMAGE_FILE="$(mktemp --suffix=.png)"
trap 'rm -f "$IMAGE_FILE"' EXIT
base64 -d > "$IMAGE_FILE" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGP4z8AARwgWXg4ArpMP8aaUSCMAAAAASUVORK5CYII=
PNG
IMAGE_URL=$(curl -sf -X POST "$BASE/api/products/$PRODUCT_ID/image" \
  -F "file=@$IMAGE_FILE;type=image/png" | jq -r .image_url)
case "$IMAGE_URL" in
  /uploads/*) : ;;
  *) fail "expected image_url under /uploads/, got $IMAGE_URL" ;;
esac
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE$IMAGE_URL")
[ "$STATUS" = "200" ] || fail "expected 200 fetching the uploaded image, got $STATUS"

echo "== uploads: replacing the photo unmounts the old path (expect 404) =="
SECOND_IMAGE_URL=$(curl -sf -X POST "$BASE/api/products/$PRODUCT_ID/image" \
  -F "file=@$IMAGE_FILE;type=image/png" | jq -r .image_url)
[ "$SECOND_IMAGE_URL" != "$IMAGE_URL" ] || fail "expected a new filename on re-upload"
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE$IMAGE_URL")
[ "$STATUS" = "404" ] || fail "expected 404 for the replaced upload's old path, got $STATUS"
rm -f "$IMAGE_FILE"
trap - EXIT

echo "== security: X-Ingress-Path must be HTML-escaped before it reaches <base href> (#181) =="
INGRESS_BODY=$(curl -s -H 'X-Ingress-Path: "><script>alert(1)</script>' "$BASE/")
if echo "$INGRESS_BODY" | grep -q '<base href'; then
  echo "$INGRESS_BODY" | grep -q '<script>alert(1)</script>' \
    && fail "raw <script> tag from X-Ingress-Path leaked unescaped into the response (XSS)"
  echo "OK: X-Ingress-Path was HTML-escaped, no raw <script> tag in response"
else
  echo "skip: no Flutter static build bundled locally (the index route only exists once vorrat/Dockerfile copies app/static/ in)"
fi

echo "== non-finite numbers are rejected over the real HTTP stack (expect 422) (#228) =="
# Kept out of pytest on purpose: the schema rejects these there too, but
# TestClient re-raises the encoder error instead of returning the 422 a real
# server sends, so only a live request exercises what clients actually see.
for payload in \
  '{"product_id": '"$PRODUCT_ID"', "amount": "Infinity"}' \
  '{"product_id": '"$PRODUCT_ID"', "amount": "NaN"}' \
  '{"product_id": '"$PRODUCT_ID"', "amount": 1.5, "price": "-Infinity"}'
do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/stock" \
    -H 'content-type: application/json' -d "$payload")
  [ "$STATUS" = "422" ] || fail "expected 422 for non-finite payload $payload, got $STATUS"
done
echo "OK: Infinity/NaN rejected with 422"

echo "== csv export: served as a real download (Content-Disposition) =="
DISPOSITION=$(curl -s -D - -o /dev/null "$BASE/api/stock/export.csv" \
  | tr -d '\r' | awk -F': ' 'tolower($1) == "content-disposition" {print $2}')
case "$DISPOSITION" in
  *stock.csv*) echo "OK: $DISPOSITION" ;;
  *) fail "expected a stock.csv attachment disposition, got '$DISPOSITION'" ;;
esac

echo "== backup: download a snapshot (expect a valid SQLite file, #212) =="
BACKUP_FILE=$(mktemp /tmp/vorrat-smoke-backup.XXXXXX.db)
curl -sf -o "$BACKUP_FILE" "$BASE/api/backup"
# grep -a (not a bash command-substitution capture) so the binary content's
# null bytes don't trip bash's "ignored null byte in input" warning.
head -c 16 "$BACKUP_FILE" | grep -aq "^SQLite format 3" \
  || fail "downloaded backup is not a valid SQLite file"

echo "== backup: round trip -- data created after the snapshot disappears once it's restored =="
MARKER_ID=$(curl -sf -X POST "$BASE/api/locations" \
  -H 'content-type: application/json' -d '{"name": "BackupRoundTripMarker"}' | jq -r .id)
curl -sf -X POST "$BASE/api/backup/restore" -F "file=@$BACKUP_FILE" | jq .
rm -f "$BACKUP_FILE"
MARKER_COUNT=$(curl -sf "$BASE/api/locations" | jq --argjson id "$MARKER_ID" '[.[] | select(.id == $id)] | length')
[ "$MARKER_COUNT" = "0" ] \
  || fail "expected marker location $MARKER_ID to be gone after restoring the pre-marker snapshot, got count=$MARKER_COUNT"

echo "== backup: server still serves normally after the restore (engine reconnected to the swapped file) =="
curl -sf "$BASE/api/health" | jq .

echo "OK"
