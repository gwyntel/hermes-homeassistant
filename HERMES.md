# Hermes Home Assistant Setup

This repository is a Hermes skill for managing Home Assistant configurations.

## Setup Instructions

1. **Environment Variables**:
   Create a `.env` file in the root directory with the following variables:
   ```env
   HA_HOST=homeassistant.local
   HA_TOKEN=<long-lived-token>
   HA_URL=http://homeassistant.local:8123
   HA_REMOTE_PATH=/config/
   SSH_IDENTITY=~/.ssh/id_ed25519_agent
   ```
   *Note: These variables are required for the skill to communicate with your instance.*

2. **SSH Keys for rsync**:
   The skill uses `rsync` over SSH for `make pull` and `make push`. Ensure you have SSH access to your Home Assistant host.
   - Install the **Advanced SSH & Web Terminal** addon in Home Assistant.
   - Configure it with your public SSH key.
   - Verify connection by running `ssh root@homeassistant.local`.

3. **Python Environment**:
   Initialize the virtual environment:
   ```bash
   make setup
   ```

4. **Skill Discovery**:
   Hermes Agent will automatically find the skill manifest at `skills/hermes-homeassistant/SKILL.md`.
   The skill is activated when you are in this directory, or by using `/skills hermes-homeassistant`.

## Commands Reference

| Command | Action |
| :--- | :--- |
| `make pull` | Pull config from HA + validate-client |
| `make push` | Validate-client + push to HA + reload |
| `make validate-client` | YAML syntax + entity refs (fast, reliable) |
| `make validate` | Full suite including ha_official |
| `make validate-yaml` | YAML syntax only |
| `make validate-references` | Entity references only |
| `make backup` | Create local backup |
| `make status` | Show HA status and entity counts |
| `make entities` | Explore HA entities (`ARGS='--domain climate'`) |
| `make reload` | Reload HA config via API (no push) |
| `make check-env` | Verify .env + SSH connectivity |

## Validation Tier

`make push` and `make pull` use **`validate-client`** as their gate — this runs YAML syntax + entity reference checks only. The `ha_official_validator` is excluded from the gate because it produces false positives on many working automations ("Unable to determine action"). Use `make validate` for a full audit when needed.

## Environment Variables Details

- `HA_HOST`: The hostname or IP address of your Home Assistant instance for SSH access.
- `HA_TOKEN`: Your Home Assistant Long-Lived Access Token.
- `HA_URL`: The base URL of your Home Assistant instance (e.g., `http://192.168.1.100:8123`).
- `HA_REMOTE_PATH`: Remote config path on HA (default: `/config/`).
- `SSH_IDENTITY`: Path to SSH private key (default: `~/.ssh/id_ed25519_agent`).
