locals {
  services = [
    "api-gateway",
    "auth-service",
    "booking-service",
    "payment-service",
    "notification-service",
  ]
}

resource "aws_ecr_repository" "services" {
  for_each             = toset(local.services)
  name                 = "securestay/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }

  tags = {
    Project   = "SecureStay"
    Service   = each.key
    ManagedBy = "Terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
