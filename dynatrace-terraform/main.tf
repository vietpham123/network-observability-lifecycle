terraform {
  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.70"   # VERIFY: pin to your tested version
    }
  }
}

# Credentials from env: DYNATRACE_ENV_URL, DYNATRACE_API_TOKEN
provider "dynatrace" {}
