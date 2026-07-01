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
