output "cluster_endpoint" {
  description = "EKS cluster API endpoint — used by Helm and Kubernetes providers"
  value       = aws_eks_cluster.securestay.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate — used by Helm and Kubernetes providers"
  value       = aws_eks_cluster.securestay.certificate_authority[0].data
}

output "cluster_name" {
  value = aws_eks_cluster.securestay.name
}

output "node_security_group_id" {
  description = "Cluster security group ID automatically created by EKS — passed to RDS security group"
  value       = aws_eks_cluster.securestay.vpc_config[0].cluster_security_group_id
}
