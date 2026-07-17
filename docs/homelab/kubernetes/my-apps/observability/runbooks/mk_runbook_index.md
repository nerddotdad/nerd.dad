---
title: Alert runbooks
---

# Homelab alert runbooks

Runbooks live here as `mk_runbook_<alert-name-kebab>.md`. ntfy **tap links** use the `runbook_url` annotation on each PrometheusRule (see `mk_runbook_template.md`).

## Tie runbooks to services

Set front matter on the runbook so it appears on the right **HelmRelease** docs pages:

```yaml
releases:
  - downloaders/nzbget
  - observability/grafana
# or
areas:
  - downloaders
# or
scope: all-helmreleases   # platform-wide (e.g. HomelabFluxHelmReleaseNotReady)
```

Co-located **`app/mk_runbook.md`** is for steps that apply only to that chart (not tied to a Prometheus alert name).

## Create a new runbook

1. Copy `mk_runbook_template.md` → `mk_runbook_<your-alert-kebab>.md`
2. Set `releases` / `areas` / `scope` in front matter; fill in **What this means**; remove the template note.
3. Add `runbook_url: https://nerd.dad/latest/homelab/kubernetes/my-apps/observability/runbooks/mk_runbook_<alert-kebab>/` to the alert in truecharts `prometheus-rules/app/*.yaml`
4. Commit docs here and deploy Pages; commit the PrometheusRule in truecharts. Alert tap opens the runbook on your phone.

## Snippets (shared sections)

Reusable blocks in `includes/homelab/runbook/` — include in any runbook with:

```markdown
--8<-- "runbook/triage-checklist.md"
```

## Runbook index

List new runbooks here (or link them from related pages). Set `alertname` / `alertnames` in each file’s front matter for your own tracking.

<!-- runbook-index-begin -->
<!-- runbook-index-end -->
