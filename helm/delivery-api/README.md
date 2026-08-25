# Delivery API Helm chart

This chart declares the Kubernetes objects owned by the delivery API release:
a Deployment, ClusterIP Service, ConfigMap, ServiceAccount, and Helm smoke-test
Pod. It deliberately does not create an Ingress or a Secret.

The image is always rendered as `repository@sha256:digest`. Kubernetes therefore
runs the exact artifact selected in Git instead of resolving a mutable tag.

The application commit is baked into the image during CI and returned by the
service's `/version` endpoint. The Pod's `imageID` independently reports the
registry digest. Keeping these two identifiers separate makes the release
traceable from source commit to published artifact to running container.

The digest in `values.yaml` is an all-zero validation placeholder and is not a
deployable artifact. The GitOps environment values file will contain the real
registry digest after CI publishes the image.

## Local validation

```bash
helm lint helm/delivery-api
helm template delivery-api helm/delivery-api --namespace delivery-api
```

These commands validate and render YAML only. They do not contact a cluster.
