# Bad-readiness release and Git-revert recovery evidence

Date: 2026-08-25 (UTC)

This record contains only public repository identifiers and sanitized Kubernetes
output. It excludes credentials, internal addresses, node names, and private
hostnames.

## Experiment design

[Pull request #2](https://github.com/lalitbagga/pull-based-kubernetes-delivery/pull/2)
changed the environment configuration from:

```yaml
readinessMode: ready
```

to:

```yaml
readinessMode: fail
```

The configuration is valid YAML and passes the chart schema and Helm lint. At
runtime, however, the `/ready` endpoint deliberately returns HTTP 503. The
Deployment uses a rolling update with `maxUnavailable: 0`, allowing the existing
ready replicas to remain available while the replacement fails readiness.

## Detection

| Event | UTC timestamp | Observation |
| --- | --- | --- |
| Bad-readiness PR merged | 2026-08-25T22:36:35Z | Merge commit `69ac4fe6de392aed4affc573ea20a2bb3f4ee59f` |
| Bad release detected | 2026-08-25T22:37:24Z | Mode `fail`; Argo CD `Synced`; health `Progressing` |

Measured detection time: **49 seconds**.

`Synced` showed that the cluster matched the intentionally bad Git state.
`Progressing` showed that Kubernetes could not complete the rollout because the
new replica failed its readiness probe.

At detection time, the Deployment reported one updated replica and two ready
replicas. A pod sample showed:

| Pod group | Ready | Status | Restarts |
| --- | --- | --- | ---: |
| New bad-readiness ReplicaSet | false | Running | 0 |
| Previous healthy ReplicaSet | true | Running | 0 |
| Previous healthy ReplicaSet | true | Running | 0 |

A request through the ClusterIP Service during the failed rollout returned:

```json
{"status":"ready"}
```

This sampled request proves that the Service remained available at that moment.
It does not claim that every request during the experiment succeeded.

## Recovery

Recovery used Git history rather than a manual Kubernetes patch:

```bash
git revert --mainline 1 69ac4fe6de392aed4affc573ea20a2bb3f4ee59f
git push
```

| Event | UTC timestamp | Observation |
| --- | --- | --- |
| Revert committed | 2026-08-25T22:39:52Z | Revert commit `b0fca6f5d83aa9a51b0d52fd5adac256bb941203` |
| Healthy state restored | 2026-08-25T22:40:34Z | Mode `ready`; `Synced`; `Healthy`; two updated and ready replicas |

Measured recovery time after the Git revert: **42 seconds**.

The total interval from bad merge to healthy recovery was 239 seconds. This
includes the deliberate observation period and human decision time before the
revert; it should not be confused with the 42-second reconciliation time after
the recovery commit.

## Result

The experiment demonstrated a valid-but-bad release, readiness-based rollout
protection, Argo CD health detection, and recovery through an auditable Git
revert. CI held no Kubernetes credential and issued no cluster deployment or
rollback command.
