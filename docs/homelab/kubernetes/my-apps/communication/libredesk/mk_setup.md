---
title: Libredesk setup
---

# Libredesk — support inbox

Self-hosted [Libredesk](https://libredesk.io/) for threaded live chat (tjhoth.me terminal contact). Manifests: `clusters/main/kubernetes/my-apps/communication/libredesk/` in truecharts.

Uses a single TrueCharts [app-template](https://github.com/trueforge-org/truecharts/tree/master/charts/stable/app-template) HelmRelease with:

- [common CNPG](https://truecharts.org/common/cnpg/cnpg/) (`cnpg.main`)
- `redis.enabled` (Valkey subchart)

## URL

| Service | Host |
|---------|------|
| Libredesk UI / API / widget | `https://support.${DOMAIN_0}` |

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
| `helm-release.yaml` | Libredesk + CNPG + Redis in one app-template release |

DB/Redis hosts and passwords are injected via TrueCharts secrets (`cnpg-main-urls`, `cnpg-main-user`, `<release>-rediscreds`), same pattern as OnlyOffice on TrueCharts.

## Cloudflare Tunnel

Tunnel public hostnames are **not** in Git (only `CLOUDFLARED_TOKEN`). After Flux creates the Ingress:

1. Zero Trust → your tunnel → **Public Hostname**
2. Hostname: `support.${DOMAIN_0}`
3. Service: same HTTPS target as other `*.${DOMAIN_0}` apps (nginx-external)
4. Confirm DNS CNAME for `support` → tunnel

## Bootstrap

1. Open `https://support.${DOMAIN_0}`
2. Login: email/user **`System`**, password from `LIBREDESK_SYSTEM_USER_PASSWORD`
3. Create your agent user; change the System password
4. **Admin → Inboxes → New inbox → Live chat**
   - Website URL: `https://tjhoth.me`
5. **Security → Trusted domains:** `tjhoth.me`, `www.tjhoth.me`
6. Copy **inbox UUID** from the Installation tab for the profile site Widget API

Widget API docs: [docs.libredesk.io/api-reference/widget-api](https://docs.libredesk.io/api-reference/widget-api)

## Observe reconcile

```bash
flux get kustomization libredesk -n flux-system
flux get helmrelease libredesk -n communication
kubectl get cluster,pods,ingress -n communication
kubectl describe helmrelease libredesk -n communication
```

Do **not** `kubectl apply` / patch live — fix Git and let Flux reconcile.

## Profile site

tjhoth.me `TerminalContact` talks to this instance via the public Widget API + `/widget/ws` (see profile repo). Inbox UUID is public config; keep the inbox signing secret server-side only if you add JWT identity later.
