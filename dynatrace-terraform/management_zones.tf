# One zone covering the whole managed estate, bound to the ownership tag.
resource "dynatrace_management_zone_v2" "network_estate" {
  name = "Network Estate"
  rules {
    rule {
      type            = "SELECTOR"
      enabled         = true
      entity_selector = "type(CUSTOM_DEVICE),tag(managed_by:${var.managed_by_value})"
    }
  }
}
