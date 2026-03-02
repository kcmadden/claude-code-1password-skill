# 1Password Secret References

Secret references are the safest way to use secrets — they point to 1Password without exposing actual values in code or config files.

## Syntax

```
op://vault/item/field
op://vault/item/section/field
```

**Examples:**
```bash
op://Dev/Anthropic/api_key
op://Personal/AWS/access_key_id
op://Dev/Supabase/section/service_key
```

## Reading a Secret Reference

```bash
# Single secret
op read "op://Dev/Anthropic/api_key"

# Into a variable
export ANTHROPIC_API_KEY=$(op read "op://Dev/Anthropic/api_key")

# Multiple secrets via op run
op run --env-file=.env.tpl -- your-command
```

## .env Template Files

Store references in a `.env.tpl` file (safe to commit):

```bash
# .env.tpl — commit this
ANTHROPIC_API_KEY=op://Dev/Anthropic/api_key
N8N_API_KEY=op://Dev/n8n/api_key
SUPABASE_SERVICE_KEY=op://Dev/Supabase/service_key
NOTION_TOKEN=op://Dev/Notion/api_token
```

Then inject at runtime:
```bash
# Run a command with secrets resolved
op run --env-file=.env.tpl -- npm start

# Export to current shell
source <(op run --env-file=.env.tpl -- env | grep -E "ANTHROPIC|N8N|SUPABASE")

# Write resolved .env (don't commit this)
op run --env-file=.env.tpl -- env | grep -E "^(ANTHROPIC|N8N|SUPABASE)" > .env
```

## In Config Files

Claude Desktop (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "my-server": {
      "command": "op",
      "args": ["run", "--", "node", "server.js"],
      "env": {
        "API_KEY": "op://Dev/MyServer/api_key"
      }
    }
  }
}
```

Docker Compose:
```yaml
services:
  app:
    image: myapp
    environment:
      - DATABASE_URL=op://Dev/Postgres/connection_string
```
Run with: `op run -- docker compose up`

n8n (environment injection):
```bash
# In your n8n startup script
op run --env-file=n8n.env.tpl -- docker compose up n8n
```

## Finding Field Names

```bash
# List all fields in an item
op item get "Item Name" --format=json | \
  python3 -c "import sys,json; [print(f['label']) for f in json.load(sys.stdin)['fields'] if f.get('value')]"

# Or view interactively
op item get "Item Name"
```

## Common Field Names by Category

| Category | Common Fields |
|----------|---------------|
| API_CREDENTIAL | `api_key`, `credential`, `token` |
| LOGIN | `username`, `password` |
| DATABASE | `connection_string`, `host`, `port`, `username`, `password` |
| SECURE_NOTE | `notesPlain` |
| SERVER | `hostname`, `port`, `username`, `password` |
