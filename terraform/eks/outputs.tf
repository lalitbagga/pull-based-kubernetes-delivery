output "cluster_name" {
  description = "Cluster name used by the explicit post-approval kubeconfig command."
  value       = aws_eks_cluster.this.name
}

output "aws_region" {
  description = "Region containing every resource in this experiment."
  value       = var.aws_region
}

output "managed_node_group_name" {
  description = "Managed node group to verify and destroy with the cluster."
  value       = aws_eks_node_group.this.node_group_name
}

output "vpc_id" {
  description = "VPC passed explicitly to the AWS Load Balancer Controller."
  value       = aws_vpc.this.id
}

output "load_balancer_controller_role_arn" {
  description = "IAM role annotated on the controller's Kubernetes service account. Keep this out of public evidence because it contains the AWS account ID."
  value       = aws_iam_role.load_balancer_controller.arn
}
