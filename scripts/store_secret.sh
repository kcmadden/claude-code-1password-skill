#!/usr/bin/env bash
# store_secret.sh — Store or update a secret in 1Password
#
# Usage:
#   bash store_secret.sh --title "My API Key" --field "api_key" --value "sk-..."
#   bash store_secret.sh --title "Project Creds" --vault Dev --category API_CREDENTIAL
#   bash store_secret.sh --update --title "Existing Item" --field "api_key" --value "new-value"
#   bash store_secret.sh --from-env MY_VAR   # Store from environment variable

set -euo pipefail

TITLE=""
FIELD="credential"
VALUE=""
VAULT=""
CATEGORY="API_CREDENTIAL"
UPDATE=false
FROM_ENV=""
GENERATE=false
GENERATE_LENGTH=32

while [[ $# -gt 0 ]]; do
  case $1 in
    --title) TITLE="$2"; shift 2 ;;
    --field) FIELD="$2"; shift 2 ;;
    --value) VALUE="$2"; shift 2 ;;
    --vault) VAULT="$2"; shift 2 ;;
    --category) CATEGORY="$2"; shift 2 ;;
    --update) UPDATE=true; shift ;;
    --from-env) FROM_ENV="$2"; shift 2 ;;
    --generate) GENERATE=true; shift ;;
    --length) GENERATE_LENGTH="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate
if [[ -z "$TITLE" ]]; then
  read -rp "Item title: " TITLE
fi

# Get value from env var if requested
if [[ -n "$FROM_ENV" ]]; then
  VALUE="${!FROM_ENV:-}"
  if [[ -z "$VALUE" ]]; then
    echo "❌ Environment variable $FROM_ENV is not set or empty"
    exit 1
  fi
  FIELD="${FROM_ENV}"
  echo "Using value from \$$FROM_ENV"
fi

# Generate a secure credential if requested
if $GENERATE; then
  VALUE=$(openssl rand -base64 "$GENERATE_LENGTH" | tr -d '=+/' | head -c "$GENERATE_LENGTH")
  echo "🔐 Generated secure credential ($GENERATE_LENGTH chars)"
fi

# Prompt for value if still empty
if [[ -z "$VALUE" ]]; then
  read -rsp "Value (hidden): " VALUE
  echo ""
fi

VAULT_FLAG=""
[[ -n "$VAULT" ]] && VAULT_FLAG="--vault $VAULT"

if $UPDATE; then
  echo "Updating '${FIELD}' in '${TITLE}'..."
  op item edit "$TITLE" $VAULT_FLAG "${FIELD}[password]=${VALUE}"
  echo "✅ Updated '${FIELD}' in '${TITLE}'"
else
  echo "Creating '${TITLE}' in 1Password..."
  RESULT=$(op item create \
    --category "$CATEGORY" \
    --title "$TITLE" \
    $VAULT_FLAG \
    "${FIELD}[password]=${VALUE}" \
    --format=json)

  ITEM_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  VAULT_NAME=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['vault']['name'])")

  echo "✅ Created '${TITLE}' (ID: ${ITEM_ID})"
  echo ""
  echo "Secret reference:"
  echo "  op://${VAULT_NAME}/${TITLE}/${FIELD}"
  echo ""
  echo "Read it back:"
  echo "  op read \"op://${VAULT_NAME}/${TITLE}/${FIELD}\""
fi
