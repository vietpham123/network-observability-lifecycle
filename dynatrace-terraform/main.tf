terraform {
  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.70"   # VERIFY: pin to your tested version
    }
  }
}

# Credentials from env: DYNATRACE_ENV_URL, DYNATRACE_API_TOKEN.
# The Grail bucket (retention.tf) additionally needs platform auth: set
# DYNATRACE_PLATFORM_TOKEN in the env (or client_id/client_secret) — the classic
# API token cannot manage Grail buckets.
provider "dynatrace" {
  platform_token = var.dt_platform_token != "" ? var.dt_platform_token : null
}
