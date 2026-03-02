#!/usr/bin/env bash
# check_setup.sh — Verify 1Password CLI is installed and authenticated
# Usage: bash check_setup.sh

set -euo pipefail

PASS=0
FAIL=0

check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  ✅ $label"
    ((PASS++)) || true
  else
    echo "  ❌ $label"
    ((FAIL++)) || true
  fi
}

echo "=== 1Password CLI Setup Check ==="
echo ""

# 1. CLI installed
check "op CLI installed" "command -v op"

# 2. Version
if command -v op &>/dev/null; then
  echo "  ℹ️  Version: $(op --version)"
fi

echo ""
echo "--- Authentication ---"

# 3. Signed in
check "Signed in to 1Password" "op account list 2>/dev/null | grep -q '.'"

# 4. Can list vaults
check "Can list vaults" "op vault list &>/dev/null"

# Show accounts if authenticated
if op account list &>/dev/null 2>&1; then
  echo ""
  echo "  Accounts:"
  op account list 2>/dev/null | tail -n +2 | while read -r line; do
    echo "    • $line"
  done

  echo ""
  echo "  Vaults:"
  op vault list --format=json 2>/dev/null | \
    python3 -c "import sys,json; [print(f'    • {v[\"name\"]} ({v[\"id\"]})') for v in json.load(sys.stdin)]" 2>/dev/null || true
fi

echo ""
echo "--- Environment ---"

# 5. OP_SERVICE_ACCOUNT_TOKEN (CI/CD pattern)
if [[ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  echo "  ✅ OP_SERVICE_ACCOUNT_TOKEN is set (service account mode)"
else
  echo "  ℹ️  OP_SERVICE_ACCOUNT_TOKEN not set (interactive/desktop app mode)"
fi

echo ""
echo "==================================="
if [[ $FAIL -eq 0 ]]; then
  echo "✅ All checks passed. 1Password CLI is ready."
else
  echo "⚠️  $FAIL check(s) failed. See above."
  echo ""
  echo "Install: https://developer.1password.com/docs/cli/get-started/"
  echo "Sign in: op signin"
fi
