#!/usr/bin/env bash
# smoke_test.sh - lightweight checks that the scripts parse, handle bad input,
# and do not crash when the op CLI is missing. No secrets, no network, no op calls.
#
# Usage: bash tests/smoke_test.sh
# Exit code 0 = all passed, 1 = one or more failed.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/scripts"
PASS=0
FAIL=0

ok()   { echo "  PASS $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL $1"; FAIL=$((FAIL+1)); }

echo "=== 1Password skill smoke tests ==="

# 1. Every script parses under bash -n
echo ""
echo "--- parse ---"
for f in "$S"/*.sh "$ROOT"/tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then ok "parses: $(basename "$f")"; else bad "parses: $(basename "$f")"; fi
done

# 2. launch-in-terminal.sh shows usage and exits non-zero with no args
echo ""
echo "--- bad input ---"
out=$(bash "$S/launch-in-terminal.sh" </dev/null 2>&1); code=$?
if [[ $code -ne 0 && "$out" == *Usage* ]]; then ok "launch-in-terminal: usage on no args"; else bad "launch-in-terminal: usage on no args (code=$code)"; fi

# 3. launch-in-terminal.sh rejects a nonexistent script path
out=$(bash "$S/launch-in-terminal.sh" /no/such/file.sh </dev/null 2>&1); code=$?
if [[ $code -ne 0 && "$out" == *"not found"* ]]; then ok "launch-in-terminal: rejects missing file"; else bad "launch-in-terminal: rejects missing file (code=$code)"; fi

# 4. Scripts reject unknown options before doing any work
for pair in "store_secret.sh" "env_from_op.sh" "store-mcp-credentials.sh"; do
  out=$(bash "$S/$pair" --definitely-not-a-flag </dev/null 2>&1); code=$?
  if [[ $code -ne 0 && "$out" == *"Unknown option"* ]]; then ok "$pair: rejects unknown option"; else bad "$pair: rejects unknown option (code=$code)"; fi
done

# 5. check_setup.sh does not crash when op is absent from PATH
echo ""
echo "--- no op present ---"
tmpbin="$(mktemp -d)"
# minimal PATH with the coreutils it needs but no op
out=$(PATH="/usr/bin:/bin:/usr/sbin:/sbin:$tmpbin" bash "$S/check_setup.sh" </dev/null 2>&1); code=$?
rmdir "$tmpbin" 2>/dev/null || true
if [[ $code -eq 0 && "$out" == *"FAIL op CLI installed"* ]]; then
  ok "check_setup: runs and reports missing op without crashing"
else
  bad "check_setup: runs without op (code=$code)"
fi

echo ""
echo "==================================="
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
