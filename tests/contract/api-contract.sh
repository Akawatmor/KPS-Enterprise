#!/bin/sh
# Contract test — POSIX-compliant, no local keyword, no functions
set -eu

BASE_URL="${1:-https://todoapp-kps.akawatmor.com}"
FAILED=0

echo "── Contract test against $BASE_URL ──"

# ── Test 1: healthz ─────────────────────────────────────────────
NAME="healthz responds"
RESP=$(curl -sf "$BASE_URL/healthz" 2>&1 || echo "REQUEST_FAILED")
if echo "$RESP" | grep -qE 'ok|healthy|true|"status"'; then
    echo "✓ $NAME"
else
    echo "✗ $NAME"
    echo "  got: $RESP"
    FAILED=$((FAILED+1))
fi

# ── Test 2: GET /api/v1/tasks ──────────────────────────────────
NAME="GET /tasks returns array or object"
RESP=$(curl -sf -H "X-User-ID: contract-test" "$BASE_URL/api/v1/tasks" 2>&1 || echo "REQUEST_FAILED")
FIRST_CHAR=$(printf '%s' "$RESP" | cut -c1)
if [ "$FIRST_CHAR" = "[" ] || [ "$FIRST_CHAR" = "{" ]; then
    echo "✓ $NAME"
else
    echo "✗ $NAME"
    echo "  got: $RESP"
    FAILED=$((FAILED+1))
fi

# ── Test 3: POST /api/v1/tasks ─────────────────────────────────
NAME="POST /tasks returns id field"
RESP=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -H "X-User-ID: contract-test" \
    -d '{"title":"contract","column":"todo"}' \
    "$BASE_URL/api/v1/tasks" 2>&1 || echo "REQUEST_FAILED")
if echo "$RESP" | grep -q '"id"'; then
    echo "✓ $NAME"
else
    echo "✗ $NAME"
    echo "  got: $RESP"
    FAILED=$((FAILED+1))
fi

# ── Test 4: response shape ─────────────────────────────────────
NAME="POST response has title field"
if echo "$RESP" | grep -q '"title"'; then
    echo "✓ $NAME"
else
    echo "✗ $NAME"
    echo "  got: $RESP"
    FAILED=$((FAILED+1))
fi

NAME="POST response has column field"
if echo "$RESP" | grep -q '"column"'; then
    echo "✓ $NAME"
else
    echo "✗ $NAME"
    echo "  got: $RESP"
    FAILED=$((FAILED+1))
fi

# ── Summary ─────────────────────────────────────────────────────
echo ""
if [ "$FAILED" -gt 0 ]; then
    echo "❌ Contract test failed: $FAILED check(s)"
    exit 1
fi
echo "✅ All contract checks passed"