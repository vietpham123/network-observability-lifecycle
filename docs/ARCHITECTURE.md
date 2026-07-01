# Architecture

Two layers, one orchestrator.

```
                          ┌────────────────────────────────────────────┐
                          │                 Ansible                     │
                          │            (top-level orchestrator)         │
                          └───────────────┬───────────────┬─────────────┘
                                          │               │
              device layer (direct)  ◄────┘               └────►  platform config layer (via CaC)
                                          │                              │
                ┌─────────────────────────▼──────┐        ┌──────────────▼───────────────┐
                │ network devices                │        │ Monaco  OR  Terraform         │
                │  • provision/update/replace/   │        │  • auto-tags (role/site/class)│
                │    retire (idempotent)         │        │  • management zones           │
                │  • compliance checks → JSON    │        │  • log processing             │
                └───────────────┬────────────────┘        │  • tag-scoped metric events   │
                                │                          │  • immutable retention bucket │
              compliance JSON   │  change/maintenance      │  • dashboards (DQL)           │
              (Log Ingest API)  │  events (Events API v2)  └──────────────┬───────────────┘
                                ▼                                         │
                        ┌───────────────────────────────────────────────▼──────┐
                        │                    Dynatrace (Grail)                  │
                        │  entities self-tag → alerts/dashboards/zones bind     │
                        │  by TAG → immutable evidence retained per event       │
                        └───────────────────────────────────────────────────────┘
```

**Division of labour** (matches Dynatrace's own guidance): the CaC tool owns Dynatrace
*configuration*; Ansible owns device management, agent/collector deployment, and orchestration.

**Why tags, not entity IDs:** an entity ID/hostname/serial changes on every refresh or RMA. A
role/site/class tag does not. Bind observability to the stable thing and hardware churn stops
breaking your monitoring.

## The entity / extension plane (what creates the device entities)

The two planes above are the *config* plane (CaC) and the *evidence* plane (compliance logs). There
is a third, which turns a device into a monitored **entity** — interfaces, throughput, errors,
CPU/mem, up/down:

```
      ┌──────────────────────────────┐        polls SNMP (v2c/v3)
      │ ActiveGate (group)           │  ───────────────────────────►  network devices (mgmt IPs)
      │  SNMP EF2.0 extensions:      │
      │   • snmp-generic-device      │  creates CUSTOM_DEVICE entities
      │   • snmp-auto-discovery      │  + interface / health metrics
      │   • cisco-* / palo-alto-*    │        │
      └──────────────────────────────┘        ▼
                                     entities self-tag (role/site/class) → alerts/zones/dashboards bind
```

This plane is **also as-code** (`dynatrace-terraform/network_extensions.tf`): the extension **version**
is pinned (`dynatrace_hub_extension_active_version` — upgrades are one-line PRs) and a **monitoring
configuration per role** (`dynatrace_hub_extension_v2_config`) targets that role's devices from an
ActiveGate group. It is gated off by default because it needs an ActiveGate with SNMP reachability.
The compliance/NCM plane does **not** depend on it; tag-scoped *alerting* does.
