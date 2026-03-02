#!/usr/bin/env bash
# store-mcp-credentials.sh — Store MCP server credentials in 1Password
#
# ⚠️  RUN THIS IN TERMINAL.APP — NOT IN CLAUDE CODE
#     Claude Code can see everything typed in its terminal.
#     Open Terminal.app separately, then run this script.
#
# Usage (Claude will generate a pre-filled version for you):
#   bash store-mcp-credentials.sh \
#     --vault Dev \
#     --item "My MCP Server" \
#     --set "url=https://api.example.com" \
#     --set "log_level=error" \
#     --secret "api_key" \
#     --secret "webhook_secret"
#
# Options:
#   --vault     1Password vault name (default: Dev)
#   --item      Item title in 1Password
#   --set       Non-secret field: key=value (pre-filled, visible)
#   --secret    Secret field: prompted with hidden input
#   --update    Update existing item instead of creating new

set -euo pipefail

VAULT="Dev"
ITEM=""
UPDATE=false
declare -a SET_FIELDS=()
declare -a SECRET_FIELDS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --vault)   VAULT="$2";                    shift 2 ;;
    --item)    ITEM="$2";                     shift 2 ;;
    --set)     SET_FIELDS+=("$2");            shift 2 ;;
    --secret)  SECRET_FIELDS+=("$2");         shift 2 ;;
    --update)  UPDATE=true;                   shift   ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ITEM" ]]; then
  read -rp "Item title in 1Password: " ITEM
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Storing: $ITEM"
echo "  Vault:   $VAULT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Show pre-filled fields
if [[ ${#SET_FIELDS[@]} -gt 0 ]]; then
  echo "Pre-filled fields:"
  for field in "${SET_FIELDS[@]}"; do
    key="${field%%=*}"
    val="${field#*=}"
    echo "  $key = $val"
  done
  echo ""
fi

# Prompt for secret fields
declare -a SECRET_VALUES=()
if [[ ${#SECRET_FIELDS[@]} -gt 0 ]]; then
  echo "Enter secret values (input is hidden):"
  for field in "${SECRET_FIELDS[@]}"; do
    read -rsp "  $field: " secret_val
    echo ""
    SECRET_VALUES+=("${field}[password]=${secret_val}")
  done
  echo ""
fi

# Build op field args for non-secret fields
declare -a OP_FIELDS=()
for field in "${SET_FIELDS[@]}"; do
  key="${field%%=*}"
  val="${field#*=}"
  OP_FIELDS+=("${key}[text]=${val}")
done

# Combine all fields
ALL_FIELDS=("${OP_FIELDS[@]+"${OP_FIELDS[@]}"}" "${SECRET_VALUES[@]+"${SECRET_VALUES[@]}"}")

echo "Saving to 1Password..."

if $UPDATE; then
  op item edit "$ITEM" --vault "$VAULT" "${ALL_FIELDS[@]}"
  echo ""
  echo "✅ Updated '$ITEM' in vault '$VAULT'"
else
  # Try create, fall back to update if already exists
  if op item get "$ITEM" --vault "$VAULT" &>/dev/null 2>&1; then
    echo "  Item already exists — updating instead..."
    op item edit "$ITEM" --vault "$VAULT" "${ALL_FIELDS[@]}"
    echo ""
    echo "✅ Updated '$ITEM' in vault '$VAULT'"
  else
    op item create \
      --category API_CREDENTIAL \
      --title "$ITEM" \
      --vault "$VAULT" \
      "${ALL_FIELDS[@]}"
    echo ""
    echo "✅ Created '$ITEM' in vault '$VAULT'"
  fi
fi

echo ""
echo "Secret references for your config:"
for field in "${SET_FIELDS[@]}"; do
  key="${field%%=*}"
  echo "  op://${VAULT}/${ITEM}/${key}"
done
for field in "${SECRET_FIELDS[@]}"; do
  echo "  op://${VAULT}/${ITEM}/${field}"
done
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done. You can close this terminal."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
