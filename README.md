# Pull-Based Kubernetes Delivery

An evidence-driven Kubernetes delivery project that removes direct cluster
authority from application CI.

CI tests a representative API, builds and publishes a Linux AMD64 image, and
opens a pull request containing its immutable registry digest. A human reviews
the declaration. Argo CD—not application CI—pulls the approved Git state and
reconciles Kubernetes.

## Delivery boundary

```text
Application commit
        |
        v
CI: test -> build -> SBOM/provenance -> publish -> resolve digest
        |
        v
Automated promotion PR changes the desired image digest
        |
        v
Human review and merge
        |
        v
Argo CD pulls Git and renders the Helm chart
        |
        v
Kubernetes rollout, readiness, and runtime evidence
```

Application CI has short-lived GitHub repository and package permissions. It
has no kubeconfig, Kubernetes token, cluster endpoint, `kubectl` deployment,
direct Helm release, or Argo CD credential.

## Verified outcomes

| Outcome | Evidence |
| --- | --- |
| Tests, image publication, and automated digest promotion | [Baseline evidence](evidence/01-baseline-and-drift.md) |
| Immutable digest reviewed through a pull request | [Promotion PR #1](https://github.com/lalitbagga/pull-based-kubernetes-delivery/pull/1) |
| Private, resource-limited Argo CD reconciliation | [Baseline evidence](evidence/01-baseline-and-drift.md) |
| Manual drift detected and corrected | 42-second correction in [drift evidence](evidence/01-baseline-and-drift.md) |
| Bad readiness release detected | 49-second detection in [failure evidence](evidence/02-bad-readiness-and-revert.md) |
| Durable recovery through Git revert | 42-second recovery in [failure evidence](evidence/02-bad-readiness-and-revert.md) |
| Helm install, test, upgrade, rollback, uninstall, and fresh install | [Helm lifecycle evidence](evidence/03-helm-lifecycle.md) |
| Final Git, Argo CD, Deployment, Pod image ID, and application version agreement | [Final-state evidence](evidence/04-final-state-agreement.md) |
| Fresh release with Argo CD already active | 32-second detection and 43-second merge-to-healthy result in [timed-release evidence](evidence/05-timed-post-argocd-release.md) |

The failed rollout retained two ready replicas while a replacement pod failed
readiness. A sampled request through the private Service succeeded. This is not
a claim that every request succeeded or that the lab is highly available.

## Repository structure

```text
application/                    Dependency-free Node.js API and tests
helm/delivery-api/              Digest-only Kubernetes packaging
gitops/environments/homelab/    Environment desired state
gitops/argocd/                  Restricted AppProject and Application
bootstrap/argocd/               Pinned, resource-limited Argo CD Core
scripts/                        Tested digest-promotion automation
.github/workflows/              Test, publish, and promotion workflow
docs/                           Architecture, operations, and release process
evidence/                       Sanitized observed results
```

## Application behavior

| Endpoint | Purpose |
| --- | --- |
| `/health` | Process liveness |
| `/ready` | Service traffic eligibility |
| `/version` | Service identity and source commit baked into the image |
| `/metrics` | Prometheus-compatible request and uptime metrics |

`READINESS_MODE=fail` creates a controlled readiness failure while liveness
remains healthy. The behavior was released through Git and recovered through a
Git revert; it was not repaired with an untracked live-cluster change.

## Local validation

```bash
npm --prefix application test
node --test scripts/test/update-gitops-digest.test.mjs
helm lint helm/delivery-api --strict \
  --values gitops/environments/homelab/values.yaml
helm template delivery-api helm/delivery-api \
  --namespace delivery-api \
  --values gitops/environments/homelab/values.yaml >/dev/null
kubectl kustomize gitops/argocd >/dev/null
```

The build uses a digest-pinned Node base image and publishes only the full
application commit tag. Kubernetes desired state uses
`repository@sha256:digest`; it does not depend on a mutable application tag.

## Operating and releasing

- [Architecture and authority boundaries](docs/ARCHITECTURE.md)
- [Operator runbook](docs/OPERATIONS.md)
- [Developer release guide](docs/RELEASING.md)

## Scope and limitations

- This is a single-node, non-HA home-lab result, not a production-availability
  claim.
- Argo CD Core runs headlessly; no permanent API server or UI is exposed.
- The public repository and GHCR image avoid long-lived repository and image-pull
  credentials in the cluster.
- GitOps faithfully applies bad declarations. Review, health signals, and a
  durable Git recovery path remain necessary.
- The project does not claim progressive delivery, admission-policy coverage,
  multi-cluster promotion, or complete software-supply-chain security.
