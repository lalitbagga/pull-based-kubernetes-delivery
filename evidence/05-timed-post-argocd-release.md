# Timed application release with Argo CD already active

Date: 2026-08-26

This experiment measures a normal application release after Argo CD was
already installed and healthy. The retained output contains only public Git and
image identifiers plus sanitized Kubernetes status. It excludes credentials,
cluster endpoints, internal IP addresses, node names, and private hostnames.

## Release trace

| Boundary | Observed value |
| --- | --- |
| Application commit | `84db89f7f968c5860b07a7efd6a42e21895d9e5c` |
| CI workflow | [Delivery API run 33015487039](https://github.com/lalitbagga/pull-based-kubernetes-delivery/actions/runs/33015487039) |
| Promotion pull request | [PR #3](https://github.com/lalitbagga/pull-based-kubernetes-delivery/pull/3) |
| Promotion merge commit | `eeb939e65484d6e987630967c92f808ab06bd1c3` |
| Promoted image | `ghcr.io/lalitbagga/delivery-api@sha256:f8303e07e737f40fa5479b73a148261cf4221f4d4b52ebf095b74d2cb4ef5be5` |
| Final application response | `{"service":"delivery-api","version":"84db89f7f968c5860b07a7efd6a42e21895d9e5c"}` |

The automated pull request changed one line in one file: the immutable
`image.digest` value in the homelab desired state. CI did not contact the
cluster or perform the merge.

## CI timing

| Event | UTC time or duration |
| --- | ---: |
| Workflow created | `2026-08-26T21:28:02Z` |
| Validation job | 14 seconds |
| Image publication and promotion job | 50 seconds |
| Workflow completion | `2026-08-26T21:29:16Z` |
| Total observed workflow window | 74 seconds |

## Pull-based rollout timing

| Event | UTC time | Time from promotion merge |
| --- | --- | ---: |
| Promotion PR merged | `2026-08-26T21:34:18Z` | 0 seconds |
| Argo CD operation started | `2026-08-26T21:34:50Z` | 32 seconds |
| New release observed healthy | `2026-08-26T21:35:01Z` | 43 seconds |

The observed reconciliation-start-to-healthy interval was 11 seconds. The
monitor began before the merge and sampled the cluster every two seconds, so
the healthy time has up to two seconds of sampling uncertainty.

## Rolling-update observation

During the transition, the Deployment already declared the new digest while a
request still reached an old ready Pod and returned the previous application
commit. This is expected rolling-update behavior: Kubernetes gradually replaces
old Pods instead of changing every replica at the same instant.

Completion required all of the following in the same observation:

- Argo CD reported `Synced` and `Healthy` with operation `Succeeded`;
- the Deployment declared the promoted immutable digest;
- two replicas were updated and ready; and
- `/version` returned the new application commit and service identity.

## Result

A reviewed Git merge was the only release instruction. Argo CD detected that
declaration without a CI cluster credential, reconciled it, and the application
became healthy 43 seconds after the promotion merge in this home-lab sample.
This is an observed lab measurement, not a production delivery SLO.
