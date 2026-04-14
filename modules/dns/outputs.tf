output "app_dns_name" {
  description = "FQDN of the application — empty if hosted_zone_id was not provided"
  value       = var.hosted_zone_id != "" ? aws_route53_record.app[0].fqdn : ""
}
