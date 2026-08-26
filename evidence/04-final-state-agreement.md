# Final Git, Argo CD, and runtime agreement

Date: 2026-08-25

This closeout capture contains public artifact identifiers and sanitized
Kubernetes state. It excludes credentials, cluster endpoints, internal IP
addresses, node names, and private hostnames.

## Final control-plane state

| Signal | Observed value |
| --- | --- |
| Argo CD synchronization | `Synced` |
| Argo CD health | `Healthy` |
| Last Argo CD operation | `Succeeded` |
| Declared readiness mode | `ready` |
| Desired replicas | 2 |
| Ready application pods | 2 |

## Source-to-runtime identity

| Identity boundary | Value |
| --- | --- |
| Application source commit returned by `/version` | `730d4e4d97635abd9286f618b3049be572e1f3a5` |
| GitOps image declaration | `ghcr.io/lalitbagga/delivery-api@sha256:170bcc91b9c4bfcbdc194c004cb38d6c89094e9b49a1a128ed3a0507976fef97` |
| Deployment image declaration | `ghcr.io/lalitbagga/delivery-api@sha256:170bcc91b9c4bfcbdc194c004cb38d6c89094e9b49a1a128ed3a0507976fef97` |
| Runtime image ID, pod 1 | `ghcr.io/lalitbagga/delivery-api@sha256:170bcc91b9c4bfcbdc194c004cb38d6c89094e9b49a1a128ed3a0507976fef97` |
| Runtime image ID, pod 2 | `ghcr.io/lalitbagga/delivery-api@sha256:170bcc91b9c4bfcbdc194c004cb38d6c89094e9b49a1a128ed3a0507976fef97` |

Both pods reported `ready=true`. Their container-runtime image field also
resolved to content identifier
`sha256:b47937537c2b0ab07078f1b9282ade52bf090f073f0b99f1bfd6c1bf4e31fc8b`.
The retained runtime image ID is the registry identity used for the release
trace because it matches the reviewed GitOps and Deployment digest exactly.

The repository contains later configuration, experiment, revert, evidence, and
documentation commits after the application source commit. That is expected:
`/version` identifies the application artifact source, while Git history records
subsequent environment and operational changes.

## Final state check

- Git declares readiness mode `ready` and the immutable image digest.
- Argo CD reports that the cluster is synchronized with Git and healthy.
- The Deployment declares the same immutable image digest.
- Both running pods report that digest as their runtime image ID.
- The application reports the source commit baked into the image by CI.
- The bad-readiness experiment was reversed by an auditable Git revert rather
  than an untracked live-cluster repair.
- Disposable Helm lifecycle namespaces were removed after testing.

## Result

The durable Git declaration, Argo CD reconciliation state, Kubernetes workload,
runtime artifact identity, and application version agree at project closeout.
