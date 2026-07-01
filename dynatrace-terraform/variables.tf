# The single source of truth for roles. Add a role here (and a matching Ansible
# group_vars file) and every tag/alert/zone below extends to it via for_each.
variable "device_roles" {
  description = "Network device roles and their tag values."
  type = map(object({
    net_class = string
  }))
  default = {
    core_switch = { net_class = "switch" }
    edge_router = { net_class = "router" }
    firewall    = { net_class = "firewall" }
  }
}

variable "managed_by_value" {
  description = "Constant tag proving as-code ownership; ties everything together."
  type        = string
  default     = "ansible-caac"
}

variable "compliance_retention_days" {
  type    = number
  default = 2555 # ~7y; set to your audit requirement
}

# The Grail evidence bucket needs platform auth (not the classic API token).
# Leave disabled for a classic-token-only deploy; enable once a platform token
# is provided via DYNATRACE_PLATFORM_TOKEN (TF_VAR_dt_platform_token).
variable "enable_grail_bucket" {
  description = "Create the long-retention Grail evidence bucket (requires platform token)."
  type        = bool
  default     = false
}

variable "dt_platform_token" {
  description = "Dynatrace platform token for Grail bucket management. Empty = unset."
  type        = string
  default     = ""
  sensitive   = true
}

# ── Entity/topology plane: SNMP extension monitoring (see network_extensions.tf) ──
# Off by default: requires an ActiveGate in the target group + SNMP reachability.
variable "enable_snmp_monitoring" {
  description = "Deploy the SNMP generic-device extension monitoring configs (requires ActiveGate)."
  type        = bool
  default     = false
}

variable "snmp_extension_version" {
  description = "Pinned version of com.dynatrace.extension.snmp-generic-device."
  type        = string
  default     = "2.2.10"
}

variable "snmp_feature_sets" {
  description = "Extension feature sets to enable."
  type        = list(string)
  default     = ["Interfaces 64-bit", "Traffic", "neighbor-discovery"]
}

variable "snmp_activegate_group" {
  description = "ActiveGate group scope for the monitoring config, e.g. ag_group-network-observability."
  type        = string
  default     = "ag_group-network-observability"
}

variable "snmp_targets" {
  description = "Per-role device management IPs to poll. Mirrors ansible/inventory/hosts.yml."
  type        = map(list(string))
  default = {
    core_switch = ["10.0.1.11", "10.0.1.12", "10.0.1.15"]
    edge_router = ["10.0.2.11", "10.0.2.12"]
    firewall    = ["10.0.3.11"]
  }
}

variable "snmp_v3_user" {
  type    = string
  default = "netobs"
}
variable "snmp_v3_auth_method" {
  type    = string
  default = "SHA"
}
variable "snmp_v3_auth_password" {
  type      = string
  default   = ""
  sensitive = true
}
variable "snmp_v3_priv_method" {
  type    = string
  default = "AES"
}
variable "snmp_v3_priv_password" {
  type      = string
  default   = ""
  sensitive = true
}
