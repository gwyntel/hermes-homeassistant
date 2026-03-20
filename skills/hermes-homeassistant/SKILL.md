---
name: hermes-homeassistant
description: Home Assistant configuration management tools for Hermes Agent
version: 1.0.0
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
    # Activated when user is in the project dir
    requires_tools: [make]
---

# Home Assistant Skill

This skill provides commands to manage your Home Assistant configuration, validate it, and explore entities.

## Activation Triggers

- **Directory Presence**: This skill is automatically recommended when working within the `hermes-homeassistant` project directory.
- **Explicit Invocation**: You can explicitly invoke this skill using `/skills hermes-homeassistant`.

## Commands

- `ha pull`: Pull current configuration from Home Assistant via rsync.
- `ha push`: Validate local configuration and push to Home Assistant, then reload.
- `ha validate`: Run validation tests on local configuration files.
- `ha backup`: Create a timestamped backup of the current local configuration.
- `ha status`: Show configuration status and entity summary.
- `ha entities [--domain X]`: Explore available entities in the registry.

## Usage Guide

All commands should be run from the root of the project directory.

### Environment Setup

Ensure you have your `.env` file configured with the required variables. You can find an example in `.env.example`.

### Pulling Configuration
Running `ha pull` will download your current HA configuration files into the `config/` directory.
```bash
cd <project_dir> && . venv/bin/activate && make pull
```

### Pushing Configuration
Running `ha push` will first validate your local changes and then upload them to your HA instance.
```bash
cd <project_dir> && . venv/bin/activate && make push
```

### Validating Changes
Running `ha validate` performs multiple layers of checks (YAML syntax, entity references, and official HA validation).
```bash
cd <project_dir> && . venv/bin/activate && make validate
```

### Monitoring Status
Running `ha status` gives you a quick overview of your configuration and entity counts.
```bash
cd <project_dir> && . venv/bin/activate && make status
```

### Exploring Entities
Use `ha entities` to see what entities are available in your registry.
```bash
cd <project_dir> && . venv/bin/activate && python tools/entity_explorer.py
```
To filter by domain:
```bash
cd <project_dir> && . venv/bin/activate && python tools/entity_explorer.py --domain light
```
