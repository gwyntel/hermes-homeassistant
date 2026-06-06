# EVSE Relay Protection — Complete Design Pattern

## The Problem

When a J1772 connector is plugged into an EV but charging is complete or suspended by the EVSE, many vehicles (especially Chevy Bolt) periodically "test" or "probe" the charger:

- Draws ~6.8kW (28A on 240V) for ~10 seconds
- EVSE allows the brief draw, then cuts power
- Cycle repeats every 30–60 minutes indefinitely
- Each cycle: relay contactor **clicks ON then OFF** — audible, causes wear
- Energy per test: ~0.021 kWh (negligible)
- **Neither the vehicle nor the EVSE can disable this behavior through configuration**

The relay contactor is rated for a finite number of cycles. Overnight, the car can trigger 8–16 unnecessary relay cycles. Over months, this accelerates contactor wear and creates noise nuisance in attached living spaces.

## The Solution: 3-Automation Relay Protection

### Automation 1: Disable When Idle

**Trigger**: numeric_state — power sensor below threshold for a grace period
**Condition**: J1772 still connected AND charger switch is ON
**Action**: Turn OFF charger switch(es)

```yaml
- id: evse_relay_protect_idle_disable
  alias: "EVSE Relay Protect - Disable When Idle"
  description: "Disable EVSE when charging complete to prevent Bolt test-probe relay cycling"
  triggers:
    - trigger: numeric_state
      entity_id: sensor.evse_power
      below: 100
      for:
        minutes: 15
  conditions:
    - condition: state
      entity_id: binary_sensor.evse_pilot_connected
      state: "on"
    - condition: state
      entity_id: switch.evse_charge
      state: "on"
  actions:
    - action: switch.turn_off
      data: {}
      metadata: {}
      target:
        entity_id: switch.evse_charge
    - action: switch.turn_off
      data: {}
      metadata: {}
      target:
        entity_id: switch.evse_cloud_control
```

**Why 15 min**: Bolt probes come at ~30-60 min intervals. 15 min < first probe → relay kills before any unnecessary cycling. The grace period must be shorter than the probe interval.

**Why 100W**: The lowest observed charging power during CV taper was ~274W (which recovers in seconds). 100W provides safe margin below actual charging but well above zero-idle. Adjust threshold based on your vehicle/EVSE — monitor power during CV taper and set below the minimum observed sustained charge power.

### Automation 2: Enable on Plug-In

**Trigger**: state — J1772 pilot sensor off→on
**Condition**: charger switch is OFF
**Action**: Turn ON charger switch(es)

```yaml
- id: evse_relay_protect_plugin_enable
  alias: "EVSE Relay Protect - Enable on Plug-In"
  description: "Re-enable EVSE when J1772 plugged in"
  triggers:
    - trigger: state
      entity_id: binary_sensor.evse_pilot_connected
      from: "off"
      to: "on"
  conditions:
    - condition: state
      entity_id: switch.evse_charge
      state: "off"
  actions:
    - action: switch.turn_on
      data: {}
      metadata: {}
      target:
        entity_id: switch.evse_charge
    - action: switch.turn_on
      data: {}
      metadata: {}
      target:
        entity_id: switch.evse_cloud_control
```

**Why**: Covers all re-enable scenarios — late arrivals, weekend plug-ins, any time. No weekday/time assumptions needed. If the EVSE scheduling handles off-peak start independently, this automation is a safety net.

### Automation 3: Enable at Midnight (Off-Peak Start)

**Trigger**: time — midnight (when off-peak rates start in many utility plans)
**Condition**: J1772 connected AND charger switch is OFF
**Action**: Turn ON charger switch(es)

```yaml
- id: evse_relay_protect_midnight_enable
  alias: "EVSE Relay Protect - Midnight Enable"
  description: "Re-enable EVSE at midnight when off-peak rates start"
  triggers:
    - trigger: time
      at: "00:00:00"
  conditions:
    - condition: state
      entity_id: binary_sensor.evse_pilot_connected
      state: "on"
    - condition: state
      entity_id: switch.evse_charge
      state: "off"
  actions:
    - action: switch.turn_on
      data: {}
      metadata: {}
      target:
        entity_id: switch.evse_charge
    - action: switch.turn_on
      data: {}
      metadata: {}
      target:
        entity_id: switch.evse_cloud_control
```

**Why**: If the car is plugged in at 11:30pm and idle-disable kills the charger before midnight, this re-enables it when off-peak starts. Only fires if charger is OFF — no-op if already charging.

## Tuning Parameters

| Parameter | Default | How to Determine |
|-----------|---------|-----------------|
| **Power threshold** | 100W | Monitor power during CV taper (lowest sustained charge). Set below minimum observed. |
| **Grace period** | 15 min | Must be shorter than vehicle probe interval. Default 15 min < typical 30-60 min probe cycle. |
| **Midnight trigger** | 00:00:00 | Adjust to match your utility's off-peak start time. |

## Design Principles

- **Power-based detection** over state strings — firmware typos and version differences make state strings unreliable
- **Event-driven, not time-based** — idle-disable and plug-in-enable work any time of day
- **Grace period < probe interval** — ensures relay is disabled before first unnecessary cycle
- **Never kills active charging** — disable condition requires power below threshold for the full grace period
- **Auto-recovery on plug-in** — if someone unplugs and re-plugs, charger re-enables immediately
- **No schedule assumptions** — driver routines vary, late arrivals happen, weekends differ

## Dual-Switch Management

Some EVSEs (e.g., Grizzl-E) have a separate cloud/OCPP control switch alongside the charge switch. Both must be toggled on every action:

1. `switch.evse_charge` — controls whether the EVSE allows charging
2. `switch.evse_cloud_control` — controls whether the EVSE reports to cloud/OCPP

If your EVSE only has a charge switch, omit the cloud_control actions from the templates above.

## Lessons Learned

1. **Vehicle test probes are unavoidable** — the J1772 handshake logic probes periodically regardless of EVSE scheduling. Only fix: disable the EVSE relay entirely so the car can't complete the handshake.

2. **YAML time values MUST be quoted** — `at: 00:00:00` parses as integer. Always `at: "00:00:00"`.

3. **HA automation action format requires `data: {}` and `metadata: {}`** — without these keys, validation or runtime may fail.

4. **Server-side validation is stricter than runtime** — `hass --config check` fails many working automations. If client-side validation passes and the automation shows `on`, it works.

5. **EVSE API fields may be inverted** — e.g., Grizzl-E `evseEnabled=1` means charging DISABLED. The HA switch entity usually handles the inversion, but verify when hitting the API directly.

6. **Firmware state strings can have typos** — "Vehile Charging", "Charing Complete". Never match against corrected spellings. Use power-based conditions instead.

7. **`yaml.dump()` append danger** — when modifying automations.yaml programmatically, always read → modify → write entire file (mode `'w'`), never append.

8. **Relay cycling is audible** — the contactor click is loud enough to hear in adjacent living space. Noise nuisance is a valid motivation alongside contactor wear.

9. **Zombie entities after removal** — after removing automation YAML entries, old entities may persist as `unavailable`. Harmless, cleaned up on next HA restart.
