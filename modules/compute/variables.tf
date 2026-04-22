variable "cluster_name" {
  description = "Name of the EKS cluster"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes (must span at least 2 AZs)"
  type        = list(string)
}

variable "eks_cluster_role_arn" {
  description = "IAM role ARN for the EKS cluster control plane"
}

variable "eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
}
