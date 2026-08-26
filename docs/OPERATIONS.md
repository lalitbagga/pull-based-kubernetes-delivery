# Delivery API operator runbook

This runbook covers the Argo CD-managed `delivery-api` workload. Git is the
durable source of truth. Direct cluster changes may be used for diagnosis, but
they are not the durable recovery mechanism.

The commands intentionally omit node names, cluster endpoints, and internal IP
addresses so their output can be retained safely.

## Healthy baseline

```bash
kubectl -n argocd get application delivery-api \
  -o 'custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,OPERATION:.status.operationState.phase'

kubectl -n delivery-api get deployment delivery-api \
  -o 'custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas'

kubectl -n delivery-api get pods \
  -l app.kubernetes.io/name=delivery-api \
  -o 'custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount'
```

Expected state is `Synced`, `Healthy`, operation `Succeeded`, two ready and
available replicas, and zero unexpected restarts.

## Failed synchronization

Symptom: Argo CD reports `OutOfSync`, `Unknown`, or a failed operation.

1. Read the Application conditions and recent namespace events:

   ```bash
   kubectl -n argocd get application delivery-api \
     -o jsonpath='{range .status.conditions[*]}{.type}{": "}{.message}{"\n"}{end}'

   kubectl -n delivery-api get events \
     --sort-by=.metadata.creationTimestamp
   ```

2. Reproduce rendering from the same Git checkout:

   ```bash
   helm lint helm/delivery-api --strict \
     --values gitops/environments/homelab/values.yaml

   helm template delivery-api helm/delivery-api \
     --namespace delivery-api \
     --values gitops/environments/homelab/values.yaml >/dev/null
   ```

3. Fix the declaration in Git and use a pull request. Do not apply a second,
   competing Helm release to the `delivery-api` namespace.

## Degraded or progressing rollout

Symptom: Git is `Synced`, but health is `Progressing` or `Degraded`.

```bash
kubectl -n delivery-api rollout status deployment/delivery-api --timeout=60s

kubectl -n delivery-api get pods \
  -l app.kubernetes.io/name=delivery-api \
  -o 'custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount'

kubectl -n delivery-api describe deployment delivery-api

kubectl -n delivery-api get events \
  --sort-by=.metadata.creationTimestamp
```

Check readiness separately from liveness. A running Pod can be intentionally
excluded from Service traffic when its readiness probe fails.

Sample current Service availability without exposing the Service externally:

```bash
kubectl -n delivery-api exec deploy/delivery-api -- \
  wget --quiet --output-document=- http://delivery-api/ready
```

One successful request proves availability at that moment; it is not evidence
that every request succeeded.

## Durable rollback

Identify the bad commit or merge from reviewed Git history. Create a revert
commit; do not use `kubectl rollout undo` as the durable fix because that would
leave Git declaring the bad state.

For a normal commit:

```bash
git revert --no-edit <bad-commit>
```

For a pull-request merge commit:

```bash
git revert --mainline 1 --no-edit <bad-merge-commit>
```

Push the recovery through the repository's approved review path. During a
time-sensitive lab recovery, a direct revert push is acceptable only when the
repository policy explicitly permits it and the action is retained in history.

Watch recovery:

```bash
kubectl -n argocd get application delivery-api --watch
kubectl -n delivery-api rollout status deployment/delivery-api --timeout=180s
```

Recovery is complete only when Git contains the known-good declaration, Argo CD
is `Synced` and `Healthy`, the Deployment is fully available, and `/ready`
returns success.

## Drift response

If an operator changes an Argo-managed object directly, self-healing should
restore the Git declaration. Investigate the actor and reason before repeatedly
fighting the controller.

```bash
kubectl -n argocd get application delivery-api \
  -o 'custom-columns=SYNC:.status.sync.status,HEALTH:.status.health.status'

kubectl -n delivery-api get deployment delivery-api \
  -o 'custom-columns=DESIRED:.spec.replicas,READY:.status.readyReplicas'
```

If the manual change was intentional, encode it in Git through review. If it was
not authorized, preserve the audit evidence and investigate repository and
cluster access.

## Escalation and stop conditions

Stop experimentation and investigate when:

- existing workloads become unhealthy;
- the node reports memory, disk, or PID pressure;
- ready replicas fall below the safe minimum;
- Argo CD repeatedly fails to reconcile the same reviewed commit; or
- recovery would require deleting non-disposable namespaces or persistent data.

Never retain kubeconfig content, tokens, Secrets, private endpoints, node names,
or internal IP addresses in public evidence.

## Tested scenarios

The commands and decisions in this runbook map to retained evidence:

- [baseline and drift correction](../evidence/01-baseline-and-drift.md);
- [bad readiness and Git-revert recovery](../evidence/02-bad-readiness-and-revert.md);
- [isolated Helm lifecycle validation](../evidence/03-helm-lifecycle.md); and
- [final Git, Argo CD, and runtime agreement](../evidence/04-final-state-agreement.md).
