# 1Password Integration Patterns

Common patterns for integrating 1Password with developer tools and AI workflows.

## Claude Code / Claude Desktop

### Claude Desktop MCP Config

Store API keys securely and reference them in `claude_desktop_config.json`:

```bash
# Store the key
op item create --category API_CREDENTIAL --title "My MCP Server" \
  --vault Dev api_key[password]=your-key-here

# Get the secret reference
# op://Dev/My MCP Server/api_key
```

```json
{
  "mcpServers": {
    "my-server": {
      "command": "op",
      "args": ["run", "--", "node", "/path/to/server.js"],
      "env": {
        "API_KEY": "op://Dev/My MCP Server/api_key"
      }
    }
  }
}
```

### Claude Code Shell Environment

```bash
# .env.tpl (safe to commit — no real secrets)
ANTHROPIC_API_KEY=op://Dev/Anthropic/api_key
OPENAI_API_KEY=op://Dev/OpenAI/api_key

# Load before starting Claude Code
source <(op run --env-file=.env.tpl -- env)
claude
```

### In CLAUDE.md (project secrets reference)

```markdown
## Secrets Setup
Secrets are managed via 1Password. Run before working:
```bash
source <(op run --env-file=.env.tpl -- env)
```
Do NOT commit `.env` — commit `.env.tpl` only.
```

## n8n

### Environment Injection at Startup

```bash
# n8n.env.tpl (commit this)
N8N_ENCRYPTION_KEY=op://Dev/n8n/encryption_key
DB_POSTGRESDB_PASSWORD=op://Dev/n8n-postgres/password
N8N_BASIC_AUTH_PASSWORD=op://Dev/n8n/basic_auth_password

# docker-compose.yml startup
op run --env-file=n8n.env.tpl -- docker compose up -d n8n
```

### n8n Credential Storage via API

Use n8n's credential API to push secrets from 1Password into n8n:

```bash
# Get secret from 1Password
API_KEY=$(op read "op://Dev/Some Service/api_key")

# Push to n8n credential (HTTP Request)
curl -s -X POST "https://n8n.example.com/api/v1/credentials" \
  -H "X-N8N-API-KEY: $(op read 'op://Dev/n8n/api_key')" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"Service Credential\", \"type\": \"httpHeaderAuth\", \"data\": {\"name\": \"Authorization\", \"value\": \"Bearer $API_KEY\"}}"
```

## Docker / Docker Compose

```yaml
# docker-compose.yml
services:
  app:
    image: myapp:latest
    environment:
      DATABASE_URL: ${DATABASE_URL}
      API_KEY: ${API_KEY}
```

```bash
# .env.tpl
DATABASE_URL=op://Dev/Postgres/connection_string
API_KEY=op://Dev/MyApp/api_key

# Start with injection
op run --env-file=.env.tpl -- docker compose up
```

## Python Scripts

```python
import subprocess

def get_secret(reference: str) -> str:
    """Read a secret from 1Password using a secret reference."""
    result = subprocess.run(
        ["op", "read", reference],
        capture_output=True, text=True, check=True
    )
    return result.stdout.strip()

# Usage
api_key = get_secret("op://Dev/Anthropic/api_key")
```

Or using the 1Password Python SDK (if available):
```bash
pip install onepassword-sdk
```

```python
import asyncio
import onepassword

async def main():
    client = await onepassword.Client.authenticate(
        auth=os.environ["OP_SERVICE_ACCOUNT_TOKEN"],
        integration_name="My Script",
        integration_version="1.0.0",
    )
    secret = await client.secrets.resolve("op://Dev/Anthropic/api_key")
```

## GitHub Actions / CI

```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: 1password/load-secrets-action@v2
        with:
          export-env: true
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
          ANTHROPIC_API_KEY: op://Dev/Anthropic/api_key
          DEPLOY_KEY: op://Dev/Deploy/private_key

      - run: deploy-script.sh  # ANTHROPIC_API_KEY is available
```

## Shell / .zshrc Auto-Load

```bash
# ~/.zshrc
# Auto-load common dev secrets on shell start (optional — only if you trust your machine)
load_dev_secrets() {
  if command -v op &>/dev/null && op whoami &>/dev/null 2>&1; then
    source <(op run --env-file=~/.config/dev.env.tpl -- env 2>/dev/null) && \
      echo "✅ Dev secrets loaded from 1Password"
  fi
}

# Call explicitly when needed:
alias load-secrets='load_dev_secrets'
```

## Supabase

```bash
# Store Supabase credentials
op item create --category API_CREDENTIAL --title "Supabase - My Project" \
  --vault Dev \
  url[text]=https://myproject.supabase.co \
  anon_key[password]=eyJ... \
  service_key[password]=eyJ...

# Use in scripts
SUPABASE_URL=$(op read "op://Dev/Supabase - My Project/url")
SUPABASE_KEY=$(op read "op://Dev/Supabase - My Project/service_key")
```

## Replit

Replit has its own Secrets manager, but for local dev before deploying:

```bash
# Generate a .env from 1Password, then paste values into Replit Secrets UI
op run --env-file=.env.tpl -- env | grep -E "^(ANTHROPIC|SUPABASE|N8N)"
# Copy output values → paste into Replit Secrets one by one
```

## Rotation Workflow

When rotating a credential:

```bash
# 1. Update in the service (get new key)
NEW_KEY="new-key-from-service"

# 2. Update in 1Password
op item edit "Service Name" api_key[password]="$NEW_KEY"

# 3. Verify
op read "op://Dev/Service Name/api_key"

# 4. Re-inject wherever used
source <(op run --env-file=.env.tpl -- env)
# Or restart services that use the key
```
