---
name: hermes-homeassistant
description: Instance-specific Home Assistant config management for this deployment. Makefile-driven push/pull, rsync, SSH deploy, validation gate. For portable HA knowledge (automation patterns, YAML pitfalls, EVSE relay protection), load homeassistant-management instead.
version: 2.1.0
author: gwyntel
license: Apache-2.0
metadata:
  hermes:
    tags: [home-assistant, deployment, rsync, validation]
    related_skills: [homeassistant-management]
---

# Home Assistant Instance Management

Instance-specific operational layer for this HA deployment. For portable HA knowledge (automation design patterns, YAML pitfalls, EVSE relay protection), see the `homeassistant-management` skill which is published and works for any HA setup.

## Access

- **SSH**: `root@homeassistant.nebulosa-bass.ts.net` via `~/.ssh/id_ed25519_agent`
- **HA API**: `http://192.168.86.54:8123` — token in `~/.hermes/.env` as `HASS_TOKEN`
- **Config path on host**: `/config/`
- **Project dir**: `/home/hermes/projects/hermes-homeassistant/`

## Commands

- `make pull`: Pull config from HA via rsync + validate-client
- `make push`: Validate-client + push to HA + reload
- `make validate-client`: YAML syntax + entity refs (the push/pull gate)
- `make validate`: Full suite including ha_official (expect false positives)
- `make validate-yaml`: YAML syntax only
- `make validate-references`: Entity reference check only
- `make backup`: Timestamped backup of local config
- `make status`: Config status and entity summary
- `make entities [--domain X]`: Explore entity registry
- `make reload`: Reload HA config via API
- `make check-env`: Verify .env + SSH connectivity

## Validation Tier

`make push`/`make pull` use `validate-client` as gate. `ha_official_validator` excluded (false positives). See `homeassistant-management` skill for rationale.

## Direct SSH Alternative

For single-file edits or custom_components when `make push` is overkill:

```bash
scp -i ~/.ssh/id_ed25519_agent local_file root@homeassistant.nebulosa-bass.ts.net:/config/path/
```

Then reload via API or restart HA.

## Environment Variables

Required in `.env`:
- `HA_HOST` - SSH hostname
- `HA_TOKEN` - Long-lived access token
- `HA_URL` - Base URL
- `HA_REMOTE_PATH` - Remote config path (default: `/config/`)
- `SSH_IDENTITY` - Path to SSH key
