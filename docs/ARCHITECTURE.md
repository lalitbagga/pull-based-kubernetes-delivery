# Pull-based delivery architecture

Status: implementation in progress. Claims remain unverified until retained
cluster evidence passes the project exit gates.

## Representative workload decision

The project uses `application/delivery-api`, a small public HTTP service with
health, readiness, version, and metrics endpoints. It has no database, external
dependency, personal data, runtime credential, or Secret. It is more useful than
a static Nginx page while remaining safe on the constrained server.

A bad release can set `config.readinessMode: fail` through Git. The process stays
alive, but Kubernetes removes the new Pod from Service endpoints because `/ready`
returns HTTP 503. This separates application liveness from traffic eligibility.

## Ownership boundary

| Component | Owns | May not do |
|---|---|---|
| Application source | Code, tests, Dockerfile, commit version | Change the live cluster |
| Application CI | Test, build, publish a commit-tagged image, propose a digest PR | Hold kubeconfig or call the Kubernetes API |
| Helm chart | Repeatable Kubernetes object templates and safe defaults | Select a logically correct release |
| GitOps desired state | Environment replica count, readiness mode, and immutable image digest | Mutate the cluster by itself |
| Human reviewer | Accept or reject the proposed environment change | Bypass Git as the durable repair |
| Argo CD | Compare Git with live state and reconcile approved declarations | Build images or decide that a bad declaration is correct |
| Kubernetes | Run workloads and report rollout and health state | Change the durable Git declaration |

No Terraform module, CI workflow, or manual Helm release will co-own the
delivery-api Deployment after Argo CD assumes ownership.

## Credential boundary

The application workflow receives GitHub's short-lived job token with these
job-scoped permissions:

- read repository content during validation;
- publish only through the repository's GHCR permission;
- create a branch and promotion pull request during the publish job.

It receives no kubeconfig, Kubernetes token, cluster address, SSH credential, or
Argo CD credential. The workflow contains no `kubectl`, direct `helm install` or
`helm upgrade`, or Kubernetes API call.

The intended portfolio repository and image are public after a separate
sanitization review. That avoids a registry pull secret and an Argo CD repository
credential in the first lab iteration. If either remains private, credentials
must be supplied out of band and must never be committed or retained in rendered
evidence.

## Desired release path

1. A commit reaches `main`.
2. CI tests the API and digest-update logic.
3. CI builds an AMD64 image with the full commit SHA baked into `/version`.
4. CI pushes only the commit-SHA tag and records the registry SHA-256 digest.
5. CI opens a pull request changing only the homelab digest.
6. A human reviews and merges the declaration.
7. Argo CD detects the Git change and reconciles the private k3s cluster.
8. `/version`, the Pod `imageID`, and Git prove commit, artifact, and deployment.

CI stops after step 5. It does not deploy.

## Cluster boundary and resource posture

- Workload namespace: `delivery-api`
- Argo CD namespace: `argocd`
- Application exposure: ClusterIP initially; no public Ingress
- Argo CD exposure: ClusterIP only; temporary authenticated port-forward when needed
- Node architecture: AMD64
- Baseline: 6/6 Pods Ready; node Ready with no reported pressure
- Baseline utilization: 13% CPU and 70% memory at the observed snapshot

Because memory use is already significant, Argo CD will use a non-HA,
single-cluster lab profile with optional controllers disabled unless required.
Resource use must be recorded before and after installation. Installation stops
if existing workload health declines.

## Current limitations and blockers

- This local repository has no Git remote, so CI, GHCR publication, and promotion
  pull requests cannot run yet.
- The all-zero digest is a schema-validation placeholder, not a deployable image.
- Helm cluster install, upgrade, rollback, uninstall, and fresh-install gates are
  not yet demonstrated.
- Argo CD is not installed and no reconciliation claim is verified.
- No drift, bad-release, or Git-revert timing evidence exists yet.

## Acceptance checks

- [x] API tests pass locally.
- [x] AMD64 container builds and passes a restricted-runtime smoke test.
- [x] Commit identity is baked into the image and returned by `/version`.
- [x] Helm strict lint and render pass with digest-only desired state.
- [x] Promotion updater accepts one SHA-256 digest and rejects unsafe input.
- [x] CI workflow contains no cluster deployment authority.
- [ ] Repository sanitization review and Git remote are complete.
- [ ] CI publishes an immutable image and opens the first promotion PR.
- [ ] Helm lifecycle validation passes against k3s.
- [ ] Minimal private Argo CD installation stays within the resource envelope.
- [ ] Drift, bad readiness, and Git-revert experiments are retained and timed.
