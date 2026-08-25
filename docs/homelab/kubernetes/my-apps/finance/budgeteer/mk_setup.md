---
title: Budgeteer setup
---

# Budgeteer — self-hosted finance app

[Budgeteer](https://github.com/nerddotdad/budgeteer) is the household ledger and PWA. Banks come in through **Plaid** (Trial / Production). Advice talks straight to **Ollama**. Optional SearXNG is used only to identify processor payees (`SQ *`, `TST *`). Firefly III is **not** the daily UI.

Manifests: `clusters/main/kubernetes/my-apps/finance/budgeteer/` in truecharts.

## What it does

| Job | Where |
|-----|--------|
| Link Patelco (and later Fidelity, Chase, …) | Budgeteer → Plaid Link |
| Browse txns, recategorize | Budgeteer PWA |
| Weekly / Evaluate / chat | Floating **Ask** (any page) → Ollama |
| Scheduled Ask prompts | Budgeteer → **Settings → Jobs** |
| Identify `SQ *FOO` | Budgeteer → SearXNG → Ollama |

Ask is a floating chat on every page (not a tab). Chats are stored as sessions: tap the title to switch, **+** to start a new one, trash to delete (no confirm — tight loops are meant to be thrown away). Opening Ask restores the last session. Follow-up questions in a session include recent turns so the model keeps context. The comments button on an Activity row includes that transaction; Ask shows **Included Transactions (N)** above the composer and sends those ids with the next question. Skills in **Settings → AI** toggle which tools the model may use. **Settings → Jobs** ships three catch-up jobs (uncategorized, same payee, transfers) on a Unix cron; each run only sends a batch so later runs walk further back. Extra recommendation presets stay opt-in. **AI may override my edits** (off by default) is a server lock: Ask and `/mcp` cannot change a transaction after you have edited it. Activity shows last editor as user / ai / none. **Settings → Categories** is the household list — Sync does not assign Plaid’s `FOOD_AND_DRINK` names. Check **Internal**, **External**, or **Investment** on a category to exclude it from spent, income, and mix charts. Activity recommends mirrored from→to transfers on one line; **Link** (or Ask `confirm_transfer`) confirms them. Ask only applies names on that list unless **Add Category** is on. Activity can still add a name when you categorize a row. Home has Chart.js mix / cash-flow / merchant charts. The header theme picker (Paper, Ember, Nord, Forest, Rosé Pine, Latte) is stored in the ledger and in the browser.

Prompts live in **Settings → AI** and can be edited. Env vars override connection fields. After a prompt change in the app, use **Reset** on Household / Weekly / Evaluate / Ask if you still have the older text saved.

## URLs

| Service | Host | Ingress |
|---------|------|---------|
| Budgeteer | `https://budgeteer.${DOMAIN_0}` | **internal** (LAN). Add to Home Screen. |

## Local first (before Flux)

Use Production Plaid keys from the Trial plan. Do not put them in git.

```bash
cd ~/Projects/budgeteer
source .venv/bin/activate
export PLAID_CLIENT_ID=...
export PLAID_SECRET=...
export PLAID_ENV=production
export PLAID_PRODUCTS=transactions
export BUDGETEER_DATA_DIR=./data
uvicorn app.main:app --reload --port 8000
```

Set Ollama in **Settings → AI**. Local options:

- `http://127.0.0.1:11434/v1` after `kubectl port-forward -n ai svc/ollama 11434:11434`
- `https://ollama-api.${DOMAIN_0}/v1` through the external ingress (needs `proxy-read-timeout` 600s; `/api/tags` is fast, chat is not)

Connect Patelco. Confirm transactions on Home / Activity. Then publish the image.

Plaid only stores accounts that were **checked in Link**. Patelco lines of credit are loan accounts, not credit cards. In **Settings → Institutions**, use **Accounts** on Patelco (login again is expected). Check every share you already use plus the lines of credit. If they still do not appear in that picker, Plaid’s Patelco connector does not expose them.

## Local → cluster

Do not copy `data/budgeteer.db` through git. Use **Settings → Backup**.

1. On the local app: **Download backup**. That zip is a consistent SQLite snapshot (ledger, Plaid item tokens, categories, jobs, chats, in-app settings and theme). Plaid/Ollama **env vars** are not in the file.
2. Bring up Budgeteer on the cluster with Production Plaid env vars (same `PLAID_CLIENT_ID` / `PLAID_SECRET` as local).
3. Open `https://budgeteer.${DOMAIN_0}` → **Settings → Backup** → restore the zip. The previous empty PVC database is kept as `budgeteer.db.bak`.
4. Confirm Patelco still syncs. Do not click **Connect bank** again unless the item is missing.

## Cluster wiring

1. Push budgeteer `main` → **Actions → Build Image** → `ghcr.io/nerddotdad/budgeteer:1.0.0`.
2. Decrypt `clusterenv.yaml` and add:
   - `BUDGETEER_PASSWORD`
   - `PLAID_CLIENT_ID`
   - `PLAID_SECRET`
3. `clustertool encrypt && clustertool cluster genconfig && clustertool encrypt && clustertool checkcrypt`
4. Uncomment `- budgeteer/ks.yaml` in `finance/kustomization.yaml`.
5. After Patelco syncs **in the cluster**, remove `fireflyiii/ks.yaml` and `firefly-importer/ks.yaml` from that file.
6. Commit. Do not `kubectl apply`.

| Variable | Purpose |
|----------|---------|
| `PLAID_CLIENT_ID` / `PLAID_SECRET` | Production Trial keys |
| `BUDGETEER_PASSWORD` | PWA login |
| `BUDGETEER_OLLAMA_URL` | In-cluster: `http://ollama.ai.svc.cluster.local:11434/v1` |
| `BUDGETEER_OLLAMA_MODEL` | Default `qwen3.6:27b` |
| `BUDGETEER_SEARXNG_URL` | Optional merchant search |

There is no Hermes sidecar in the Budgeteer pod. Ollama and SearXNG are the existing `ai` namespace services.

Ledger SQLite is `/data/budgeteer.db` on PVC `budgeteer-data`.

## Observe

```bash
flux get kustomization budgeteer -n flux-system
kubectl get pods,ingress,pvc -n finance
```

Never `kubectl apply` or `rollout restart` — GitOps only.
