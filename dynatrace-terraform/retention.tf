# Long-retention Grail bucket = continuous ISO evidence store.
# `retention` is in days; the real resource is dynatrace_platform_bucket.
resource "dynatrace_platform_bucket" "network_compliance" {
  name         = "network_compliance"
  display_name = "Network Compliance Evidence"
  table        = "logs"
  retention    = var.compliance_retention_days
}
