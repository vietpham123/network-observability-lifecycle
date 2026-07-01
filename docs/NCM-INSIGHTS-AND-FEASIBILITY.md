# Network NCM & Observability — Insights & Feasibility

*A plain-language brief for a network team evaluating this approach. What each tool owns, how
Dynatrace turns the data into NCM-style insight, and why the Day-2 / Day-3 lifecycle is safe to
run. Everything marked **Verified** below was actually executed against a live Dynatrace tenant
while building this repo — not asserted from a diagram.*

---

## 1. The one-paragraph version

This is a **strangler-friendly, as-code replacement for the config-compliance + change-tracking
half of a tool like SolarWinds NCM**, built on tools a network team can read and own. Ansible does
the device work and evaluates config compliance; Terraform (or Monaco) declares the Dynatrace
config; Dynatrace stores the compliance evidence and renders the NCM report. The keystone that
makes ongoing operations safe is **tag-based binding** — nothing is wired to a device serial or an
IP, so hardware swaps, RMAs, and refreshes never orphan an alert or a dashboard.

---

## 2. What each tool manages (separation of concerns)

| Tool | Owns | Does **not** own | Why it's here |
|------|------|------------------|---------------|
| **Ansible** | The **device plane** + the **orchestration**: provision / update / replace / retire, and the ISO-27001 compliance evaluation. Ships results to Dynatrace. | Dynatrace platform config (delegates that to Terraform/Monaco). | Network teams already think in inventory + playbooks; it's imperative where devices need imperative steps, idempotent where they don't. |
| **Terraform** *(or Monaco)* | The **Dynatrace config plane** as code: auto-tag rules, management zones, log-processing, tag-scoped alerts, retention bucket, dashboards. | Touching devices. | One declarative source of truth for the observability config; `plan` shows drift before it's applied. Terraform and Monaco are two interchangeable engines for the same job — pick one. |
| **Dynatrace (Grail)** | The **data + insight plane**: ingests compliance evidence and change events, retains them, and answers questions via DQL (the dashboards). | Deciding what "compliant" means (that's the Ansible control catalog). | Durable, queryable, long-retention evidence store + the reporting surface — the NCM report. |
| **Git / GitHub** | The **system of record**. Every device, every control, every tag, every dashboard is a file with history. | — | Audit trail and rollback for the *whole system*, not just device configs. |

**Mental model:** Ansible acts, Terraform declares, Dynatrace remembers and reports, Git records.

---

## 3. The keystone: configuration management via **tags** (why Day-2/3 is safe)

This is the single most important thing for a network team to internalise, because it's what makes
the ongoing lifecycle boring (in a good way).

**Everything binds by tag, never by identity.** A device is described once, by *role*, in a
`group_vars` file:

```
net_role   = core_switch      # what it is
net_site   = chi-dc1          # where it is
net_class  = switch           # its category
managed_by = ansible-caac     # proof it's owned as-code
```

Those four keys are a **contract**. The same keys are referenced by the auto-tag rules, the
management zone, every alert scope, the retention bucket filter, and the dashboard queries. Because
the binding is `tag(net_role:core_switch)` and **not** `device FOC1115` or `10.0.1.15`:

- **Swap the hardware** → the replacement gets the same role tag on provision → every alert,
  dashboard, and zone instantly applies to the new box. Zero Dynatrace edits.
- **Add a device** → one line in the inventory under the right group; it inherits the entire
  monitoring + compliance profile. (See [ADDING-HARDWARE.md](ADDING-HARDWARE.md) — it's literally one line.)
- **Retire a device** → remove the line; nothing else references it by name, so nothing dangles.

This is the opposite of the classic NCM failure mode where a device replacement quietly drops out
of a compliance policy because the policy was pinned to the old serial or node ID.

---

## 4. How Dynatrace handles the data for NCM insight

The flow is deliberately simple and inspectable:

```
Ansible compliance run
   → per-device JSON evidence  (device, role, site, per-control PASS/FAIL, ISO ref, failed_count)
   → POST /api/v2/logs/ingest  (log.source = "ansible-compliance")
   → Grail (Dynatrace's data lakehouse) stores it, immutable, long-retention
   → DQL queries shape it on demand
   → Dashboard tiles render the NCM report
```

Key properties that matter to a network + audit team:

- **Structured, not screen-scraped.** Each control ships as `{control_key, iso_control, title,
  result}` mapped to an **ISO/IEC 27001:2022 Annex A** control, so the evidence carries audit
  context, not just a pass/fail bit.
- **Schema-on-read (DQL).** You don't pre-model the report. The same raw evidence answers "posture
  by site", "which ISO controls fail most", "show me device X's history" — just different queries.
  New questions never require re-ingesting data.
- **Long-retention evidence bucket.** Compliance records land in a dedicated Grail bucket with a
  multi-year retention (audit-configurable), giving you a continuous, tamper-evident evidence
  trail rather than a point-in-time PDF.
- **Latest-state vs. history, both free.** `dedup device.name, sort:{timestamp desc}` gives current
  posture; dropping the dedup gives the full timeline. The dashboard uses both.

---

## 5. The NCM report (what the dashboard actually shows)

A single **Network NCM & Compliance** dashboard, deployed as code, gives a SolarWinds-NCM-style view:

| Tile | NCM equivalent |
|------|----------------|
| Devices evaluated · Compliance % · Devices in drift · Open control failures | Compliance summary KPIs |
| **Compliance matrix — controls per device (✓/✗)** | The per-requirement **crosstab**: devices as rows, controls as columns, a check or cross in every cell |
| **Compliance heatmap — device × ISO control (green/red)** | The at-a-glance "scan for red" grid |
| **All controls — every device × requirement (✓/✗)** | The exhaustive checklist; fully dynamic, scales to any control count |
| Current compliance status by device | Device policy report |
| ISO 27001 control violations | Policy-violation breakdown |
| Control failures by role / by site | Grouped posture |
| Compliance drift over time | Trend / historical compliance |
| Recent compliance evaluations | Audit trail |

A reviewer can scroll the matrix and see exactly what's in or out of compliance per device, per
control — the green-check / red-x experience — and click into the trend or audit trail for history.

---

## 6. Day-2 / Day-3 feasibility — mapped to operations

Every lifecycle operation is a playbook that also produces its own evidence. (Full runbook:
[DAY2-DAY3-RUNBOOK.md](DAY2-DAY3-RUNBOOK.md).)

| Operation | Play | Safety property for the network team |
|-----------|------|--------------------------------------|
| Provision / refresh | `device_provision.yml` | Idempotent baseline; device self-tags and inherits all monitoring on discovery. |
| Update (firmware/config) | `device_update.yml` | Runs one device at a time: **pre-check → apply → change event on the timeline → post-check → auto-rollback if the post-check regresses.** |
| Replace (RMA/failure) | `device_replace.yml` | Maintenance event mutes expected noise; replacement rebinds by tag. |
| Retire | `device_retire.yml` | Final compliance snapshot + decommission event; nothing orphans. |
| Compliance sweep | `compliance_check.yml` | Fleet-wide evidence refresh, on demand or scheduled. |

Why a cautious network team can trust this:

1. **Change is gated by tests.** The update path won't leave a device in a worse compliance state —
   a failed post-check triggers rollback. That's the safety net that makes automated change palatable.
2. **Every change is on the Davis timeline.** Config changes emit events attached by tag, so if a
   change later correlates with an incident, the timeline already shows it.
3. **Drift is caught both ways.** Device drift shows up in the compliance evidence; *platform* drift
   (someone hand-edits a dashboard or mutes an alert in the UI) is caught by the CI diff of live
   Dynatrace config against git.
4. **Nothing is a black box.** Controls are readable YAML, tags are a documented contract, queries
   are plain DQL, and the whole thing is in git with history.

---

## 7. What was proven live (evidence) — and the honest prerequisites

### Test environment this was validated against

This was validated the way a network team would run a **proof in their own test/dev environment** —
a small, representative fleet against a real observability backend, not production hardware:

| Component | What was used |
|-----------|---------------|
| **Observability backend** | A **live Dynatrace Gen3 (Grail) tenant** — real Log Ingest, real DQL, real dashboards. Not a mock. |
| **Network fleet** | A **6-device topology across 3 roles and 2 sites** — 3 core switches (`chi-dc1`), 2 edge routers (`chi-dc1`, `mke-dc2`), 1 perimeter firewall. |
| **Device representation** | Each device was driven by its **running-config fixture** (Cisco-IOS-style config), which the compliance role parses — the *same code path* a real or virtualized device feeds. The device layer was config-fixture-driven, **not** live network-OS SSH sessions. |
| **Control node** | Ansible-core 2.21 (Python venv) on macOS; Terraform 1.14 with the `dynatrace-oss/dynatrace` provider; `dtctl` 0.22 (SSO/OAuth) for DQL + dashboard deploy. |

**Why this is representative — and how a virtual lab plugs in unchanged.** The compliance engine
evaluates **running-config text**; everything downstream (structured evidence → Log Ingest → Grail →
dashboard) is identical regardless of where that config came from — a physical device, a
**virtualized network OS**, or a fixture. So the exact validation an org would run in test/dev is a
drop-in: stand up a **containerlab / vrnetlab topology** (e.g. Arista cEOS, Nokia SR Linux, Cisco
IOL — the same virtual devices used in most network test/dev labs), point the Ansible inventory at
it, and swap the config-gather step from the fixture to `ios_facts` / `nxos_facts`. Nothing in the
Dynatrace pipeline or the dashboard changes. This build exercised that entire pipeline end-to-end
with representative fleet data; the remaining adoption step is sourcing the config from live (or
virtual) devices instead of fixtures.

**Verified in a live Dynatrace tenant during this build:**

- Terraform deployed the Dynatrace config — **6 objects applied and confirmed via API**: 3 role
  auto-tags, the management zone, the tag-scoped compliance-drift alert, the log-processing rule.
  (`terraform plan/apply` clean; objects queried back.)
- The compliance sweep ran against a **6-device fleet across 3 roles** (switches, routers, firewall)
  evaluating **20 device-relevant controls / 12 ISO Annex A references**, shipped structured
  evidence, and it was **read back via DQL**: **3 devices compliant, 3 in drift, 9 control failures
  total** — e.g. `core-sw-05` failing telnet/SNMP/NTP/port-security/banner. Every result reproduced
  on the dashboard.
- The NCM dashboard — including the per-control **crosstab**, the **heatmap**, and a fully-dynamic
  **all-controls table** (every device × requirement, scales to any control count) — deployed as
  code and **rendered that live data** (13/13 tiles validated).

**Honest prerequisites / caveats (so there are no surprises):**

- **Two planes, two prerequisites.** The *evidence + reporting* plane (compliance logs → dashboard)
  works today off log data alone. The *tag-based alerting/zone* plane binds to Dynatrace **device
  entities**, which requires the devices to be monitored as entities (SNMP/extension or custom-device
  ingest). Standing up that monitoring is the one additional Day-0 step to light up tag-scoped
  alerts and zones; it does not affect the NCM report.
- **Change events need an entity to attach to.** Events posted with an `entitySelector` that matches
  no monitored entity are dropped by design. Same fix as above: have the devices present as entities
  (or route change history as log/bizevents if entity-less change history is preferred).
- **Grail bucket + DQL read-back need a platform token.** The classic API token deploys the config
  and ingests data; managing the Grail retention bucket and running DQL programmatically use a
  platform token / OAuth. (The bucket is opt-in in Terraform for exactly this reason.)
- **The device-config templates are illustrative.** The compliance probes and baseline templates
  ship as a working shape (string-match probes over a device config); wiring them to real
  `ios_facts` / `nxos_facts` for your fleet is the expected adoption step.

---

## 8. Bottom line

The feasibility question — *"can as-code tooling really cover Day-2/Day-3 network config compliance
and give us NCM-style insight in Dynatrace?"* — was answered by doing it: config deployed, evidence
ingested, and the NCM report rendered against live data. The design's tag-based binding is what
makes the ongoing operation low-risk: **describe a device once by role, and every swap, add, update,
and retire keeps its monitoring and compliance intact with no manual Dynatrace work.** The remaining
work to go from this proof to production is standard adoption (monitor the devices as entities, wire
the real config facts), not a rethink of the approach.
