data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.project_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "${var.project_name}-node"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

locals {
  node_policy_arns = {
    worker = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    cni    = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    ecr    = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  }
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each = local.node_policy_arns

  role       = aws_iam_role.eks_node.name
  policy_arn = each.value
}

# EKS publishes an OpenID Connect (OIDC) issuer for the cluster. Registering it
# with IAM lets one Kubernetes service account assume one AWS role without
# storing long-lived AWS access keys in the cluster.
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[length(data.tls_certificate.eks_oidc.certificates) - 1].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

locals {
  load_balancer_controller_namespace       = "kube-system"
  load_balancer_controller_service_account = "aws-load-balancer-controller"
  oidc_provider_name                       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

data "aws_iam_policy_document" "load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_name}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_name}:sub"
      values = [
        "system:serviceaccount:${local.load_balancer_controller_namespace}:${local.load_balancer_controller_service_account}",
      ]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.project_name}-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume_role.json
}

# This policy is copied unchanged from the controller's pinned v3.3.0 release.
resource "aws_iam_policy" "load_balancer_controller" {
  name   = "${var.project_name}-load-balancer-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller-v3.3.0.json")
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}
