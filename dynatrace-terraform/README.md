# dynatrace-terraform

Configuration as Code (option B) — the "or Terraform" path. Functionally equivalent to
`dynatrace-monaco/`: pick ONE, don't run both against the same tenant.

Same principle: everything binds to **tags** and is driven from `var.device_roles`, so adding a
role or a device never means editing a resource by hand.

```bash
cp terraform.tfvars.example terraform.tfvars   # git-ignored
export DYNATRACE_ENV_URL="https://{id}.live.dynatrace.com"
export DYNATRACE_API_TOKEN="dt0c01...."
terraform init && terraform plan && terraform apply
```

> Resource names in the Dynatrace provider (`dynatrace-oss/dynatrace`) shift between versions.
> Lines marked `# VERIFY` should be checked against your pinned provider version.
