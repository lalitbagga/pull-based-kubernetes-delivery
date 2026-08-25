# Pull-Based Kubernetes Delivery

An evidence-driven Kubernetes delivery project that removes direct cluster
authority from application CI.

CI tests the application, builds and publishes an immutable container image,
and proposes a Git pull request containing the registry digest. Argo CD—not
application CI—will reconcile the approved Git declaration into Kubernetes.

## Delivery boundary

```text
Application commit
        |
        v
CI: test -> build AMD64 image -> publish commit tag -> resolve digest
        |
        v
Automated pull request updates the homelab image digest
        |
        v
Human review and merge
        |
        v
Argo CD pulls approved desired state
        |
        v
Helm renders Deployment, Service, ConfigMap, and ServiceAccount
        |
        v
Kubernetes rollout and health signals
```

Application CI has registry and Git proposal permissions. It has no kubeconfig,
Kubernetes token, cluster endpoint, `kubectl` deployment, direct Helm release,
or Argo CD credential.

## Repository structure

```text
application/                    Dependency-free Node.js HTTP service and tests
helm/delivery-api/              Digest-only Kubernetes packaging
gitops/environments/homelab/    Environment desired state
scripts/                        Tested digest-promotion automation
.github/workflows/              Test, publish, and promotion workflow
docs/                           Architecture and authority decisions
```

## Application behavior

The representative service exposes:

| Endpoint | Purpose |
|---|---|
| `/health` | Process liveness |
| `/ready` | Service traffic eligibility |
| `/version` | Source commit baked into the image |
| `/metrics` | Prometheus-compatible request and uptime metrics |

`READINESS_MODE=fail` creates a controlled readiness failure while liveness
remains healthy. This supports the planned failed-release and Git-revert
recovery experiment.

## Local validation

```bash
npm --prefix application test
node --test scripts/test/update-gitops-digest.test.mjs
helm lint --strict helm/delivery-api \
  --values gitops/environments/homelab/values.yaml
helm template delivery-api helm/delivery-api \
  --namespace delivery-api \
  --values gitops/environments/homelab/values.yaml
```

The image is built for the home server's AMD64 architecture:

```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg APP_VERSION="$(git rev-parse HEAD)" \
  --load \
  --tag delivery-api:local \
  application
```

## Verification status

Verified locally:

- application tests;
- digest-updater safety tests;
- restricted AMD64 container execution;
- commit identity through `/version` and OCI image metadata;
- strict Helm lint and rendering; and
- rejection of mutable image references.

Not yet claimed as verified:

- GitHub-hosted CI publication;
- GHCR digest promotion pull request;
- complete Helm lifecycle against k3s;
- private Argo CD installation and reconciliation;
- drift correction;
- failed-readiness rollout behavior;
- Git-revert recovery; or
- detection and recovery measurements.

Repository configuration proves intent. Retained runtime evidence will be added
only after each behavior is observed and sanitized.

## Planned operational proof

1. Publish a commit-addressable AMD64 image and promote its immutable digest.
2. Validate Helm install, test, upgrade, rollback, uninstall, and fresh install.
3. Install a pinned, resource-constrained, private Argo CD deployment.
4. Trace one commit through CI, Git, Argo CD, and the running Pod.
5. Introduce safe live drift and observe reconciliation.
6. Merge a bad readiness declaration and retain Kubernetes and Argo CD signals.
7. Revert Git, observe recovery, and measure detection and recovery time.

See [the architecture record](docs/ARCHITECTURE.md) for component ownership,
credentials, resource posture, and current limitations.
