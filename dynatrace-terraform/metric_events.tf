# Tag-scoped compliance-drift alert. Not per-device: any tagged device is covered.
resource "dynatrace_metric_events" "compliance_drift" {   # VERIFY
  enabled       = true
  summary       = "Network device failed one or more compliance controls"
  metric_id     = "log.ansible.compliance.failed_count"
  aggregation   = "MAX"

  event_template {
    title       = "Compliance drift on network device"
    description = "A device tagged managed_by=${var.managed_by_value} failed a control."
    event_type  = "CUSTOM_ALERT"
  }

  model_properties {
    type              = "STATIC_THRESHOLD"
    threshold         = 0
    alert_condition   = "ABOVE"
    violating_samples = 1
    samples           = 1
  }

  # Scope by tag -> survives all hardware churn
  dimension_filter {
    dimension_key = "dt.entity.host"
    filter        = "tag(managed_by:${var.managed_by_value})"
  }
}
