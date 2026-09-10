# Temporary EKS infrastructure

This folder creates the smallest useful EKS target for the portability test.
It must be planned and reviewed before any paid AWS resources are created.

Terraform-managed resources:

- one VPC with two public subnets and no NAT gateway;
- one EKS 1.36 control plane with its public API restricted to one `/32` and
  private API access for worker nodes inside the VPC;
- one managed node group with one AMD64 `c7i-flex.large` node and a 20 GiB
  gp3 disk; this account reported that size as Free Tier eligible;
- cluster and node IAM roles, an explicit EKS access entry for a stable
  non-root operator, and the standard VPC CNI, kube-proxy, and CoreDNS add-ons;
- a cluster-specific OIDC provider and IRSA role for the AWS Load Balancer
  Controller; and
- the controller's official permissions, copied from its pinned v3.3.0
  release.

Terraform creates the AWS-side identity for the Load Balancer Controller, but
does not install the controller. After the cluster is healthy, Helm installs
the pinned controller chart and connects its Kubernetes service account to the
IAM role. Argo CD Core and the application are installed afterward.

The access entry must use a stable non-root IAM user or role. Root and temporary
STS session identities are rejected by the input validation because they are
not suitable day-to-day Kubernetes operator identities.

Never commit `terraform.tfvars`, Terraform state, a kubeconfig, an account ID,
an IAM principal ARN, or a public IP address.
