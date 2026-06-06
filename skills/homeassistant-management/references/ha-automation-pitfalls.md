# HA Automation YAML Pitfalls

Collected from production debugging sessions. Each pitfall caused real automation failures.

## 1. Unquoted Time Values Parse as Integers

**Symptom**: Time-based triggers never fire, or fire at seemingly random times.

```yaml
# WRONG — parsed as integer 44100 (12*3600 + 15*60)
triggers:
  - trigger: time
    at: 12:15:00

# CORRECT — parsed as time string
triggers:
  - trigger: time
    at: "12:15:00"
```

YAML 1.1 treats `12:15:00` as seconds (sexagesimal). Always quote time values. This affects `at:` in time triggers and any colon-separated time-like value.

## 2. Missing `data: {}` and `metadata: {}` in Actions

**Symptom**: Automation shows `unavailable` or validation reports "Unable to determine action".

```yaml
# WRONG — missing required keys
action:
  - action: switch.turn_off
    target:
      entity_id: switch.device

# CORRECT
action:
  - action: switch.turn_off
    data: {}
    metadata: {}
    target:
      entity_id: switch.device
```

HA 2024.x+ requires `data` and `metadata` keys in action blocks. Even when there's no data to pass, include `data: {}`. This is an HA schema requirement, not optional.

## 3. `action:` vs `service:` Key Confusion

**Symptom**: Automation `unavailable` after edit, or duplicate key errors.

HA 2024.x+ uses `action:` in automations. The older `service:` key is deprecated. Mixing them (having both in one automation block) causes parse failures.

When rebuilding automations: **replace the entire YAML block**, never patch individual keys. Old keys (`service:`, `actions:`, `conditions:`, `triggers:`) can coexist alongside new keys (`action:`, `condition:`, `trigger:`) if you patch instead of replace — this creates corrupt YAML.

## 4. `yaml.dump()` Does Not Replace File Contents

**Symptom**: Duplicate automation IDs, missing automations, corrupted YAML.

```python
# WRONG — appends instead of replacing
with open("automations.yaml", "a") as f:
    yaml.dump(new_automation, f)

# CORRECT — read, modify in memory, write complete file
with open("automations.yaml", "r") as f:
    automations = yaml.safe_load(f)
automations.append(new_automation)
with open("automations.yaml", "w") as f:
    yaml.dump(automations, f)
```

## 5. Numeric State Threshold Edge Cases

**Symptom**: Automation triggers too early or not at all.

- `below: 100` triggers when value drops from 101 to 99. It does NOT re-trigger while value stays at 99 (already below threshold). It triggers again only if value goes above 100 and then drops below again.
- Add `for: minutes: N` to avoid false triggers from transient spikes. A 10-second power dip during CV taper shouldn't trigger an idle-disable if the car is still charging.
- The threshold must be BELOW the minimum observed sustained operating value (e.g., if CV taper dips to 274W but recovers, set threshold at 100W, not 200W).

## 6. State String Matching Is Fragile

**Symptom**: Automation doesn't trigger because the state string didn't match.

Device state strings are set by firmware and can contain:
- Typos: "Vehile Charging" instead of "Vehicle Charging"
- Version differences: different firmware may use different strings
- Localization: some integrations return localized state strings
- Case sensitivity: HA state matching is case-sensitive

**Prefer numeric conditions** (power, voltage, current) over string state matching when possible. Numbers are unambiguous.

## 7. Automation Reload vs HA Restart

**Symptom**: New entities don't appear after deployment.

- **Reload** (`POST /api/services/automation/reload`): picks up changes to existing automations. Fast, no downtime.
- **Restart** (`POST /api/services/homeassistant/restart`): required when:
  - Adding NEW platforms to custom integrations (e.g., adding switch.py or number.py)
  - Making changes to `configuration.yaml` that add new integrations
  - Cleaning up zombie entities (automations removed from YAML but still in entity registry as `unavailable`)

## 8. The `/api/config/automation/config` Endpoint Returns 404

**Symptom**: 404 when trying to manage automations via REST API.

This endpoint doesn't exist on most HA versions. The documented config flow API is for integrations, not automations. Automations are managed exclusively through YAML files on the host filesystem.

## 9. Custom Component Deployment Requires Exact Path

Custom integrations must be at `/config/custom_components/{integration_name}/` with:
- `__init__.py` (required)
- `manifest.json` (required — must have `domain` matching the directory name)
- Platform files (`sensor.py`, `switch.py`, etc.)

After SCP deployment, reload the integration via API. If adding NEW platform files that didn't exist before, restart HA.

## 10. `.storage/` Is Not Safe to Edit

The `.storage/` directory under HA's config is managed by HA at runtime. Local file changes get overwritten on next restart or when HA writes state. This includes entity registry, device registry, and other core data. Only modify via HA UI or API.
