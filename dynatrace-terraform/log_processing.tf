# Parse the compliance JSON Ansible ships. The `query` is the DQL matcher that
# scopes which log records this rule runs on; `processor_definition.rule` is the
# DPL processing statement.
resource "dynatrace_log_processing" "compliance_parse" {
  enabled   = true
  rule_name = "ansible-compliance-parse"
  query     = "matchesValue(log.source, \"ansible-compliance\")"

  processor_definition {
    rule = "PARSE(content, \"JSON:payload\") | FIELDS_ADD(net_role: payload[net_role], failed_count: payload[compliance.failed_count])"
  }

  rule_testing {
    sample_log = "{\"log.source\":\"ansible-compliance\",\"content\":\"{\\\"net_role\\\":\\\"core_switch\\\",\\\"compliance\\\":{\\\"failed_count\\\":2}}\"}"
  }
}
