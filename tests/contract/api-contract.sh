#!/bin/sh
# Contract test: ตรวจว่า API ปัจจุบัน (production) ยังตอบ schema ที่คาดหวัง
set -e

BASE_URL="${1:-https://todoapp-kps.akawatmor.com}"
FAILED=0

check() {
  local name="\$1"
  local expected="\$2"
  local actual="\$3"
  if echo "$actual" | grep -q "$expected"; then
    echo "✓ $name"
  else
    echo "✗ $name — expected pattern '$expected' not found"
    echo "  got: $actual"
    FAILED=$((FAILED+1))
  fi
}

echo "── Contract test against $BASE_URL ──"

# 1. Healthz returns 200 + "ok"-like response
RESP=$(curl -sf "$BASE_URL/healthz")
check "healthz responds" "ok\|healthy\|true" "$RESP"

# 2. GET /api/v1/tasks returns array
RESP=$(curl -sf -H "X-User-ID: contract-test" "$BASE_URL/api/v1/tasks")
check "GET /tasks returns array or object" "^\[\|^{" "$RESP"

# 3. POST /api/v1/tasks accepts {title, column} and returns id
RESP=$(curl -sf -X POST \
  -H "Content-Type: application/json" \
  -H "X-User-ID: contract-test" \
  -d '{"title":"contract","column":"todo"}' \
  "$BASE_URL/api/v1/tasks")
check "POST /tasks returns id field" '"id"' "$RESP"

# 4. Response มี field ที่ frontend ต้องการ
check "POST response has title" '"title"' "$RESP"
check "POST response has column" '"column"' "$RESP"

if [ "$FAILED" -gt 0 ]; then
  echo "❌ Contract test failed: $FAILED check(s)"
  exit 1
fi
echo "✅ All contract checks passed"