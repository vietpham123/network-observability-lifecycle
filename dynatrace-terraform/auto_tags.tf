# One auto-tag rule per role — generated from var.device_roles. Entities self-tag
# on discovery, which is what makes new hardware bind with zero manual work.
resource "dynatrace_autotag_v2" "net_role" {   # VERIFY resource name
  for_each = var.device_roles
  name     = "net_role_${each.key}"

  rules {
    type    = "ME"
    enabled = true
    # VERIFY: condition should match how your net entities surface role metadata
    attribute_rule {
      entity_type = "HOST"
      host_group_condition {
        key      = "HOST_GROUP_NAME"
        operator = "CONTAINS"
        value    = each.key
      }
    }
    value_format = each.key
  }
}
