---
name: hermes-homeassistant
description: Instance-specific Home Assistant config management using this repository's Makefile, SSH, rsync, and validation gates. Configure your own deployment before use; portable HA patterns are in homeassistant-management.
version: 2.1.0
author: gwyntel
license: Apache-2.0
metadata:
  hermes:
    tags: [home-assistant, deployment, rsync, validation]
    related_skills: [homeassistant-management]
---

# Home Assistant Instance Management

This is the deployment-specific layer for an installation using this repository. The target system is Home Assistant; the agent running these instructions may be Hermes, Claude Code, Codex, or another agent. Portable HA patterns and bundled validators are in `homeassistant-management`.

## Configure your deployment first

Set values in the repository's ignored `.env` using `.env.example`: `HA_HOST`, `HA_TOKEN`, `HA_URL`, `HA_REMOTE_PATH`, and (if needed) `SSH_IDENTITY`. Use your own reachable HA host, API URL, config path, and SSH identity. Do not assume any host, key, token location, username, or project directory from another operator's setup. Never put credentials in tracked files or prompts. Confirm target and intended changes before any operation that writes to HA.

## Commands

From this cloned repository, after reviewing its configuration:

- `make pull`: Pull config via rsync + validate-client
- `make push`: Validate-client + push to HA + reload (writes to target)
- `make validate-client`: YAML syntax + entity references (push/pull gate)
- `make validate`: Full suite including ha_official (may produce false positives)
- `make validate-yaml`, `make validate-references`: focused checks
- `make backup`, `make status`, `make entities [--domain X]`
- `make reload`: Reload HA config via API (acts on target)
- `make check-env`: Verify configured environment and SSH connectivity

`make push` and `make reload` are state-changing. Never run them without explicit user authorization and a verified target. Do not edit HA `.storage/` runtime state.

## Validation

`make push`/`make pull` use `validate-client`; the official validator may report false positives. See the `homeassistant-management` skill for portable rationale and automation patterns.

## Direct SSH alternative

If needed, use the configured host and identity, not another operator's private host/key:

```bash
set -a
. ./.env
set +a
SSH_OPTS=()
if [ -n "${SSH_IDENTITY:-}" ]; then SSH_OPTS=(-i "$SSH_IDENTITY"); fi
scp "${SSH_OPTS[@]}" local_file "$HA_HOST:$HA_REMOTE_PATH/path/"
```

Review the exact destination and obtain authorization before writing. Then reload through the HA UI/API only when explicitly authorized.

## Agent capability adapters

The workflow is tool-agnostic. Use the agent's shell/terminal for repository commands, SSH, and validators. For HA API calls, use an available Home Assistant integration/tool, or `curl` with `HA_URL` and `HA_TOKEN` from the local ignored environment; never print or expose token values. If a capability is unavailable, explain the requirement and provide commands for the operator rather than assuming Hermes-specific tools exist.
