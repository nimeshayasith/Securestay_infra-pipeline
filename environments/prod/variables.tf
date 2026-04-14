variable "aws_region" {
  description = "AWS region for all resources"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "securestay-eks"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "db_username" {
  default = "securestay_admin"
}

variable "db_password" {
  description = "Injected via TF_VAR_db_password GitHub Secret — never set in tfvars"
  sensitive   = true
}

variable "rabbitmq_password" {
  description = "Injected via TF_VAR_rabbitmq_password GitHub Secret — never set in tfvars"
  sensitive   = true
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID. Leave empty to skip DNS record creation."
  default     = ""
}
