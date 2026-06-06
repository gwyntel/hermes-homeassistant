# Home Assistant Configuration Management

A comprehensive system for managing Home Assistant configurations with automated validation, testing, and deployment — built for Hermes Agent and Claude Code.

Fork of [philippb/claude-homeassistant](https://github.com/philippb/claude-homeassistant) with Makefile-driven validation, client-side gate checks, and Hermes skill integration.

## Features

- **Makefile-Driven Workflow** — `make pull`, `make push`, `make validate` for all operations
- **Client-Side Validation Gate** — YAML syntax + entity reference checks block broken config before it reaches HA
- **Two-Tier Validation** — `make validate-client` (fast, reliable) vs `make validate` (full suite including `ha_official`)
- **Entity Discovery** — Explore and search available entities by domain, area, or keyword
- **Safe Deployments** — `make push` validates first, only syncs YAML, never overwrites `.storage/`
- **Hermes Agent Skill** — Fully integrated as a loadable skill

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/gwyntel/hermes-homeassistant.git
cd hermes-homeassistant
make setup
```

### 2. Configure Connection

```bash
cp .env.example .env
# Edit .env with your HA details
```

Required in `.env`:
```bash
HA_HOST=homeassistant.local       # SSH hostname or IP
HA_TOKEN=your_long_lived_token    # HA API token
HA_URL=http://homeassistant.local:8123
HA_REMOTE_PATH=/config/
```

### 3. SSH Access

Install the [Advanced SSH & Web Terminal](https://github.com/hassio-addons/addon-ssh) add-on in HA, add your public key, and verify:

```bash
ssh root@homeassistant.local
```

The Makefile uses `~/.ssh/id_ed25519_agent` by default. Override with `SSH_IDENTITY` in `.env`.

### 4. Pull Your Config

```bash
make pull
```

This downloads your real HA config into `config/`, then runs client-side validation.

### 5. Edit and Push

Edit YAML files locally, then:

```bash
make push
```

This validates first (blocks on failure), rsyncs YAML to HA, then triggers a config reload.

## Available Commands

| Command | Description |
|---------|-------------|
| `make pull` | Pull config from HA + validate |
| `make push` | Validate + push to HA + reload |
| `make validate-client` | YAML syntax + entity references (fast, reliable) |
| `make validate` | Full suite including `ha_official` (may produce false positives) |
| `make validate-yaml` | YAML syntax check only |
| `make validate-references` | Entity reference check only |
| `make backup` | Timestamped tar.gz backup |
| `make status` | Config status + entity counts |
| `make entities` | Entity explorer (`ARGS='--domain climate'`) |
| `make reload` | Reload HA config via API (no push) |
| `make check-env` | Verify .env + SSH connectivity |

## Validation System

### Two Tiers

| Target | What it runs | When to use |
|--------|-------------|-------------|
| `make validate-client` | YAML syntax + entity refs | Pre-push gate, after edits |
| `make validate` | All three validators including `ha_official` | Full audit |

**Why two tiers?** The `ha_official_validator.py` uses HA's own validation package, which is stricter than the HA runtime. It produces false positives on dozens of working automations ("Unable to determine action"). Client-side validation catches real problems without the noise.

### What `validate-client` checks

1. **YAML Syntax** — Valid YAML with HA-specific tags (`!include`, `!secret`, `!input`), encoding, structure
2. **Entity References** — All referenced entities exist in your HA instance, disabled entity warnings, Jinja2 template extraction

### Integration Points

- **`make push`** and **`make pull`** both run `validate-client` automatically
- **Claude Code hooks** in `.claude-code/hooks/` provide additional post-edit and pre-push validation for Claude Code users
- **Hermes Agent** loads the skill at `skills/hermes-homeassistant/SKILL.md`

## Project Structure

```
├── config/                 # HA configuration (synced from HA)
│   ├── automations.yaml
│   ├── configuration.yaml
│   └── .storage/          # Entity registry (pulled, never pushed)
├── tools/                 # Validation scripts
│   ├── run_tests.py       # Full test suite runner
│   ├── yaml_validator.py  # YAML syntax validation
│   ├── reference_validator.py  # Entity reference validation
│   ├── ha_official_validator.py # Official HA validation
│   ├── entity_explorer.py # Entity discovery tool
│   └── reload_config.py   # HA config reload via API
├── skills/                # Hermes Agent skill definition
├── .claude-code/hooks/    # Claude Code automated hooks
├── Makefile               # All management commands
└── CLAUDE.md              # Agent instructions
```

## Rsync Architecture

Two separate exclude files protect HA's runtime state:

| File | Used By | Purpose |
|------|---------|---------|
| `.rsync-excludes-pull` | `make pull` | Less restrictive, includes `.storage/` for reference |
| `.rsync-excludes-push` | `make push` | More restrictive, **never** overwrites `.storage/` |

`.storage/` contains runtime state managed by HA (integration configs, entity registries, dashboards, auth). Local modifications get overwritten by HA on restart or ignored entirely.

## Entity Naming Convention

**Format: `location_room_device_sensor`**

```
binary_sensor.home_basement_motion_battery
media_player.home_kitchen_sonos
climate.home_living_room_heatpump
```

## Troubleshooting

### Validation Fails

1. Run `make validate-yaml` to check syntax first
2. Run `make validate-references` to check entity refs
3. If both pass but `make validate` fails, it's likely a `ha_official` false positive — safe to push

### SSH Issues

1. Verify key permissions: `chmod 600 ~/.ssh/your_key`
2. Test connection: `ssh root@your_ha_host`
3. Check the add-on is running in HA

### Build Error: lru-dict (macOS)

Old Python from Xcode CLT. Fix:
```bash
brew install python@3.12
export PATH="/opt/homebrew/bin:$PATH"
make setup
```

## License

Apache 2.0
