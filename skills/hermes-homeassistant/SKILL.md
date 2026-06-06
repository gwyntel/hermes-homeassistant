---
name: hermes-homeassistant
description: Home Assistant configuration management tools for Hermes Agent
version: 2.0.0
author: gwyntel
license: Apache 2.0
required_environment_variables:
  - name: HA_HOST
    prompt: Home Assistant SSH host (e.g., homeassistant.local)
    help: The hostname or IP address of your Home Assistant instance for SSH access.
  - name: HA_TOKEN
    prompt: Home Assistant Long-Lived Access Token
    help: Create this in your Home Assistant user profile under 'Long-lived access tokens'.
  - name: HA_URL
    prompt: Home Assistant URL (e.g., http://homeassistant.local:8123)
    help: The base URL of your Home Assistant instance.
metadata:
  hermes:
    requires_tools: [make]
---

# Home Assistant Skill

This skill provides commands to manage your Home Assistant configuration, validate it, and explore entities.

## Activation Triggers

- **Directory Presence**: This skill is automatically recommended when working within the `hermes-homeassistant` project directory.
- **Explicit Invocation**: You can explicitly invoke this skill using `/skills hermes-homeassistant`.

## Commands

- `make pull`: Pull current configuration from Home Assistant via rsync + validate-client.
- `make push`: Validate-client + push to Home Assistant + reload.
- `make validate-client`: Run client-side validation (YAML syntax + entity refs). This is the pre-push gate.
- `make validate`: Run full validation suite including ha_official (may produce false positives).
- `make validate-yaml`: YAML syntax check only.
- `make validate-references`: Entity reference check only.
- `make backup`: Create a timestamped backup of the current local configuration.
- `make status`: Show configuration status and entity summary.
- `make entities [--domain X]`: Explore available entities in the registry.
- `make reload`: Reload HA config via API without pushing.
- `make check-env`: Verify .env configuration and SSH connectivity.

## Validation Tier

`make push` and `make pull` use **`validate-client`** as their gate — YAML syntax + entity reference checks only. The `ha_official_validator` is excluded because it produces false positives on many working automations. Use `make validate` for a full audit when needed.

## Usage Guide

All commands should be run from the root of the project directory.

### Pulling Configuration
```bash
cd <project_dir> && make pull
```

### Pushing Configuration
```bash
cd <project_dir> && make push
```

### Validating Changes
```bash
cd <project_dir> && make validate-client   # Fast, reliable gate
cd <project_dir> && make validate          # Full suite (may have false positives)
```

### Exploring Entities
```bash
cd <project_dir> && make entities
cd <project_dir> && make entities ARGS='--domain climate'
cd <project_dir> && make entities ARGS='--search motion'
```

## Environment Variables

Required in `.env`:
- `HA_HOST` - SSH hostname or IP of your Home Assistant instance
- `HA_TOKEN` - Long-lived access token from HA user profile
- `HA_URL` - Base URL of your Home Assistant instance
- `HA_REMOTE_PATH` - Remote config path (default: `/config/`)
- `SSH_IDENTITY` - Path to SSH private key (default: `~/.ssh/id_ed25519_agent`)
