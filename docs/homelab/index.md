---
title: Homelab
edit_url: https://github.com/nerddotdad/nerd.dad/edit/main/docs/homelab/index.md
---

# Homelab documentation

Hand-written homelab / cluster docs for [nerd.dad](https://nerd.dad/). Published on **GitHub Pages**: [https://nerd.dad/latest/homelab/](https://nerd.dad/latest/homelab/)

GitOps manifests live in [truecharts](https://github.com/nerddotdad/truecharts). Prose docs live **only** here.

## Guides

| Guide | What it’s for |
|-------|----------------|
| [Cluster guide](guides/cluster-guide.md) | Architecture, namespaces, GitOps habits, troubleshooting |
| [Navigation](guides/navigation.md) | Repo map, app discovery, deploy workflow |
| [kubectl quick reference](guides/quick-reference.md) | Observe-only commands (get/describe/logs/flux) |
| [Jellyfin watch history](guides/jellyfin-watch-history.md) | Finding playback / watch history |
| [Hearth triage sandbox](kubernetes/my-apps/observability/mk_hearth-sandbox.md) | LLM-agnostic incident sandbox (MCP + terminal) |
| [Hearth Agent](kubernetes/my-apps/observability/mk_hearth-agent.md) | Hermes core sidecar in the Hearth pod |
| [Retire Hermes WebUI triage](kubernetes/my-apps/observability/mk_retire-hermes-webui-triage.md) | WebUI/`hermes-oncall` retirement (done) |

## Service docs & runbooks

Layout under `kubernetes/` mirrors the cluster tree in truecharts.

| Pattern | Use |
|---------|-----|
| `mk_*.md` | Area or service docs |
| `mk_runbook_*.md` | Alert runbooks (`kubernetes/my-apps/observability/runbooks/`) |

Keep runbooks **out of** truecharts `clusters/` so ClusterTool `genconfig` stays happy.

## Alert `runbook_url`

In truecharts PrometheusRules:

```yaml
runbook_url: https://nerd.dad/latest/homelab/kubernetes/my-apps/observability/runbooks/mk_runbook_<alert-kebab>/
```

## Where to edit

| Content | Location |
|---------|----------|
| Guides, runbooks, service notes | **this repo** → `docs/homelab/` |
| Snippets | `includes/homelab/runbook/` |
| HelmRelease / alerts / Flux YAML | [truecharts](https://github.com/nerddotdad/truecharts) `clusters/` |

## Workflow

1. Edit under `docs/homelab/`.
2. Push to `main` and deploy Pages (`mike` / your usual build).
3. Confirm at `https://nerd.dad/latest/homelab/...`.
