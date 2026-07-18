---
title: "Runbook: HomelabImmichframeAssetApiDown"
alertname: HomelabImmichframeAssetApiDown
severity: warning
homelab_team: media
releases:
  - media/immichframe
---

# HomelabImmichframeAssetApiDown

--8<-- "runbook/overview.md"

| Field | Value |
|-------|-------|
| **Alert** | `HomelabImmichframeAssetApiDown` |
| **Severity** | `warning` |
| **Team** | `media` |
| **PrometheusRule** | `homelab-immichframe.yaml` |

## What this means

Blackbox cannot get **HTTP 200** from ImmichFrame’s **`/api/Asset/RandomImageAndInfo`** for 5+ minutes. The frame’s `/` probe can still be healthy while album/image loading is broken (common after Immich major API changes).

## Triage

--8<-- "runbook/triage-checklist.md"

1. Confirm versions:

   ```bash
   kubectl get deploy -n media immichframe-app-template -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
   kubectl get deploy -n media immich -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
   flux get helmrelease immichframe -n media
   ```

2. Check ImmichFrame logs for Immich API / deserialize errors (e.g. `AlbumUserRole`, `owner`):

   ```bash
   kubectl logs -n media deploy/immichframe-app-template --tail=80
   ```

3. Confirm the blackbox probe:

   ```promql
   probe_success{target="homelab-immichframe-asset"}
   probe_http_status_code{target="homelab-immichframe-asset"}
   ```

## Diagnose

--8<-- "runbook/flux-helmrelease-diagnose.md"

Typical causes:

- ImmichFrame still on an Immich **2.x**-era image (`v1.0.33` and older) while Immich is **v3+**
- Flux HelmRelease **Stalled** / rolled back after a failed upgrade (timeout during node upgrade)
- Wrong `ApiKey` / `Albums` config, or Immich unreachable from the ImmichFrame pod
- `AuthenticationSecret` mismatch (probe and clients get 401)

## Resolve

--8<-- "runbook/resolve-gitops.md"

- Keep ImmichFrame on **v1.0.34+** when Immich is v3 (see [ImmichFrame releases](https://github.com/immichFrame/ImmichFrame/releases)).
- If the HelmRelease is `Stalled` / `RetriesExceeded`, fix the image tag in Git, push, then:

  ```bash
  flux reconcile helmrelease immichframe -n media --with-source
  ```

## Escalation

--8<-- "runbook/escalation.md"

## Applies to

- HelmRelease `media/immichframe`
- Probe target `homelab-immichframe-asset` (blackbox-exporter)
