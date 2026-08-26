# Pull-based delivery architecture

Status: verified for the documented single-node home-lab scope on 2026-08-25.

## Representative workload

`application/delivery-api` is a small public HTTP service with health,
readiness, version, and metrics endpoints. It has no database, external runtime
dependency, personal data, credential, or Kubernetes Secret.

A Git value can set `config.readinessMode: fail`. The process remains live, but
the readiness endpoint returns HTTP 503. This creates a meaningful failed
release without crashing the process or risking persistent data.

## Ownership boundary

| Component | Owns | Does not own |
| --- | --- | --- |
| Application source | Code, tests, Dockerfile, commit version | Live cluster state |
| Application CI | Test, publish the image, propose a digest PR | Kubernetes deployment |
| Helm chart | Kubernetes templates, schema, and safe defaults | Environment version selection |
| GitOps desired state | Replica count, readiness mode, immutable image digest | Direct cluster mutation |
| Human reviewer | Accept or reject the declared release | Controller reconciliation |
| Argo CD | Compare Git with live state and reconcile | Image builds or release correctness |
| Kubernetes | Run workloads and report rollout health | Durable desired state in Git |

No Terraform module, CI workflow, or manual Helm release co-owns the
Argo-managed `delivery-api` Deployment. Helm lifecycle tests use separate
disposable namespaces.

## Credential and authority boundary

The workflow begins with repository read permission. Only the main-branch
publication job receives job-scoped permission to publish the GHCR package,
push an automation branch, and open the promotion pull request.

It receives no kubeconfig, Kubernetes token, cluster address, SSH credential,
or Argo CD credential. Workflow inspection confirms no `kubectl`, direct
`helm install` or `helm upgrade`, or Kubernetes API call.

The repository and image are public. Argo CD therefore needs no Git credential,
and Kubernetes needs no GHCR pull secret for this workload.

## Desired release path

1. An application change is reviewed and merged to `main`.
2. CI tests the API and digest-promotion logic.
3. CI builds a Linux AMD64 image with the full commit SHA in `/version`.
4. CI publishes the commit tag with SBOM and provenance attestations.
5. CI resolves the registry digest and opens a promotion pull request.
6. A human verifies that the pull request changes only the desired digest.
7. After merge, Argo CD pulls `main` and combines the chart with the homelab
   values file.
8. Kubernetes rolls out the declared digest and reports health.

CI stops after proposing the Git change. It never deploys or rolls back the
cluster.

## Argo CD design

The platform bootstrap pins Argo CD Core v3.5.1 to immutable upstream commit
`109ca7ca71139e514114499d294a492e7910a965`.

Core mode was selected because the single-cluster lab does not need a permanent
API server, UI, OIDC, notifications, or multi-tenant RBAC. Four internal
components run with explicit requests and limits. Every Service is `ClusterIP`.

The `delivery-api` AppProject permits only:

- the public project repository;
- the in-cluster `delivery-api` namespace; and
- the resource types rendered by this chart.

The Application enables:

- automated sync, so merged Git changes are pulled without a CI deployment;
- pruning, so resources removed from Git are removed from the release; and
- self-healing, so unauthorized live drift is restored to the Git declaration.

Pruning and self-healing can also faithfully apply a harmful declaration. The
review boundary, Kubernetes readiness, Argo health, and Git revert remain part
of the safety model.

## Resource posture

The host snapshot before installation showed no memory, disk, or PID pressure.
The four Argo CD Core pods became ready with zero restarts.

| Component | Observed CPU | Observed memory |
| --- | ---: | ---: |
| Application controller | 2m | 30 MiB |
| ApplicationSet controller | 1m | 21 MiB |
| Redis | 14m | 9 MiB |
| Repository server | 2m | 25 MiB |
| **Total** | **19m** | **85 MiB** |

These measurements are a home-lab snapshot, not production sizing guidance.

## Failure and recovery behavior

Manual replica drift was observed as `OutOfSync` and corrected in 42 seconds.

A valid Git change set readiness to fail. Argo CD became `Synced` because the
cluster matched Git, while health became `Progressing` because the rollout could
not make the new Pod ready. The rolling-update policy retained two ready old
replicas. The bad release was detected 49 seconds after merge.

A Git revert restored the known-good declaration. Argo CD returned the
Application to `Synced` and `Healthy` 42 seconds after the revert commit.

A later application release was measured with Argo CD already active. Argo CD
started reconciliation 32 seconds after the promotion PR merged, and the two
updated replicas were healthy 43 seconds after merge. The in-cluster rollout
took 11 seconds from reconciliation start to the healthy observation.

## Verified acceptance checks

- [x] Representative API with liveness, readiness, version, and metrics.
- [x] Application and digest-promotion tests.
- [x] Strict Helm lint and digest-only rendering.
- [x] Helm install, test, upgrade, rollback, uninstall, and fresh install.
- [x] Public immutable image with commit identity, SBOM, and provenance.
- [x] Automated digest-promotion pull request.
- [x] CI with no cluster credential or deployment command.
- [x] Pinned, private, healthy, resource-limited Argo CD Core.
- [x] Healthy pull-based reconciliation.
- [x] Manual drift detection and correction.
- [x] Bad readiness release and retained health evidence.
- [x] Durable Git-revert recovery with measured timing.
- [x] Sanitized public evidence, operator runbook, and release guide.

## Limitations

- Single-node k3s cannot demonstrate control-plane or workload high
  availability.
- A sampled successful request does not prove zero request loss.
- AppProject policy narrows this Application's declared scope, but the Argo CD
  controller remains a privileged in-cluster reconciler.
- Repository compromise can still produce harmful desired state.
- No progressive-delivery controller, admission policy, multi-cluster
  promotion, or production SLO is claimed.

See [the retained evidence](../evidence/) and [operator runbook](OPERATIONS.md).
