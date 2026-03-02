#!/usr/bin/env bash
# launch-in-terminal.sh — Open a script in a NEW Terminal.app window
#
# This is how the 1Password skill keeps secrets OUT of Claude Code.
# Claude generates the script, then calls this launcher.
# The script runs in Terminal.app — Claude never sees what you type.
#
# Usage:
#   bash launch-in-terminal.sh /path/to/script.sh
#   bash launch-in-terminal.sh /path/to/script.sh "window title"

set -euo pipefail

SCRIPT_PATH="${1:-}"
TITLE="${2:-1Password Setup}"

if [[ -z "$SCRIPT_PATH" ]]; then
  echo "Usage: bash launch-in-terminal.sh /path/to/script.sh"
  exit 1
fi

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "❌ Script not found: $SCRIPT_PATH"
  exit 1
fi

chmod +x "$SCRIPT_PATH"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Opening Terminal.app to collect secrets"
echo "  Script: $SCRIPT_PATH"
echo ""
echo "  ⚠️  Type your secrets in the Terminal"
echo "     window that is about to open."
echo "     Claude Code cannot see that window."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

osascript <<APPLESCRIPT
tell application "Terminal"
  activate
  set newTab to do script "echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'; echo '  ${TITLE}'; echo '  Type secrets here — Claude Code cannot see this window'; echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'; echo ''; bash ${SCRIPT_PATH}"
end tell
APPLESCRIPT

echo "✅ Terminal.app opened. Complete the prompts there, then return here."
echo "   (This window will wait for you to press Enter when done)"
echo ""
read -rp "Press Enter once you've finished in Terminal.app... "
echo ""
echo "Continuing..."
