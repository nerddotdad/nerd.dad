---
title: Firefly III setup
---

# Firefly III — retired for daily banking

Do **not** use Firefly III as the household ledger. Patelco does not sync through SimpleFIN, and Budgeteer is the product: [Budgeteer setup](../budgeteer/mk_setup.md).

These charts remain in GitOps only until Budgeteer has an in-cluster Patelco sync. Then remove `fireflyiii/ks.yaml` and `firefly-importer/ks.yaml`.

The rest of this page is leftover installer notes.

## URLs

| Service | Host | Ingress |
|---------|------|---------|
| Firefly III | `https://firefly.${DOMAIN_0}` | external (Cloudflare Tunnel) |
| Data Importer | `https://firefly-import.${DOMAIN_0}` | internal (LAN) |

## Manifests

| Path | Role |
|------|------|
| `finance/fireflyiii/` | TrueCharts [`fireflyiii`](https://github.com/trueforge-org/truecharts/blob/master/charts/stable/fireflyiii/values.yaml) chart (CNPG + Valkey + cron). Image overridden to `fireflyiii/core:version-6.6.6` because the chart is still on 6.2.21 and Data Importer 2.3.x requires **>= 6.6.0**. |
| `finance/firefly-importer/` | `app-template` + `docker.io/fireflyiii/data-importer:version-2.3.4` |

TrueCharts does not ship the importer ([installation notes](https://truecharts.org/charts/stable/fireflyiii/installation_notes/)).

`APP_KEY` and `STATIC_CRON_TOKEN` are generated and remembered by the Firefly chart.

| Variable | Purpose |
|----------|---------|
| `FIREFLY_III_ACCESS_TOKEN` | Firefly PAT for the Data Importer (`Options → Profile → OAuth`) |

After adding or rotating it: `clustertool encrypt` and `clustertool cluster genconfig`, then commit. Do not put the token in the importer HelmRelease as plaintext.

## Cloudflare Tunnel

After Flux creates the Firefly Ingress:

1. Zero Trust → tunnel → **Public Hostname**
2. Hostname: `firefly.${DOMAIN_0}`
3. Service: same HTTPS target as other external apps (nginx-external)
4. Confirm DNS CNAME for `firefly` on the `DOMAIN_0` zone → tunnel

The importer stays on **internal** ingress. Do not put SimpleFIN tokens on a public hostname.

## Bootstrap

1. Open `https://firefly.${DOMAIN_0}` and create the first user (you).
2. **Options → Remote access and tokens → Personal Access Tokens** — create a token named `data-importer` (direct URL: `https://firefly.${DOMAIN_0}/profile/oauth`). Copy it once. Do **not** use the command-line token. Firefly **6.6.0+** invalidates older PATs and moved this off the Profile OAuth tab.
3. Open `https://firefly-import.${DOMAIN_0}` on LAN.
4. Paste the token when the importer asks (or set `FIREFLY_III_ACCESS_TOKEN` in `clusterenv.yaml` later, then `clustertool encrypt` + `clustertool cluster genconfig`).
5. Importer should already know `FIREFLY_III_URL` (`http://fireflyiii.finance.svc.cluster.local:10082`) and `VANITY_URL` (`https://firefly.${DOMAIN_0}`).

## SimpleFIN (US bank sync)

The importer's US live path is [SimpleFIN Bridge](https://beta-bridge.simplefin.org/) ($1.50/mo or $15/yr). Search institutions first: [supported institutions](https://beta-bridge.simplefin.org/search-institutions).

| Institution | Role | Expectation |
|-------------|------|-------------|
| **Patelco** | Daily banking | Best shot at full transactions. Link this first. |
| **Fidelity** | Old 401k + 529s | Often balance-only. NetBenefits vs brokerage may be two connections. |
| **Empower** | Current 401k | Same as Fidelity. |
| **Chase** | Mortgage | Liability if MX exposes it; importer liability mapping has been flaky. |
| **HealthEquity** | HSA | Plan on CSV from the portal. Aggregators often fail here. |

Setup:

1. Create a SimpleFIN Bridge account and connect **Patelco**.
2. Confirm transactions appear in the SimpleFIN dashboard.
3. Create an app connection / claim URL and finish the import in the Data Importer ([SimpleFIN tutorial](https://docs.firefly-iii.org/tutorials/data-importer/simplefin/)).
4. Save the importer config JSON if you want scheduled re-imports.
5. Then try Fidelity, Empower, and Chase. HealthEquity: export CSV from the HSA portal and import that file.

Optional later: put `SIMPLEFIN_TOKEN` in `clusterenv.yaml` so the importer does not ask every time.

Lunch Flow is the paid backup if SimpleFIN misses Fidelity/Empower ([Fidelity listing](https://www.lunchflow.app/coverage/fidelity)).

## HealthEquity CSV

1. Log into HealthEquity → export cash / investment activity as CSV.
2. Data Importer → file import → map date, amount, description.
3. Use a stable `external_id` (or Firefly's duplicate detection) so re-uploads do not double-post.

## Observe reconcile

```bash
flux get kustomization fireflyiii firefly-importer -n flux-system
flux get helmrelease fireflyiii firefly-importer -n finance
kubectl get cluster,pods,ingress -n finance
kubectl describe helmrelease fireflyiii -n finance
```

Never `kubectl apply` these resources — GitOps only.