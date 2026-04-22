output "rds_endpoint" {
  description = "RDS endpoint — paste into App repo DATABASE_URL secret"
  value       = module.database.rds_endpoint
}

output "rds_db_name" {
  value = module.database.rds_db_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs — hand to Member 4 (DevOps) for the App pipeline"
  value       = { for k, v in module.ecr.repositories : k => v.repository_url }
}

output "eks_endpoint" {
  value = module.compute.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.compute.cluster_name
}

output "app_assets_bucket" {
  value = module.storage.app_assets_bucket_name
}

output "database_url_format" {
  description = "Full DATABASE_URL format for App repo — substitute actual password"
  value       = "postgresql://${module.database.rds_username}:<PASSWORD>@${module.database.rds_endpoint}/${module.database.rds_db_name}?sslmode=require"
  sensitive   = false
}
