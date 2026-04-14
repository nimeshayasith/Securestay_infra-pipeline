variable "vpc_id" {
  description = "VPC ID where the RDS instance will be deployed"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (must span at least 2 AZs for multi-AZ)"
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group ID of the EKS worker nodes — granted ingress on port 5432"
}

variable "db_username" {
  description = "PostgreSQL master username"
  default     = "securestay_admin"
}

variable "db_password" {
  description = "PostgreSQL master password — injected via TF_VAR_db_password GitHub Secret"
  sensitive   = true
}
