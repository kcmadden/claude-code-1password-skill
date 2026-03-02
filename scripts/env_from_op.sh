#!/usr/bin/env bash
# env_from_op.sh — Generate a .env file from 1Password items
#
# Usage:
#   bash env_from_op.sh                        # Interactive: prompts for vault + items
#   bash env_from_op.sh --vault Dev            # Use specific vault
#   bash env_from_op.sh --item "My Project"    # Export all fields from one item
#   bash env_from_op.sh --output .env          # Write to file (default: .env)
#   bash env_from_op.sh --dry-run              # Print without writing
#
# Output format:
#   FIELD_NAME=op://Vault/Item/field           # Secret references (safest)
#   FIELD_NAME=actual_value                    # Resolved values (with --resolve)

set -euo pipefail

VAULT=""
ITEM=""
OUTPUT=".env"
DRY_RUN=false
RESOLVE=false

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --vault) VAULT="$2"; shift 2 ;;
    --item) ITEM="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --resolve) RESOLVE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check op is available
if ! command -v op &>/dev/null; then
  echo "❌ 1Password CLI (op) not found. Install: https://developer.1password.com/docs/cli/get-started/"
  exit 1
fi

# If no item specified, list items and prompt
if [[ -z "$ITEM" ]]; then
  echo "Available items in vault '${VAULT:-all vaults}':"
  if [[ -n "$VAULT" ]]; then
    op item list --vault "$VAULT" --format=json | \
      python3 -c "import sys,json; [print(f'  {i[\"title\"]}') for i in json.load(sys.stdin)]"
  else
    op item list --format=json | \
      python3 -c "import sys,json; [print(f'  [{i[\"vault\"][\"name\"]}] {i[\"title\"]}') for i in json.load(sys.stdin)]"
  fi
  echo ""
  read -rp "Enter item title: " ITEM
fi

echo "Fetching '${ITEM}' from 1Password..."

# Get item as JSON
if [[ -n "$VAULT" ]]; then
  ITEM_JSON=$(op item get "$ITEM" --vault "$VAULT" --format=json)
else
  ITEM_JSON=$(op item get "$ITEM" --format=json)
fi

VAULT_NAME=$(echo "$ITEM_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['vault']['name'])")
ITEM_TITLE=$(echo "$ITEM_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['title'])")

# Build .env content
ENV_CONTENT=$(echo "$ITEM_JSON" | python3 - <<'PYEOF'
import sys, json, re

data = json.load(sys.stdin)
vault = data['vault']['name']
title = data['title']
lines = []

SKIP_LABELS = {'username', 'password', 'notesPlain', 'notes'}
SKIP_TYPES = {'CONCEALED'} if False else set()  # resolved mode: don't skip

for field in data.get('fields', []):
    label = field.get('label', '')
    value = field.get('value', '')
    field_id = field.get('id', '')
    ftype = field.get('type', '')

    # Skip empty, metadata, or UI-only fields
    if not value or not label:
        continue
    if label.lower() in {'username', 'notesplain', 'notes', 'password'} and ftype not in {'CONCEALED', 'URL'}:
        continue

    # Convert label to ENV_VAR format
    env_key = re.sub(r'[^A-Z0-9_]', '_', label.upper().replace(' ', '_').replace('-', '_'))
    env_key = re.sub(r'_+', '_', env_key).strip('_')

    # Use secret reference (safer than raw value)
    ref = f"op://{vault}/{title}/{label}"
    lines.append(f"{env_key}={ref}")

print('\n'.join(lines))
PYEOF
)

# Handle resolve flag — replace refs with real values
if $RESOLVE; then
  echo "⚠️  Writing resolved values (actual secrets). Handle carefully."
  FINAL_CONTENT=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^([A-Z_]+)=(op://.+)$ ]]; then
      key="${BASH_REMATCH[1]}"
      ref="${BASH_REMATCH[2]}"
      value=$(op read "$ref" 2>/dev/null || echo "ERROR_READING")
      FINAL_CONTENT+="${key}=${value}"$'\n'
    else
      FINAL_CONTENT+="$line"$'\n'
    fi
  done <<< "$ENV_CONTENT"
  ENV_CONTENT="$FINAL_CONTENT"
fi

# Header
HEADER="# Generated from 1Password: ${VAULT_NAME}/${ITEM_TITLE}
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Load with: op run --env-file=.env -- <command>
#            or: eval \$(op run --env-file=.env -- env | grep KEY)

"

FULL_CONTENT="${HEADER}${ENV_CONTENT}"

if $DRY_RUN; then
  echo ""
  echo "--- .env preview ---"
  echo "$FULL_CONTENT"
  echo "--- end ---"
else
  echo "$FULL_CONTENT" > "$OUTPUT"
  echo "✅ Written to $OUTPUT (${#ENV_CONTENT} chars, $(echo "$ENV_CONTENT" | grep -c '=' || true) vars)"
  echo ""
  echo "To use:"
  echo "  op run --env-file=$OUTPUT -- your-command"
  echo "  source <(op run --env-file=$OUTPUT -- env)"
fi
