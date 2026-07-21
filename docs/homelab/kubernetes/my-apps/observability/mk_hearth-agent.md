---
title: Hearth Agent (Hermes core sidecar)
---

# Hearth Agent

Headless **Hermes Agent** runs as a **sidecar** in the Hearth Deployment — same pod, same Flux app. Hermes WebUI / `hermes-oncall` is retired.

| | |
|--|--|
| Pod | `hearth` in `observability` (containers `hearth` + `agent`) |
| Agent API | `http://127.0.0.1:8642` (loopback from Hearth container) |
| Dashboard | `https://hermes-dash.${DOMAIN_0}` (port 9119; basic auth `admin` / `${ADMIN_PASS}`) |
| Auth (API) | `Authorization: Bearer ${HEARTH_AGENT_API_KEY}` |
| Tools | Hearth MCP at `http://127.0.0.1:8000/mcp` (`HEARTH_SANDBOX_AGENT_API_KEY` in agent env only) |
| Model | Chosen in Hearth Settings → AIOps; sent per-request as OpenAI `model`. Hermes maps it via `platforms.api_server.extra.model_routes` (synced from Ollama on agent boot). |
| State | PVC `hearth-agent-data` + ConfigMap `hearth-agent-seed` |

## Secrets (never in chat)

| Secret | Used by |
|--------|---------|
| `HEARTH_AGENT_API_KEY` | Hearth → agent API; agent `API_SERVER_KEY`; dashboard session secret |
| `HEARTH_SANDBOX_AGENT_API_KEY` | Agent → Hearth `/mcp` |
| `ADMIN_PASS` | Hermes dashboard basic auth |
| `HERMES_ALERT_TRIAGE_SECRET` | Optional Hearth `TRIAGE_AUTH_TOKEN` for legacy `/homelab/*` API paths |

## Flow

```text
ntfy Ask AI / Investigate / incident chat (Hearth UI)
  → ensure sandbox pod (best-effort)
  → POST 127.0.0.1:8642 /v1/responses (streamed)
  → agent MCP → 127.0.0.1:8000/mcp → sandbox_exec
  → transcript on incident (provider=agent)
```

**Ask AI** (ntfy): opens `https://incidents.<domain>/go/alert?fingerprint=<fp>&investigate=1` — Hearth raises/finds the incident and starts Investigate.

**Incident chat** (Hearth UI, replaces Hermes WebUI): on the incident page, operators continue a narrowly scoped conversation via `POST /api/incidents/:id/agent/chat`. Replies render as markdown. Chat reuses the same Hermes conversation as Investigate; blocked while status is `running`.

## GitOps

All under `observability/hearth/app/`:

| File | Role |
|------|------|
| `deployment.yaml` | Hearth + agent sidecar (+ dashboard process) |
| `service.yaml` | Ports 8000 (UI/API) and 9119 (dashboard) |
| `ingress.yaml` | `incidents.*` → UI; `hermes-dash.*` → dashboard |
| `pvc-agent.yaml` | Agent `~/.hermes` state |
| `agent-seed-configmap.yaml` | First-boot model/MCP seed |
| `sandbox-rbac.yaml` | Ephemeral triage pods (separate) |

Provider: `HEARTH_AIOPS_PROVIDER=agent`.

## Related

- [Hearth triage sandbox](mk_hearth-sandbox.md)
- [Observability overview](mk_observability.md)
