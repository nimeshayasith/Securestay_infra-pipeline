output "app_assets_bucket_name" {
  value = aws_s3_bucket.app_assets.id
}

output "app_assets_bucket_arn" {
  value = aws_s3_bucket.app_assets.arn
}

output "access_logs_bucket_name" {
  value = aws_s3_bucket.access_logs.id
}
