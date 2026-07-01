# Day 2 / Day 3 runbook

| Scenario | Command | What happens | Evidence |
|----------|---------|--------------|----------|
| **Refresh** (planned model swap) | `device_provision.yml -l <host>` | new box configured to baseline; self-tags; inherits all monitoring | provisioning event + baseline compliance |
| **Replace** (RMA/failure) | `device_replace.yml -l <host>` | maintenance event mutes expected noise; replacement provisions + rebinds by tag | swap + re-validation in bucket |
| **Update** (firmware/config) | `device_update.yml -l <host>` | pre-check → apply → change event on device timeline → post-check → auto-rollback on regression | pre/post compliance delta; Davis correlation |
| **Retire** | `device_retire.yml -l <host>` | final snapshot + decommission event; entity ages out | final compliance record |

## The update hot path in detail

`device_update.yml` runs `serial: 1` (one device at a time) and:

1. **pre** compliance snapshot,
2. applies the update,
3. **emits a `CUSTOM_CONFIGURATION` event** attached to the device by tag — this is what puts the
   change on the timeline so Davis can correlate it with any post-change telemetry impact,
4. **post** compliance snapshot,
5. if `compliance_post_failed`, triggers `device_config` in `rollback` mode.

## Governance: catching out-of-band drift

The CI `drift-check` job runs `monaco download` and diffs live Dynatrace config against git. If
someone mutes an alert or edits a dashboard in the UI, the diff surfaces it. Wire the exit-code
gate to your policy (warn vs. fail-and-revert).

## Alert hygiene during maintenance

Always run `device_replace.yml` (or send a maintenance/marked-for-termination event) **before**
pulling a device, or you will page on a planned outage and write false compliance failures.
