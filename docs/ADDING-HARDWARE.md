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
