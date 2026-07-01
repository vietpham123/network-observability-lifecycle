# One auto-tag rule per role — generated from var.device_roles. Entities self-tag
# on discovery, which is what makes new hardware bind with zero manual work.
# Uses a SELECTOR rule (free-form entity selector) rather than brittle attribute
# enums, so the same rule works for custom-device network entities.
resource "dynatrace_autotag_v2" "net_role" {
  for_each = var.device_roles
  name     = "net_role_${each.key}"

  rules {
    rule {
      type                = "SELECTOR"
      enabled             = true
      entity_selector     = "type(CUSTOM_DEVICE),tag(net_role:${each.key})"
      value_format        = each.key
      value_normalization = "Leave text as-is"
    }
  }
}
