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

## Setup Check

Always verify the CLI is ready before any operation:

```bash
bash scripts/check_setup.sh
```

If not installed: https://developer.1password.com/docs/cli/get-started/
If not signed in: `op signin`

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
# Interactive — lists items, choose one
bash scripts/env_from_op.sh

# From a specific item (dry run preview)
bash scripts/env_from_op.sh --item "Project Credentials" --dry-run

# Write .env.tpl (secret references — safe to commit)
bash scripts/env_from_op.sh --item "Project Credentials" --output .env.tpl

# Write .env with resolved real values (DO NOT commit)
bash scripts/env_from_op.sh --item "Project Credentials" --resolve --output .env
```

---

## Secret References (op://)

The safest pattern — store `op://` references in config files instead of real values.

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

# ✅ Inject at runtime — secrets stay in subprocess, never in shell history
op run --env-file=.env.tpl -- your-command

# ⚠️  Avoid sourcing into current shell — unsafe if values contain $(...) or backticks
# source <(op run --env-file=.env.tpl -- env)   ← skip this pattern
```

For full syntax and edge cases: [references/secret_references.md](references/secret_references.md)

---

## Integration Guides

Read [references/integrations.md](references/integrations.md) for patterns with:

- **Claude Desktop** — MCP server config using `op run`
- **n8n** — Environment injection at startup, credential push via API
- **Docker / Docker Compose** — `op run -- docker compose up`
- **GitHub Actions** — `1password/load-secrets-action`
- **Python scripts** — subprocess + 1Password SDK
- **Supabase** — Storing and retrieving project credentials
- **Replit** — Local dev → Replit Secrets bridge
- **Rotation workflow** — Update in service → update in 1Password → re-inject

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

Create service accounts: 1Password UI → Settings → Developer → Service Accounts.
Grant vault access only to what the service needs.

---

## Security Rules

1. **Never hardcode secrets** — always use `op://` references or runtime injection
2. **Commit `.env.tpl`** to private repos only — it exposes vault/item structure, not values
3. **Never commit `.env`** (real values) — add it to `.gitignore` immediately: `echo ".env" >> .gitignore`
4. **Use vaults to scope access** — separate vault per project or team
5. **Rotate on exposure** — use `store_secret.sh --update` then re-inject everywhere
6. **Service accounts for CI/CD** — never use personal account tokens in automation
