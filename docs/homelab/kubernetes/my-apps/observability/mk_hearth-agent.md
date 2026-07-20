---
title: Hearth Agent (Hermes core sidecar)
---

# Hearth Agent

Headless **Hermes Agent** runs as a **sidecar** in the Hearth Deployment — same pod, same Flux app. Not Hermes WebUI.

| | |
|--|--|
| Pod | `hearth` in `observability` (containers `hearth` + `agent`) |
| Agent API | `http://127.0.0.1:8642` (loopback from Hearth container) |
| Auth | `Authorization: Bearer ${HEARTH_AGENT_API_KEY}` |
| Tools | Hearth MCP at `http://127.0.0.1:8000/mcp` (`HEARTH_SANDBOX_AGENT_API_KEY` in agent env only) |
| Model | In-cluster Ollama (`qwen3.5:9b` seed) |
| State | PVC `hearth-agent-data` + ConfigMap `hearth-agent-seed` |

## Secrets (never in chat)

| Secret | Used by |
|--------|---------|
| `HEARTH_AGENT_API_KEY` | Hearth → agent API; agent `API_SERVER_KEY` |
| `HEARTH_SANDBOX_AGENT_API_KEY` | Agent → Hearth `/mcp` |
| `HERMES_ALERT_TRIAGE_SECRET` | Legacy WebUI webhook only |

## Flow

```text
Investigate (Hearth UI)
  → ensure sandbox pod
  → POST 127.0.0.1:8642 /v1/responses
  → agent MCP → 127.0.0.1:8000/mcp → sandbox_exec
  → transcript on incident (provider=agent)
```

## GitOps

All under `observability/hearth/app/`:

| File | Role |
|------|------|
| `deployment.yaml` | Hearth + agent sidecar |
| `pvc-agent.yaml` | Agent `~/.hermes` state |
| `agent-seed-configmap.yaml` | First-boot model/MCP seed |
| `sandbox-rbac.yaml` | Ephemeral triage pods (separate) |

Provider: `HEARTH_AIOPS_PROVIDER=agent` (default) or `webui` fallback.

## Related

- [Hearth triage sandbox](mk_hearth-sandbox.md)
- [Retire Hermes WebUI triage](mk_retire-hermes-webui-triage.md)
