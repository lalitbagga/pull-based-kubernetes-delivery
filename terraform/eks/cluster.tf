resource "aws_eks_cluster" "this" {
  name     = var.project_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  upgrade_policy {
    support_type = "STANDARD"
  }

  vpc_config {
    # The developer uses the restricted public endpoint. Worker nodes use this
    # private endpoint so their API traffic never depends on a public IP allowlist.
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.developer_cidr]
    subnet_ids              = values(aws_subnet.public)[*].id
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.cluster_admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.project_name}-amd64"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = values(aws_subnet.public)[*].id

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  disk_size      = 20
  instance_types = var.node_instance_types

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    workload = "temporary-portability-test"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_node]
}

locals {
  eks_addons = toset([
    "coredns",
    "kube-proxy",
    "vpc-cni",
  ])
}

data "aws_eks_addon_version" "this" {
  for_each = local.eks_addons

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "this" {
  for_each = local.eks_addons

  addon_name                  = each.key
  addon_version               = data.aws_eks_addon_version.this[each.key].version
  cluster_name                = aws_eks_cluster.this.name
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.this]
}
