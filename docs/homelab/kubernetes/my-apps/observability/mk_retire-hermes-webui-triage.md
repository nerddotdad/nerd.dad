---
title: Retire Hermes WebUI from triage
---

# Retire Hermes WebUI from triage (follow-up)

After **Hearth Agent** Investigate is proven in production:

## Checklist

1. Confirm `HEARTH_AIOPS_PROVIDER=agent` on Hearth and successful investigations (agent panel messages, sandbox MCP tool calls).
2. Remove WebUI fallback from Settings docs / stop documenting `provider=webui` for triage.
3. In truecharts:
   - Optionally remove `hermes-oncall` if you no longer want freeform Hermes chat.
   - The investigate agent already lives as a sidecar on Hearth — do not re-add `ai/hearth-agent`.
   - Drop Hearth env `HERMES_WEBUI_*` if unused.
4. Keep `HEARTH_SANDBOX_AGENT_API_KEY` and `HEARTH_AGENT_API_KEY` (distinct secrets).
5. Optional: archive `hermes-homelab` image builds if nothing else consumes them.

Do **not** remove hearth-agent or the Hearth sandbox — those are the long-term triage path.
