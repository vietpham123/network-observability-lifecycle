# =============================================================================
# Entity / topology plane — SNMP extension monitoring as code.
#
# This is what turns the network devices into monitored Dynatrace ENTITIES
# (interfaces, throughput, errors, CPU/mem, up/down) so the tag-based auto-tags,
# management zone, and metric-event alert actually bind to something. The
# compliance/NCM plane (logs → dashboard) does NOT need this; live health +
# tag-scoped alerting does.
#
# Two as-code concerns, both handled here:
#   1. VERSION (updating) — dynatrace_hub_extension_active_version pins the
#      extension version. A version bump is a one-line PR + terraform apply,
#      reviewed and diffable, not a console click.
#   2. CONFIG — dynatrace_hub_extension_v2_config declares one monitoring
#      configuration per ROLE, scoped to an ActiveGate group, targeting that
#      role's devices. Same role contract as everything else in this repo.
#
# PREREQUISITES (why this is gated off by default):
#   - An ActiveGate (env or standalone) in the group named by var.snmp_activegate_group,
#     with SNMP reachability to the device management IPs.
#   - SNMP v3 credentials (var.snmp_v3_*).
# Without an ActiveGate the monitoring config cannot poll, so enable_snmp_monitoring
# defaults to false. Flip it on once the ActiveGate + creds exist, then apply.
# =============================================================================

# --- 1. Pin the extension version (the "updating" story, as code) ------------
resource "dynatrace_hub_extension_active_version" "snmp_generic_device" {
  count   = var.enable_snmp_monitoring ? 1 : 0
  name    = "com.dynatrace.extension.snmp-generic-device"
  version = var.snmp_extension_version
}

# --- 2. One monitoring configuration per role, scoped to an ActiveGate group -
# Reuses var.device_roles (the single source of truth for roles). Device targets
# per role come from var.snmp_targets, which mirrors the Ansible inventory.
resource "dynatrace_hub_extension_v2_config" "snmp_by_role" {
  for_each = var.enable_snmp_monitoring ? var.device_roles : {}

  name  = dynatrace_hub_extension_active_version.snmp_generic_device[0].name
  scope = var.snmp_activegate_group # e.g. "ag_group-network-observability"

  # The monitoring configuration. Structure conforms to the snmp-generic-device
  # monitoring schema for the pinned version; validated by the provider on apply.
  value = jsonencode({
    enabled     = true
    description = "network-observability — ${each.key}"
    version     = var.snmp_extension_version
    featureSets = var.snmp_feature_sets

    # Devices for this role (management IPs). Mirrors ansible/inventory/hosts.yml;
    # generate from the inventory to keep one source of truth.
    snmp = {
      connectionAddresses = lookup(var.snmp_targets, each.key, [])
      snmpVersion         = "v3"
    }

    # SNMPv3 credentials — supplied via env (TF_VAR_snmp_v3_*), never committed.
    snmpV3 = {
      user          = var.snmp_v3_user
      authMethod    = var.snmp_v3_auth_method
      authPassword  = var.snmp_v3_auth_password
      privMethod    = var.snmp_v3_priv_method
      privPassword  = var.snmp_v3_priv_password
      securityLevel = "authPriv"
    }
  })
}
