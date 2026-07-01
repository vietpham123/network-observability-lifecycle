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
