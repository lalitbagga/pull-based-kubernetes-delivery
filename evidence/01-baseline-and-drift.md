# Baseline delivery and drift-correction evidence

Date: 2026-08-25 (UTC)

This record contains only public repository identifiers and sanitized Kubernetes
output. It excludes kubeconfig data, credentials, internal addresses, node names,
and private hostnames.

## Pull-based delivery baseline

| Check | Result |
| --- | --- |
| CI validation and image publication | [Successful run](https://github.com/lalitbagga/pull-based-kubernetes-delivery/actions/runs/32902106118) |
| Automated digest promotion | [Pull request #1](https://github.com/lalitbagga/pull-based-kubernetes-delivery/pull/1), reviewed and merged |
| Application source commit in the image | `730d4e4d97635abd9286f618b3049be572e1f3a5` |
| Desired image | `ghcr.io/lalitbagga/delivery-api@sha256:170bcc91b9c4bfcbdc194c004cb38d6c89094e9b49a1a128ed3a0507976fef97` |
| Argo CD application state | `Synced`, `Healthy`, operation `Succeeded` |
| Kubernetes rollout | Two ready replicas, zero restarts |
| Application health response | `{"status":"healthy"}` |
| Application readiness response | `{"status":"ready"}` |

CI had GitHub repository and package permissions, but no Kubernetes credentials.
The promotion pull request changed the desired image digest in Git. After merge,
Argo CD pulled the repository and reconciled the cluster.

## Argo CD Core footprint

All four Argo CD pods were ready with zero restarts. Every Argo CD Service used
the internal-only `ClusterIP` type.

Observed steady-state usage immediately after installation:

| Component | CPU | Memory |
| --- | ---: | ---: |
| Application controller | 2m | 30 MiB |
| ApplicationSet controller | 1m | 21 MiB |
| Redis | 14m | 9 MiB |
| Repository server | 2m | 25 MiB |
| **Total** | **19m** | **85 MiB** |

## Drift-correction experiment

The live Deployment was deliberately scaled from the Git-declared two replicas
to one:

```bash
kubectl -n delivery-api scale deployment/delivery-api --replicas=1
```

Git remained unchanged with `replicaCount: 2` and Argo CD self-healing enabled.

| Event | UTC timestamp | Observation |
| --- | --- | --- |
| Manual drift introduced | 2026-08-25T22:26:22Z | Deployment requested one replica |
| Drift first observed | 2026-08-25T22:26:22Z | One replica; Argo CD `OutOfSync` |
| Desired state restored | 2026-08-25T22:27:04Z | Two replicas; Argo CD `Synced` |

Measured drift-correction time: **42 seconds**.

The first poll already reported `OutOfSync`. With approximately one-second
polling resolution, detection was observed in one second or less; the data does
not justify a more precise detection-time claim.

## Result

Argo CD detected an unauthorized live-state change and restored the replica
count declared in Git without a CI deployment command or Kubernetes credential.
