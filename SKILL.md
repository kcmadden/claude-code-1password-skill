---
name: 1password
description: >
  Integrate 1Password secrets management into Claude Code workflows. Use when the user wants to:
  store API keys or credentials in 1Password, read secrets from 1Password into scripts or config,
  set up .env files using 1Password secret references, rotate or update credentials, manage
  developer secrets across projects, use 1Password service accounts for CI/CD, or integrate
  1Password with tools like Claude Desktop, n8n, Docker, Supabase, GitHub Actions, or Replit.
  Triggers on phrases like "store in 1Password", "read from 1Password", "op://", "secret reference",
  "manage API keys with 1Password", "1Password CLI", or any request involving the `op` command.
---

# 1Password Skill

> **Platform:** macOS. The Terminal-launch secret-entry flow uses AppleScript and Terminal.app.
> The `op` CLI commands themselves work on any OS, but this skill's secret-entry pattern is macOS-only.

## Critical: Never Type Secrets Into Claude Code

**Claude Code can see everything typed in its terminal and chat.**

When a user needs to store a secret, ALWAYS use the Terminal launch pattern:
1. Generate a pre-filled script with known values already set
2. Use `launch-in-terminal.sh` to open it in Terminal.app
3. User types secrets in that window - Claude Code cannot see it
4. 1Password stores the secret, outputs `op://` references back to Claude

```bash
# Claude generates the script, then launches it outside its own view:
bash scripts/launch-in-terminal.sh /tmp/setup-my-service.sh "Service Name Setup"
```

Never ask users to paste API keys, passwords, or tokens into:
- The Claude Code chat
- A Bash tool call visible in Claude Code
- Any file Claude Code writes before it's stored in 1Password

---

## Setup Check

Always verify the CLI is ready before any operation:

```bash
bash scripts/check_setup.sh
```

If not installed: https://developer.1password.com/docs/cli/get-started/
If not signed in: unlock the **1Password desktop app** (after Mac restart, the app must be unlocked before the CLI works)

---

## Storing Secrets: The Terminal Launch Pattern

When a user needs to store a new secret or credential:

**Step 1 - Generate the script** (Claude does this, with known values pre-filled):

```bash
cat > /tmp/setup-SERVICE.sh << 'EOF'
bash /path/to/store-mcp-credentials.sh \
  --vault Dev \
  --item "Service Name" \
  --set "url=https://known-url.com" \
  --set "env=production" \
  --secret "api_key" \
  --secret "webhook_secret"
EOF
```

**Step 2 - Launch in Terminal.app** (secrets stay out of Claude Code):

```bash
bash scripts/launch-in-terminal.sh /tmp/setup-SERVICE.sh "Service Name Setup"
```

**Step 3 - Update config** (Claude uses the `op://` references from the output):

```json
"SERVICE_API_KEY": "op://Dev/Service Name/api_key"
```

---

## Core Patterns

### Read a secret

```bash
op read "op://VaultName/ItemTitle/field_name"
export API_KEY=$(op read "op://Dev/Anthropic/api_key")
```

### Store a new secret

```bash
# Basic
bash scripts/store_secret.sh --title "My API Key" --field api_key --value "sk-..."

# With vault
bash scripts/store_secret.sh --title "My API Key" --vault Dev --field api_key --value "sk-..."

# From environment variable
bash scripts/store_secret.sh --from-env ANTHROPIC_API_KEY --title "Anthropic"

# Generate a secure credential
bash scripts/store_secret.sh --title "App Secret" --field secret --generate --length 32
```

### Update an existing secret

```bash
bash scripts/store_secret.sh --update --title "My API Key" --field api_key --value "new-value"
# Or directly:
op item edit "My API Key" api_key[password]=new-value
```

### Generate a .env from 1Password

```bash
# Interactive - lists items, choose one
bash scripts/env_from_op.sh

# From a specific item (dry run preview)
bash scripts/env_from_op.sh --item "Project Credentials" --dry-run

# Write .env.tpl (secret references - safe to commit)
bash scripts/env_from_op.sh --item "Project Credentials" --output .env.tpl

# Write .env with resolved real values (DO NOT commit)
bash scripts/env_from_op.sh --item "Project Credentials" --resolve --output .env
```

---

## Secret References (op://)

The safest pattern - store `op://` references in config files instead of real values.

> **Privacy note:** `op://` references reveal vault names, item names, and field names.
> Safe to commit to **private repos**. For public repos, check that your vault/item naming
> doesn't expose sensitive structure (client names, internal service names, etc.).

```
op://VaultName/ItemTitle/field_name
```

```bash
# .env.tpl (commit this file)
ANTHROPIC_API_KEY=op://Dev/Anthropic/api_key
N8N_API_KEY=op://Dev/n8n/api_key
SUPABASE_SERVICE_KEY=op://Dev/Supabase/service_key

# Inject at runtime - secrets stay in subprocess, never in shell history
op run --env-file=.env.tpl -- your-command

# Avoid sourcing into current shell - unsafe if values contain $(...) or backticks
# source <(op run --env-file=.env.tpl -- env)   <- skip this pattern
```

For full syntax and edge cases: [references/secret_references.md](references/secret_references.md)

---

## Integration Guides

Read [references/integrations.md](references/integrations.md) for patterns with:

- **Claude Desktop** - MCP server config using `op run`
- **n8n** - Environment injection at startup, credential push via API
- **Docker / Docker Compose** - `op run -- docker compose up`
- **GitHub Actions** - `1password/load-secrets-action`
- **Python scripts** - subprocess + 1Password SDK
- **Supabase** - Storing and retrieving project credentials
- **Replit** - Local dev -> Replit Secrets bridge
- **Rotation workflow** - Update in service -> update in 1Password -> re-inject

---

## Common CLI Commands

Full reference: [references/op_commands.md](references/op_commands.md)

```bash
op item list                           # List all items
op item list --vault Dev               # Filter by vault
op item get "Item Title"               # View item details
op item get "Item Title" --format json # JSON output
op vault list                          # List vaults
op whoami                              # Check auth status
op account list                        # List accounts
```

---

## CI/CD: Service Accounts

For non-interactive environments (GitHub Actions, Docker, n8n server):

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_eyJ..."
op read "op://Dev/MyApp/api_key"   # works without signin prompt
```

Create service accounts: 1Password UI -> Settings -> Developer -> Service Accounts.
Grant vault access only to what the service needs.

---

## Never Print a Secret

Anything a command prints lands in Claude's context and the session transcript. Load secrets into variables and use them; never print them, or any part of them.

```bash
# Presence check - prints SET/UNSET, never the value
[ -n "$API_KEY" ] && echo SET || echo UNSET

# Length only
echo "${#API_KEY}"

# Compare two secrets without revealing either - short fingerprint
printf '%s' "$API_KEY" | shasum -a 256 | cut -c1-12

# Use it without printing it; send keys in headers, not URLs
API_KEY=$(op read -n "op://vault/item/credential")
curl -s -H "Authorization: Bearer $API_KEY" https://api.example.com/me
```

Patterns that leak (do not use):
- `${VAR:+yes}${VAR:-no}` - when VAR is set, the `:-` half prints the full value
- `${TOKEN:0:8}` or any slice - a partial secret is still a leak
- `op read ...` or `op item get --reveal` with output going straight to the terminal
- `https://api.example.com/x?key=$TOKEN` - many client libraries echo the full URL in error messages
- `env`, `printenv`, `cat .env` - use `env | cut -d= -f1` to list names only

If a secret does get printed: say so immediately and rotate it. It is already in the transcript.

Want this enforced automatically instead of by convention? 1Password Pro adds hooks that block these commands before they run and hide keys that appear in output.

---

## Troubleshooting

- **`op read` value does not match** - `op read` adds a trailing newline. Use `op read -n` when comparing or hashing.
- **Service account: "item not found"** - service accounts need `--vault <name>` on `op item get` / `op item edit`.
- **`op` hangs with no output** - it is waiting for a biometric or password prompt it cannot show. Run it in the foreground, never in the background, and update the CLI (`op --version`, then upgrade through your package manager).
- **Wrong item returned** - titles get renamed and misspelled. Reference items by ID (`op://<vault-id>/<item-id>/<field>`), not title.

---

## Security Rules

1. **Never hardcode secrets** - always use `op://` references or runtime injection
2. **Commit `.env.tpl`** to private repos only - it exposes vault/item structure, not values
3. **Never commit `.env`** (real values) - add it to `.gitignore` immediately: `echo ".env" >> .gitignore`
4. **Use vaults to scope access** - separate vault per project or team
5. **Rotate on exposure** - use `store_secret.sh --update` then re-inject everywhere
6. **Service accounts for CI/CD** - never use personal account tokens in automation
