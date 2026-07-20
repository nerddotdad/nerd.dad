---
title: Retire Hermes WebUI from triage
---

# Retire Hermes WebUI from triage

**Status: done.** Triage and freeform agent UI no longer use Hermes WebUI / `hermes-oncall`.

| Before | After |
|--------|--------|
| `hermes-oncall` HelmRelease (`ai` ns) | Removed from Flux |
| ntfy **Ask AI** → `hermes.?incident=` | → `incidents.?/go/alert?fingerprint=&investigate=1` |
| Hermes WebUI + gateway image | Official `nousresearch/hermes-agent` sidecar on Hearth |
| `hermes-dash.*` → WebUI dashboard | → Agent dashboard on Hearth sidecar (:9119) |

Keep:

- Hearth Investigate (`HEARTH_AIOPS_PROVIDER=agent`)
- Hearth triage sandbox + MCP
- Distinct keys: `HEARTH_AGENT_API_KEY`, `HEARTH_SANDBOX_AGENT_API_KEY`

Optional cleanup (manual): delete leftover PVCs/secrets in `ai` for `hermes-oncall` after Flux prune; archive the `hermes-homelab` image repo if unused.

See [Hearth Agent](mk_hearth-agent.md).
