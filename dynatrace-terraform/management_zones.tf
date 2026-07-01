# One zone covering the whole managed estate, bound to the ownership tag.
resource "dynatrace_management_zone_v2" "network_estate" {   # VERIFY
  name = "Network Estate"
  rules {
    type    = "ME"
    enabled = true
    attribute_conditions {
      conditions {
        key      = "HOST_TAGS"
        operator = "TAG_KEY_EQUALS"
        tag      = "managed_by:${var.managed_by_value}"
      }
    }
  }
}
