# Delivery API release guide

Application CI proves and publishes an artifact. It does not deploy to
Kubernetes. Git declares the immutable image digest, and Argo CD pulls the
reviewed declaration into the cluster.

## Application release

1. Create a branch and change the application or its tests.
2. Open a pull request. The validation job runs application tests, promotion
   tests, Helm lint, Helm rendering, and immutable-digest validation.
3. Review and merge the application pull request.
4. The `main` push job builds a Linux AMD64 image tagged with the full commit
   SHA, publishes it to GHCR, and records its registry digest.
5. CI creates an automation branch and opens a promotion pull request changing
   only `gitops/environments/homelab/values.yaml`.
6. Review the promotion pull request. Confirm that only `image.digest` changed
   and that the value matches `sha256:<64 hexadecimal characters>`.
7. Merge the promotion pull request. Argo CD detects `main`, renders the Helm
   chart with the environment values, and reconciles Kubernetes.

CI stops at step 5. It has repository and package permissions, but no
kubeconfig, cluster token, Argo CD credential, or cluster endpoint.

## Configuration-only release

For an environment change such as replica count or readiness configuration:

1. Change `gitops/environments/homelab/values.yaml` on a branch.
2. Open a pull request and wait for Helm validation.
3. Review the rendered behavior and merge.
4. Argo CD reconciles the new declaration.

A GitOps-only merge does not build a new image because the workflow's `push`
paths exclude environment-only changes.

## Release verification

```bash
kubectl -n argocd get application delivery-api \
  -o 'custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,OPERATION:.status.operationState.phase'

kubectl -n delivery-api rollout status deployment/delivery-api --timeout=180s

kubectl -n delivery-api get deployment delivery-api \
  -o jsonpath='desired_image={.spec.template.spec.containers[0].image}{"\n"}'

kubectl -n delivery-api exec deploy/delivery-api -- \
  wget --quiet --output-document=- http://127.0.0.1:8080/version
```

The release is complete when Argo CD is `Synced` and `Healthy`, the rollout is
complete, the Deployment declares the reviewed digest, and `/version` reports
the application commit used to build that image.

## Failed release

Do not repair only the live Deployment. Revert the incorrect Git commit or merge
a corrective pull request, then allow Argo CD to reconcile the durable source of
truth. Follow [the operator runbook](OPERATIONS.md) for diagnosis and recovery.

## Permission boundary

| Actor | Required authority |
| --- | --- |
| Pull-request validation | Read repository contents |
| Main-branch publication | Write the repository promotion branch and GHCR package |
| Human reviewer | Review and merge repository changes |
| Argo CD | Read the public repository and reconcile the in-cluster Application |
| Application CI | No Kubernetes or Argo CD authority |

## Evidence

The verified delivery and controlled recovery experiments are retained in the
repository's [evidence directory](../evidence/). A later application release was
timed continuously with Argo CD already active; its promotion merge, Argo CD
operation start, and healthy rollout are retained in
[the timed-release evidence](../evidence/05-timed-post-argocd-release.md).
