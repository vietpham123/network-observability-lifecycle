# network-observability-lifecycle

Reference scaffold for running **network device lifecycle (day 2 / day 3) as code**, with two
cooperating layers:

1. **Ansible** — manages the network devices themselves (provision, retire, replace, update) and
   runs the ISO compliance checks, emitting structured results.
2. **Dynatrace Configuration as Code** (Monaco *or* Terraform) — manages the *observability*
   configuration: auto-tags, management zones, log processing, tag-scoped alerts, an immutable
   retention bucket, and dashboards.

Ansible is the top-level orchestrator. It drives the device layer directly and drives the
Dynatrace platform config by invoking Monaco/Terraform. This split is deliberate and matches
Dynatrace's own guidance: Configuration-as-Code tooling manages Dynatrace *configuration*;
component/agent deployment and everything off-platform is handled by Ansible/Terraform/etc.

> ⚠️ **This is an illustrative reference, not copy-paste-to-prod.** The Ansible flow and the
> *shape* of the Dynatrace configs are real, but exact Settings 2.0 schema IDs, schema versions,
> and Terraform resource names change between Dynatrace releases. Every file that needs validating
> against your tenant/provider version is annotated with `# VERIFY:`.

---

## The one idea that prevents orphaning

Adding hardware must never mean hand-editing alerts or dashboards. So **nothing in the Dynatrace
config references a device by entity ID, hostname, or serial.** Everything is scoped by **tags**
that are derived from device *role / site / class* — attributes that live in the Ansible inventory
and get stamped onto the Dynatrace entity via auto-tag rules.

```
inventory (role/site/class)  ->  auto-tag rules (Monaco/TF)  ->  entities self-tag on discovery
                                          |
              tag-scoped alerts, dashboards, management zones, retention all bind to the TAG
```

Consequence: **adding a device = one inventory entry.** Retiring one = removing that entry (plus a
clean decommission event). The monitoring surface reconciles itself. See
[`docs/ADDING-HARDWARE.md`](docs/ADDING-HARDWARE.md).

---

## Repo layout

```
ansible/
  inventory/            <- THE surface you edit to add/remove hardware
    hosts.yml
    group_vars/         <- per-role monitoring profile + compliance baseline
    host_vars/          <- per-device overrides (example: a brand-new switch)
  playbooks/            <- device_provision / _retire / _replace / _update / compliance_check / dynatrace_sync
  roles/
    device_config/      <- (stub) vendor config push
    compliance/         <- ISO-27001 checks -> structured JSON result -> shipped to Dynatrace
    dynatrace_events/   <- emit change / maintenance / decommission events via Events API v2
dynatrace-monaco/       <- Configuration as Code, option A
dynatrace-terraform/    <- Configuration as Code, option B (pick one)
.github/workflows/      <- CI: on inventory change -> reconcile device + observability config
docs/
  ARCHITECTURE.md
  DAY2-DAY3-RUNBOOK.md
  ADDING-HARDWARE.md
```

## The lifecycle at a glance

| Event | Ansible playbook | What Dynatrace does | Evidence written |
|-------|------------------|---------------------|------------------|
| Refresh (model swap) | `device_provision.yml` | new entity self-tags -> inherits alerts/dashboards | baseline compliance pass |
| Replace (RMA) | `device_replace.yml` | maintenance event suppresses noise; re-tag rebinds | swap + re-validation |
| Update (firmware/config) | `device_update.yml` | change event on device timeline -> Davis correlates | pre/post compliance delta |
| Retire (decommission) | `device_retire.yml` | decommission event; entity ages out of tag scope | final compliance snapshot |

## Quick start

```bash
# 1. Point at your tenant
cp ansible/inventory/group_vars/all.example.yml ansible/inventory/group_vars/all.yml
$EDITOR ansible/inventory/group_vars/all.yml          # tenant URL, token via env/vault

# 2. Deploy the Dynatrace observability config ONCE (choose one)
ansible-playbook ansible/playbooks/dynatrace_sync.yml -e caac_tool=monaco
#   or: cd dynatrace-terraform && terraform init && terraform apply

# 3. Run a day-2 event
ansible-playbook ansible/playbooks/device_update.yml -l core-sw-05
```

Secrets (`DT_API_TOKEN`, device creds) come from environment variables or Ansible Vault — never
committed. See `.gitignore`.
