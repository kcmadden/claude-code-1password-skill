# Claude Code 1Password Skill

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code/skills) that integrates 1Password secrets management into AI-assisted developer workflows.

Stop hardcoding API keys. Stop copying secrets from browser to terminal. Let 1Password and Claude handle it.

---

## What it does

- **Store** API keys, tokens, and credentials in 1Password from the Claude Code chat
- **Read** secrets via `op://` references — secrets never touch disk or shell history
- **Generate** `.env.tpl` files with secret references (safe to commit) from any 1Password item
- **Rotate** credentials in one command, then re-inject everywhere
- **Integrate** with Claude Desktop, n8n, Docker, GitHub Actions, Python, Supabase, and Replit

---

## Install

Clone into your Claude Code skills directory:

```bash
git clone https://github.com/kcmadden/claude-code-1password-skill.git \
  ~/.claude/skills/1password
```

Or if you already have it, pull the latest:

```bash
cd ~/.claude/skills/1password && git pull
```

Then restart Claude Code (or start a new session).

**Requirements:**
- [1Password CLI](https://developer.1password.com/docs/cli/get-started/) v2+ (`op`)
- Signed in: `op signin`

---

## Usage

Once installed, Claude Code automatically loads this skill when you ask about 1Password. Just talk to it:

> "Store my Anthropic API key in 1Password"

> "Generate a .env.tpl for my project from the 'Dev Credentials' item"

> "Read my Supabase service key into this script"

> "Set up my Claude Desktop MCP config to use 1Password for secrets"

> "Rotate my n8n API key and update 1Password"

---

## What's included

### Scripts

| Script | Purpose |
|--------|---------|
| `check_setup.sh` | Verify op CLI is installed and authenticated |
| `store_secret.sh` | Create or update a secret, outputs the `op://` reference |
| `env_from_op.sh` | Generate `.env.tpl` (references) or `.env` (resolved) from any 1Password item |

### References (loaded on demand, no context bloat)

| File | Contents |
|------|---------|
| `op_commands.md` | Full CLI command reference with accurate flags |
| `secret_references.md` | `op://` syntax, safe injection patterns, what to avoid |
| `integrations.md` | Claude Desktop, n8n, Docker, GitHub Actions, Python, Supabase, Replit |

---

## Core pattern

```bash
# 1. Store your secret
bash scripts/store_secret.sh --title "Anthropic" --field api_key --value "sk-..."
# → op://Dev/Anthropic/api_key

# 2. Reference it in .env.tpl (commit this)
echo "ANTHROPIC_API_KEY=op://Dev/Anthropic/api_key" >> .env.tpl
echo ".env" >> .gitignore

# 3. Use it
op run --env-file=.env.tpl -- your-command
```

---

## Security model

This skill follows a security-first approach:

**Safe patterns (recommended):**
```bash
op run --env-file=.env.tpl -- your-command     # secrets stay in subprocess
export KEY=$(op read "op://vault/item/field")   # single secret into variable
```

**Patterns to avoid:**
```bash
source <(op run --env-file=.env.tpl -- env)    # ⚠️ unsafe — shell metacharacters in values execute as code
eval $(op run ... env)                          # ⚠️ same risk
```

**Rules built into this skill:**
1. Never hardcode secrets — always use `op://` references
2. Commit `.env.tpl` (references only), never `.env` (real values)
3. Always add `.env` to `.gitignore`
4. Use vaults to scope access by project or team
5. Use service accounts for CI/CD — never personal tokens in automation

---

## Example: Claude Desktop with 1Password

Keep your MCP server API keys in 1Password instead of plaintext in `claude_desktop_config.json`:

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

Claude Desktop runs `op run` which resolves the reference at startup. Your actual key never appears in the config file.

---

## Example: Your dev environment

```bash
# .env.tpl (commit this)
ANTHROPIC_API_KEY=op://Dev/Anthropic/api_key
SUPABASE_SERVICE_KEY=op://Dev/Supabase/service_key
N8N_API_KEY=op://Dev/n8n/api_key

# Start Claude Code with secrets injected
op run --env-file=.env.tpl -- claude
```

---

## Contributing

Issues and PRs welcome. If you add integration patterns for other tools, open a PR against `references/integrations.md`.

---

## License

MIT
