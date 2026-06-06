---
name: homeassistant-management
description: Manage Home Assistant configuration, automations, and custom integrations. Use when creating or editing HA automations, deploying custom components, validating YAML config, troubleshooting parsing issues, or working with the HA REST API. Includes bundled validators for YAML syntax and entity reference checking.
version: 1.1.0
author: gwyntel
license: Apache-2.0
compatibility: Requires Home Assistant 2024.x+ and Python 3.10+ with PyYAML
metadata:
  hermes:
    tags: [home-assistant, automation, yaml, rest-api, validation, smart-home]
    related_skills: [homeassistant-cli]
---

# Home Assistant Management

Manage HA config, build reliable automations, deploy custom integrations, validate YAML, and avoid common pitfalls. Bundles working validators you can run immediately after install.

## When to Use

- Creating or editing HA automations (especially `automations.yaml`)
- Deploying custom components/integrations via SCP
- Troubleshooting automation `unavailable` states or YAML parsing failures
- Validating HA config before pushing
- Working with the HA REST API
- Exploring entity registry

## Available Scripts

- **`scripts/yaml_validator.py`** — Validates YAML syntax, file encoding, HA tag handling (`!include`, `!secret`, etc.), and structure of automations/scripts/configuration files. Run: `python3 scripts/yaml_validator.py [config_dir]`
- **`scripts/reference_validator.py`** — Validates all entity references in config files actually exist in the entity registry. Detects stale/broken references and disabled entities. Run: `python3 scripts/reference_validator.py [config_dir]`
- **`scripts/entity_explorer.py`** — Parse entity registry and display entities organized by domain and area. Supports filtering by domain, area, and search. Run: `python3 scripts/entity_explorer.py [config_dir] [--domain X] [--area X] [--search X]`

Dependency: `pip install pyyaml`

### Quick Validation

```bash
# YAML syntax check (fast, no HA required)
python3 scripts/yaml_validator.py config/

# Entity reference check (needs .storage/core.entity_registry)
python3 scripts/reference_validator.py config/

# Both (client-side gate — recommended before any push)
python3 scripts/yaml_validator.py config/ && python3 scripts/reference_validator.py config/
```

## HA REST API Quick Reference

```bash
# Get all states
GET /api/states

# Get specific entity
GET /api/states/{entity_id}

# Call service
POST /api/services/{domain}/{service}
Body: {"entity_id": "switch.charge"}

# Reload automations
POST /api/services/automation/reload

# Restart HA
POST /api/services/homeassistant/restart

# Check config validity
POST /api/config/core/check_config

# Reload integration by entry_id
POST /api/config/config_entries/entry/{entry_id}/reload
```

Auth via `Authorization: Bearer {long_lived_access_token}`.

## Creating Automations — Preferred Workflow

1. Read current `automations.yaml` from HA host
2. Append new automation YAML to the file on the HA host directly
3. Reload via `POST /api/services/automation/reload`
4. Verify the new automation entity shows state `on` (not `unavailable`)
5. If `unavailable`, check YAML parse with: `python3 -c 'import yaml; yaml.safe_load(open("/config/automations.yaml"))'`
6. If still unavailable after fix, full HA restart may be needed

**Do NOT use the HA REST API `/api/config/automation/config` endpoint** — it returns 404 on most HA versions. Write YAML to the file directly.

## Reloading After Changes

- **Automations**: `POST /api/services/automation/reload`
- **Scenes**: `POST /api/services/scene/reload`
- **Scripts**: `POST /api/services/script/reload`
- **Integration**: `POST /api/config/config_entries/entry/{id}/reload`
- **Full restart**: `POST /api/services/homeassistant/restart`

## Deploying Custom Components

1. SCP the updated Python files to `/config/custom_components/{integration}/`
2. If adding NEW platforms (e.g. switch.py, number.py that didn't exist before), HA restart is required — reload is insufficient
3. If updating existing platforms, integration reload via API may work
4. Verify new entities appear with correct state

## Power-Based Automation Design

Prefer `numeric_state` conditions over device state string matching. Firmware state strings can contain typos, vary across versions, and are unreliable for programmatic matching. Power readings are unambiguous.

```yaml
trigger:
  - platform: numeric_state
    entity_id: sensor.device_power
    below: 100
    for:
      minutes: 15
condition:
  - condition: state
    entity_id: binary_sensor.device_connected
    state: "on"
action:
  - action: switch.turn_off
    data: {}
    metadata: {}
    target:
      entity_id: switch.device
```

## Entity Naming Convention

Format: `domain.location_room_device_sensor`

When creating automations, discover entities first via `ha_list_entities` or the entity explorer script. Never assume entity IDs — verify them.

## Validation Strategies

HA server-side validation (`hass --config check`) can be **stricter than the HA runtime** — it produces false positives on many working automations.

**Recommended approach**:
1. Client-side validation (YAML syntax + entity reference checks) as the push gate
2. If client-side passes and automation shows `on` in HA, it IS working
3. Server-side validation only for full audits — expect false positives

## What's Safe to Edit

- ✅ `automations.yaml`, `scenes.yaml`, `scripts.yaml`, `configuration.yaml`, `secrets.yaml`
- ❌ `.storage/` — managed by HA at runtime, local changes get overwritten on next restart

## HA Automation Pitfalls (Deep Dive)

See `references/ha-automation-pitfalls.md` for 10 production-debugged YAML traps including unquoted time values, missing action keys, yaml.dump() append corruption, numeric state edge cases, and the `.storage/` write hazard.
