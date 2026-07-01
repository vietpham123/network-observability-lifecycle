# Immutable, long-retention Grail bucket = continuous ISO evidence store.
resource "dynatrace_grail_bucket" "network_compliance" {   # VERIFY resource name
  name           = "network_compliance"
  display_name   = "Network Compliance Evidence"
  table          = "logs"
  retention_days = var.compliance_retention_days
}
