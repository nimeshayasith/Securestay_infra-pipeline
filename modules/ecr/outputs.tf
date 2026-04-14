output "repositories" {
  description = "Map of service name → ECR repository resource"
  value       = aws_ecr_repository.services
}
