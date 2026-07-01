# Adding hardware without orphaning

The whole design optimizes this path. In the common case it is **one line**.

## Case 1 — another device of an existing role (99% of adds)

1. Add a host line under the correct group in `ansible/inventory/hosts.yml`:
   ```yaml
   core_switches:
     hosts:
       core-sw-06: { ansible_host: 10.0.1.16, site: chi-dc1, mgmt_serial: FOC1116 }
   ```
2. Provision it:
   ```bash
   ansible-playbook ansible/playbooks/device_provision.yml -l core-sw-06
   ```

That's it. The device inherits `core_switches.yml` (monitoring profile + compliance controls +
tags). On discovery the auto-tag rule stamps `net_role=core_switch`, and every tag-scoped alert,
dashboard, zone, and the retention bucket already apply. **No Dynatrace edits.**

## Case 2 — a brand-new role (rare)

1. Add a group in `hosts.yml` + a `group_vars/<role>.yml` (copy an existing one, change
   `net_role` / `net_class` / `compliance_controls`).
2. Extend the role set in the CaC layer:
   - Monaco: the auto-tag/zone configs already key on `managed_by`; add a role-specific
     auto-tag only if you need role-level alert scoping.
   - Terraform: add one line to `var.device_roles` — `for_each` does the rest.
3. `ansible-playbook ansible/playbooks/dynatrace_sync.yml`

## Retiring hardware

```bash
ansible-playbook ansible/playbooks/device_retire.yml -l core-sw-06   # evidence + decommission event
# then remove the host line from hosts.yml and commit
```
The entity stops matching the tag scope and ages out. No alert/dashboard cleanup.

---

# Complexity & effort — what adding / replacing actually costs

The honest answer: **low and bounded**, because the role/tag contract means you describe a device
*once* and every plane inherits from it. The effort to add the 500th switch is the same one line as
the 6th — it does **not** scale with fleet size. Here is the effort per scenario, split across the
two planes a device touches: the **NCM / compliance-insight plane** (does it show up correctly in the
dashboard and evidence?) and the **observability / extension plane** (is it monitored as a live
entity — interfaces, CPU, up/down?).

### Add a device of an existing role (the 99% case)

| Plane | What you touch | Effort | Automatic afterwards? |
|-------|----------------|--------|-----------------------|
| Inventory | `+1 line` in `hosts.yml` (host, mgmt IP, site, serial) | 1 line | — |
| Provision | `device_provision.yml -l <host>` | 1 command | idempotent baseline pushed |
| **NCM / compliance** | *nothing* — inherits the role's `compliance_controls`; self-tags `net_role` | **0** | ✅ appears in the dashboard's dynamic tiles (matrix, heatmap, all-controls table, KPIs) with no tile edits |
| **Observability / extension** | add the mgmt IP to the role's `snmp_targets` **or** rely on the `snmp-auto-discovery` extension | 0–1 line | ✅ entity created + metrics flow; auto-tags / zone / alerts bind by tag |
| Dynatrace console | *nothing* | **0** | — |

**Total: ~1–2 lines + 1 command.** No dashboard edits, no alert edits, no zone edits — on either plane.

### Replace a device (RMA / model refresh, same role)

| Plane | What you touch | Effort | Notes |
|-------|----------------|--------|-------|
| Inventory | update `mgmt_serial` (and IP only if it changed) | 0–1 line | hostname/role usually unchanged |
| Run | `device_replace.yml -l <host>` | 1 command | opens a maintenance window (suppresses expected noise), provisions the new box, rebinds by tag |
| **NCM / compliance** | *nothing* | **0** | new box self-tags the same role; compliance re-runs; the swap is visible in the evidence trail; dashboard unchanged because it's tag-bound, not serial-bound |
| **Observability / extension** | *nothing* if IP unchanged; else 1 line in `snmp_targets` | 0–1 line | entity re-binds by tag; the monitoring config already targets the role |
| Dynatrace console | *nothing* | **0** | — |

**Total: ~1 command.** This is the payoff of tag-based binding: the thing that changes on an RMA (the
serial / entity ID) is exactly the thing nothing is wired to.

### Add a brand-new role (rare)

| Plane | What you touch | Effort |
|-------|----------------|--------|
| Inventory | new group in `hosts.yml` + a `group_vars/<role>.yml` (copy an existing one; set `net_role` / `net_class` / `compliance_controls`) | ~1 small file |
| CaC (Terraform) | `+1 entry` in `var.device_roles` (auto-tag / zone / alert extend via `for_each`) + `+1 entry` in `var.snmp_targets` | 2 lines |
| Run | `dynatrace_sync.yml` then `device_provision.yml` | 2 commands |
| **NCM / compliance** | *nothing extra* — dashboard tiles group by `net_role`, so the new role appears automatically; new controls surface in the dynamic matrix / heatmap / all-controls tiles with no tile edits | **0 tile edits** |
| **Observability / extension** | the new role's `snmp_targets` entry (above) is all the extension config needs | (included above) |

**Total: one small group_vars file + ~2 lines of CaC + 2 commands** — still all in git, still one apply.

### Where the real (one-time) effort actually is

To keep expectations honest, the *bounded, per-device* effort above assumes three **one-time**
foundations are in place — adoption steps, not per-device work:

1. **Vendor config templates.** `device_config` ships as a working shape; wiring the baseline push +
   `ios_facts` / `nxos_facts` gather to your actual platforms is a one-time per-vendor task.
2. **ActiveGate + SNMP credentials.** The extension plane polls from an ActiveGate group with SNMP
   reach to the mgmt network. Standing that up (and setting `enable_snmp_monitoring = true`) is
   one-time infra. See [NCM-INSIGHTS-AND-FEASIBILITY.md](NCM-INSIGHTS-AND-FEASIBILITY.md) §7.
3. **Auto-discovery vs. explicit targets.** With the `snmp-auto-discovery` extension a new device in
   a monitored subnet needs **zero** extension-config lines; with explicit `snmp_targets` it needs
   one. Pick per your change-control preference.

### The contrast that matters

In a console-driven / per-device NCM tool, adding or replacing a device is **linear effort with
orphaning risk** — you re-point policies, re-scope alerts, re-add it to dashboards, and a missed step
silently drops it from compliance. Here the same operation is **one line (or one command) with no
orphaning possible**, because binding is by role tag and every plane — compliance evidence, the NCM
dashboard, and the extension monitoring config — inherits from that single description.
