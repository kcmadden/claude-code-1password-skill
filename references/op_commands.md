# 1Password CLI (op) Command Reference

## Authentication

```bash
# Sign in (interactive)
op signin

# Sign in to specific account
op signin --account team-name.1password.com

# Check who you're signed in as
op whoami

# List accounts
op account list

# Service account (CI/CD — set env var, no signin needed)
export OP_SERVICE_ACCOUNT_TOKEN="your-token"
```

## Items

```bash
# List items
op item list
op item list --vault Dev
op item list --categories API_CREDENTIAL

# Get item details
op item get "Item Title"
op item get "Item Title" --vault Dev
op item get "Item Title" --format json

# Get a specific field
op item get "Item Title" --fields api_key
op item get "Item Title" --fields label=api_key

# Read using secret reference (most common)
op read "op://Dev/Item Title/api_key"

# Create item
op item create --category API_CREDENTIAL --title "My API Key" api_key[password]=sk-abc123
op item create --category LOGIN --title "Service Account" --vault Dev \
  username[text]=myuser password[password]=mypass

# Edit/update item
op item edit "Item Title" api_key[password]=new-value
op item edit "Item Title" --vault Dev new_field[text]=value

# Delete item
op item delete "Item Title"
op item delete "Item Title" --vault Dev

# Move item to different vault
op item move "Item Title" --current-vault Dev --destination-vault Personal
```

## Vaults

```bash
# List vaults
op vault list
op vault list --format json

# Create vault
op vault create "New Vault"

# Get vault details
op vault get "Vault Name"
```

## Secrets Injection

```bash
# Run command with secrets from .env template (RECOMMENDED)
op run --env-file=.env.tpl -- your-command arg1 arg2

# Inject into Docker
op run --env-file=.env.tpl -- docker compose up

# Inject a single reference via env var (op run picks up op:// values automatically)
export API_KEY="op://Dev/MyApp/api_key"
op run -- node app.js   # API_KEY is resolved at runtime

# ⚠️  AVOID: sourcing op run output into the current shell
# source <(op run --env-file=.env.tpl -- env)   ← UNSAFE
# If secret values contain $(...) or backticks, they execute as shell code.
# Use 'op run -- your-command' instead (secrets stay in subprocess only).
```

## Password Generation

```bash
# Generate at item creation time (no standalone command)
op item create --category PASSWORD --title "Generated Secret" \
  --generate-password='letters,digits,symbols,32'

# Generate with custom recipe
op item create --category LOGIN --title "My Login" \
  --generate-password='letters,digits,20'

# Or use openssl for scripted generation
openssl rand -base64 32 | tr -d '=+/'
```

## Document / File Management

```bash
# Store a file
op document create ./private-key.pem --title "SSH Private Key" --vault Dev

# Get a file
op document get "SSH Private Key" --output ./private-key.pem

# List documents
op document list
```

## Service Accounts (CI/CD)

```bash
# Create service account (in 1Password UI: Settings → Developer → Service Accounts)
# Then set token as env var:
export OP_SERVICE_ACCOUNT_TOKEN="ops_eyJ..."

# No signin needed — op commands work automatically
op item list  # works with service account token
op read "op://vault/item/field"
```

## Connect (Self-hosted, advanced)

```bash
# For teams running 1Password Connect server
export OP_CONNECT_HOST="https://your-connect-server"
export OP_CONNECT_TOKEN="your-connect-token"

# Then op commands use Connect instead of 1Password.com
op item get "Item Title"
```

## Output Formats

Valid values: `json` or `human-readable` (default).

```bash
op item list --format=json           # Machine-readable JSON
op item get "Item" --format=json     # Full item JSON
op item list                         # Human-readable (default)
op vault list --format=json          # Vaults as JSON
```

## Useful Patterns

```bash
# Find item by field value (search)
op item list --format=json | \
  python3 -c "import sys,json; [print(i['title']) for i in json.load(sys.stdin)]"

# Export all items in a vault to JSON (backup)
op item list --vault Dev --format=json | \
  python3 -c "import sys,json; ids=[i['id'] for i in json.load(sys.stdin)]"
# (then loop to get each)

# Check if a specific item exists
op item get "My Item" &>/dev/null && echo "exists" || echo "not found"

# Get item ID (for scripting)
op item get "My Item" --format=json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])"
```
