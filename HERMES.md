# Hermes Home Assistant Setup

This repository is a Hermes skill for managing Home Assistant configurations.

## Setup Instructions

1. **Environment Variables**:
   Create a `.env` file in the root directory with the following variables:
   ```env
   HA_HOST=homeassistant.local
   HA_TOKEN=<long-lived-token>
   HA_URL=http://homeassistant.local:8123
   ```
   *Note: These variables are required for the skill to communicate with your instance.*

2. **SSH Keys for rsync**:
   The skill uses `rsync` over SSH for the `ha pull` and `ha push` commands. Ensure you have SSH access to your Home Assistant host.
   - Install the **Advanced SSH & Web Terminal** addon in Home Assistant.
   - Configure it with your public SSH key.
   - Verify connection by running `ssh root@homeassistant.local`.

3. **Python Environment**:
   Initialize the virtual environment:
   ```bash
   make setup
   ```
   *Note: If on Linux, use `./setup-linux.sh`. On Mac, use `./setup-mac.sh`.*

4. **Skill Discovery**:
   Hermes Agent will automatically find the skill manifest at `skills/hermes-homeassistant/SKILL.md`.
   The skill is activated when you are in this directory, or by using `/skills hermes-homeassistant`.

## Commands Reference

| Command | Action |
| :--- | :--- |
| `ha pull` | Pull config from HA |
| `ha push` | Validate and push config to HA |
| `ha validate` | Run validation tests |
| `ha backup` | Create local backup |
| `ha status` | Show HA status and entity counts |
| `ha entities` | Explore HA entities |

## Environment Variables Details

- `HA_HOST`: The hostname or IP address of your Home Assistant instance for SSH access.
- `HA_TOKEN`: Your Home Assistant Long-Lived Access Token.
- `HA_URL`: The base URL of your Home Assistant instance (e.g., `http://192.168.1.100:8123`).
