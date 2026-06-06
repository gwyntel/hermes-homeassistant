---
name: homeassistant-management
description: Manage Home Assistant configuration, automations, and custom integrations. Use when creating or editing HA automations, deploying custom components, designing EVSE/smart-plug automation patterns, troubleshooting YAML parsing issues, or working with the HA REST API. Covers power-based automation design, relay protection patterns, validation strategies, and common YAML pitfalls.
version: 1.0.0
author: gwyntel
license: Apache-2.0
compatibility: Requires Home Assistant 2024.x+ and access to the HA REST API or SSH to the HA host
metadata:
  hermes:
    tags: [home-assistant, automation, evse, smart-home, yaml, rest-api]
    related_skills: [homeassistant-cli]
---

# Home Assistant Management

Practical knowledge for managing Home Assistant config, building reliable automations, deploying custom integrations, and avoiding common YAML/API pitfalls. Field-tested from production EVSE relay protection and multi-automation systems.

## When to Use

- Creating or editing HA automations (especially `automations.yaml`)
- Deploying custom components/integrations via SCP
- Designing power-based automations (EVSE, smart plugs, energy monitoring)
- Troubleshooting automation `unavailable` states or YAML parsing failures
- Working with the HA REST API
- Setting up validation workflows for HA config

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

**Pattern**: trigger on power sensor dropping below threshold for a grace period, then take action.

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

**Why power-based**: avoids firmware typos (e.g., "Vehile Charging" instead of "Vehicle Charging"), works across firmware versions, and provides precise threshold control.

See `references/evse-relay-protection.md` for a complete real-world example protecting an EVSE relay from vehicle probe cycling.

## Entity Naming Convention

Format: `domain.location_room_device_sensor`

Examples: `binary_sensor.home_basement_motion_battery`, `sensor.office_driveway_camera_battery`

When creating automations, discover entities first via `ha_list_entities` or entity explorer tools. Never assume entity IDs — verify them.

## Critical YAML Pitfalls

### 1. Time Values MUST Be Quoted

`at: 12:15:00` is parsed as the integer 44100 (seconds in YAML). Always write `at: "12:15:00"`. Affects `time` triggers and any colon-separated time-like value.

### 2. Automation Action Format Requires `data: {}` and `metadata: {}`

HA 2024.x+ requires these keys in action blocks. Without them, validation or runtime may fail with "Unable to determine action". Correct format:

```yaml
action:
  - action: switch.turn_off
    data: {}
    metadata: {}
    target:
      entity_id: switch.device
```

### 3. `action:` Not `service:`

HA 2024.x+ uses `action:` in automations, not the older `service:` key. Mixing them (e.g., having both `action:` and `service:` keys) causes `unavailable` state. When rebuilding automations, replace the entire YAML block — never patch individual keys.

### 4. Python `yaml.dump()` Append Danger

When modifying `automations.yaml` programmatically, `yaml.dump()` serializes the full in-memory structure. Must read → modify → write entire file (mode `'w'`), never append. Otherwise duplicate IDs and corrupted YAML result.

### 5. YAML Duplicate Key Corruption

When editing automations in-place via multiple edits, old keys (`actions:`, `conditions:`, `triggers:`) can coexist alongside new keys (`action:`, `condition:`, `trigger:`), making the automation `unavailable`. When rebuilding, always replace the entire YAML block.

## Validation Strategies

HA server-side validation (`hass --config check`) can be **stricter than the HA runtime** — it produces false positives ("Unable to determine action", "extra keys not allowed") on many working automations.

**Recommended approach**:
1. Client-side validation (YAML syntax + entity reference checks) as the push gate
2. If client-side passes and automation shows `on` in HA, it IS working
3. Server-side validation only for full audits — expect false positives
4. This is a known gap between HA's config validator and its runtime engine

## What's Safe to Edit

- ✅ `automations.yaml`, `scenes.yaml`, `scripts.yaml`, `configuration.yaml`, `secrets.yaml`
- ❌ `.storage/` — managed by HA at runtime, local changes get overwritten on next restart

## EVSE / Smart Charger Specifics

See `references/evse-relay-protection.md` for a complete EVSE relay protection pattern including:
- Chevy Bolt test-probe cycling behavior
- 3-automation design (idle-disable, plug-in-enable, midnight-enable)
- Power threshold tuning (why 100W / 15min)
- Dual-switch management (charge + cloud control)
