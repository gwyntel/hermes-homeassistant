# EVSE Relay Protection — Design Pattern

## The Problem

When a J1772 connector is plugged into an EV but charging is complete or suspended by the EVSE, many vehicles periodically "test" or "probe" the charger:

- Vehicle draws high power briefly (varies by vehicle, typically 3-7kW for ~10s)
- EVSE allows the brief draw, then cuts power as charging is suspended
- Cycle repeats on a regular interval (typically 30-60 min depending on vehicle)
- Each cycle: relay contactor **clicks ON then OFF** — audible, causes wear
- **Neither the vehicle nor the EVSE can disable this behavior through configuration**

The relay contactor is rated for a finite number of cycles. Overnight, a car can trigger 8–16+ unnecessary relay cycles. Over months, this accelerates contactor wear and creates noise nuisance in attached living spaces.

## The Solution: 3-Automation Relay Protection

### Automation 1: Disable When Idle

**Trigger**: numeric_state — power sensor below threshold for a grace period
**Condition**: J1772 still connected AND charger switch is ON
**Action**: Turn OFF charger switch(es)

```yaml
- id: evse_relay_protect_idle_disable
  alias: "EVSE Relay Protect - Disable When Idle"
  description: "Disable EVSE when charging complete to prevent test-probe relay cycling"
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

**Tuning the grace period**: Must be shorter than your vehicle's probe interval. If probes come at ~30-60 min, use 15 min. The grace period ensures the relay is disabled before the first unnecessary cycle after charging completes.

**Tuning the power threshold**: Set below the minimum observed sustained charging power during CV taper. Monitor your vehicle's charging profile and pick a value with safe margin. 100W works well for most 240V L2 setups where CV taper minimums are 200W+.

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

**Why**: Covers all re-enable scenarios — late arrivals, weekend plug-ins, any time. No weekday/time assumptions.

### Automation 3: Enable at Off-Peak Start

**Trigger**: time — when off-peak rates begin
**Condition**: J1772 connected AND charger switch is OFF
**Action**: Turn ON charger switch(es)

```yaml
- id: evse_relay_protect_offpeak_enable
  alias: "EVSE Relay Protect - Off-Peak Enable"
  description: "Re-enable EVSE when off-peak rates start"
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

**Why**: If the car is plugged in before off-peak hours and idle-disable kills the charger, this re-enables it when rates drop. Only fires if charger is OFF — no-op if already charging. Adjust the time to match your utility's off-peak schedule.

## Tuning Parameters

| Parameter | Default | How to Determine |
|-----------|---------|-----------------|
| **Power threshold** | 100W | Monitor power during CV taper. Set below minimum sustained charge power. |
| **Grace period** | 15 min | Must be shorter than vehicle probe interval. Observe your vehicle's cycle timing. |
| **Off-peak trigger** | 00:00:00 | Match your utility's off-peak start time. Omit this automation if no TOU rates. |

## Design Principles

- **Power-based detection** over state strings — firmware typos and version differences make state strings unreliable across EVSE brands
- **Event-driven, not time-based** — idle-disable and plug-in-enable work any time of day
- **Grace period < probe interval** — ensures relay is disabled before first unnecessary cycle
- **Never kills active charging** — disable requires power below threshold for the full grace period
- **Auto-recovery on plug-in** — if someone unplugs and re-plugs, charger re-enables immediately
- **No schedule assumptions** — driver routines vary, dynamic > hardcoded

## Dual-Switch Management

Some EVSEs (e.g., Grizzl-E) have a separate cloud/OCPP control switch alongside the charge switch. Both must be toggled on every action. If your EVSE only has a charge switch, omit the cloud_control actions from the templates above.

## Production Notes

1. **Vehicle test probes are unavoidable** — J1772 handshake logic probes periodically. Only fix: disable the EVSE relay entirely so the vehicle can't complete the handshake.

2. **YAML time values MUST be quoted** — `at: 00:00:00` parses as integer. Always `at: "00:00:00"`.

3. **HA automation action format requires `data: {}` and `metadata: {}`** — without these keys, validation or runtime may fail.

4. **Server-side validation is stricter than runtime** — `hass --config check` fails many working automations. If client-side validation passes and the automation shows `on`, it works.

5. **EVSE API fields may be inverted** — some EVSEs use inverted logic (e.g., evseEnabled=1 means disabled). The HA switch entity usually handles this, but verify when hitting the API directly.

6. **Prefer power-based conditions over state strings** — firmware state strings can have typos and vary across versions. Numeric conditions are unambiguous.

7. **`yaml.dump()` append danger** — when modifying automations.yaml programmatically, always read → modify → write entire file (mode `'w'`), never append.

8. **Relay cycling is audible** — contactor clicks are loud enough to hear in adjacent rooms. Noise nuisance is a valid motivation alongside contactor wear.

9. **Zombie entities after removal** — after removing automation YAML, old entities may persist as `unavailable`. Harmless, cleaned up on next HA restart.
