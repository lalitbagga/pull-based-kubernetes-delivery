variable "aws_profile" {
  description = "Optional local AWS CLI profile. Leave null to use standard AWS environment credentials."
  type        = string
  default     = null
  nullable    = true
}

variable "aws_region" {
  description = "AWS Region for every resource in this experiment."
  type        = string
  default     = "ca-central-1"
}

variable "developer_cidr" {
  description = "Current public IPv4 address in CIDR form, used to restrict the EKS API."
  type        = string

  validation {
    condition     = can(cidrhost(var.developer_cidr, 0)) && endswith(var.developer_cidr, "/32")
    error_message = "Use one IPv4 address followed by /32, for example 203.0.113.10/32."
  }
}

variable "cluster_admin_principal_arn" {
  description = "Stable IAM user or role ARN used for temporary kubectl access. Never commit its value."
  type        = string

  validation {
    condition = (
      startswith(var.cluster_admin_principal_arn, "arn:") &&
      strcontains(var.cluster_admin_principal_arn, ":iam::") &&
      !strcontains(var.cluster_admin_principal_arn, ":root") &&
      !strcontains(var.cluster_admin_principal_arn, ":sts::")
    )
    error_message = "Use a stable non-root IAM user or role ARN, not a root or STS session ARN."
  }
}

variable "project_name" {
  description = "Short name used in resource names and tags."
  type        = string
  default     = "gitops-eks-portability"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version under standard support."
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "Allowed EC2 type for the single-node managed node group."
  type        = list(string)
  default     = ["c7i-flex.large"]
}

variable "vpc_cidr" {
  description = "Private address range used only by this temporary VPC."
  type        = string
  default     = "10.42.0.0/16"
}
