---
title: Libredesk setup
---

# Libredesk — support inbox

Self-hosted [Libredesk](https://libredesk.io/) for threaded live chat (tjhoth.me floating terminal widget). Manifests: `clusters/main/kubernetes/my-apps/communication/libredesk/` in truecharts.

Uses a single TrueCharts [app-template](https://github.com/trueforge-org/truecharts/tree/master/charts/stable/app-template) HelmRelease with:

- [common CNPG](https://truecharts.org/common/cnpg/cnpg/) (`cnpg.main`)
- `redis.enabled` (Valkey subchart)

## URL

| Service | Host |
|---------|------|
| Libredesk UI / API / widget | `https://support.${DOMAIN_1}` (`support.tjhoth.me`) |

Ingress uses `ingressClassName: external` (Cloudflare Tunnel → nginx-external), same pattern as ntfy.

## Clusterenv variables

| Variable | Purpose |
|----------|---------|
| `LIBREDESK_DB_PASSWORD` | CNPG app user password (`cnpg.main.password`) |
| `LIBREDESK_ENCRYPTION_KEY` | 32-char app encryption key |
| `LIBREDESK_SYSTEM_USER_PASSWORD` | Initial `System` user password (change after first login) |
| `LIBREDESK_REDIS_PASSWORD` | Redis/Valkey password (`redis.password`) |

Generate:

```bash
openssl rand -hex 16          # encryption key (32 hex chars)
openssl rand -base64 24       # passwords
```

Encrypt with `clustertool encrypt` (and `clustertool cluster genconfig` so Flux `clustersettings` picks up new keys) before commit.

## Manifests

| File | Role |
|------|------|
| `configmap.yaml` | Full `config.toml` defaults (avoids `--config=""` zero-value panics) |
| `helm-release.yaml` | Libredesk + CNPG + Redis in one app-template release |

DB/Redis hosts and passwords are injected via env overrides on top of the ConfigMap (`cnpg-main-urls`, `cnpg-main-user`, `<release>-rediscreds`).

## Cloudflare Tunnel

Tunnel public hostnames are **not** in Git (only `CLOUDFLARED_TOKEN`). After Flux creates the Ingress:

1. Zero Trust → your tunnel → **Public Hostname**
2. Hostname: `support.${DOMAIN_1}` (`support.tjhoth.me`)
3. Service: same HTTPS target as other external apps (nginx-external)
4. Confirm DNS CNAME for `support` on the `tjhoth.me` zone → tunnel

## Bootstrap

1. Open `https://support.${DOMAIN_1}`
2. Login: email/user **`System`**, password from `LIBREDESK_SYSTEM_USER_PASSWORD`
3. Create your agent user; change the System password
4. **Admin → Inboxes → New inbox → Live chat**
   - Website URL: `https://tjhoth.me`
5. **Security → Trusted domains:** `tjhoth.me`, `www.tjhoth.me`
6. Copy **inbox UUID** from the Installation tab for the profile site Widget API

Widget API docs: [docs.libredesk.io/api-reference/widget-api](https://docs.libredesk.io/api-reference/widget-api)

## AI (Ollama)

Libredesk AI is configured in the UI (**Admin → AI → Providers**), not in `config.toml`. Worker limits already live in the ConfigMap `[ai_agent]` block. Providers talk to in-cluster Ollama over the OpenAI-compatible API.

Ollama keeps both models on disk via `ollama-model-pull-job` (`qwen3.6:27b` + `qwen3-embedding:0.6b`) and `OLLAMA_MAX_LOADED_MODELS=2` so embeddings do not unload the chat model.

| Provider | Used for | Values |
|----------|----------|--------|
| **Completion** | Copilot, drafts, summaries, assistant replies | Preset **Ollama**. Base URL `http://ollama-api.ai.svc.cluster.local:11434/v1`. Model `qwen3.6:27b`. API key any non-empty string (Ollama ignores it; Libredesk requires one — use `ollama`). **Reasoning effort: `none`** (required — see below). |
| **Embedding** | Snippet / tag vectors for RAG | Same base URL and dummy API key. Model `qwen3-embedding:0.6b`. **Dimensions** `1024`. |

Hit **Test connection** on each. `[ssrf]` stays `enabled = false` so Libredesk can reach the cluster-internal Ollama IP.

The 0.6B embedding tag (~639MB, 1024-dim) is intentional: `qwen3-embedding` / `:8b` is 4.7GB and will evict the 27B on a 24GB GPU. Changing embedding model or dimensions re-embeds existing snippets.

### Assistant setup (required after providers)

Provider tests only prove Ollama answers a ping. The live assistant always calls tools (`search_knowledge_base`, `hand_off_to_human`, `resolve`) and **answers only from snippets**.

1. **Completion → Reasoning effort = `none`.** `qwen3.6:27b` is a thinking model. With tools and thinking left on, Ollama returns empty `content` and no `tool_calls`. Libredesk then posts the private note *“The AI assistant did not have an answer and handed this conversation off to a human.”* That note is agent-only — the chat widget never shows it.
2. **Admin → AI → Snippets** — add at least one self-contained snippet (title + full answer). Empty or un-embedded knowledge makes the model hand off. Wait until the snippet shows as embedded after saving the embedding provider.
3. **Admin → AI → Assistants** — create an assistant, leave it **enabled**, set a **fallback team** if you want handoffs to land somewhere. Use the assistant **Test** tab with a question that matches a snippet before assigning live chats.
4. Assign an **open** conversation to the assistant **after** a customer message (or add an automation that assigns new live-chat conversations). Replies go out as normal outgoing messages; the widget will show those.

### Site brief tool (tjhoth.me)

Do **not** point a tool at `https://tjhoth.me` — that returns the full HTML page. The profile site publishes a text snapshot of the same content collections:

`GET https://tjhoth.me/llms.txt`

| Field | Value |
|-------|--------|
| Name | `get_site_profile` |
| Description | Fetch TJ Hoth's public profile (bio, roles, projects, skills, links). Use this for questions about who TJ is, his work history, homelab, or how to reach him. |
| URL | `https://tjhoth.me/llms.txt` |
| Method | `GET` |
| Require verified contact | Off (this is public) |

Grant the tool on the assistant. In the assistant **Instructions**, tell it to call `get_site_profile` for career/site questions. Also **import that URL as a snippet** (Admin → AI → Snippets → Import from URL) so `search_knowledge_base` has the same text — the assistant is grounded on snippets first.

Upstream: [docs.libredesk.io/configuration/ai](https://docs.libredesk.io/configuration/ai)

## Observe reconcile

```bash
flux get kustomization libredesk -n flux-system
flux get helmrelease libredesk -n communication
kubectl get cluster,pods,ingress -n communication
kubectl describe helmrelease libredesk -n communication
```

Do **not** `kubectl apply` / patch live — fix Git and let Flux reconcile.

## Profile site

tjhoth.me mounts a **floating terminal chat widget** (bottom-right launcher → terminal panel) — a terminal skin over the Libredesk Widget API, not stock `widget.js`. It mirrors inbox **Messages** and **Pre-chat form** settings with no local fallbacks (disabled form ⇒ anonymous visitor). Free-form chat uses WebSocket + `sessionStorage` resume. Implementation: profile repo `src/lib/terminal-chat/` (`window.TjChat.show()` / `.hide()` / `.toggle()`).

When the Pre-chat form collects name + email, `/api/libredesk/session` signs a widget JWT so agents see the contact (`LIBREDESK_INBOX_SECRET` on Cloudflare Pages; `baseUrl`/`inboxId` from site config). Do not put the secret in `profile.yaml`.

Libredesk itself does not emit CORS for custom Widget API clients. The HelmRelease ingress enables nginx CORS for `https://tjhoth.me` and `https://www.tjhoth.me`.
