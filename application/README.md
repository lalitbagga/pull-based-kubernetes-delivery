# Delivery API

This small HTTP service is the representative workload for the pull-based
delivery project. It is intentionally more useful than a static Nginx page but
small enough for the constrained home server.

## Why this workload

- `/health` proves the process is alive.
- `/ready` proves whether the Pod should receive Service traffic.
- `/version` connects a running Pod to an application commit.
- `/metrics` exposes a small Prometheus-compatible surface for later labs.
- `READINESS_MODE=fail` creates a controlled readiness failure while the process
  and liveness endpoint remain healthy.
- The runtime has no external service, database, credential, or package
  dependency.

This is a public lab service. It must never contain personal data, secrets, or
private infrastructure identifiers.

## Local verification

```bash
npm test
APP_VERSION=local npm start
docker build --build-arg APP_VERSION=<commit-sha> -t delivery-api:local .
```

In another terminal:

```bash
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/ready
curl --fail http://127.0.0.1:8080/version
curl --fail http://127.0.0.1:8080/metrics
```

Set `READINESS_MODE=fail` only during the planned bad-readiness experiment. It
makes `/ready` return HTTP 503 but leaves `/health` at HTTP 200.

CI passes the full application commit SHA through the `APP_VERSION` build
argument. The resulting image returns that commit from `/version`. Kubernetes'
container `imageID` separately proves the immutable registry digest that ran.
