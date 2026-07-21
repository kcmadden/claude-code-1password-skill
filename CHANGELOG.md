# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [1.0.0] - 2026-07-21

First tagged release. The skill is stable and ready to install into
`~/.claude/skills/1password`.

### Added
- `check_setup.sh` - verifies the `op` CLI is installed and authenticated, lists
  accounts and vaults, and reports service-account mode. Now prints a macOS
  platform note.
- `store_secret.sh` - create or update a secret and print its `op://` reference;
  supports `--from-env`, `--generate`, and `--update`.
- `store-mcp-credentials.sh` - store MCP server credentials (mixed pre-filled and
  hidden-prompt fields), create-or-update, prints references for your config.
- `env_from_op.sh` - generate a `.env` of `op://` references (or resolved values
  with `--resolve`) from any 1Password item.
- `launch-in-terminal.sh` - open a generated script in Terminal.app so secrets are
  typed outside the Claude Code session.
- `references/` - `op_commands.md`, `secret_references.md`, `integrations.md`.
- `tests/smoke_test.sh` - parse, bad-input, and no-`op` safety checks.

### Changed
- All scripts and docs are now plain ASCII (no emoji, arrows, box-drawing, or
  em-dashes) for clean terminal output and portability.
- Documented the platform requirement (macOS) in README, SKILL.md, and
  check_setup.sh - the Terminal-launch secret-entry flow uses AppleScript; the
  `op` commands themselves are cross-platform.

### Fixed
- Removed the unsafe `source <(op run --env-file=... -- env)` suggestion from
  `env_from_op.sh` output. Shell metacharacters inside secret values can execute
  as code when sourced; `op run --env-file=... -- <command>` is the safe pattern
  the skill already recommends.

### Security
- Reaffirmed: never source or `eval` resolved secrets into the current shell;
  inject them into a subprocess with `op run` instead.
