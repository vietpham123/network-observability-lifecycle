# dynatrace-monaco

Configuration as Code (option A). Every config here binds to **tags**, not entity IDs —
so new hardware is picked up automatically and retired hardware ages out with no edits.

Deploy order is dependency-driven by Monaco, but conceptually:
`auto-tags` → `management-zones` → `log-processing` → `metric-events` → `retention-bucket` → `dashboards`.

`monaco deploy manifest.yaml --environment production`

> The `net_role` etc. tag keys MUST match `ansible/inventory/group_vars/all.yml:tag_schema`.
> That shared contract is the whole anti-orphan mechanism.
