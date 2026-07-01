# Tag-scoped compliance-drift alert. Not per-device: any tagged device is covered.
# The metric selector carries the tag scope, so it survives all hardware churn.
resource "dynatrace_metric_events" "compliance_drift" {
  enabled = true
  summary = "Network device failed one or more compliance controls"

  query_definition {
    type            = "METRIC_SELECTOR"
    metric_selector = "log.ansible.compliance.failed_count:filter(and(in(\"dt.entity.custom_device\",entitySelector(\"tag(managed_by:${var.managed_by_value})\")))):max"
  }

  event_template {
    title       = "Compliance drift on network device"
    description  = "A device tagged managed_by=${var.managed_by_value} failed a control."
    event_type  = "CUSTOM_ALERT"
    davis_merge = false
  }

  model_properties {
    type               = "STATIC_THRESHOLD"
    threshold          = 0
    alert_condition    = "ABOVE"
    alert_on_no_data   = false
    dealerting_samples = 5
    violating_samples  = 3
    samples            = 5
  }
}
