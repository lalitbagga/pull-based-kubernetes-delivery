# Helm lifecycle evidence

Date: 2026-08-25

This test used disposable namespaces and did not modify the Argo CD-managed
`delivery-api` namespace. Retained output excludes cluster endpoints,
credentials, node names, and internal addresses.

## Test inputs

| Input | Value |
| --- | --- |
| Kubernetes | k3s v1.36.3 |
| Helm | v4.2.4 |
| Helm Linux AMD64 archive SHA-256 | `c306b46f719b0a4da32d0f78ee21bf90ce8d602f15b22ab753f0674d1670a7f3` |
| Repository commit | `c4a520c7d255e8dfc44ad37032e7329529c451af` |
| Chart | `delivery-api-0.1.0` |
| Image selection | Immutable digest from `gitops/environments/homelab/values.yaml` |

The repository commit and Helm archive checksum were verified before the first
cluster operation. Helm received the k3s kubeconfig explicitly. The temporary
Helm client was an operator tool and was not installed into application CI.

## Install and smoke test

Release `delivery-api-lifecycle` was installed into the fresh namespace
`delivery-api-helm-lifecycle`.

| Field | Result |
| --- | --- |
| Revision | 1 |
| Release status | `deployed` |
| Description | `Install complete` |
| Helm test phase | `Succeeded` |
| Smoke-test response | `{"status":"ready"}` |

## Upgrade and rollback

Revision 2 overrode `replicaCount` from two to one. Kubernetes reported one
desired, ready, and available replica after the upgrade.

The release was then rolled back to revision 1. Helm created revision 3, and
Kubernetes reported two desired, ready, and available replicas.

| Revision | Helm status after rollback | Description |
| ---: | --- | --- |
| 1 | `superseded` | Install complete |
| 2 | `superseded` | Upgrade complete |
| 3 | `deployed` | Rollback to 1 |

## Uninstall, fresh install, and cleanup

The lifecycle release was uninstalled and its disposable namespace was deleted.
A second release, `delivery-api-fresh`, was then installed into a new namespace,
`delivery-api-helm-fresh`.

The fresh-install smoke test succeeded and returned:

```json
{"status":"ready"}
```

The fresh release was uninstalled and its namespace was deleted. Final
namespace lookups returned `NotFound` for both disposable namespaces.

## Result

Helm lint, render, install, test, upgrade, rollback, uninstall, fresh-namespace
install, retest, and cleanup all passed. These manual lifecycle checks validated
the package in isolation; routine application delivery remains owned by Argo CD.
