# Parse the compliance JSON Ansible ships. On Grail/OpenPipeline you may model this
# as an OpenPipeline processor resource instead. VERIFY resource + processor syntax.
resource "dynatrace_log_processing" "compliance_parse" {   # VERIFY
  enabled = true
  matcher = "log.source == \"ansible-compliance\""
  rule    = "PARSE(content, \"JSON:payload\") | FIELDS_ADD(net_role: payload[net_role], failed_count: payload[compliance.failed_count])"
}
