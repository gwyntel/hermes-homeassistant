# Home Assistant Configuration Management

This repository manages Home Assistant configuration files with automated validation, testing, and deployment.

## Before Making Changes

**Always consult the latest Home Assistant documentation** at https://www.home-assistant.io/docs/ before suggesting configurations, automations, or integrations. HA updates frequently and syntax/features change between versions.

## Project Structure

- `config/` - Contains all Home Assistant configuration files (synced from HA instance)
- `tools/` - Validation and testing scripts
- `venv/` - Python virtual environment with dependencies
- `Makefile` - Commands for pulling/pushing configuration
- `.claude-code/` - Claude Code project settings and hooks (optional)

## Rsync Architecture

This project uses **two separate exclude files** for different sync operations:

| File | Used By | Purpose |
|------|---------|---------|
| `.rsync-excludes-pull` | `make pull` | Less restrictive |
| `.rsync-excludes-push` | `make push` | More restrictive |

**Why separate files?**
- `make pull` downloads most files including `.storage/` (excluding sensitive auth files) for local reference
- `make push` **never** overwrites HA's runtime state (`.storage/`)

## What This Repo Can and Cannot Manage

### SAFE TO MANAGE (YAML files)
- `automations.yaml` - Automation definitions
- `scenes.yaml` - Scene definitions
- `scripts.yaml` - Script definitions
- `configuration.yaml` - Main configuration
- `secrets.yaml` - Secret values

### NEVER MODIFY LOCALLY (Runtime State)
These files in `.storage/` are managed by Home Assistant at runtime. Local modifications will be **overwritten** by HA on restart or ignored entirely.

### Entity/Device Changes (Manual Only)

Do not change entities or devices programmatically from this repo. If changes are
needed, make them manually in the Home Assistant UI:
- Settings → Devices & Services → Entities → Edit

### Reloading After YAML Changes
- Automations: `POST /api/services/automation/reload`
- Scenes: `POST /api/services/scene/reload`
- Scripts: `POST /api/services/script/reload`
- Or use `make reload` to trigger reload via API

## Workflow Rules

### Before Making Changes
1. Run `make pull` to ensure local files are current
2. Identify if the change affects YAML files or `.storage/` files
3. YAML files → edit locally, then `make push`
4. `.storage/` files → use the HA UI only (manual changes)

### Before Running `make push`
1. Client-side validation runs automatically (`validate-client`)
2. Only YAML configuration files will be synced (`.storage/` is protected)
3. If validation fails, push is blocked — fix errors first

### After `make push`
1. HA config reload is triggered automatically
2. Verify changes took effect in HA UI

## Available Commands

### Configuration Management
- `make pull` - Pull latest config from Home Assistant + validate
- `make push` - Validate + push to Home Assistant + reload
- `make backup` - Create timestamped backup of current config
- `make validate-client` - Client-side validation (YAML + entity refs)
- `make validate` - Full validation suite including ha_official
- `make validate-yaml` - YAML syntax check only
- `make validate-references` - Entity reference check only
- `make validate-ha` - Official HA validation only

### Entity Discovery
- `make entities` - Explore available Home Assistant entities
- `make entities ARGS='--domain climate'` - Climate entities only
- `make entities ARGS='--search motion'` - Search for motion sensors
- `make entities ARGS='--area kitchen'` - Kitchen entities only
- `make entities ARGS='--full'` - Complete detailed output

### Other
- `make reload` - Reload HA configuration via API (no push)
- `make status` - Show configuration status and entity counts
- `make check-env` - Validate environment configuration
- `make format-yaml` - Format YAML files

## Validation System

### Two-Tier Validation

| Target | What it runs | Speed | Reliability |
|--------|-------------|-------|-------------|
| `make validate-client` | YAML syntax + entity refs | Fast | High — catches real problems |
| `make validate` | All 3 validators including ha_official | Slower | Low — many false positives |

### Why Two Tiers?

The `ha_official_validator.py` is stricter than the HA runtime itself. It produces false positives ("Unable to determine action") on dozens of working automations. Client-side validation catches actual problems without the noise.

**`make push` and `make pull` use `validate-client` as their gate.** This is intentional — the client-side checks are the authoritative validation. `make validate` is available for full audits when needed.

### Individual Validators
```bash
. venv/bin/activate
python tools/yaml_validator.py config/         # YAML syntax
python tools/reference_validator.py config/    # Entity references
python tools/ha_official_validator.py config/  # Official HA (expect false positives)
```

## Entity Naming Convention

**Format: `location_room_device_sensor`**

- **location**: `home`, `office`, `cabin`, etc.
- **room**: `basement`, `kitchen`, `living_room`, `driveway`, etc.
- **device**: `motion`, `heatpump`, `sonos`, `lock`, etc.
- **sensor**: `battery`, `tamper`, `temperature`, `status`, etc.

When creating automations, use the entity explorer (`make entities`) to discover available entities before writing automations. Follow this naming convention when suggesting entity names.

## Important Notes

- **Never push without validation** — `make push` enforces this automatically
- **Blueprint files** use `!input` tags which are normal and expected
- **Secrets are skipped** during validation for security
- **SSH access required** for pull/push operations
- **Python venv required** for validation tools
- All python tools need `source venv/bin/activate && python <tool_path>`

## Troubleshooting

### Validation Fails
1. Run `make validate-yaml` to isolate syntax errors
2. Run `make validate-references` to check entity refs
3. If both pass but `make validate` fails, it's likely a `ha_official` false positive
4. Safe to proceed with `make push` if client-side validation passes

### SSH Issues
1. Verify SSH key permissions: `chmod 600 ~/.ssh/your_key`
2. Test connection: `ssh root@your_ha_host`
3. Check `.env` has the correct `HA_HOST` and `SSH_IDENTITY`

### Missing Dependencies
1. Activate venv: `source venv/bin/activate`
2. Install requirements: `pip install homeassistant voluptuous pyyaml jsonschema requests`
